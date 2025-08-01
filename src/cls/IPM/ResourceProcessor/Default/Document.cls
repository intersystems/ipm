Include %IPM.Common

Class %IPM.ResourceProcessor.Default.Document Extends %IPM.ResourceProcessor.AbstractCompilable
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Default resource processor class for %Studio.AbstractDocument subclasses";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Compile,CompileAfter,Flags,ExportFlags,Directory,LoadAsDirectory,FilenameExtension,FilenameTranslateIdentifier,FilenameTranslateAssociator,Format";

/// May be set to determine the value of <property>Extension</property> based on a static value rather than based on the resource name.
/// The only expected use case at this point is class packages (.PKG, but Extension will be .CLS)
Parameter EXTENSION;

/// When a module is loaded in developer mode, this is appended to the resource name in ^Sources - e.g., ^Sources(..Extension, <resource name>_..#NAMEPOSTFIX)
/// The only expected use case at this point is class packages (.PKG, but Extension will be .CLS)
Parameter NAMEPOSTFIX;

/// If true, the resource will be compiled during the compilation phase in the module lifecycle.
Property Compile As %Boolean [ InitialExpression = 1 ];

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "") [ InitialExpression = {$zconvert(..#EXTENSION,"L")} ];

Property DirectoryDefined As %Boolean [ InitialExpression = 0, Transient ];

/// If true (default is false), the resource is loaded as a directory.
Property LoadAsDirectory As %Boolean [ InitialExpression = 0 ];

/// Characters in the filename to use as the identifier in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and ignore "%"
Property FilenameTranslateIdentifier As %String [ InitialExpression = ".%" ];

/// Characters in the filename to use as the associator in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and ignore "%"
Property FilenameTranslateAssociator As %String [ InitialExpression = "/" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "xml" ];

/// Export format - list of acceptable values may differ by subclass.
Property Format As %String;

/// Name of the server document (without extension)
Property Name As %String(MAXLEN = 255) [ Private ];

/// Extension of the server document(s) represented by this resource
Property Extension As %String [ Private ];

Method DirectorySet(pValue As %String) As %Status
{
    set i%Directory = pValue
    set ..DirectoryDefined = 1
    quit $$$OK
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set pResourceHandled = 0
    try {
        set tVerbose = $get(pParams("Verbose"),0)
        set tDeveloperMode = $get(pParams("DeveloperMode"),0)
        set tName = $piece(..ResourceReference.Name,".",1,*-1)
        set tRoot = ##class(%File).NormalizeDirectory(..ResourceReference.Module.SourcesRoot, ..ResourceReference.Module.Root)
        set tInScope = ..ResourceReference.IsInScope(pPhase,.tInCurrentPhase)
        if (..Directory'="") {
            set ..DirectoryDefined = 1
        }
        if ((pPhase = "Reload") && tInScope) || tInCurrentPhase {
            set tCatDirectory = ""
            set tCatDirectory = tCatDirectory _ $listbuild(..Directory)
            if (..Directory="rtn") {
                // Ensure backward compatibility. In v0.7.0 and earlier, the default directory was "mac" for routines
                set tCatDirectory = tCatDirectory _ $listbuild("mac")
            }
            if ('..DirectoryDefined) {
                if (..Directory="mac") {
                    set tCatDirectory = tCatDirectory _ $listbuild("rtn")
                }
                if (..Directory'="") {
                    set tCatDirectory = tCatDirectory _ $listbuild("")
                }
            }
            set tListNames = ""
            set tListNames = tListNames _ $listbuild(tName)
            set tListNames = tListNames _ $listbuild($translate(tName, "%", "_"))
            set tListNames = tListNames _ $listbuild($translate(tName, "_", ""))
            set tListNames = tListNames _ $listbuild($translate(tName, "%", ""))
            set ptrn = 0
            while $listnext(tListNames, ptrn, tName) {
                // Runs in Reload normally, and also in Test for test scope / Verify for verify scope
                set tSourcesPrefix = $char($parameter("%IPM.ExtensionBase.SourceControl.Interface","NOPREFIXCHARCODE"))

                if '$get(pParams("NoMapping"),0) {
                    // Currently, still need mapping creation, since if a module is installed with a resource
                    // already presented in another namespace and have a upperlevel mapping to another namespace,
                    // then it should have a package mapping of this specific resource to its namespace database
                    $$$ThrowOnError(..OnConfigureMappings(.pParams))
                }
                if ..ResourceReference.Generated {
                    set pResourceHandled = 1
                    quit
                }

                if '..ResourceReference.Generated {
                    set tSubDirectory = $select(..ResourceReference.Preload:"preload/",1:"")
                    set tResourceDirectory = ##class(%File).NormalizeDirectory(tRoot_"/"_tSubDirectory)
                    if ('##class(%File).DirectoryExists(tResourceDirectory)) {
                        quit
                    }
                    set ptr = 0
                    set tResourceCatDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory)
                    while $listnext(tCatDirectory, ptr, tDirectory) {
                        set tResourceCatDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory _ tDirectory)
                        if (##class(%File).DirectoryExists(tResourceCatDirectory)) {
                            quit
                        }
                    }
                    if ##class(%File).DirectoryExists(tResourceCatDirectory) {
                        set tResourceDirectory = tResourceCatDirectory
                    }

                    if tDeveloperMode && (..Extension '= "") && (tName '= "") {
                        set ^Sources(..Extension,tName_..#NAMEPOSTFIX) = tSourcesPrefix _ tResourceDirectory
                    }

                    if '..ResourceReference.Preload {
                        for allowPercentSymbol = 0, 1 {
                            set tFileExtension = ""
                            set identifiers = ..FilenameTranslateIdentifier
                            set associators = ..FilenameTranslateAssociator
                            if allowPercentSymbol {
                                set pos = $find(identifiers, "%") - 1
                                if pos {
                                    set $extract(identifiers, pos) = ""
                                    set $extract(associators, pos) = ""
                                }
                            }
                            set tResourcePath = ##class(%File).NormalizeFilename(tResourceDirectory _ tSubDirectory _ $translate(tName, identifiers, associators))
                            if '..LoadAsDirectory {
                                // For user document types (generally), dynamilly support both the resource and filename extension
                                // e.g., for lookup tables, both .xml and .lut are supported regardless of configuration in module.xml.
                                // Generally, FilenameExtension SHOULD be specified (for the sake of embedded source control integration if nothing else),
                                // but this makes IPM less picky about reasonable things users might do.
                                set tItemFileExtension = $$$lcase("." _ $piece(..ResourceReference.Name, ".", *))
                                set tFileExtension =  $$$lcase("." _ ..FilenameExtension)
                                for tFileExtension = tFileExtension,tItemFileExtension {
                                    quit:##class(%IPM.Utils.File).Exists(tResourcePath _ tFileExtension)
                                }

                                set tResourcePath = tResourcePath _ tFileExtension

                                if ($$$lcase(tFileExtension)'=".xml")&&('##class(%IPM.Utils.File).Exists(tResourcePath)) {
                                    set tResourcePathXML = tResourcePath
                                    set $piece(tResourcePath, ".", *) = "xml"
                                    if (##class(%IPM.Utils.File).Exists(tResourcePathXML)) {
                                        set tResourcePath = tResourcePathXML
                                        set ..Format = "XML"
                                    }
                                }

                                if ($$$lcase(tFileExtension)=".mac")&&('##class(%IPM.Utils.File).Exists(tResourcePath)) {
                                    set tResourcePathRTN = tResourcePath
                                    set $piece(tResourcePathRTN, ".", *) = "rtn"
                                    if (##class(%IPM.Utils.File).Exists(tResourcePathRTN)) {
                                        set tResourcePath = tResourcePathRTN
                                    }
                                }
                            }
                            set tDeployedProjectPath = ##class(%IPM.Utils.Module).GetDeployedProjectPath(..ResourceReference.Module.Root)
                            // If resource path exists and the resource is not deployed with a deployed.xml existing
                            if ##class(%IPM.Utils.File).Exists(.tResourcePath) && '(##class(%IPM.Utils.File).Exists(tDeployedProjectPath) && ..ResourceReference.Deploy) {
                                set tSC = $$$OK
                                quit
                            }
                            if ..ResourceReference.Deploy {
                                if tVerbose {
                                    write !, "Loading deployed resource from Studio project: "_..ResourceReference.Name
                                }
                                set ..CompileFromProject = 1
                                if '$data($$$DeployedProjectInstalled(tDeployedProjectPath)) {
                                    set sc = ##class(%Studio.Project).InstallFromFile(tDeployedProjectPath, "<none>")
                                    if $$$ISERR(sc) {
                                        $$$ThrowStatus($$$ERROR($$$GeneralError, "Resource path '" _ tDeployedProjectPath _ "' not found"))
                                    }
                                    set $$$DeployedProjectInstalled(tDeployedProjectPath) = ""
                                }
                                return $$$OK
                            }
                            set tSC = $$$ERROR($$$GeneralError, "Resource path '" _ tResourcePath _ "' not found")
                        }
                        if $$$ISERR(tSC) continue

                        $$$ThrowOnError(..OnLoad(tResourcePath,tVerbose,tInCurrentPhase,.tLoadedList,.pParams))

                        set tSC = ##class(%IPM.Storage.LoadedResource).TrackResourceNames(..ResourceReference.Module.Name,..ResourceReference.UniqueName,tLoadedList)
                        $$$ThrowOnError(tSC)
                    }
                }
                set pResourceHandled = 1
                set tSC = $$$OK
                quit
            }
        } elseif (pPhase = "Compile") {
            if tInScope {
                // If Compile is false, indicate that the resource's compilation phase has already been handled and nothing special should happen.
                set pResourceHandled = '..Compile
            } else {
                // If out of scope, nothing should happen.
                set pResourceHandled = 1
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    set tSC = ..OnExportDeployedItem(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
    set tSC = $$$OK
    if pItemHandled || $$$ISERR(tSC) {
        quit tSC
    }
    set tSC = $$$OK
    set tExportFlags = "-d /diffexport/createdirs"_..ExportFlags
    set tVerbose = $get(pParams("Verbose"),0)
    try {
        if (..Format = "UDL") {
            // This is tailored toward support of "Other" documents exported in UDL format.
            if ##class(%Atelier.v1.Utils.General).ValidateDocName(pItemName,.tSC,.tCategory) {
                // Ensure directory containing file exists, and attempt to create it if not.
                if ($extract(pFullExportPath) = """") {
                    // Avoid issues with the path being quoted. (These mess up GetDirectory().)
                    set pFullExportPath = $extract(pFullExportPath,2,*-1)
                }

                set tTargetDirectory = ##class(%Library.File).GetDirectory(pFullExportPath)
                if '##class(%Library.File).DirectoryExists(tTargetDirectory) {
                    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(tTargetDirectory))
                }

                $$$ThrowOnError($system.OBJ.ExportUDL(pItemName,pFullExportPath,tExportFlags))
            }
            set pItemHandled = 1
        } elseif (..Format = "XML") {
            $$$ThrowOnError($system.OBJ.Export(pItemName,pFullExportPath,tExportFlags))
            set pItemHandled = 1
        } elseif (..Format = "%RO") {
            set tSC = $$Export^%apiRTN(pItemName,pFullExportPath,"Save for Source Control","WNSK\UTF8\",tExportFlags)
            set pItemHandled = 1
        }
        write:tVerbose !,"Exporting '",pItemName,"' to '",pFullExportPath,"'"
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnExportDeployedItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"),0)
        set tDeveloperMode = $get(pParams("DeveloperMode"),0)
        if (tDeveloperMode || ('..ResourceReference.Deploy) || ('$listlength(..ResourceReference.Module.Lifecycle.PhaseList))) {
            // Only export deployed items if we say to, are in a non-developer-mode context, and are currently executing module lifecycle phases.
            // OnExportItem may also be called from a source control extension context, and in this case PhaseList will be empty.
            quit
        }
        set tModuleName = ..ResourceReference.Module.Name
        set fileExt = $$$ucase($piece(pItemName, ".", *))
        set tName = $piece(pItemName, ".", 1, * - 1)
        quit:'($listfind($listbuild("CLS","MAC","INT"), fileExt))
        if $data(pParams($$$DeployedProjectIndex), deployedProject) {
            if tVerbose {
                write !, $$$FormatText("Adding deployed item '%1' to project '%2'", pItemName, deployedProject.Name)
            }
            $$$ThrowOnError(##class(%IPM.Storage.Module).AddItemToProject(deployedProject, pItemName))
            set pItemHandled = 1
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
    quit $$$OK
}

/// Subclasses may override to customize resource load behavior during the Reload phase. <br />
/// @Argument	pFullResourcePath			The absolute path to the resource present on the file system
/// @Argument	pVerbose					1: display output from loading files, 0: do not display output
/// @Argument	pCompile					1: compile files upon load, 0: do not compile files
/// @Argument	pLoadedList					Output: comma delimited list of files that have been loaded
Method OnLoad(
	pFullResourcePath As %String,
	pVerbose As %Boolean,
	pCompile As %Boolean = 0,
	Output pLoadedList As %String,
	ByRef pParams As %String) As %Status
{
    set pLoadedList = ""
    set tVerbose = $get(pParams("Verbose"),0)
    set tSC = $$$OK
    try {
        // Workaround: need to clean up after other UDL import/export operations
        kill ^||%oddDEF
        set tFlags = $select(pVerbose:"/display",1:"/nodisplay")_
            $select(pCompile:"/compile",1:"/nocompile")_
            $select($tlevel||..ResourceReference.Deploy:"/multicompile=0",1:"")

        if ..LoadAsDirectory {
            set tSC = $system.OBJ.ImportDir(pFullResourcePath, "*"_..FilenameExtension, tFlags, , 1, .pLoadedList)
            $$$ThrowOnError(tSC)
            set pLoadedList = "" // ImportDir returns as an array and clears the top node
            set tResourceKey = ""
            for {
                set tResourceKey = $order(pLoadedList(tResourceKey))
                if (tResourceKey = "") {
                    quit
                }
                set pLoadedList = pLoadedList_$listbuild(tResourceKey)
            }
            set pLoadedList = $listtostring(pLoadedList)
        } elseif (..Format = "%RO") {
            // This tolerates some unusual %RO header formats that $System.OBJ.Load does not respect.
            set pLoadedList = ""
            set tSC = $$Import^%apiRTN(pFullResourcePath,"replace,compile="_pCompile,,,.tResult,$select(pVerbose:"d",1:"-d"))
        } else {
            set tProcessed = 0
            set fileExt = $$$UPPER($piece(pFullResourcePath, ".", *))
            if '$listfind($listbuild("CLS", "MAC"), fileExt), ##class(%RoutineMgr).UserType(..ResourceReference.Name, .docclass, .doctype) {
                try {
                    set stream = ##class(%Stream.FileCharacter).%New()
                    $$$ThrowOnError(stream.LinkToFile(pFullResourcePath))
                    try {
                        quit:'##class(%XML.XPATH.Document).CreateFromStream(stream, .tDocument)
                        quit:'$isobject(tDocument)
                        quit:'tDocument.EvaluateExpression("/Export/Document", "node()", .tRes)
                        if $isobject(tRes),tRes.Size  {
                            set tSC = $system.OBJ.Load(pFullResourcePath,tFlags,,.pLoadedList)
                            set tProcessed = 1
                        }
                    } catch ex { }
                    if 'tProcessed {
                        try {
                            write:tVerbose !,"Loading file " _ pFullResourcePath _ " as " _ docclass
                            set routineMgr = ##class(%RoutineMgr).%OpenId(..ResourceReference.Name)
                            do routineMgr.Code.Rewind()
                            do routineMgr.Code.CopyFrom(stream)
                            $$$ThrowOnError(routineMgr.%Save())
                            write:tVerbose !,"Imported document: ", ..ResourceReference.Name, !, "Load finished successfully.", !
                            set tProcessed = 1
                        } catch ex { }
                    }
                } catch ex {
                #; Default way
                }
            }
            if 'tProcessed {
                set tSC = $system.OBJ.Load(pFullResourcePath,tFlags,,.pLoadedList)
                $$$ThrowOnError(tSC)
            }
        }
        $$$ThrowOnError(..OnLoadDeployed(.pParams, .pLoadedList))
        if $data(tResourceKey)>1 {
            set tResourceKey = ""
            for {
                set tResourceKey = $order(tResult(tResourceKey))
                if (tResourceKey = "") {
                    quit
                }
                set pLoadedList = pLoadedList_$listbuild(tResourceKey)
            }
            set pLoadedList = $listtostring(pLoadedList)
        }

        if $data(pLoadedList)#2 {
            do ..ResourceReference.UpdateChildrenFromString(pLoadedList)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnLoadDeployed(
	ByRef pParams,
	ByRef pLoadedList) As %Status
{
    set tSC = $$$OK
    try {
        set tr = 1
        set tVerbose = $get(pParams("Verbose"),0)
        set tModuleName = ..ResourceReference.Module.Name
        set tName = ""
        for {
            set tName = $order(pLoadedList(tName))
            quit:tName=""
            continue:($$$ucase($piece(tName,".",*))'="GBL")
            set tGN = "^" _ $piece(tName, ".", 1, * - 1)
            #; Yep, it's just a workaround for eror with python
            #; <OBJECT DISPATCH> *python object not found
            if tName["rPYC(" {
                set tValue = $get(@tGN)
                set @tGN = +tValue
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %OnNew(pResourceReference As %IPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
    set tResourceRefName = pResourceReference.Name
    // Set LoadAsDirectory to 1 if resource reference name is a path.
    // Else, get name and extension from resource reference name
    if ($extract(tResourceRefName) = "/") {
        set ..LoadAsDirectory = 1
        set i%Directory = tResourceRefName
        set tSC = ##super(pResourceReference)
        if (..Extension = "") {
            set ..Extension = $$$lcase(..#EXTENSION)
        }
    } else {
        set ..Name = $piece(tResourceRefName,".",1,*-1)
        set ..Extension = $$$lcase($case(..#EXTENSION,"":$piece(tResourceRefName,".",*),:..#EXTENSION))
        set tSC = ##super(pResourceReference)
        if (i%Directory = "") {
            set i%Directory = $zconvert(..Extension,"L")
            if $listfind($listbuild("dtl","bpl"),i%Directory) {
                set i%Directory = "cls"
            }
        }
    }
    quit tSC
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        if (pPhase = "Validate") {
            if (..Extension = "") {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid resource name '%1' - must have a file extension to identify the Studio document type.",..Name))
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Enumerate all documents contained in the resource being processed. <br />
/// @Argument	pResourceArray			ByRef: array of the following format: pResourceArray(<Studio document name>) = <module that contains document>
/// pResourceArray(<Studio document name>, <resource referenty property>) = value of resource reference property for given document
Method OnResolveChildren(ByRef pResourceArray) As %Status
{
    if ..LoadAsDirectory {
        kill pResourceArray(..ResourceReference.Name)
        set tKey = ""
        while 1 {
            do ..ResourceReference.Children.GetNext(.tKey)
            quit:(tKey = "")
            set pResourceArray(tKey) = ..ResourceReference.Module.Name
            set pResourceArray(tKey,"Processor") = ..ResourceReference.Processor
            set pResourceArray(tKey,"Generated") = ..ResourceReference.Generated
            set pResourceArray(tKey,"Preload") = ..ResourceReference.Preload
            set pResourceArray(tKey,"Scope") = ..ResourceReference.Scope
            set pResourceArray(tKey,"Deploy") = ..ResourceReference.Deploy
            set pResourceArray(tKey,"RelativePath") = ..OnItemRelativePath(tKey)
        }
    } else {
        // Add the relative path for purposes of lifecycle %Export method
        set pResourceArray(..ResourceReference.Name,"RelativePath") = ..OnItemRelativePath(..ResourceReference.Name)
    }
    quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
    set tFileExtension = $select(..LoadAsDirectory:"",1:"."_..FilenameExtension)
    set tSourceRoot = ..ResourceReference.Module.SourcesRoot
    if tSourceRoot'="","\/"'[$extract(tSourceRoot, *) {
        set tSourceRoot = tSourceRoot _ "/"
    }
    set directory = ..Directory
    quit $select(..ResourceReference.Preload:"preload/",1:"")_ tSourceRoot _ $select(directory=$char(0):"", 1:directory _ "/") _ $translate($piece(pItemName,".",1,*-1),..FilenameTranslateIdentifier,..FilenameTranslateAssociator)_tFileExtension
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
    set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
    set pInfo.SourceControlAware = 1
    set pInfo.RelativePath = ..Directory
    set pInfo.ResourceType = ..Extension
    set pInfo.Prefix = ..Name_..#NAMEPOSTFIX
    if (..ResourceReference.Preload) {
        set pInfo.RelativePath = "/preload/"_pInfo.RelativePath
    }
    quit $$$OK
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
    if ($extract(..ResourceReference.Name) = "/") {
        set pUniqueName = ..ResourceReference.Module.Name_"@"_..ResourceReference.Name
    }
}

/// Helper method to be used in derived classes' OnConfigureMappings() to skip creating unnecessary mappings.
/// Returns true if <var>pResourceName</var> (in InternalName format - e.g., %Foo.Bar.PKG) is mapped to the current namespace's default routine database.
ClassMethod ResourceIsMappedToDefaultDB(pResourceName As %String) As %Boolean
{
    set defaultDB = ##class(%IPM.Utils.Module).GetRoutineDatabaseDir($namespace)
    set name = $piece(pResourceName,".",1,*-1)
    set type = $zconvert($piece(pResourceName,".",*),"U")
    if (type = "PKG") {
        set db = ##class(%SYS.Namespace).GetPackageDest(,name)
    } elseif (type = "CLS") {
        set db = ##class(%SYS.Namespace).GetPackageDest(,$piece(name,".",1,*-1))
    } else {
        set db = ##class(%SYS.Namespace).GetRoutineDest(,name)
    }
    set db = $piece(db,"^",2,*) // Slight difference in format of reporting here
    return (db = defaultDB)
}

}
