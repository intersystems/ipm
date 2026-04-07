Include %syPrompt

/// Database packaging lifecycle. Packages a module as an IRIS.DAT file inside a .tgz.
/// The .tgz contains IRIS.DAT, an enriched module.xml with SHA-256 checksum,
/// and a dependencies.xml compiling all dependency manifests.
Class %IPM.Lifecycle.Database Extends %IPM.Lifecycle.Base
{

Property Payload As %Stream.TmpBinary [ Private ];

Parameter PACKAGING As STRING [ Final ] = "database";

/// Entry point for database packaging.
Method %Package(ByRef params) As %Status
{
    set sc = $$$OK
    set tempDBName = ""
    set tempDBPath = ""
    set oldDBName = ""
    set stagingDir = ""
    set dbRemapped = 0
    set generatedExports = ""
    set ns = $namespace
    new $namespace

    try {
        set verbose = $get(params("Verbose"))
        set includeTests = $get(params("IncludeTestResources"), 0)
        set useCurrentDB = $get(params("UseCurrentDB"), 0)
        set dbName = $get(params("DatabaseName"), "")

        write:verbose !, "Starting database packaging: ", ..Module.Name, " v", ..Module.VersionString

        // Validate IPM is externally mapped — must not be in the routines DB being packaged
        write:verbose !, "Validating IPM mapping..."
        do ..ValidateIPMNotInRoutinesDB()

        if useCurrentDB {
            // -use-current-db: use the existing routines DB directly, no remapping
            // Note: globals mapping is unchanged throughout — IPM metadata stays in globals DB
            set $namespace = "%SYS"
            $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
            set $namespace = ns
            set curDBName = $get(nsProps("Routines"))
            set tempDBPath = ##class(%Library.File).NormalizeDirectory(
                ##class(%Library.File).ManagerDirectory() _ curDBName)
        } else {
            // Default: create a fresh empty temp database
            write:verbose !, "Creating temporary database..."
            do ..CreateTempDatabase(.dbName, .tempDBPath)
            set tempDBName = dbName

            // Export Generated resources from source namespace BEFORE remapping.
            // Once the old DB is dismounted, compiled Generated classes are inaccessible.
            write:verbose !, "Exporting generated resources from source namespace..."
            do ..ExportGeneratedResources(ns, includeTests, .params, .generatedExports)

            // Remap namespace routines to the temp DB
            // Note: globals mapping is unchanged — ^IPM.* globals remain in the real globals DB
            // and will NOT enter the temp IRIS.DAT. No cleanup step is needed.
            write:verbose !, "Remapping namespace routines to temp database..."
            set dbRemapped = 1
            do ..RemapRoutinesDB(ns, tempDBName, .oldDBName)

            // Load and compile module resources into the temp DB
            write:verbose !, "Loading resources into temp database..."
            do ..LoadResourcesIntoDatabase(ns, includeTests, .params)

            // Import generated resources into the temp namespace
            if $listlength(generatedExports) > 0 {
                write:verbose !, "Importing generated resources into temp database..."
                new $namespace
                set $namespace = ns
                set ptr = 0
                while $listnext(generatedExports, ptr, tempFile) {
                    $$$ThrowOnError($system.OBJ.Load(tempFile, "ck"))
                    do ##class(%Library.File).Delete(tempFile)
                }
                set generatedExports = ""
            }

            // Restore namespace mapping before packaging
            write:verbose !, "Restoring namespace routines..."
            do ..RestoreRoutinesDB(ns, oldDBName, tempDBName, tempDBPath)
            set dbRemapped = 0
        }

        // Compute SHA-256 checksum of the IRIS.DAT
        write:verbose !, "Computing SHA-256 checksum..."
        set irisDAT = tempDBPath _ "IRIS.DAT"
        set checksumHex = ..ComputeSHA256Hex(irisDAT)
        write !, "  Checksum: ", checksumHex

        // Assemble staging dir and create .tgz
        set stagingDir = ##class(%Library.File).NormalizeDirectory(
            ##class(%Library.File).TempFilename()) _ "stage/"
        set packageFile = ..AssemblePackage(irisDAT, stagingDir, checksumHex, .params)
        set params("PackageFile") = packageFile

        // Store in Payload for the Publish phase
        set srcStream = ##class(%Stream.FileBinary).%New()
        $$$ThrowOnError(srcStream.LinkToFile(packageFile))
        $$$ThrowOnError(..Payload.CopyFrom(srcStream))

    } catch ex {
        set sc = ex.AsStatus()
    }

    // Safety net: restore namespace if an error occurred mid-remap
    if dbRemapped && (oldDBName '= "") {
        set restoreSC = $$$OK
        try {
            do ..RestoreRoutinesDB(ns, oldDBName, tempDBName, tempDBPath)
        } catch restoreEx {
            set restoreSC = restoreEx.AsStatus()
        }
        if $$$ISERR(restoreSC) {
            write !, "ERROR: Failed to restore namespace routines DB — manual intervention required."
            write !, $system.Status.GetErrorText(restoreSC)
        }
    }

    // Clean up any generated resource export temp files not yet imported (error path)
    set ptr = 0
    while $listnext(generatedExports, ptr, tempFile) {
        if ##class(%Library.File).Exists(tempFile) {
            do ##class(%Library.File).Delete(tempFile)
        }
    }

    // Clean up staging directory
    if (stagingDir '= "") && ##class(%Library.File).DirectoryExists(stagingDir) {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(stagingDir)
    }

    // Clean up temp DB directory (IRIS.DAT already copied into the .tgz by AssemblePackage)
    if (tempDBName '= "") && (tempDBPath '= "") && ##class(%Library.File).DirectoryExists(tempDBPath) {
        new $namespace
        set $namespace = "%SYS"
        do ##class(%Library.File).RemoveDirectoryTree(tempDBPath)
    }

    quit sc
}

