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
    set ns = $namespace

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
            new $namespace
            set $namespace = "%SYS"
            $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
            set curDBName = $get(nsProps("Routines"))
            set tempDBPath = ##class(%Library.File).NormalizeDirectory(
                ##class(%Library.File).ManagerDirectory() _ curDBName)
        } else {
            // Default: create a fresh empty temp database
            write:verbose !, "Creating temporary database..."
            do ..CreateTempDatabase(.dbName, .tempDBPath)
            set tempDBName = dbName

            // Remap namespace routines to the temp DB
            // Note: globals mapping is unchanged — ^IPM.* globals remain in the real globals DB
            // and will NOT enter the temp IRIS.DAT. No cleanup step is needed.
            write:verbose !, "Remapping namespace routines to temp database..."
            set dbRemapped = 1
            do ..RemapRoutinesDB(ns, tempDBName, .oldDBName)

            // Load and compile module resources into the temp DB
            write:verbose !, "Loading resources into temp database..."
            do ..LoadResourcesIntoDatabase(ns, includeTests, .params)

            // Restore namespace mapping before packaging
            write:verbose !, "Restoring namespace routines..."
            do ..RestoreRoutinesDB(ns, oldDBName, tempDBName, tempDBPath)
            set dbRemapped = 0
        }

        // Compute SHA-256 checksum of the IRIS.DAT
        write:verbose !, "Computing SHA-256 checksum..."
        set irisDAT = tempDBPath _ "IRIS.DAT"
        set checksumHex = ..ComputeSHA256Hex(irisDAT)
        write:verbose !, "  Checksum: ", checksumHex

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

/// During database packaging without -include-test-resources,
/// skip test-scoped resources so they don't get compiled into the DB.
Method %Reload(ByRef params) As %Status
{
    set sc = $$$OK
    try {
        set orderedResourceList = ..Module.GetOrderedResourceList()
        set tKey = ""
        for {
            #dim tResource As %IPM.Storage.ResourceReference
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:tKey=""

            // Skip test-scoped resources unless -include-test-resources was specified
            if '$get(params("IncludeTestResources")) {
                set scope = $zconvert(tResource.Scope, "L")
                if (scope = "test") || (scope = "verify") {
                    continue
                }
            }

            if $isobject(tResource.Processor) && tResource.IsInScope("Reload") {
                $$$ThrowOnError(tResource.Processor.OnPhase("Reload", .params))
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
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
        $$$ThrowOnError(depModule.XMLExportToStream(.depStream, , "literal,indent"))
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
    write:verbose !, "Database package generated:", !, $char(9), packageFile

    quit packageFile
}

}