/// Validates that %IPM classes are not stored in the current namespace's local routines database.
/// IPM must be mapped from another namespace so it survives a database swap.
Method ValidateIPMNotInRoutinesDB()
{
    if ##class(%Dictionary.ClassDefinition).%ExistsId("%IPM.Main") {
        if ..IsClassInLocalRoutinesDB("%IPM.Main") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"IPM must be mapped from another namespace. %IPM classes were found in the current routines database. Map IPM from a non-system code namespace before packaging."))
        }
    }
}

/// Returns 1 if the given class is stored locally in the current namespace's routines database
/// (as opposed to being mapped from another namespace or database).
ClassMethod IsClassInLocalRoutinesDB(className As %String) As %Boolean
{
    quit '##class(%Library.RoutineMgr).IsMapped(className _ ".CLS")
}

/// Creates a new empty IRIS.DAT in a temporary directory and registers it in Config.Databases.
/// dbName: caller-supplied name, or auto-generated if empty.
/// Sets dbPath to the normalized directory path (trailing slash) containing IRIS.DAT.
ClassMethod CreateTempDatabase(
	ByRef dbName As %String,
	Output dbPath As %String)
{
    new $namespace
    set $namespace = "%SYS"

    if dbName = "" {
        set dbName = "IPMDBPKG" _ $translate(
            $system.Encryption.Base64Encode($system.Encryption.GenCryptRand(6)), "+/=", "")
    }

    set dbPath = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).ManagerDirectory() _ dbName)

    if '##class(%Library.File).CreateDirectory(dbPath, .result) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to create temp database directory: " _ dbPath _ " - " _ result))
    }

    $$$ThrowOnError(##class(SYS.Database).CreateDatabase(dbPath))

    set dbProps("Directory") = dbPath
    set dbProps("MountRequired") = 0
    $$$ThrowOnError(##class(Config.Databases).Create(dbName, .dbProps))

    set mountSC = ##class(SYS.Database).MountDatabase(dbPath)
    if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
        $$$ThrowOnError(mountSC)
    }
}

/// Dismounts the current routines DB, remaps the namespace to newDBName, and stores
/// the original DB name in oldDBName for later restoration.
ClassMethod RemapRoutinesDB(
	ns As %String,
	newDBName As %String,
	Output oldDBName As %String)
{
    new $namespace
    set $namespace = "%SYS"

    $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
    set oldDBName = $get(nsProps("Routines"))

    set oldPath = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).ManagerDirectory() _ oldDBName)

    // Remap namespace to new DB first, then dismount old DB
    // This avoids a window where the namespace has no mounted routines DB
    set nsProps("Routines") = newDBName
    $$$ThrowOnError(##class(Config.Namespaces).Modify(ns, .nsProps))
    $$$ThrowOnError(##class(SYS.Database).DismountDatabase(oldPath))
}

/// Dismounts the temp DB, remaps the namespace back to oldDBName, remounts it,
/// and removes the temp database config entry.
/// Logs warnings on partial failures but always attempts full restoration.
ClassMethod RestoreRoutinesDB(
	ns As %String,
	oldDBName As %String,
	tempDBName As %String,
	tempDBPath As %String)
{
    new $namespace
    set $namespace = "%SYS"

    // Dismount temp DB (best-effort — log but continue)
    set dismountSC = ##class(SYS.Database).DismountDatabase(tempDBPath)
    if $$$ISERR(dismountSC) {
        write !, "Warning: failed to dismount temp DB: ", $system.Status.GetErrorText(dismountSC)
    }

    // Remap namespace back to original DB
    $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
    set nsProps("Routines") = oldDBName
    $$$ThrowOnError(##class(Config.Namespaces).Modify(ns, .nsProps))

    // Remount original DB
    set mountSC = ##class(SYS.Database).MountDatabase(
        ##class(%Library.File).NormalizeDirectory(
            ##class(%Library.File).ManagerDirectory() _ oldDBName))
    if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
        $$$ThrowOnError(mountSC)
    }

    // Remove temp DB config entry only — caller cleans up the directory
    // after it is done reading IRIS.DAT (e.g. after AssemblePackage).
    if ##class(Config.Databases).Exists(tempDBName) {
        $$$ThrowOnError(##class(Config.Databases).Delete(tempDBName))
    }
}

/// Runs the Reload and Compile lifecycle phases in ns (which maps to the temp DB).
Method LoadResourcesIntoDatabase(
	ns As %String,
	includeTestResources As %Boolean,
	ByRef params)
{
    new $namespace
    set $namespace = ns

    set loadParams("Verbose") = $get(params("Verbose"))
    set loadParams("DatabasePackaging") = 1
    set loadParams("IncludeTestResources") = includeTestResources

    $$$ThrowOnError(..%Reload(.loadParams))
    $$$ThrowOnError(..%Compile(.loadParams))
}

/// Before remapping the namespace routines DB, exports each Generated resource
/// from the current (source) namespace to a temp XML file.
/// Returns generatedExports as a $list of temp file paths to be imported later.
/// Must be called before RemapRoutinesDB — once the old DB is dismounted, the
/// compiled generated classes are no longer accessible.
/// 
/// This export/import is the primary mechanism for Generated resources that have
/// no in-lifecycle generator: classes produced by external tools or processes that
/// are pre-compiled in the source DB but not recreated during %Reload/%Compile.
/// 
/// For resources that are regenerated during packaging (BPL/DTL compilation
/// auto-generates their .1.cls subclass; <Invoke After Compile> explicitly creates
/// a class via %Dictionary API), the import is redundant but harmless — the class
/// already exists in the temp DB by import time.
Method ExportGeneratedResources(
	ns As %String,
	includeTestResources As %Boolean,
	ByRef params,
	Output generatedExports As %List) [ Private ]
{
    set generatedExports = ""
    set orderedList = ..Module.GetOrderedResourceList()
    set tKey = ""
    for {
        #dim tResource As %IPM.Storage.ResourceReference
        set tResource = orderedList.GetNext(.tKey)
        quit:tKey=""

        if 'includeTestResources {
            set scope = $zconvert(tResource.Scope, "L")
            if (scope = "test") || (scope = "verify") {
                continue
            }
        }

        if 'tResource.Generated {
            continue
        }

        set tempFile = ##class(%Library.File).TempFilename("xml")
        set exportSC = $system.OBJ.Export(tResource.Name, tempFile, "-d")
        if $$$ISOK(exportSC) && (##class(%Library.File).GetFileSize(tempFile) > 0) {
            set generatedExports = generatedExports _ $listbuild(tempFile)
        } elseif ##class(%Library.File).Exists(tempFile) {
            do ##class(%Library.File).Delete(tempFile)
        }
    }
}

/// Returns 1 if the current context is a database package install.
/// Both conditions required: module declares database packaging (not just a lifecycle override
/// for source packaging) AND IRIS.DAT is present in the module root (extracted package dir).
Method IsInstallContext() As %Boolean [ Private ]
{
    set irisDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", ..Module.Root)
    quit (..Module.Packaging = "database") && ##class(%Library.File).Exists(irisDAT)
}

/// Handles three contexts:
/// - Install (Packaging=database and IRIS.DAT in root): skip source loading entirely.
/// - Database packaging inside %Package (params("DatabasePackaging")=1):
///   load resources into temp DB, filtering test scope unless requested.
/// - All other contexts (packaging phase chain on source): delegate to ##super.
Method %Reload(ByRef params) As %Status
{
    // Install context: IRIS.DAT already in place — no source to reload.
    // Also skip <Invoke> elements in all subsequent phases: they ran during packaging.
    // The new IRIS.DAT isn't mounted until %Activate, so any invoke referencing packaged
    // classes would fail with <CLASS DOES NOT EXIST>.
    if ..IsInstallContext() {
        set params("SkipInvokes") = 1
        quit $$$OK
    }

    // Inside %Package.LoadResourcesIntoDatabase: load resources, filtering test scope.
    if $get(params("DatabasePackaging")) {
        set sc = $$$OK
        try {
            set orderedResourceList = ..Module.GetOrderedResourceList()
            set key = ""
            for {
                #dim resource As %IPM.Storage.ResourceReference
                set resource = orderedResourceList.GetNext(.key)
                quit:key=""

                // Type A: regular resources with Scope="test" or Scope="verify" — skip unless requested
                if '$get(params("IncludeTestResources")) {
                    set scope = $zconvert(resource.Scope, "L")
                    if (scope = "test") || (scope = "verify") {
                        continue
                    }
                }

                // Type B: <UnitTest> parent resources have Scope="" and a Test processor.
                // OnPhase("Reload") is a no-op for this processor; loading is done via LoadTestDirectory.
                if $isobject(resource.Processor) && resource.Processor.%IsA("%IPM.ResourceProcessor.Test") && ($extract(resource.Name, *) = "/") {
                    if $get(params("IncludeTestResources")) {
                        set testDir = ##class(%Library.File).NormalizeDirectory(resource.Module.Root _ resource.Name)
                        set format = resource.Processor.Format
                        set loadSC = ##class(%IPM.Test.Manager).LoadTestDirectory(testDir, $get(params("Verbose")), , format)
                        $$$ThrowOnError(loadSC)
                    }
                    continue
                }

                if $isobject(resource.Processor) {
                    set reloadPhase = $select(resource.Scope '= "": resource.Scope, 1: "Reload")
                    $$$ThrowOnError(resource.Processor.OnPhase(reloadPhase, .params))
                }
            }
        } catch ex {
            set sc = ex.AsStatus()
        }
        quit sc
    }

    // Packaging phase chain on source module: delegate to Base.
    quit ##super(.params)
}

/// During a database package install, there is no source to compile.
/// In all other contexts, delegate to ##super.
Method %Compile(ByRef pParams) As %Status
{
    if ..IsInstallContext() {
        quit $$$OK
    }
    quit ##super(.pParams)
}

/// Computes the SHA-256 hash of a file and returns it as a lowercase hex string (64 chars).
ClassMethod ComputeSHA256Hex(filePath As %String) As %String
{
    set stream = ##class(%Stream.FileBinary).%New()
    $$$ThrowOnError(stream.LinkToFile(filePath))

    set binHash = ##class(%SYSTEM.Encryption).SHAHashStream(256, stream, .sc)
    $$$ThrowOnError(sc)

    set hexHash = ""
    for i=1:1:$length(binHash) {
        set byte = $ascii($extract(binHash, i))
        set hex = $zhex(byte)
        if $length(hex) = 1 { set hex = "0" _ hex }
        set hexHash = hexHash _ $zconvert(hex, "L")
    }
    quit hexHash
}

/// XSLT to inject <Packaging>database</Packaging> and
/// <Checksum Algorithm="SHA-256">...</Checksum> into a module XML stream.
/// REPLACECHECKSUM is substituted with the real checksum before XSLT compilation.
XData InjectDatabasePackagingTransform
{
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="no"/>
  <xsl:strip-space elements="*"/>

  <!-- Identity transform -->
  <xsl:template match="@*|node()">
    <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
  </xsl:template>

  <!-- Export: each child on its own line, 2-space indent -->
  <xsl:template match="*[local-name()='Export']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select="*">
        <xsl:text>&#10;  </xsl:text>
        <xsl:apply-templates select="."/>
      </xsl:for-each>
      <xsl:text>&#10;</xsl:text>
    </xsl:copy>
  </xsl:template>

  <!-- Document: each child on its own line, 4-space indent -->
  <xsl:template match="*[local-name()='Document']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select="*">
        <xsl:text>&#10;    </xsl:text>
        <xsl:apply-templates select="."/>
      </xsl:for-each>
      <xsl:text>&#10;  </xsl:text>
    </xsl:copy>
  </xsl:template>

  <!-- Module: each child on its own line, 6-space indent.
       Skip any existing Packaging/Checksum (will be re-injected).
       Inject Packaging + Checksum immediately after Version. -->
  <xsl:template match="*[local-name()='Module']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select="*[local-name()!='Packaging' and local-name()!='Checksum']">
        <xsl:text>&#10;      </xsl:text>
        <xsl:apply-templates select="."/>
        <xsl:if test="local-name()='Version'">
          <xsl:text>&#10;      </xsl:text>
          <xsl:element name="Packaging" namespace="{namespace-uri(..)}">database</xsl:element>
          <xsl:text>&#10;      </xsl:text>
          <xsl:element name="Checksum" namespace="{namespace-uri(..)}">
            <xsl:attribute name="Algorithm">SHA-256</xsl:attribute>REPLACECHECKSUM</xsl:element>
        </xsl:if>
      </xsl:for-each>
      <xsl:text>&#10;    </xsl:text>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
}

/// Compiles InjectDatabasePackagingTransform with the real checksum substituted in.
ClassMethod CompilePackagingTransform(checksumHex As %String) As %XML.XSLT.CompiledStyleSheet
{
    set xData = ##class(%Dictionary.CompiledXData).IDKEYOpen(
        $classname(), "InjectDatabasePackagingTransform", , .sc)
    $$$ThrowOnError(sc)

    set raw = ""
    while 'xData.Data.AtEnd {
        set raw = raw _ xData.Data.Read()
    }
    set raw = $replace(raw, "REPLACECHECKSUM", checksumHex)

    set stream = ##class(%Stream.TmpCharacter).%New()
    $$$ThrowOnError(stream.Write(raw))
    $$$ThrowOnError(stream.Rewind())

    $$$ThrowOnError(##class(%XML.XSLT.CompiledStyleSheet).CreateFromStream(stream, .compiled))
    quit compiled
}

/// Exports the module manifest, applies the database packaging XSLT transform
/// (injecting Packaging and Checksum elements), and writes to targetDir/module.xml.
Method WritePackageModuleXML(
	targetDir As %String,
	checksumHex As %String)
{
    set srcPath = ##class(%Library.File).NormalizeFilename("module.xml", ..Module.Root)
    set baseStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(baseStream.LinkToFile(srcPath))
    $$$ThrowOnError(baseStream.Rewind())

    set compiled = ..CompilePackagingTransform(checksumHex)
    $$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(baseStream, compiled, .transformed))

    set outPath = ##class(%Library.File).NormalizeFilename("module.xml", targetDir)
    set outStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(outStream.LinkToFile(outPath))
    $$$ThrowOnError(outStream.CopyFrom(transformed))
    $$$ThrowOnError(outStream.%Save())
}

/// Recursively collects all unique transitive dependency names into depMap(name) = "".
ClassMethod CollectAllDependencies(
	module As %IPM.Storage.Module,
	ByRef depMap)
{
    for i=1:1:module.Dependencies.Count() {
        set depName = module.Dependencies.GetAt(i).Name
        if $data(depMap(depName)) {
            continue
        }
        set depMap(depName) = ""
        if ##class(%IPM.Storage.Module).NameExists(depName) {
            set depModule = ##class(%IPM.Storage.Module).NameOpen(depName, , .sc)
            $$$ThrowOnError(sc)
            do ..CollectAllDependencies(depModule, .depMap)
        }
    }
}

/// Writes dependencies.xml to targetDir by compiling all dependency module manifests.
Method WriteDependenciesXML(targetDir As %String)
{
    do ..CollectAllDependencies(..Module, .depMap)

    set outPath = ##class(%Library.File).NormalizeFilename("dependencies.xml", targetDir)
    set outStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(outStream.LinkToFile(outPath))

    do outStream.WriteLine("<?xml version=""1.0"" encoding=""UTF-8""?>")
    do outStream.WriteLine("<Dependencies>")

    set depName = ""
    for {
        set depName = $order(depMap(depName))
        quit:depName=""

        if '##class(%IPM.Storage.Module).NameExists(depName) {
            continue
        }
        set depModule = ##class(%IPM.Storage.Module).NameOpen(depName, , .sc)
        $$$ThrowOnError(sc)

        set depStream = ##class(%Stream.TmpCharacter).%New()
        $$$ThrowOnError($system.OBJ.ExportToStream(depModule.Name _ ".ZPM", .depStream, "-d"))
        $$$ThrowOnError(depStream.Rewind())

        // Strip the <?xml...?> header before appending
        set firstLine = depStream.ReadLine()
        if firstLine '[ "<?xml" {
            do outStream.WriteLine(firstLine)
        }
        $$$ThrowOnError(outStream.CopyFrom(depStream))
    }

    do outStream.WriteLine("</Dependencies>")
    $$$ThrowOnError(outStream.%Save())
}

/// Copies non-compiled resource source files (FileCopy, PythonWheel, CPF) from
/// the module source tree into stagingDir so their processors can find them during install.
/// Called from AssemblePackage after IRIS.DAT is already in stagingDir.
/// WebApplication is configuration-only and is not handled here.
Method CopyNonCompiledResources(
	stagingDir As %String,
	includeTestResources As %Boolean,
	exportPythonDeps As %Boolean = 1)
{
    set orderedResourceList = ..Module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""

        // Skip test-scoped resources unless requested
        if 'includeTestResources {
            set scope = $zconvert(resource.Scope, "L")
            if (scope = "test") || (scope = "verify") {
                continue
            }
        }

        if $isobject(resource.Processor) && resource.Processor.%IsA("%IPM.ResourceProcessor.FileCopy") {
            set name = resource.Processor.Name
            set sourcePath = ##class(%Library.File).NormalizeFilename(name, ..Module.Root)
            if '##class(%Library.File).Exists(sourcePath) {
                continue
            }
            set destPath = ##class(%Library.File).NormalizeFilename(name, stagingDir)
            set destDir = ##class(%Library.File).GetDirectory(destPath)
            if '##class(%Library.File).CreateDirectoryChain(destDir) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot create dir for FileCopy: " _ destDir))
            }
            if '##class(%Library.File).CopyFile(sourcePath, destPath, 1) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot copy FileCopy source: " _ sourcePath))
            }
        } elseif exportPythonDeps && $isobject(resource.Processor) && resource.Processor.%IsA("%IPM.ResourceProcessor.PythonWheel") {
            set wheelDir = resource.Processor.Directory
            set wheelName = resource.Processor.Name
            set sourceDir = ##class(%Library.File).NormalizeDirectory(..Module.Root _ wheelDir)
            set sourcePath = ##class(%Library.File).NormalizeFilename(wheelName, sourceDir)
            if '##class(%Library.File).Exists(sourcePath) {
                continue
            }
            set destDir = ##class(%Library.File).NormalizeDirectory(stagingDir _ wheelDir)
            if '##class(%Library.File).CreateDirectoryChain(destDir) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot create wheels dir: " _ destDir))
            }
            if '##class(%Library.File).CopyFile(sourcePath, destDir _ wheelName, 1) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot copy wheel: " _ sourcePath))
            }
        } elseif $isobject(resource.Processor) && resource.Processor.%IsA("%IPM.ResourceProcessor.CPF") {
            set cpfName = resource.Processor.Name
            set cpfSubdir = resource.Processor.Directory
            set sourceDir = ##class(%Library.File).NormalizeDirectory(..Module.Root _ ..Module.SourcesRoot _ "/" _ cpfSubdir)
            set sourcePath = ##class(%Library.File).NormalizeFilename(cpfName, sourceDir)
            if '##class(%Library.File).Exists(sourcePath) {
                continue
            }
            set destDir = ##class(%Library.File).NormalizeDirectory(stagingDir _ ..Module.SourcesRoot _ "/" _ cpfSubdir)
            if '##class(%Library.File).CreateDirectoryChain(destDir) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot create CPF staging dir: " _ destDir))
            }
            if '##class(%Library.File).CopyFile(sourcePath, destDir _ cpfName, 1) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot copy CPF file: " _ sourcePath))
            }
        }
        // Compiled resources (Class, Routine, Include, etc.) are handled via IRIS.DAT — no file staging needed.
        // WebApplication is configuration-only — no file staging needed.
    }
}

/// Copies IRIS.DAT into stagingDir, writes module.xml and dependencies.xml,
/// then calls Archive.Create to build the final .tgz. Returns path to .tgz.
Method AssemblePackage(
	irisDAT As %String,
	stagingDir As %String,
	checksumHex As %String,
	ByRef params) As %String
{
    if '##class(%Library.File).CreateDirectoryChain(stagingDir, .result) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot create staging dir: " _ result))
    }

    if '##class(%Library.File).CopyFile(irisDAT, stagingDir _ "IRIS.DAT", 1, .result) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot copy IRIS.DAT: " _ result))
    }

    // Stage non-compiled resource files so processors can find them during install
    set includeTestResources = $get(params("IncludeTestResources"), 0)
    set exportPythonDeps = $get(params("ExportPythonDependencies"), 1)
    do ..CopyNonCompiledResources(stagingDir, includeTestResources, exportPythonDeps)

    do ..WritePackageModuleXML(stagingDir, checksumHex)
    do ..WriteDependenciesXML(stagingDir)

    set outputDir = $get(params("Path"))
    if outputDir = "" {
        set outputDir = ##class(%Library.File).NormalizeDirectory($$$FileTempDirSys)
    } else {
        set outputDir = ##class(%Library.File).NormalizeDirectory(outputDir)
        if '##class(%Library.File).DirectoryExists(outputDir) {
            if '##class(%Library.File).CreateDirectoryChain(outputDir, .reason) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Cannot create output directory " _ outputDir _ ": " _ reason))
            }
        }
    }

    set packageFile = outputDir _ ..Module.Name _ "-" _ ..Module.VersionString _ "-database.tgz"
    $$$ThrowOnError(##class(%IPM.General.Archive).Create(stagingDir, packageFile, .archiveOutput))

    set verbose = $get(params("Verbose"))
    for i=1:1:$get(archiveOutput) {
        write:verbose !, archiveOutput(i)
    }
    write !, "Database package generated:", !, $char(9), packageFile

    quit packageFile
}

/// Pre-install validation for a database swap.
/// Throws on any failure. Does not modify any state.
Method ValidateBeforeSwap(
	packageDir As %String,
	ns As %String) [ Private ]
{
    set irisDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", packageDir)
    if '##class(%Library.File).Exists(irisDAT) {
        set msg = "Database package is missing IRIS.DAT in: " _ packageDir
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
    if ##class(%Library.File).GetFileSize(irisDAT) <= 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "IRIS.DAT in database package is zero-sized."))
    }

    set moduleXML = ##class(%Library.File).NormalizeFilename("module.xml", packageDir)
    if '##class(%Library.File).Exists(moduleXML) {
        set msg = "Database package is missing module.xml in: " _ packageDir
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }

    set xmlStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(xmlStream.LinkToFile(moduleXML))
    $$$ThrowOnError(##class(%XML.XPATH.Document).CreateFromStream(xmlStream, .xpathDoc))

    $$$ThrowOnError(xpathDoc.EvaluateExpression("/Export/Document/Module/Packaging", "text()", .packagingResults))
    set packagingValue = $select(packagingResults.Count() > 0: packagingResults.GetAt(1).Value, 1: "")
    if packagingValue '= "database" {
        set msg = "module.xml does not declare <Packaging>database</Packaging>. Got: " _ packagingValue
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }

    set depsXML = ##class(%Library.File).NormalizeFilename("dependencies.xml", packageDir)
    if '##class(%Library.File).Exists(depsXML) {
        set msg = "Database package is missing dependencies.xml in: " _ packageDir
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }

    $$$ThrowOnError(xpathDoc.EvaluateExpression("/Export/Document/Module/Checksum", "text()", .checksumResults))
    if checksumResults.Count() = 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "module.xml is missing <Checksum> element."))
    }
    set expectedChecksum = checksumResults.GetAt(1).Value
    set actualChecksum = ..ComputeSHA256Hex(irisDAT)
    if $zconvert(actualChecksum, "L") '= $zconvert(expectedChecksum, "L") {
        set msg = "IRIS.DAT SHA-256 mismatch. Expected: " _ expectedChecksum _ " Actual: " _ actualChecksum
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }

    // Only one database package per namespace is allowed
    set conflictStmt = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(conflictStmt.%Prepare("SELECT Name FROM %IPM_Storage.ModuleItem WHERE Packaging = 'database' AND Name != ?"))
    set conflictRS = conflictStmt.%Execute(..Module.Name)
    if conflictRS.%Next() {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "A database package ('" _ conflictRS.%Get("Name") _ "') is already installed in this namespace. Only one database package per namespace is allowed."))
    }

    // Validate IPM is not in the target namespace's routines DB
    do ..ValidateIPMNotInRoutinesDB()
}

/// Dismounts the current routines DB, renames IRIS.DAT to a timestamped backup,
/// moves the packaged IRIS.DAT into place, and remounts.
/// Sets dbDir and backupPath for use in rollback on failure.
Method PerformDatabaseSwap(
	packageDir As %String,
	ns As %String,
	Output dbDir As %String,
	Output backupPath As %String) [ Private ]
{
    set dbDir = ""
    set backupPath = ""

    new $namespace
    set $namespace = "%SYS"

    $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
    set routinesDBName = $get(nsProps("Routines"))
    set dbDir = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).ManagerDirectory() _ routinesDBName)

    $$$ThrowOnError(##class(SYS.Database).DismountDatabase(dbDir))

    // Rename current IRIS.DAT to timestamped backup: IRIS_<dbname>_YYYYMMDDHHmmss.DAT
    set h = $horolog
    set timestamp = $translate($zdate(h, 8), "-", "") _ $translate($ztime($piece(h, ",", 2), 2), ":", "")
    set backupPath = dbDir _ "IRIS_" _ routinesDBName _ "_" _ timestamp _ ".DAT"
    if '##class(%Library.File).Rename(dbDir _ "IRIS.DAT", backupPath) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to rename IRIS.DAT to backup: " _ backupPath))
    }

    // Move (rename) packaged IRIS.DAT into the database directory
    set srcDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", packageDir)
    if '##class(%Library.File).Rename(srcDAT, dbDir _ "IRIS.DAT") {
        set tMsg = "Failed to move IRIS.DAT from " _ srcDAT _ " to " _ dbDir
        $$$ThrowStatus($$$ERROR($$$GeneralError, tMsg))
    }

    $$$ThrowOnError(##class(SYS.Database).MountDatabase(dbDir))
}

/// Best-effort rollback after a failed swap. Never throws — called from a catch block.
/// Dismounts new DB, removes new IRIS.DAT if present, restores backup, remounts.
Method RollbackDatabaseSwap(
	dbDir As %String,
	backupPath As %String) [ Private ]
{
    if dbDir = "" {
        quit
    }

    new $namespace
    set $namespace = "%SYS"

    set sc = ##class(SYS.Database).DismountDatabase(dbDir)
    if $$$ISERR(sc) {
        write !, "Rollback warning — could not dismount database at ", dbDir
    }

    set newDAT = dbDir _ "IRIS.DAT"
    if ##class(%Library.File).Exists(newDAT) {
        if '##class(%Library.File).Delete(newDAT) {
            write !, "Rollback warning — could not delete new IRIS.DAT at ", newDAT
        }
    }

    if (backupPath '= "") && ##class(%Library.File).Exists(backupPath) {
        if '##class(%Library.File).Rename(backupPath, dbDir _ "IRIS.DAT") {
            write !, "Rollback warning — could not restore backup from ", backupPath
            write !, "  Manual intervention required to restore IRIS.DAT."
        }
    }

    set mountSC = ##class(SYS.Database).MountDatabase(dbDir)
    if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
        write !, "Rollback warning — could not remount database at ", dbDir
        write !, "  Namespace routines may be unavailable — manual remount required."
    }
}

/// Shows the namespace and current DB path, then prompts for y/N confirmation.
/// Throws if the user declines or cancels.
Method PromptForSwapConfirmation(ns As %String) [ Private ]
{
    new $namespace
    set $namespace = "%SYS"
    $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
    set routinesDBName = $get(nsProps("Routines"))
    set dbDir = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).ManagerDirectory() _ routinesDBName)
    set $namespace = ns

    write !, "WARNING: This will replace the routines database for namespace ", ns
    write !, "  Current database: ", dbDir _ "IRIS.DAT"
    write !, "  The current IRIS.DAT will be renamed to a timestamped backup before the swap."
    write !

    set confirmed = 0
    set response = ##class(%Library.Prompt).GetYesNo("Proceed with database swap? [y/N] ", .confirmed)
    if (response '= $$$SuccessResponse) || 'confirmed {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Database swap cancelled by user."))
    }
}

/// Reads dependencies.xml and registers each dependency's module metadata
/// into the current namespace's IPM storage.
/// The dependency code is already in the swapped-in routines DB;
/// this only registers the IPM metadata so zpm list and dependency tracking work.
ClassMethod RegisterDependencyMetadata(packageDir As %String)
{
    set depsXML = ##class(%Library.File).NormalizeFilename("dependencies.xml", packageDir)
    if '##class(%Library.File).Exists(depsXML) {
        quit
    }

    set depsStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(depsStream.LinkToFile(depsXML))

    set fullContent = ""
    while 'depsStream.AtEnd {
        set fullContent = fullContent _ depsStream.Read(32000)
    }

    // Extract each <Export>...</Export> block (one per dependency) and load it
    set searchPos = 1
    for {
        set blockStart = $find(fullContent, "<Export", searchPos) - $length("<Export")
        quit:blockStart<=0

        set blockEnd = $find(fullContent, "</Export>", blockStart)
        quit:blockEnd<=0

        set fragment = $extract(fullContent, blockStart, blockEnd - 1)

        set tempFile = ##class(%Library.File).TempFilename("xml")
        set out = ##class(%Stream.FileCharacter).%New()
        $$$ThrowOnError(out.LinkToFile(tempFile))
        $$$ThrowOnError(out.Write("<?xml version=""1.0"" encoding=""UTF-8""?>" _ $char(10)))
        $$$ThrowOnError(out.Write(fragment))
        $$$ThrowOnError(out.%Save())

        set loadSC = $system.OBJ.Load(tempFile, "ck")
        do ##class(%Library.File).Delete(tempFile)
        $$$ThrowOnError(loadSC)

        set searchPos = blockEnd
    }
}

/// For a database package install: validate, optionally prompt, swap the routines database,
/// and register dependency metadata in IPM storage.
/// For all other contexts: delegate to ##super.
Method %Activate(ByRef params) As %Status
{
    if '..IsInstallContext() {
        quit ##super(.params)
    }

    set sc = $$$OK
    set dbDir = ""
    set backupPath = ""
    try {
        if $get(params("DeveloperMode")) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Database packages cannot be installed in developer mode."))
        }

        set ns = $namespace
        set packageDir = ..Module.Root

        do ..ValidateBeforeSwap(packageDir, ns)

        if '$get(params("SwapDB")) {
            do ..PromptForSwapConfirmation(ns)
        }

        do ..PerformDatabaseSwap(packageDir, ns, .dbDir, .backupPath)
        do ##class(%IPM.Lifecycle.Database).RegisterDependencyMetadata(packageDir)

        write !, "Database swap complete for namespace ", ns
        write !, "  Backup: ", backupPath

    } catch ex {
        set sc = ex.AsStatus()
        if dbDir '= "" {
            write !, "ERROR — attempting rollback..."
            do ..RollbackDatabaseSwap(dbDir, backupPath)
        }
    }
    quit sc
}

}
