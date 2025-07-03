Include (%occInclude, %occErrors, %syConfig, %syPrompt, %IPM.Common, %IPM.Formatting)

Class %IPM.Utils.Module [ System = 3 ]
{

/// SSL/TLS config to use for HTTPS requests made by package manager code.
Parameter DefaultSSLConfigName As STRING [ Internal ] = "ZPMSSLConfig";

/// Returns the name of the default SSL config after creating if it it does not already exist.
ClassMethod CreateAndGetSSLConfig(ByRef pProperties) As %String
{
    set name = ..#DefaultSSLConfigName
    new $namespace
    set $namespace = "%SYS"
    if '##class(Security.SSLConfigs).Exists(name) {
        set pProperties("Description") = "Default SSL Config to be used by HealthShare Package Manager"
        set sc = ##class(Security.SSLConfigs).Create(name, .pProperties)
        $$$ThrowOnError(sc)
    }
    return name
}

/// Format of <var>pDependencyGraph</var>:
/// pDependencyGraph("module name") = $ListBuild(<depth>,<server name>,<version>)
/// pDependencyGraph("module name","<dependent module> <dependent module version>") = <irrelevant>
ClassMethod LoadDependencies(
	ByRef pDependencyGraph,
	ByRef pParams,
	pWorkQueue As %SYSTEM.WorkMgr)
{
    // Suspend the error count to avoid spurious messages about errors being detected in load/compile.
    $$$SuspendErrorCount
    set tSC = $$$OK
    set tLocked = 0
    set tRestoreParams = 0
    try {
        set initWorkQueueManager = '$data(pParams("Multicompile","CacheTempIndex"),tCacheTempIndex) || '$isobject($get(pWorkQueue))
        if initWorkQueueManager {
            if '$isobject($get(pWorkQueue)) {
                // There may be one at a higher stack level.
                // Deal with dependencies here, and ensure that previous CacheTempIndex can be restored at the end.
                merge tParamBackup = pParams
                set tRestoreParams = 1
            }

            if ($get(pParams("Threads")) = 1) || ($tlevel > 0) {
                set tNumWorkers = -1 // Disable multithreading.
            } else {
                set tNumWorkers = $get(pParams("Threads"),1) // Enable multicompile
            }

            set pWorkQueue = ##class(%SYSTEM.WorkMgr).Initialize("/multicompile="_tNumWorkers,.tSC)
            $$$ThrowOnError(tSC)

            set tModuleName = ""
            for {
                set tModuleName = $order(pDependencyGraph(tModuleName),1,tData)
                quit:tModuleName=""

                // List modules to avoid duplicate loads.
                set pParams("Multicompile","ModuleContext",tModuleName) = $listbuild("Activate")

                // Invert dependency graph, subscripts (<module>,<depends on>)
                set tInvertedDependencyGraph(tModuleName) = $list(tData,2,*)

                set tDependentKey = ""
                for {
                    set tDependentKey = $order(pDependencyGraph(tModuleName,tDependentKey))
                    quit:tDependentKey=""

                    set tInvertedDependencyGraph($piece(tDependentKey," "),tModuleName) = ""
                }
            }

            set tCacheTempIndex = $increment($$$ZPMTempLoadGraphRoot)
            set pParams("Multicompile","CacheTempIndex") = tCacheTempIndex
            kill $$$ZPMTempLoadGraph(tCacheTempIndex)
            merge $$$ZPMTempLoadGraph(tCacheTempIndex) = tInvertedDependencyGraph
        } else {
            lock +$$$ZPMTempLoadGraph(tCacheTempIndex):$$$LockTimeout
            if $test {
                set tLocked = 1
            } else {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to obtain lock on dependency graph."))
            }
            merge tInvertedDependencyGraph = $$$ZPMTempLoadGraph(tCacheTempIndex)
        }

        // Queue load of modules without uninstalled dependencies.
        set tModuleName = ""
        for {
            set tModuleName = $order(tInvertedDependencyGraph(tModuleName),1,tData)
            quit:tModuleName=""

            // Check if ALL subnode modules have no server name in the top level node of those modules
            // in the inverted dependency graph (which means they are already installed)
            // ONLY want to check on the initial version of the graph because nodes are killed as modules are installed
            if initWorkQueueManager {
                set tHasUninstalledDependency = 0
                set tSubnode = ""
                while 1 {
                    set tSubnode = $order(tInvertedDependencyGraph(tModuleName, tSubnode))
                    if (tSubnode = "") {
                        quit
                    }
                    // Check if subnode exists. If it doesn't, then its already been installed because subnodes are killed
                    set tSubnodeServerName = $listget($get(tInvertedDependencyGraph(tSubnode)), 1)
                    if (tSubnodeServerName '= "") {
                        set tHasUninstalledDependency = 1
                        quit
                    }
                }
            } else {
                set tHasUninstalledDependency = ($data(tInvertedDependencyGraph(tModuleName)) >= 10)
            }
            // If no uninstalled dependencies remain...
            if 'tHasUninstalledDependency {
                set $listbuild(tServerName, tVersion, tDeployed, tPlatformVersion) = tData
                zkill $$$ZPMTempLoadGraph(tCacheTempIndex,tModuleName)

                // Missing server name indicates that it's already present locally; nothing to do in that case.
                if (tServerName '= "") {
                    if ($tlevel = 0) && ($get(pParams("Multicompile","Verbose"),$get(pParams("Verbose"),0))) {
                        write !,"Queuing module load: ",tModuleName," ",tVersion," @ ",tServerName
                    }
                    set tSC = pWorkQueue.QueueCallback(
                        "##class("_$classname()_").LoadModuleReference",
                        "##class("_$classname()_").LoadCompleted",
                        tServerName, tModuleName, tVersion, $get(tDeployed), $get(tPlatformVersion), .pParams, .pDependencyGraph)
                    $$$ThrowOnError(tSC)
                } else {
                    // Remove this module from dependencies.
                    set tDependentKey = ""
                    for {
                        set tDependentKey = $order($$$ZPMTempLoadGraph(tCacheTempIndex,tDependentKey))
                        quit:tDependentKey=""

                        kill $$$ZPMTempLoadGraph(tCacheTempIndex,tDependentKey,tModuleName)
                    }
                }
            }
        }
        if (tLocked) {
            lock -$$$ZPMTempLoadGraph(tCacheTempIndex)
            set tLocked = 0
        } else {
            // Only call WaitForComplete once (!!!)
            // Recursive calls will do repeat execution of previously-queued jobs.
            set tSC = pWorkQueue.WaitForComplete()
            $$$ThrowOnError(tSC)
        }

        merge $$$ZPMHandledModules($namespace) = pParams("Multicompile","ModuleContext")
    } catch e {
        if (e.Name["ZSOAP") {
            set tSC = $get(%objlasterror,e.AsStatus())
        } else {
            set tSC = e.AsStatus()
        }
    }
    if tRestoreParams {
        kill pParams
        merge pParams = tParamBackup
    }
    if (tLocked) {
        lock -$$$ZPMTempLoadGraph(tCacheTempIndex)
    }
    quit tSC
}

/// Intended to be invoked only as a work queue callback (so %status and %workqueue will be defined)
/// Signature must match <method>LoadModuleReference</method> per work queue manager conventions.
ClassMethod LoadCompleted(
	pServerName As %String,
	pModuleName As %String,
	pVersion As %String,
	pDeployed As %String,
	pPlatformVersion As %String,
	ByRef pParams,
	ByRef pDependencyGraph) As %Status
{
    // Suspend the error count to avoid spurious messages about errors being detected in load/compile.
    $$$SuspendErrorCount
    set tSC = $$$OK
    set tLocked = 0
    try {
        $$$ThrowOnError(%status)
        if $$$ISOK(tSC) && $data(pParams("Multicompile","CacheTempIndex"),tCacheTempIndex) {
            // Remove loaded dependency from dependencies subscript.
            lock +$$$ZPMTempLoadGraph(tCacheTempIndex):$$$LockTimeout
            if $test {
                set tLocked = 1
            } else {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to obtain lock on dependency graph."))
            }
            set tDependentKey = ""
            for {
                set tDependentKey = $order($$$ZPMTempLoadGraph(tCacheTempIndex,tDependentKey))
                quit:tDependentKey=""

                kill $$$ZPMTempLoadGraph(tCacheTempIndex,tDependentKey,pModuleName)
            }
            lock -$$$ZPMTempLoadGraph(tCacheTempIndex)
            set tLocked = 0

            // Schedule load of any other modules that may need to be scheduled.
            set tSC = ..LoadDependencies(.pDependencyGraph,.pParams,%workqueue)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if (tLocked) {
        lock -$$$ZPMTempLoadGraph(tCacheTempIndex)
    }
    quit tSC
}

ClassMethod LoadQualifiedReference(
	pReference As %IPM.Storage.QualifiedModuleInfo,
	ByRef pParams,
	ByRef pDependencyGraph,
	pSynchronous As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        #dim tReference As %IPM.Storage.QualifiedModuleInfo
        set tReference = pReference.%ConstructClone()
        set tSC = ..LoadModuleReference(tReference.ServerName, tReference.Name, tReference.VersionString, tReference.Deployed, tReference.PlatformVersion, .pParams, .pDependencyGraph, pSynchronous)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod LoadModuleReference(
	pServerName As %String,
	pModuleName As %String,
	pVersion As %String,
	pDeployed As %Boolean,
	pPlatformVersion As %String,
	ByRef pParams,
	ByRef pDependencyGraph,
	pSynchronous As %Boolean = 0) As %Status
{
    // Keep a reference of the singleton in this process (which can be a new process!), so subsequent .%Get() calls return the same instance
    set configReference = ##class(%IPM.General.EnvironmentConfig).%Get()

    // Suspend the error count to avoid spurious messages about errors being detected in load/compile.
    $$$SuspendErrorCount
    #dim tExpression As %IPM.General.SemanticVersionExpression
    set tSC = $$$OK
    try {
        // Backward-compatibility: if params isn't an array, use it as qstruct
        if $data(pParams) = 1 {
            set qstruct = pParams
        }

        set tVerbose = $get(pParams("Verbose"))

        if '$data(pParams("qstruct")) {
            set qstruct = "ck"_$select(tVerbose:"d",1:"-d")
        } else {
            merge qstruct = pParams("qstruct")
        }

        // Use % variables that intentionally leak in worker processes, to avoid duplicate work when they go out of scope.
        #dim %installcontext As %IPM.General.InstallContext
        #dim %manager As %IPM.Repo.Manager
        if '$$$IsISCWorker {
            new %installcontext
            new %manager
        }
        set %installcontext = ##class(%IPM.General.InstallContext).%Get(.tSC)
        $$$ThrowOnError(tSC)
        do %installcontext.SetGraph(.pDependencyGraph)
        merge tIndex = pParams("Multicompile","CacheTempIndex")
        do %installcontext.SetCacheTempIndex(.tIndex)

        set %manager = $select($isobject($get(%manager)):%manager,1:##class(%IPM.Repo.Manager).%Get(.tSC))
        $$$ThrowOnError(tSC)

        set tClient = %manager.CheckServiceCache(pServerName,.tAvailable)
        if 'tAvailable {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pServerName))
            quit
        }
        set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
        set tModRef.Name = pModuleName
        set tModRef.VersionString = pVersion
        set tModRef.Deployed = pDeployed
        set tModRef.PlatformVersion = pPlatformVersion
        if pDeployed {
            $$$ThrowOnError(tModRef.PlatformVersions.Insert(pPlatformVersion))
        }

        // Make sure we're not downgrading.
        if '$get(pParams("PermitDowngrade")) {
            if ##class(%IPM.Storage.Module).NameExists(pModuleName) {
                set tInstModule = ##class(%IPM.Storage.Module).NameOpen(pModuleName,,.tSC)
                if $$$ISERR(tSC) {
                    quit
                }
                if $get(pParams("Install")),pModuleName'=$$$IPMModuleName,tInstModule.DeveloperMode,'$get(pParams("DeveloperMode"),0) {
                    set tSC = $$$ERROR($$$GeneralError, $$$FormatText("Cannot install '%1' over previously installed in developer mode", tInstModule.Name))
                    quit
                }
                if tInstModule.Version.Follows(tModRef.Version) {
                    set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Cannot downgrade %1 from version %2 to %3",tInstModule.Name,tInstModule.VersionString,pVersion))
                    quit
                }
            }
        }

        // Ensure requested versions match those required by other modules in the namespace, excluding versions currently being installed
        // (the requirements of such modules are already known to be satisfied)
        set tSC = ..GetRequiredVersionExpression(pModuleName,%installcontext.GetPendingModuleList(),.tExpression,.tSourceList)
        if $$$ISERR(tSC) {
            quit
        }
        if 'tExpression.IsSatisfiedBy(tModRef.Version) {
            set tSourceString = $listtostring(tSourceList,"; ")
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Requested version (%1 %2) does not satisfy the requirements of other modules installed in the current namespace (%3).",tModRef.Name,pVersion,tSourceString))
            quit
        }

        if tClient.Supports("GetModuleDirectory") {
            set tDirectory = tClient.GetModuleDirectory(tModRef)
            set tDeveloperMode = 0
            if (tModRef.Version.IsSnapshot() && $get(pParams("DeveloperMode"),0)) {
                // If we are loading a module in developer mode, and are loading a snapshot version of a dependency from disk,
                // also load the snapshot version of that dependency in developer mode.
                // This doesn't make sense if we're loading the dependency from a remote server.
                set tDeveloperMode = 1
            }
            set dotModules = ##class(%File).NormalizeDirectory(".modules", tDirectory)
            set tmpRepoMgr = ##class(%IPM.General.TempLocalRepoManager).%New(dotModules, 0)
            set tSC = ..LoadModuleFromDirectory(tDirectory,.pParams,tDeveloperMode,pServerName,pSynchronous)
            set tSC = $$$ADDSC(tSC, tmpRepoMgr.CleanUp())
        } else {
            set tAsArchive = -1
            set tPayload = tClient.GetModule(tModRef, .tAsArchive)
            if (tVerbose) {
                set serverDef = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(pServerName)
                write !,"Module "_pModuleName_" was downloaded from " _ pServerName
                if $isobject(serverDef) {
                    write " (",serverDef.Details,")"
                }
            }
            set tFileName = ""
            if ($isobject(tPayload)) && (tPayload.%IsA("%Stream.FileBinary") ) {
                set tFileName = tPayload.Filename
            }

            if (tAsArchive<0) {
                // Read the file header
                set tHeader = tPayload.Read(2,.tSC)
                if (tHeader = $char(31, 139)) {
                    // This is a .tgz file
                    set tAsArchive = 1
                }
            }
            if (tFileName="") {
                set tFileName = "module." _ $select(tAsArchive: "tgz", 1: "xml")
            }
            do tPayload.Rewind()
            set tTmpStream = ##class(%Stream.FileBinary).%New()
            set tTmpStream.Filename = tFileName
            do tTmpStream.CopyFromAndSave(tPayload)

            if (tAsArchive) {
                set tSC = ..LoadModuleFromArchive(tModRef.Name,tModRef.VersionString,tTmpStream,.pParams, pServerName,pSynchronous)
            } else {
                // Old format (TODO: officially deprecate): try loading a .xml file

                // Load without compiling -> Update legacy superclasses -> Compile
                if $data(qstruct) \ 2 = 1 {
                    set qstruct = $translate(qstruct,"c","")
                } elseif $data(qstruct("/compile")) {
                    kill qstruct("/compile")
                }
                set tSC = $system.OBJ.Load(tTmpStream.Filename,.qstruct, , .tLoaded)
                set tSC = $$$ADDSC(tSC, ##class(%IPM.Utils.LegacyCompat).UpdateSuperclassAndCompile(.tLoaded, .qstruct))
            }
            set errorMsg = "", success = 0
            if $$$ISOK(tSC) {
                set success = 1
            } else {
                set success = 0
                set errorMsg = $system.Status.GetErrorText(tSC)
            }
            if ($system.CLS.IsMthd(tClient, "CollectAnalytics")) {
                do tClient.CollectAnalytics("install", pModuleName, pVersion,success,errorMsg)
            }
        }
        if $$$ISERR(tSC) {
            quit
        }
    } catch e {
        if (e.Name["ZSOAP") {
            set tSC = $get(%objlasterror,e.AsStatus())
        } else {
            set tSC = e.AsStatus()
        }
    }
    quit tSC
}

ClassMethod LoadModuleFromArchive(
	pModuleName As %String,
	pModuleVersion As %String,
	pArchiveStream As %Stream.Object,
	ByRef pParams,
	pRepository As %String = "",
	pSynchronous As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))

        set randomDir = $translate($system.Encryption.Base64Encode($system.Encryption.GenCryptRand(6)),"+/=")
        set tTargetDirectory = ##class(%SYS.System).TempDirectory()_"/"_randomDir
        if ##class(%File).DirectoryExists(tTargetDirectory) {
            // Delete it.
            set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tTargetDirectory)
            if $$$ISERR(tSC) {
                quit
            }
        }
        set tCreated = ##class(%File).CreateDirectoryChain(tTargetDirectory,.tReturnValue)
        if 'tCreated {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",tTargetDirectory,tReturnValue))
            quit
        }
        set tTargetDirectory = ##class(%File).NormalizeFilenameWithSpaces(tTargetDirectory)
        set tSC = ##class(%IPM.General.Archive).Extract(pArchiveStream.Filename,tTargetDirectory,.tOutput)
        if $$$ISERR(tSC) {
            quit
        }
        for i=1:1:$get(tOutput) {
            write:tVerbose !,tOutput(i)
        }

        set dotModules = ##class(%File).NormalizeDirectory(".modules", tTargetDirectory)
        set tmpRepoMgr = ##class(%IPM.General.TempLocalRepoManager).%New(dotModules, 0)
        set tSC = ..LoadModuleFromDirectory(tTargetDirectory, .pParams, , pRepository,pSynchronous)
        set tSC = $$$ADDSC(tSC, tmpRepoMgr.CleanUp())
        if $$$ISERR(tSC) {
            quit
        }
        // Delete directory at the end of the run
        if ##class(%File).DirectoryExists(tTargetDirectory) {
            set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tTargetDirectory)
            if $$$ISERR(tSC) {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod LoadModuleFromDirectory(
	pDirectory As %String,
	ByRef pParams,
	pOverrideDeveloperMode As %Boolean = 0,
	pRepository As %String = "",
	pSynchronous As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        // LoadNewModule goes all the way through Reload->Validate->Compile->Activate, also compiling the new module.
        write:tVerbose !,"Loading from ",pDirectory,!
        if $get(pParams("Install")) {
            // Propagate pParams fully.
            merge tParams = pParams
            zkill tParams("Install")
        } else {
            // Only propagate selected settings that should apply to dependencies.
            set tParams("DeveloperMode") = $get(pOverrideDeveloperMode,0)
            set tParams("Verbose") = tVerbose
            set tParams("cmd") = "install"
            merge tParams("NoLock") = pParams("NoLock")
            merge tParams("NoMapping") = pParams("NoMapping")
            merge tParams("NoTransaction") = pParams("NoTransaction")
            merge tParams("NoJournal") = pParams("NoJournal")
            merge tParams("Multicompile") = pParams("Multicompile")
            merge tParams("Threads") = pParams("Threads")
            merge tParams("NoStudioProject") = pParams("NoStudioProject")
            merge tParams("AngularBuild") = pParams("AngularBuild")
            merge tParams("Artifactory") = pParams("Artifactory")
            merge tParams("AngularArtifact") = pParams("AngularArtifact")
            merge tParams("EnvFiles") = pParams("EnvFiles")
        }
        set tSC = ..LoadNewModule(pDirectory,.tParams,pRepository,pSynchronous)
        if $$$ISERR(tSC) {
            quit
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Given a path to a module.xml file (directory), tries to correlate it to an instance of <class>%IPM.Storage.Module</class>.
/// Throws errors.
ClassMethod GetModuleObjectFromPath(
	pPath As %String,
	Output pFound As %Boolean) As %IPM.Storage.Module
{
    set pFound = 0
    set pPath = ##class(%Library.File).NormalizeDirectory(pPath)
    set modulePath = pPath_"module.xml"
    if '##class(%Library.File).Exists(modulePath) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"File not found to obtain module object: "_modulePath))
    }
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(modulePath))
    return ..GetModuleObjectFromStream(stream,.pFound)
}

/// Given a stream, tries to correlate it to an instance of <class>%IPM.Storage.Module</class>.
/// Throws errors.
ClassMethod GetModuleObjectFromStream(
	pStream As %Stream.Object,
	Output pFound As %Boolean) As %IPM.Storage.Module
{
    set pFound = 0
    set reader = ##class(%XML.Reader).%New()
    set sc = reader.OpenStream(pStream)
    $$$ThrowOnError(sc)
    do reader.Correlate("Module","%IPM.Storage.Module")
    set pFound = (reader.Next(.moduleObj, .sc) > 0)
    $$$ThrowOnError(sc)
    return $get(moduleObj)
}

/// Returns a semantic version expression capturing all version requirements for a given module name in the current namespace.
/// A list of modules to exclude may be provided (for example, if these modules would be updated at the same time).
ClassMethod GetRequiredVersionExpression(
	pModuleName As %String,
	pExcludeModules As %List = "",
	Output pExpression As %IPM.General.SemanticVersionExpression,
	Output pSourceList As %List) As %Status
{
    set tSC = $$$OK
    try {
        set pExpression = ##class(%IPM.General.SemanticVersionExpression).%New()
        set pSourceList = ""

        set tResult = ##class(%IPM.Storage.Module).VersionRequirementsFunc(pModuleName,pExcludeModules)
        if (tResult.%SQLCODE < 0) {
            $$$ThrowStatus($$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message))
        }

        while tResult.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            set tVersion = tResult.%Get("Version")
            $$$ThrowOnError(##class(%IPM.General.SemanticVersionExpression).FromString(tVersion,.tVersionExpr))
            set pExpression = pExpression.And(tVersionExpr)
            set pSourceList = pSourceList_$listbuild($listtostring(tResult.%Get("ModuleNames"),", ")_": "_tVersion)
        }
        $$$ThrowOnError(tSC)
    } catch e {
        set pExpression = $$$NULLOREF
        set pSourceList = ""
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns a flat list of dependents for a given module name (and optional version) <br />
/// <var>pRepoNames</var> is a $ListBuild list of repositories in which to search for dependents; if blank, only currently-installed modules (and any missing dependencies) are considered. <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod GetDependentsList(
	Output pList As %Library.ListOfObjects(ELEMENTTYPE="%IPM.Storage.QualifiedModuleInfo"),
	Output pErrorList,
	pModuleName As %String,
	pModuleVersion As %String = "",
	pRepoNames As %List = "") As %Status
{
    set tSC = $$$OK
    kill pErrorList
    set pList = ##class(%Library.ListOfObjects).%New()
    if $get(pModuleName)="" {
        quit $$$OK
    }
    try {
        set tSC = ..BuildAllDependencyGraphs(pRepoNames,.tGraphs,.pErrorList)
        if $$$ISERR(tSC) {
            quit
        }

        // Find subscripts containing the requested module name (and possibly version) as a dependency
        set tDepList = ""
        for i=1:1:$get(tGraphs) {
            if $data(tGraphs(i,pModuleName),tInfo) {
                // Check for version match, if a version was specified.
                if (pModuleVersion '= "") && (pModuleVersion '= $listget(tInfo,3)) {
                    continue
                }

                set tQualRef = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
                set tQualRef.ServerName = $listget(tGraphs(i),1)
                set tQualRef.Name = $listget(tGraphs(i),2)
                set tQualRef.VersionString = $listget(tGraphs(i),3)
                do pList.Insert(tQualRef)
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns a tree of dependents, with dependent modules at the root, for a given module name (and optional version) <br />
/// <var>pRepoNames</var> is a $ListBuild list of repositories in which to search for dependents; if blank, only currently-installed modules (and any missing dependencies) are considered. <br />
/// Tree subscripts are $lb(Name,VersionString,ServerName). <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod GetDependentsAsTree(
	Output pTree,
	Output pErrorList,
	pModuleName As %String,
	pModuleVersion As %String = "",
	pRepoNames As %List = "") As %Status
{
    new %DepTree
    if $get(pModuleName)="" {
        quit $$$OK
    }
    set tSC = $$$OK
    kill pErrorList
    kill pTree
    try {
        set tSC = ..BuildAllDependencyGraphs(pRepoNames,.tGraphs,.pErrorList)
        if $$$ISERR(tSC) {
            quit
        }

        // Find subscripts containing the requested module name (and possibly version) as a dependency
        set tDepList = ""
        for i=1:1:$get(tGraphs) {
            if $data(tGraphs(i,pModuleName),tInfo) {
                // Check for version match, if a version was specified.
                if (pModuleVersion '= "") && (pModuleVersion '= $listget(tInfo,3)) {
                    continue
                }

                set tDepList = tDepList_$listbuild(i)
            }
        }

        // TODO: Handle cyclic dependencies?
        set tPointer = 0
        while $listnext(tDepList,tPointer,tDepIndex) {
            kill tInfo merge tInfo = tGraphs(tDepIndex)
            do ..InvertDependencies(pModuleName,.tInfo,.tTree)
            merge %DepTree = tTree
        }

        // Trim extra nodes from tree (i.e., those also dependend on by another module)
        set tRef = "%DepTree"
        for {
            set tRef = $query(@tRef)
            quit:tRef=""

            if $data(@tRef) > 10 {
                zkill @tRef
            }
        }

        merge pTree = %DepTree
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod InvertDependencies(
	pNodeName As %String,
	ByRef pGraph,
	Output pTree) [ Private ]
{
    set pTree=""
    set tSource = ""
    if ($listget(pGraph,2) = pNodeName) {
        set tKey = $listbuild(pNodeName,$listget(pGraph,3),$listget(pGraph,1))
        set pTree(tKey) = ""
    } else {
        set tKey = $listbuild(pNodeName,$listget(pGraph(pNodeName),3),$listget(pGraph(pNodeName),2))
        for {
            set tSource = $order(pGraph(pNodeName,tSource))
            set pTree(tKey) = ""
            quit:(tSource="")

            do ..InvertDependencies($piece(tSource," "),.pGraph,.tTree)
            merge pTree(tKey) = tTree
        }
    }
}

ClassMethod BuildAllDependencyGraphs(
	pRepoNames As %List = "",
	Output pGraphs,
	Output pErrorList) As %Status [ Internal ]
{
    #dim tModule As %IPM.Storage.Module
    set tSC = $$$OK
    kill pGraphs
    kill pErrorList
    try {
        if '$listlength(pRepoNames) {
            set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name from %IPM_Storage.ModuleItem")
            if (tRes.%SQLCODE < 0) {
                throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
            }
            while tRes.%Next(.tSC) {
                if $$$ISERR(tSC) {
                    quit
                }

                set tModule = ##class(%IPM.Storage.Module).NameOpen(tRes.%Get("Name"),,.tSC)
                if $$$ISERR(tSC) {
                    quit
                }

                // Build dependency graph. Unlike case below, do not force "reload"
                kill tDependencyGraph,tSubModules
                set tGraphSC = tModule.BuildDependencyGraph(.tDependencyGraph,,,,,.tSubModules)

                // If there's an error, note it and just move on.
                if $$$ISERR(tGraphSC) {
                    // Non-fatal error
                    set pErrorList($increment(pErrorList)) = $listbuild("",tModule.Name,tModule.VersionString,tGraphSC)
                    continue
                }

                // Add dependency graph to pGraphs, subscripted by qualified module reference.
                set pGraphs($increment(pGraphs)) = $listbuild("",tModule.Name,tModule.VersionString)
                merge pGraphs(pGraphs) = tDependencyGraph
            }
            if $$$ISERR(tSC) {
                quit
            }
        } else {
            set tPointer = 0
            while $listnext(pRepoNames,tPointer,tRepoName) {
                set tRepo = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tRepoName,,.tSC)
                if $$$ISERR(tSC) {
                    // Fatal error: repository name invalid
                    quit
                }

                if 'tRepo.Enabled {
                    continue
                }

                #dim tPackageService As %IPM.Repo.IPackageService
                set tPackageService = tRepo.GetPackageService()
                set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
                set tSearchCriteria.IncludePrerelease = tRepo.Prereleases
                set tSearchCriteria.IncludeSnapshots = tRepo.Snapshots
                set tList = tPackageService.ListModules(tSearchCriteria)
                for i=1:1:tList.Count() {
                    #dim tModRef As %IPM.Storage.ModuleInfo
                    set tModRef = tList.GetAt(i)

                    // Retrieve module manifest
                    set tManifest = tPackageService.GetModuleManifest(tModRef)

                    set tReader = ##class(%XML.Reader).%New()
                    set tSC = tReader.OpenStream(tManifest)
                    if $$$ISERR(tSC) {
                        quit
                    }
                    do tReader.Correlate("Module","%IPM.Storage.Module")
                    do tReader.Next(.tModule,.tCorrSC)
                    if $$$ISERR(tCorrSC) {
                        // Non-fatal error
                        set pErrorList($increment(pErrorList)) = $listbuild(tRepoName,tModRef.Name,tModRef.VersionString,tCorrSC)
                        continue
                    }

                    // Build dependency graph, ignoring currently-installed modules (the last argument)
                    kill tDependencyGraph,tSubModules
                    set tGraphSC = tModule.BuildDependencyGraph(.tDependencyGraph,,,,,.tSubModules,,,1)

                    // If there's an error, note it and just move on.
                    if $$$ISERR(tGraphSC) {
                        // Non-fatal error
                        set pErrorList($increment(pErrorList)) = $listbuild(tRepoName,tModRef.Name,tModRef.VersionString,tGraphSC)
                        continue
                    }

                    if '$data(tDependencyGraph) {
                        // No dependencies, don't bother recording anything.
                        continue
                    }

                    // Add dependency graph to pGraphs, subscripted by qualified module reference.
                    set pGraphs($increment(pGraphs)) = $listbuild(tRepoName,tModRef.Name,tModRef.VersionString)
                    merge pGraphs(pGraphs) = tDependencyGraph
                }
                if $$$ISERR(tSC) {
                    quit
                }
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Uninstalls all modules from the current namespace
ClassMethod UninstallAll(
	pForce As %Boolean,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        // Get all dependency graphs for the namespace.
        set tSC = ..BuildAllDependencyGraphs(,.tGraphs)
        $$$ThrowOnError(tSC)

        // Build arrays mapping dependencies in both directions.
        // Doesn't need to be recursive.
        for tIndex=1:1:$get(tGraphs) {
            set tModuleName = $listget(tGraphs(tIndex),2)
            set tModuleNames(tModuleName) = ""
            set tDependency = ""
            for {
                set tDependency = $order(tGraphs(tIndex,tDependency),1,tData)
                if (tDependency = "") {
                    quit
                }
                if ($listget(tData,2) '= "") {
                    // This is not actually installed locally.
                    continue
                }
                set tDependsOn(tModuleName,tDependency) = ""
                set tModuleNames(tDependency,tModuleName) = ""
            }
        }

        set tProgressMade = 1
        for {
            if '$data(tModuleNames) {
                quit
            }
            if 'tProgressMade {
                set tFirstSC = $$$ERROR($$$GeneralError,"Unable to uninstall all modules.")
                set tSC = $system.Status.AppendStatus(tFirstSC,tSC) // Append any previous errors (which may be causes or unrelated)
                $$$ThrowStatus(tSC)
            }
            set tProgressMade = 0

            // Loop over "dependents" array to delete each module that has nothing left that depends on it.
            // If a module fails to uninstall, modules that it depends on will not be uninstalled, unless
            // pForce is true.
            set tModuleName = ""
            for {
                set tModuleName = $order(tModuleNames(tModuleName))
                if (tModuleName = "") {
                    quit
                }

                if ($data(tModuleNames(tModuleName)) > 1) {
                    // If there are dependencies left that have not been uninstalled yet, skip this module.
                    continue
                }

                if $data(tFailedModules(tModuleName)) {
                    // If we have already tried unsuccessfully to uninstall a given module, don't try again.
                    continue
                }

                kill tParams
                merge tParams = pParams
                write !,"Uninstalling ",tModuleName
                set tOneSC = ##class(%IPM.Storage.Module).Uninstall(tModuleName,pForce,,.tParams)
                if $$$ISOK(tOneSC) || pForce {
                    // If we are forcing uninstallation of everything that can be uninstalled,
                    // treat the module in question as uninstalled even if something went fatally wrong.
                    set tDependentModule = ""
                    for {
                        set tDependentModule = $order(tDependsOn(tModuleName,tDependentModule))
                        if (tDependentModule = "") {
                            quit
                        }
                        kill tModuleNames(tDependentModule,tModuleName)
                    }
                    kill tDependsOn(tModuleName)
                    kill tModuleNames(tModuleName)
                    set tProgressMade = 1
                }
                if $$$ISERR(tOneSC) {
                    write !,"Error uninstalling ",tModuleName,": ",$system.Status.GetErrorText(tOneSC)
                    set tSC = $system.Status.AppendStatus(tSC,tOneSC)
                    set tFailedModules(tModuleName) = ""
                }
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// If <var>pSnapshots</var> is empty, lists all modules.
/// If 1, only snapshots; if 0, only non-snapshots.
ClassMethod GetInstalledModuleListSQL(
	Output pSQL As %String,
	pSnapshots As %Boolean = "") As %Status
{
    set pSQL = "select Name from %IPM_Storage.ModuleItem"
    if (pSnapshots = 0) {
        set pSQL = pSQL_" where Version_Build <> 'snapshot'"
    } elseif (pSnapshots = 1) {
        set pSQL = pSQL_" where Version_Build = 'snapshot'"
    }
    set pSQL = pSQL_" order by Name"
    quit $$$OK
}

ClassMethod GetModuleListSQL(Output pSQL As %String) As %Status
{
    try {
        set tSC = $$$OK
        set pSQL = "select * from %IPM_Utils.Module_GetAvailableModuleNames()"
    } catch ex {
        set tSC = ex.AsStatus()
    }
    quit tSC
}

Query GetAvailableModuleNames() As %Query(ROWSPEC = "Name:%String") [ SqlProc ]
{
}

ClassMethod GetAvailableModuleNamesExecute(ByRef qHandle As %Binary) As %Status
{
    set tSC = $$$OK
    try {
        set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
        set tSC = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(tSearchCriteria,.tResults)
        if $$$ISERR(tSC) {
            quit
        }
        for i=1:1:tResults.Count() {
            #dim tRef As %IPM.Storage.QualifiedModuleInfo = tResults.GetAt(i)
            set qHandle(tRef.Name) = ""
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod GetAvailableModuleNamesFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = GetAvailableModuleNamesExecute ]
{
    set qHandle = $order(qHandle($get(qHandle)))
    if (qHandle = "") {
        set AtEnd = 1
    } else {
        set Row = $listbuild(qHandle)
    }
    quit $$$OK
}

ClassMethod GetAvailableModuleNamesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = GetAvailableModuleNamesExecute ]
{
    quit $$$OK
}

Query GetModuleList(
	pServer As %String,
	pShowAllVersions As %Boolean) As %Query(ROWSPEC = "Name:%String,Version:%String,Repository:%String,Description:%String,Origin:%String,AllVersions:%String") [ SqlProc ]
{
}

ClassMethod GetModuleListExecute(
	ByRef qHandle As %Binary,
	pServer As %String,
	pShowAllVersions As %Boolean = 0) As %Status
{
    if (pServer = "") {
        set qHandle = ""
        quit $$$OK
    }
    set tSC = $$$OK
    try {
        set tServer = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(pServer,,.tSC)
        if $$$ISERR(tSC) {
            quit
        }

        set tClient = tServer.GetPackageService()
        if tClient.IsAvailable() {
            set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
            set tSearchCriteria.IncludePrerelease = tServer.Prereleases
            set tSearchCriteria.IncludeSnapshots = tServer.Snapshots
            set tSearchCriteria.AllVersions = pShowAllVersions
            set tList = tClient.ListModules(tSearchCriteria)
            for i=1:1:tList.Count() {
                set tMod = tList.GetAt(i)
                set qHandle($increment(qHandle)) = $listbuild(tMod.Name,tMod.Version.ToString(),tMod.Repository,tMod.Description, tMod.Origin, tMod.AllVersions)
            }
        }

        set qHandle = ""
    } catch e {
        if (e.Name["ZSOAP") {
            set tSC = $get(%objlasterror,e.AsStatus())
        } else {
            set tSC = e.AsStatus()
        }
    }
    quit tSC
}

ClassMethod GetModuleListFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = GetModuleListExecute ]
{
    set qHandle = $order(qHandle(qHandle),1,Row)
    set:qHandle="" AtEnd = 1
    quit $$$OK
}

ClassMethod GetModuleListClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = GetModuleListExecute ]
{
    quit $$$OK
}

Query ListProcessorAttributes(pProcessorClass As %String) As %Query(ROWSPEC = "Name:%String,Type:%String,Description:%String,Default:%String,Required:%Boolean,VALUELIST:%String,DISPLAYLIST:%String,MINLEN:%String,MAXLEN:%String,MINVAL:%Integer,MAXVAL:%Integer") [ SqlProc ]
{
}

ClassMethod ListProcessorAttributesExecute(
	ByRef qHandle As %Binary,
	pProcessorClass As %String = "") As %Status
{
    set tSC = $$$OK
    try {
        set qHandle("pointer") = ""
        set tSuper = "%IPM.ResourceProcessor.Abstract"
        if '$$$comClassDefined(pProcessorClass) && $$$comClassDefined($$$DefaultProcessorPackageDot_pProcessorClass) {
            set pProcessorClass = $$$DefaultProcessorPackageDot_pProcessorClass
        }
        if '$classmethod(pProcessorClass,"%Extends",tSuper) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Class '%1' does not extend '%2'",pProcessorClass,tSuper))
            quit
        }
        set tSC = $classmethod(pProcessorClass,"GetAttributeMetadata",.tMetadata)
        if $$$ISERR(tSC) {
            quit
        }
        merge qHandle("data") = tMetadata
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod ListProcessorAttributesFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ListAttributesExecute ]
{
    set qHandle("pointer") = $order(qHandle("data",qHandle("pointer")),1,Row)
    if (qHandle("pointer") = "") {
        set AtEnd = 1
    }
    quit $$$OK
}

ClassMethod ListProcessorAttributesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ListAttributesExecute ]
{
    quit $$$OK
}

ClassMethod GetModuleNameFromXML(
	pDirectory As %String,
	Output name As %String) As %Status
{
    set stream=##class(%Stream.FileBinary).%New()
    set tSC = stream.LinkToFile(pDirectory_"module.xml")
    return:$$$ISERR(tSC) tSC
    set tSC = ##class(%XML.XPATH.Document).CreateFromStream(stream, .tDocument)
    return:$$$ISERR(tSC) tSC
    set tSC = tDocument.EvaluateExpression("/Export/Document/Module/Name", "text()", .tRes)
    if $$$ISERR(tSC) return tSC
    set name = $$$lcase(tRes.GetAt(1).Value)
    return $$$OK
}

ClassMethod ExportDocumentForObject(
	pSourceModule As %IPM.Storage.Module,
	Output pSourceControlOutput) As %Status
{
    set tSC = $$$OK
    set tCookie = ""
    try {
        new %SourceControl

        do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)

        do ##class(%Studio.SourceControl.Interface).SourceControlCreate()

        set tDocName = pSourceModule.Name_".ZPM"

        set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tDocName,.tIsInSourceControl,.tIsEditable)
        $$$ThrowOnError(tSC)

        if tIsInSourceControl && 'tIsEditable {
            // Try to make the document editable.
            set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnMakeModuleEditable(pSourceModule)
            $$$ThrowOnError(tSC)
        }

        // Did we actually make the document editable?
        set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tDocName,,.tIsEditable)
        $$$ThrowOnError(tSC)

        // If still not editable, error out.
        if 'tIsEditable {
            $$$ThrowStatus($$$ERROR($$$ItemNotCheckedOut,tDocName))
        }

        set tModuleStream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen(pSourceModule.Name,,.tSC)
        if $listfind($listfromstring($system.Status.GetErrorCodes(tSC)),$$$KeyValueNotFoundOpen) {
            // It's possible that only the module exists - we'll skip the merge with the document's content if it does.
            set tSC = $$$OK
        }
        if $$$ISERR(tSC) {
            quit
        }

        if $isobject(tModuleStream) {
            // Extract comments from existing document stream
            set tHandler = ##class(%IPM.Utils.XMLCommentHandler).%New()
            set tReader = ##class(%XML.SAX.Parser).%New()
            set tSC = ##Class(%XML.SAX.Parser).ParseStream(tModuleStream.Contents,tHandler)
            $$$ThrowOnError(tSC)
        }

        // Use document API
        #dim tExportStream As %Stream.Object
        set tSC = pSourceModule.XMLExportToStream(.tExportStream,,"literal,indent")
        if $$$ISERR(tSC) {
            quit
        }

        if $isobject(tModuleStream) {
            // Reapply comments to exported XML stream
            set tSC = tHandler.Reapply(.tExportStream)
            $$$ThrowOnError(tSC)
        }

        // Save the document.
        set tRtn = ##class(%Library.RoutineMgr).%OpenId(tDocName)
        if (tRtn = $$$NULLOREF) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Module %1 does not exist.",pModuleName))
            quit
        }

        // NOTE: tRtn.Code is a %IPM.StudioDocument.Module
        do tRtn.Code.Code.Clear()
        set tHeader = tExportStream.ReadLine()
        if ($extract(tHeader,1,2) '= "<?") {
            do tRtn.Code.Code.WriteLine("<?xml version=""1.0""?>")
        }
        do tExportStream.Rewind()
        set tSC = tRtn.Code.Code.CopyFrom(tExportStream)
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = tRtn.%Save()
        if $$$ISERR(tSC) {
            quit
        }
    } catch e {
        set tSC = e.AsStatus()
    }

    // Ensure I/O redirection ends.
    do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pSourceControlOutput)
    quit tSC
}

ClassMethod LoadNewModule(
	pDirectory As %String,
	ByRef pParams,
	pRepository As %String = "",
	pSynchronous As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        set tVerbose = $get(pParams("Verbose"))
        set tUseTransactions = '($get(pParams("NoTransaction"),0) || $get(pParams("NoJournal"),0))
        if '$data(pParams("qstruct")) {
            set qstruct = "ck"_$select(tVerbose:"d",1:"-d")
        }

        // Check for valid license key prior to top-level module load
        // This may throw an exception.
        if '$data($$$ZPMHandledModules($namespace)) {
            set tLicenseIsValid = ..CheckLicenseKey()
            if 'tLicenseIsValid {
                write !,"WARNING: Continuing module load without a valid license."
            }
        }

        // Create a singleton instance for logging of warnings/error messages
        set tLogManager = ##class(%IPM.General.LogManager).%Get(.tSC)
        $$$ThrowOnError(tSC)

        // Show INFO+ if verbose, WARNING+ if not.
        set tMinLogLevel = $select(tVerbose:1,1:2)
        if (tLogManager.Threshold > tMinLogLevel) {
            set tLogManager.Threshold = tMinLogLevel
        }

        set pDirectory = ##class(%File).NormalizeDirectory("",pDirectory)

        if ($get(pParams("NoJournal"),0) '= 0) {
            // Disable journalling with process-level switch.
            set tJournalMgr = ##class(%IPM.Utils.JournalManager).%New(0)
        } elseif tUseTransactions {
            tstart
        }
        set tSC = $system.OBJ.Load(pDirectory_"module.xml",$select(tVerbose:"d",1:"-d"),,.tLoadedList)
        $$$ThrowOnError(tSC)

        set tFirstLoaded = $order(tLoadedList(""))
        if (tFirstLoaded = "") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"No module definition found."))
        }
        if ($order(tLoadedList(tFirstLoaded)) '= "") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"module.xml contains multiple documents."))
        }
        set tFirstLoaded = $$$lcase(tFirstLoaded)
        if ($piece(tFirstLoaded,".",*) '= "zpm") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"No module definition found."))
        }

        set tDisplayName = $piece(tFirstLoaded, ".", 1, *-1)
        set tModuleName = $$$lcase(tDisplayName)

        if (pRepository '= "") {
            // Force developer mode to be 0 if repository is read only.
            if ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(pRepository, .tRepositoryId) {
                if +##class(%IPM.Repo.Definition).ReadOnlyGetStored(tRepositoryId) {
                    // Set in pParams directly so that this value gets transmitted downstream
                    set pParams("DeveloperMode") = 0
                    if tVerbose {
                        write !, "Repository "_pRepository_" is Read-Only so "_tDisplayName_" will be loaded in non-developer mode"
                    }
                }
            }
        }

        set tModule = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
        $$$ThrowOnError(tSC)
        set tModule.Repository = pRepository

        if $data(pParams("DeveloperMode"),tDeveloperMode) {
            // Mark module as not deployed if installing with dev mode
            set tModule.Deployed = 0
            set tModule.DeveloperMode = tDeveloperMode
            set tModule.Root = pDirectory
            set tSC = tModule.%Save()
            $$$ThrowOnError(tSC)
        } else {
            set tDeveloperMode = +tModule.DeveloperMode
        }

        if (tDeveloperMode && tUseTransactions) {
            // In developer mode, save the module manifest so we can fix it even if errors occur afterward.
            tcommit

            // Nested transactions in underlying calls to LoadNewModule during the dependency resolution process may be rolled back at the end of this method.
            // To debug a dependency, that module itself should be loaded in "developer mode"
            tstart
        }

        if '$data($$$ZPMHandledModules($namespace)) {
            // The purpose of this NEW command is to make sure that the % variable $$$ZPMHandledModules refers to doesn't leak outside this scope.
            // This only happens for the first module to be loaded in a set of dependencies (using zpm "load ..." or zpm "install ...")
            // $$$ZPMHandledModules is also used in the ExecutePhases method of %IPM.Storage.Module to
            // cover cases where new dependencies are added and a module is compiled without reloading, and in the BuildDependencyGraph
            // method to treat installed snapshot versions as installed rather than forcing reload if they have been reloaded
            // as part of the same root module operation.
            new $$$ZPMHandledModules
            set $$$ZPMHandledModules($namespace) = "" //Initialize.
        }
        merge $$$ZPMHandledModules($namespace) = pParams("Multicompile","ModuleContext")

        $$$ThrowOnError(##class(%IPM.Storage.Module).CheckSystemRequirements(tModuleName))

        #dim tInstallContext As %IPM.General.InstallContext
        set tInstallContext = ##class(%IPM.General.InstallContext).%Get(.tSC)
        $$$ThrowOnError(tSC)
        if 'tInstallContext.ModuleIsDependency(tModuleName) {
            if 'pSynchronous {
                // Regular async multi-threaded loading of dependencies
                set tSC = tModule.LoadDependencies("",.pParams)
                $$$ThrowOnError(tSC)
            } else {
                // Temporary custom loading of dependencies in a synchronous
                // manner to prevent lock timeouts until lifecycle rework
                // is complete (HSIEO-4450)
                do ..SyncLoadDependencies(tModule, .pParams)
            }
        }

        set tSC = $system.OBJ.Load(pDirectory_"module.xml",$select(tVerbose:"d",1:"-d"),,.tLoadedList)
        $$$ThrowOnError(tSC)
        set tSC = tModule.%Reload()
        $$$ThrowOnError(tSC)

        if (tDeveloperMode && tUseTransactions) {
            // In developer mode, commit load of dependencies (if all went well) and don't wrap reload/compile of this module's code
            // in a transaction; we want to be able to debug!
            tcommit
        }
        set pParams("RootDirectory") = pDirectory
        if tVerbose || $get(pParams("Multicompile","Verbose"),0) {
            write !,"Loading "_tDisplayName_" in process "_$job
        }
        set tSC = ##class(%IPM.Storage.Module).ExecutePhases(tModuleName,$listbuild("Activate"),1,.pParams)
        if $$$ISOK(tSC) && 'tDeveloperMode && tUseTransactions {
            tcommit
        }
        $$$ThrowOnError(tSC)
        do tModule.WriteAfterInstallMessage()
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }
    quit tSC
}

/// Temporary workaround to synchronously load dependencies. Can be removed once
/// HSIEO-4450 is complete.
ClassMethod SyncLoadDependencies(
	pModule As %IPM.Storage.Module,
	ByRef pParams)
{
    set isVerbose = $get(pParams("Verbose"),0)

    /*
     * Call to BuildDependencyGraph copied from %IPM.Storage.Module:LoadDependencies
     */

    set reloadSnapshots = +$get(pParams("UpdateSnapshots"))
    set permitDowngrade = +$get(pParams("PermitDowngrade"))
    set ignoreInstalled = +$get(pParams("IgnoreInstalled"))
    write !, "Building dependency graph..." // Intentionally always write even in non-verbose mode
    set sc = pModule.BuildDependencyGraph(.depdendencyGraph,,reloadSnapshots,,"",,,,ignoreInstalled,,permitDowngrade)
    $$$ThrowOnError(sc)
    write "Done."

    /* This setting is copied from %IPM.Main:Install */
    set pParams("Install") = 1

    do ..ConstructInvertedDependencyGraph(.depdendencyGraph, .invertedDependencyGraph)
    if isVerbose {
        write !, "Created inverted dependency graph from dependency graph"
    }

    #dim flatDepList As %Library.ListOfObjects
    set flatDepList = ..GetFlatDependencyListFromInvertedDependencyGraph(.invertedDependencyGraph)
    if isVerbose {
        write !, "Constructed flat dependency list from inverted dependency graph"
        write !, "Starting installation of dependencies..."
        write !
    }
    for i = 1:1:flatDepList.Count() {
        #dim moduleReference As %IPM.Storage.QualifiedModuleInfo
        set moduleReference = flatDepList.GetAt(i)
        if (moduleReference.ServerName = "") {
            // Ignore modules already installed that do not need to be installed again
            continue
        }
        set sc = ..LoadModuleReference(moduleReference.ServerName, moduleReference.Name, moduleReference.VersionString,$get(tDeployed), $get(tPlatformVersion), .pParams)
        $$$ThrowOnError(sc)
    }
}

/// Construct an inverted dependency graph from the dependency graph of a module. <br />
/// @Argument	pDependencyGraph			Dependency graph constructed. <br />
/// @Argument	pInvertedDependencyGraph	Inverted dependency graph constructed. <br />
ClassMethod ConstructInvertedDependencyGraph(
	ByRef pDependencyGraph,
	Output pInvertedDependencyGraph)
{
    set moduleName = ""
    while 1 {
        set moduleName = $order(pDependencyGraph(moduleName), 1, data)
        if (moduleName = "") {
            quit
        }
        // Invert dependency graph, subscripts (<module>, <depends on>)
        set pInvertedDependencyGraph(moduleName) = $list(data, 2, 3)
        set dependentKey = ""
        for {
            set dependentKey = $order(pDependencyGraph(moduleName, dependentKey))
            if (dependentKey = "") {
                quit
            }
            set pInvertedDependencyGraph($piece(dependentKey, " "), moduleName) = ""
        }
    }
}

/// Given an inverted dependency graph, construct an ordered dependency list.
/// The ordering is from least dependent module to most dependent. It is essentially a
/// flattened dependency graph. <br />
/// @Argument	pInvertedDependencyGraph		Inverted dependency graph. <br />
ClassMethod GetFlatDependencyListFromInvertedDependencyGraph(ByRef pInvertedDependencyGraph) As %Library.ListOfObjects(ELEMENTTYPE="%IPM.Storage.QualifiedModuleInfo")
{
    #dim moduleReference As %IPM.Storage.QualifiedModuleInfo
    set orderedDependencyList = ##class(%Library.ListOfObjects).%New()
    set moduleName = ""
    while 1 {
        // Note that all nodes have to be killed eventually because no cyclic dependencies
        // are allowed to exist
        if '$data(pInvertedDependencyGraph) {
            quit
        }
        set moduleName = $order(pInvertedDependencyGraph(moduleName))
        if (moduleName = "") {
            set moduleName = $order(pInvertedDependencyGraph(moduleName))
        }

        // If it has no remaining dependencies
        if $data(pInvertedDependencyGraph(moduleName)) < 10 {
            set $listbuild(repositoryName, versionString) = $get(pInvertedDependencyGraph(moduleName))
            // Create qualified module reference to add to list
            set moduleReference = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
            set moduleReference.Name = moduleName
            set moduleReference.VersionString = versionString
            set moduleReference.ServerName = repositoryName
            $$$ThrowOnError(orderedDependencyList.Insert(moduleReference))
            // Remove node from graph
            kill pInvertedDependencyGraph(moduleName)
            // Remove from all entries in graph
            set dependencyName = ""
            while 1 {
                set dependencyName = $order(pInvertedDependencyGraph(dependencyName))
                if (dependencyName = "") {
                    quit
                }
                zkill pInvertedDependencyGraph(dependencyName, moduleName)
            }
        }
    }
    return orderedDependencyList
}

ClassMethod CheckLicenseKey() As %Boolean
{
    // Limit the number of attempts in case this somehow ends up running in a non-interactive process.
    #define MaxTries 5
    set tValidLicense = ($system.License.GetKeyStatus() '= "Invalid")
    while ('tValidLicense) && $$$InProgrammerMode && ('$$$IsISCWorker) && ($increment(tTries) <= $$$MaxTries) {
        write !!,"Your system has no (valid) license key present"
        write !,"Copy a valid license key into "_$system.Util.ManagerDirectory()
        write !,"and then enter 'y' to activate it. Enter 'n' to continue without a license key, "
        write !,"or 'q' to quit."
        set tValue = 1
        set tResponse = ##class(%Library.Prompt).GetYesNo("Action >",.tValue,,$$$DisableHelpCharMask + $$$DisableBackupCharMask + $$$EnableQuitCharMask)
        if (tResponse '= $$$SuccessResponse) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Installation cancelled due to lack of license key."))
        }
        if ('tValue) {
            // The user wants to keep going anyway.
            quit
        }

        // Try to activate the license.
        set tSC = $system.License.Upgrade()
        if $$$ISERR(tSC) {
            write !!,"ERROR activating license: ",!,$system.Status.GetErrorText(tSC)
        } else {
            write !,"License activated."
            set tValidLicense = 1
        }
    }
    quit tValidLicense
}

ClassMethod AddPackageMapping(
	pNamespace As %String,
	pMapping As %String,
	pFrom As %String,
	pSkipActivation As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        if $$$ucase(pNamespace) = "%ALL" {
            set tSC = ..CreateAllNamespace()
            if $$$ISERR(tSC) {
                quit
            }
        }
        set tPrevNS = $namespace
        new $namespace
        set $namespace = "%SYS"
        if '##class(Config.MapPackages).Exists(pNamespace,pMapping) {
            set tProps("Database") = pFrom
            $$$ThrowOnError(##class(Config.MapPackages).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
            if 'pSkipActivation {
                new $namespace
                set $namespace = tPrevNS
                $$$ThrowOnError(..ActivateMappings(pNamespace))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod RemovePackageMapping(
	pNamespace As %String,
	pMapping As %String,
	pSkipActivation As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        set tPrevNS = $namespace
        new $namespace
        set $namespace = "%SYS"
        if ##class(Config.MapPackages).Exists(pNamespace,pMapping) {
            $$$ThrowOnError(##class(Config.MapPackages).Delete(pNamespace,pMapping,,$$$CPFSave))
            if 'pSkipActivation {
                new $namespace
                set $namespace = tPrevNS
                $$$ThrowOnError(..ActivateMappings(pNamespace))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod AddRoutineMapping(
	pNamespace As %String,
	pMapping As %String,
	pType As %String = "ALL",
	pFrom As %String,
	pSkipActivation As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        if $$$ucase(pNamespace) = "%ALL" {
            set tSC = ..CreateAllNamespace()
            if $$$ISERR(tSC) {
                quit
            }
        }
        set tPrevNS = $namespace
        new $namespace
        set $namespace = "%SYS"
        set pMapping = pMapping_$select(pType="ALL":"",1:"_"_pType)
        if '##class(Config.MapRoutines).Exists(pNamespace,pMapping) {
            set tProps("Database") = pFrom
            $$$ThrowOnError(##class(Config.MapRoutines).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
            if 'pSkipActivation {
                new $namespace
                set $namespace = tPrevNS
                $$$ThrowOnError(..ActivateMappings(pNamespace))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod RemoveRoutineMapping(
	pNamespace As %String,
	pMapping As %String,
	pType As %String = "ALL",
	pSkipActivation As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        set tPrevNS = $namespace
        new $namespace
        set $namespace = "%SYS"
        set pMapping = pMapping_$select(pType="ALL":"",1:"_"_pType)
        if ##class(Config.MapRoutines).Exists(pNamespace,pMapping) {
            $$$ThrowOnError(##class(Config.MapRoutines).Delete(pNamespace,pMapping,,$$$CPFSave))
            if 'pSkipActivation {
                new $namespace
                set $namespace = tPrevNS
                $$$ThrowOnError(..ActivateMappings(pNamespace))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod AddGlobalMapping(
	pNamespace As %String,
	pMapping As %String,
	pFrom As %String,
	pSetCollation As %Boolean = 0,
	pSkipActivation As %Boolean = 0,
	ByRef pChanged As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        if $$$ucase(pNamespace) = "%ALL" {
            set tSC = ..CreateAllNamespace()
            if $$$ISERR(tSC) {
                quit
            }
        }
        set tPrevNS = $namespace
        new $namespace
         set $namespace = "%SYS"
        if (pMapping [ ":(") {
            // 2008 has glo:(subs), 2009 has glo(subs)
            set pMapping=$piece(pMapping,":(")_"("_$piece(pMapping,":(",2,*)
        }

        if '##Class(Config.MapGlobals).Exists(pNamespace,pMapping) {
            set tProps("Database") = pFrom
            if pSetCollation {
                set tDB=##class(SYS.Database).%OpenId(##class(%Library.File).NormalizeDirectory($system.Util.InstallDirectory()_"mgr")_pFrom)
                if $isobject(tDB) {
                    set tProps("Collation") = tDB.NewGlobalCollation
                }
            }
            $$$ThrowOnError(##class(Config.MapGlobals).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
            if pSkipActivation {
                set pChanged = 1
            } else {
                new $namespace
                set $namespace = tPrevNS
                $$$ThrowOnError(..ActivateMappings(pNamespace))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod RemoveGlobalMapping(
	pNamespace As %String,
	pMapping As %String = "",
	pSkipActivation As %Boolean = 0,
	ByRef pChanged As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        set tPrevNS = $namespace
        new $namespace
        set $namespace = "%SYS"
        if pMapping [ ":(" {
            // 2008 has glo:(subs), 2009 has glo(subs)
            set pMapping=$piece(pMapping,":(")_"("_$piece(pMapping,":(",2,999)
        }
        if ##class(Config.MapGlobals).Exists(pNamespace,pMapping) {
            $$$ThrowOnError(##class(Config.MapGlobals).Delete(pNamespace,pMapping,,$$$CPFSave))
            if pSkipActivation {
                set pChanged = 1
            } else {
                new $namespace
                set $namespace = tPrevNS
                $$$ThrowOnError(..ActivateMappings(pNamespace))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod CreateAllNamespace() As %Status
{
    new $namespace
    set $namespace = "%SYS"

    set ns = "%All"
    set tSC = $$$OK

    if ('##Class(Config.Namespaces).Exists(ns)) {
        set dbPrefix = $select($zversion["IRIS": "IRIS", 1: "CACHE")
        set Properties("Globals") = dbPrefix _ "TEMP"
        set Properties("Routines") = dbPrefix _ "TEMP"
        set tSC = ##Class(Config.Namespaces).Create(ns, .Properties)
        if ($$$ISERR(tSC)) {
            return tSC
        }
    }
    return tSC
}

ClassMethod GetRoutineDatabase(pNamespace As %String) As %String
{
    new $namespace
    set $namespace="%SYS"
    quit ##class(Config.Namespaces).Open(pNamespace).Routines
}

ClassMethod GetGlobalDatabase(pNamespace As %String) As %String
{
    new $namespace
    set $namespace="%SYS"
    quit ##class(Config.Namespaces).Open(pNamespace).Globals
}

ClassMethod GetRoutineDatabaseDir(pNamespace As %String) As %String
{
    new $namespace
    set $namespace="%SYS"
    quit ..GetDatabaseDirectory(..GetRoutineDatabase(pNamespace))
}

ClassMethod GetGlobalDatabaseDir(pNamespace As %String) As %String
{
    new $namespace
    set $namespace="%SYS"
    quit ..GetDatabaseDirectory(..GetGlobalDatabase(pNamespace))
}

ClassMethod GetDatabaseDirectory(pDatabase As %String) As %String
{
    new $namespace
    set $namespace="%SYS"
    quit ##class(Config.Databases).Open(pDatabase).Directory
}

ClassMethod ActivateMappings(pNamespace = {$namespace}) As %Status [ Internal ]
{
    set tSC=$$$OK
    try {
        set tInterruptManager = ##class(%IPM.Utils.InterruptManager).%New()
        do tInterruptManager.DisableInterrupts()
        new $namespace
        set $namespace = "%SYS"
        $$$ThrowOnError(##class(Config.CPF).Write())
        $$$ThrowOnError(##class(Config.Map).MoveToActive())
        $$$ThrowOnError(##class(Config.Namespaces).Load(pNamespace))
    } catch ex {
        set tSC = ex.AsStatus()
    }
    quit tSC
}

/// Copy a package from one namespace to another. This works whether or not the contents of
/// the package are deployed. <br />
/// This copies classes and include files in the package. <br />
ClassMethod CopyItemsInPackage(
	pPackage As %String,
	pFromNamespace As %String,
	pToNamespace As %String)
{
    #define CopyTempGlobal ^CacheTemp.CopyPercentItems
    if $extract(pPackage, "*") '= "." {
        set pPackage = pPackage_"."
    }

    new $namespace
    set $namespace = pFromNamespace

    // Create Studio project
    set project = ##class(%Studio.Project).%New()

    // Add classes to project
    set sc = project.AddItem(pPackage_"PKG")
    $$$ThrowOnError(sc)

    // Add include files to project
    set key = pPackage
    while 1 {
        set key = $order(^rINC(key))
        if (key = "") || ($extract(key, 1, $length(pPackage)) '= pPackage) {
            quit
        }
        set sc = project.AddItem(key_".INC")
        $$$ThrowOnError(sc)
    }

    // Deploy project to temp global
    kill $$$CopyTempGlobal
    set globalName = $name($$$CopyTempGlobal)
    set sc = project.DeployToGbl(globalName)
    $$$ThrowOnError(sc)

    // Switch to pToNamespace and import project
    set $namespace = pToNamespace
    set sc = ##class(%Studio.Project).InstallFromGbl(globalName)
    $$$ThrowOnError(sc)
}

/// This method exports items (classes, routines, etc.) and reloads it into a different namespace
/// The syntax for itemspec is the Name attribute in <Resource> tag and <Mapping> tag
ClassMethod CopyItems(
	itemspec,
	source,
	target,
	qspec)
{
    set tSC = $$$OK
    try {
        new $namespace
        set $namespace = target
        set tSC = ##class(%IPM.Utils.Module).ResolveItems(.itemlist,itemspec,source)
        quit:$$$ISERR(tSC)
        set filestream=##class(%FileCharacterStream).%New()
        do filestream.Write("")
        set tSC = $$exportItems(source,.itemlist,filestream.Filename) quit:$$$ISERR(tSC)
        set tSC = $system.OBJ.Load(filestream.Filename,"/nocompile/checkuptodate"_qspec)
        quit:$$$ISERR(tSC)
    } catch ex {
        set tSC = ex.AsStatus()
    }
    quit tSC
    ;
exportItems(namespace,itemlist,filename)
    new $namespace
    set $namespace = namespace
    quit $system.OBJ.Export(.itemlist,filename,"/nodisplay"_qspec)
}

/// This method resolves itemspec used by Name sttribute in <Resource> and <Mapping>
ClassMethod ResolveItems(
	itemlist,
	itemspec,
	namespace) As %Status
{
    set tSC = $$$OK
    try {
        new $namespace
        set $namespace = namespace
        kill itemlist
        set type = $piece(itemspec,".",*)
        if type="PKG" do getPackage(.itemlist,$piece(itemspec,".",1,*-1)) quit
        if $listfind($listbuild("CLS","MAC","INC"),type) set itemlist(itemspec) = "" quit
    } catch ex {
        set tSC = ex.AsStatus()
    }
    quit tSC
    ;
getPackage(itemlist,package)
    set pplen = $length(package,".")
    set class = package_"."
    for  {
        set class = $order(^oddDEF(class)) quit:class=""  quit:$piece(class,".",1,pplen)'=package
        set itemlist(class_".CLS") = ""
    }
    quit
    ;
}

/// This method enables I/O redirection (see EndCaptureOutput for retrieval). <var>pCookie</var> has the previous I/O redirection info.
ClassMethod BeginCaptureOutput(Output pCookie As %String) As %Status [ ProcedureBlock = 0 ]
{
    new tSC,e

    #dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException

    try {
        #; This facility is not re-entrant
        if $data(^||%capture) set tSC=$$$ERROR($$$GeneralError,"Capture Already Active") quit

        #; If re-direction is already active
        if $zutil(82,12) {
            #; Retain the name of the re-directed routine
            set pCookie=$zutil(96,12)
        } else {
            set pCookie=""
        }

        #; Use THIS routine for redirection
        use $io::("^"_$zname)

        #; Switch redirection on
        do $zutil(82,12,1)

        kill ^||%capture

    } catch (e) {
    set tSC=e.AsStatus()
    }
    quit tSC

   #; Internal Entry points for device re-direction
rstr(sz,to) [rt] public {
    new rt set vr="rt"
    set rd=$zutil(82,12,0)
    set:$data(sz) vr=vr_"#"_sz set:$data(to) vr=vr_":"_to
    read @vr
    do:$data(to) $zutil(96,4,$test)
    do $zutil(82,12,rd)
    quit rt
  }
wchr(s)public { do write($char(s)) }
wff() public { do write($char(12)) }
wnl() public {
    if '$data(^||%capture(0)) set ^||%capture(0)=1,^(1)=""
    set ^||%capture($increment(^||%capture(0)))=""
  }
wstr(s) public { do write(s) }
wtab(s) public { do write($justify("",s-$x)) }
write(s) public {
    set lf=$find(s,$char(10))
    while lf {
        do write($extract(s,1,lf-2)),wnl()
        set s=$extract(s,lf,*)
        set lf=$find(s,$char(10))
    }
    set lno=$get(^||%capture(0)) set:lno="" lno=1,^||%capture(0)=1
    set ^||%capture(lno)=$get(^||%capture(lno))_$translate(s,$char(13))
  }
}

/// This method captures the output from a program and delivers it as an array of lines
ClassMethod EndCaptureOutput(
	pCookie As %String,
	Output pText) As %Status
{
    #dim tLast,tKey,tValue As %String

    if pCookie'="" {
        #; Use the original redirected routine
        use $io::("^"_pCookie)
    } else {
        #; Otherwise switch redirection off
        do $zutil(82,12,0)
    }

    try {
        set tLast=$get(^||%capture(0),0)
        for tKey=1:1:tLast-1 {
            set pText($increment(pText)) = ^||%capture(tKey)
        }
        if tLast,^||%capture(tLast)'="" {
            set pText($increment(pText)) = ^||%capture(tLast)
        }
    } catch {
        set pText($increment(pText)) = "Capture error: "_$zerror
    }

    kill ^||%capture

    quit $$$OK
}

Query OrphanedResources(
	pNamespace As %String = {$namespace},
	pType As %String = "") As %Query(ROWSPEC = "Name:%String") [ SqlProc ]
{
}

ClassMethod OrphanedResourcesExecute(
	ByRef qHandle As %Binary,
	pNamespace As %String = {$namespace},
	pType As %String = "") As %Status
{
    set tSC = $$$OK
    try {
        set tFilter = $case(pType,"":"",:"*."_pType)
        // (Spec,Dir,OrderBy,SystemFiles,Flat,NotStudio=0,ShowGenerated=1,Filter,RoundTime=0,Mapped=1)
        set tResult = ##class(%Library.RoutineMgr).StudioOpenDialogFunc(tFilter,1,1,0,1,,0,,,0)
        if (tResult.%SQLCODE < 0) {
            set tSC = $$$ERROR($$$SQLCode,qHandle.%SQLCODE,qHandle.Message)
        }
        while tResult.%Next(.tSC) {
            if $$$ISERR(tSC) {
                quit
            }

            set tName = tResult.%Get("Name")
            if '$isobject(##class(%IPM.ExtensionBase.Utils).FindHomeModule(tName)) {
                set ^||%IPM.OrphanedResources($increment(^||%IPM.OrphanedResources)) = $listbuild(tName)
            }
        }
        set qHandle=""
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod OrphanedResourcesFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = OrphanedResourcesExecute ]
{
    set tSC = $$$OK
    try {
        set qHandle = $order(^||%IPM.OrphanedResources(qHandle),1,tData)
        if (qHandle = "") {
            set AtEnd = 1
        } else {
            set Row = tData
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod OrphanedResourcesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = OrphanedResourcesExecute ]
{
    kill ^||%IPM.OrphanedResources
    quit $$$OK
}

/// Helper method to see if <var>pNamespace</var> has <var>pModule</var> (a module name) installed.
/// Returns false if the module is not installed (which may be because the namespace does not exist).
ClassMethod NamespaceHasModule(
	pNamespace As %String,
	pModuleName As %String) As %Boolean
{
    set tModuleExists = 0
    new $namespace
    try {
        set $namespace = pNamespace // This might fail.
        set tModuleExists = ##class(%IPM.Storage.Module).NameExists(pModuleName)
    } catch e {
        // Ignore - this means the namespace does not exist.
    }
    quit tModuleExists
}

/// Short-term approach to lock a module's dependencies within the module manifest (rather than using a separate file).
ClassMethod LockWithCurrentDependencies(pModuleName As %String) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        tstart
        set tModule = ##class(%IPM.Storage.Module).NameOpen(pModuleName,,.tSC)
        $$$ThrowOnError(tSC)

        set tSC = tModule.BuildDependencyGraph(.tGraph,,,,,,,,1)
        $$$ThrowOnError(tSC)

        // Build map of dependency name to position in module's dependencies
        set tDepKey = ""
        for {
            set tDependency = tModule.Dependencies.GetNext(.tDepKey)
            if (tDepKey = "") {
                quit
            }
            set tDepMap(tDependency.Name) = tDepKey
        }

        // Add dependencies or update their versions as needed
        set tModuleName = ""
        for {
            set tModuleName = $order(tGraph(tModuleName),1,tData)
            if (tModuleName = "") {
                quit
            }
            set tVersion = $listget(tData,3)
            if $data(tDepMap(tModuleName),tDependencyKey) {
                // Lock down version.
                write !,"Locking dependency: ",tModuleName," ",tVersion
                set tModule.Dependencies.GetAt(tDependencyKey).VersionString = tVersion
            } else {
                // Add new dependency for unlisted transitive dependency.
                write !,"Adding dependency: ",tModuleName," ",tVersion
                set tNewDependency = ##class(%IPM.Storage.ModuleReference).%New()
                set tNewDependency.Name = tModuleName
                // Copy the actual version string (a semantic version) into the module manifest dependency's version string (a semantic version expression)
                // A semantic version is also a valid semantic version expression, but not vice versa.
                set tNewDependency.VersionString = tVersion
                $$$ThrowOnError(tModule.Dependencies.Insert(tNewDependency))
            }
        }

        $$$ThrowOnError(tModule.%Save())

        // Use the API to update the module manifest on disk from the updated persistent object
        set tStatus = ..ExportDocumentForObject(tModule,.tSourceControlOutput)

        // Always show any output (before checking tStatus)
        for tLine=1:1:$get(tSourceControlOutput) {
            write !,$get(tSourceControlOutput(tLine))
        }
        $$$ThrowOnError(tStatus)
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }
    quit tSC
}

/// Creates (or updates) an include file with name <var>pName</var> and contents in an indexed
/// subscripted array <var>pLineArray</var>. <br />
/// @Argument	pName		Name of include file. <br />
/// @Argument	pLineArray	Subscripted array whose keys are indices and values correspond to
/// lines in the include file. The top level node should have the number of lines. <br />
ClassMethod CreateOrUpdateIncludeFile(
	pName As %String,
	ByRef pLineArray As %String)
{
    // Create include file
    set routine = ##class(%Library.Routine).%New(pName_".INC")
    // Write lines
    for i = 1:1:$get(pLineArray) {
        $$$ThrowOnError(routine.WriteLine(pLineArray(i)))
    }
    // Save the routine
    $$$ThrowOnError(routine.Save())
}

ClassMethod ConvertW3CToTimestampUTC(pDateTime As %String) As %TimeStamp
{
    set date = $piece(pDateTime, "T", 1)
    set time = $piece(pDateTime, "T", 2)

    // Validation
    set containsPlus = ($find(time, "+") > 0)
    set containsMinus = ($find(time, "-") > 0)
    set containsZ = ($find(time, "Z") > 0)
    if ((containsPlus + containsZ + containsMinus) > 1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid time format. Cannot contain multiple timezone offset formats"))
    }
    if ((containsPlus + containsZ + containsMinus) = 0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid time format. Missing timezone offset"))
    }

    set parsedTime = ""
    set dateAdd = ""

    // Obtain UTC time
    if containsZ {
        set parsedTime = $extract(time, 1, *-1)
    } else {
        set operator = $case(containsPlus, 1: "+", : "-")

        set absTime = $piece(time, operator, 1)
        set offset = $piece(time, operator, 2)
        set $listbuild(offsetHours, offsetMinutes) = $listfromstring(offset, ":")
        set offsetHours = "-"_operator_offsetHours
        set offsetMinutes = "-"_operator_offsetMinutes
        set $listbuild(hours, minutes, seconds) = $listfromstring(absTime, ":")

        set computedMinutes = minutes + offsetMinutes
        set netMinutes = computedMinutes#60
        set hoursAdd = $case((computedMinutes < 0), 1: -1, : $case((computedMinutes >= 60), 1: 1, : 0))
        set computedHours = (hours + offsetHours + hoursAdd)
        set netHours = computedHours#24
        set dateAdd = $case((computedHours < 0), 1: -1, : $case((computedHours >= 24), 1: 1, : 0))

        // Add padding of 0's if needed
        if ($length(netHours) = 1) {
            set netHours = "0"_netHours
        }
        if ($length(netMinutes) = 1) {
            set netMinutes = "0"_netMinutes
        }

        set parsedTime = netHours_":"_netMinutes_":"_seconds
    }
    set dateTime = date_" "_parsedTime
    if (dateAdd '= "") {
        // Adjust date
        set dateTime = $system.SQL.DATEADD("day", dateAdd, dateTime)
    }
    return dateTime
}

ClassMethod ConvertTimestampUTCToW3C(pDateTime As %TimeStamp) As %String
{
    set date = $piece(pDateTime, " ", 1)
    set time = $piece(pDateTime, " ", 2)
    return date_"T"_time_"Z"
}

ClassMethod GetInstallerProperties(
	pClass As %String = "",
	pExcept As %String = "") [ PublicList = (tExcept, tClass) ]
{
    set tExcept = pExcept
    if '$listvalid(pExcept) {
        set tExcept = $listfromstring(pExcept)
    }
    set tClass = "%Installer."_pClass
    set tRes = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT LIST(Name) FROM %Dictionary.PropertyDefinition "_
        "WHERE Parent = :tClass AND (:tExcept IS NULL OR Name NOT %INLIST :tExcept) "_
        "ORDER BY SequenceNumber")
    do tRes.%Next()
    set res = tRes.%GetData(1)
    quit tRes.%GetData(1)
}

/// Copied from %Net.Remote.Utility:RunCommandViaCPIPE and modified slightly to fit these purposes:
/// Run a command using $ZF(-1) and an external temporary file to store the command output. <br>
/// If <var>pDeleteTempFile</var> is 0 (false), the temporary file is not deleted; in this case, it is up to the caller to delete it when done with it.
ClassMethod RunCommandViaZF(
	pCmd As %String,
	Output pLogOutput,
	Output pErrOutput,
	pTimeout As %Integer = 10,
	Output pRetCode As %String,
	pArgs... As %String) As %Status
{
    set tSC = $$$OK
    set pRetCode = ""
    set IO = $io
    set ZEOFMode = $zutil(68,40,1)

    try {
        set tFile = ##class(%File).TempFilename("txt")
        if tFile="" set tSC = $$$ERROR($$$ObjectScriptError, "Failed to obtain a temporary file name") quit
        set tErrFile = ##class(%File).TempFilename("txt")
        if tErrFile="" set tSC = $$$ERROR($$$ObjectScriptError, "Failed to obtain a temporary file name") quit
        if $system.Version.GetBuildOS()="VMS" {
            set pRetCode = $zf(-1,pCmd,tFile)
        } else {
            set:pCmd[" 2>&1" pCmd = $piece(pCmd,"2>&1",1)
            set pRetCode = $zf(-1,pCmd_" > "_tFile_" 2> "_tErrFile)
        }

        $$$ThrowOnError(..GetFileLines(tFile,.pLogOutput))
        $$$ThrowOnError(..GetFileLines(tErrFile,.pErrOutput))
    } catch (ex) {
        set tSC = ex.AsStatus()
    }

    if 'ZEOFMode do $zutil(68,40,0) // Restore ZEOF mode
    use IO

    quit tSC
}

/// Run command with $ZF(-100) <br />
/// <var>pCwd</var> - Working folder<br/ >
/// <var>pCmd</var> - $ListBuild for command with arguments<br/ >
/// <var>pLogOutput</var> - Pass filename or stream object, to get all output, empty string to ignore and have output from command in default output<br/ >
/// <vr>pErrOutput</var> - if not specified, gets the value from pLogOutput<br/ >
/// <vr>pRetCode</var> - Code returned by OS<br/ >
ClassMethod RunCommand(
	pCwd As %String = "",
	pCmd As %List = "",
	ByRef pLogOutput As %Stream.Object,
	ByRef pErrOutput As %Stream.Object,
	Output pRetCode As %String) As %Status
{
    if (pCmd="") || ('$listvalid(pCmd)) || ($listget(pCmd) = "") {
        quit $$$ERROR($$$GeneralError,"Wrong command.")
    }
    if (pCwd="") && '##class(%File).DirectoryExists(pCwd) {
        quit $$$ERROR($$$GeneralError,"Working folder does not exists or inaccessible.")
    }
    set tSC = $$$OK
    try {
        set currentDirectory = ##class(%SYSTEM.Process).CurrentDirectory(pCwd)
        set flags = ""
        set cmd = $listget(pCmd)
        set args = 0
        for i = 2:1:$listlength(pCmd) {
            set args($increment(args)) = $listget(pCmd, i)
        }
        if '$data(pLogOutput),$data(pErrOutput) {
            set pLogOutput = pErrOutput
        }
        set stdout = ..GetFilename4Output(.pLogOutput, .stdoutTmp)
        set stderr = ..GetFilename4Output(.pErrOutput, .stderrTmp)
        if stdout '= "", stderr = "" {
            set stderr = stdout
        }
        if stdout '= "" {
            set flags = flags _ "/STDOUT=""" _ stdout _ """"
        }
        if stderr '= "" {
            set flags = flags _ "/STDERR=""" _ stderr _ """"
        }
        set pRetCode = $zf(-100, flags, cmd, args...)
        $$$ThrowOnError(..ReadFileToStream(stdout, .pLogOutput, $get(stdoutTmp)))
        $$$ThrowOnError(..ReadFileToStream(stderr, .pErrOutput, $get(stderrTmp)))

        if (pRetCode'=0) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Running command returned error."))
        }
    } catch (ex) {
        if (ex.Code = 34) {
            set tSC = $$$ERROR($$$GeneralError, "Command " _ $get(cmd) _ " not found.")
        } else {
            set tSC = ex.AsStatus()
        }
    }
    if $get(currentDirectory)'="" {
        do ##class(%SYSTEM.Process).CurrentDirectory(currentDirectory)
    }
    quit tSC
}

ClassMethod GetFilename4Output(
	pOutput As %Stream.Object,
	Output pAsTemporary = 0) As %String
{
    if '$data(pOutput) {
        quit ""
    }
    set filename = ##class(%Library.Device).GetNullDevice()
    if $isobject(pOutput),pOutput.%IsA("%Stream.Object") {
        do pOutput.Clear()
        if pOutput.%IsA("%Stream.FileBinary") {
            set filename = pOutput.Filename
        } else {
            set filename = ##class(%File).TempFilename()
            set pAsTemporary = 1
        }
    } elseif '$isobject(pOutput) && (pOutput'="") && ##class(%File).DirectoryExists(##class(%File).GetDirectory(pOutput)) {
        set filename = pOutput
    }
    quit filename
}

ClassMethod ReadFileToStream(
	pFileName As %String = "",
	ByRef pOutput As %Stream.Object,
	pDeleteAfter As %Boolean = 0) As %Status
{
    if (pFileName="") || (pFileName=##class(%Library.Device).GetNullDevice()) {
        quit $$$OK
    }
    if '$data(pOutput) || '$isobject(pOutput) || (pFileName = pOutput) {
        quit $$$OK
    }
    if pOutput.%IsA("%Stream.FileBinary") && (pOutput.Filename = pFileName) {
        quit $$$OK
    }
    set tStream = $select(pOutput.IsCharacter(): ##class(%Stream.FileCharacter).%New(), 1: ##class(%Stream.FileBinary).%New())
    $$$QuitOnError(tStream.LinkToFile(pFileName))
    $$$QuitOnError(pOutput.CopyFrom(tStream))
    if pDeleteAfter {
        do ##class(%File).Delete(pFileName)
    }
    quit $$$OK
}

ClassMethod GetFileLines(
	pFileName As %String,
	Output pOutput) As %Status [ Internal, Private ]
{
    set tSC = $$$OK
    try {
        kill pOutput
        close pFileName
        open pFileName:("RS"):5
        if '$test {
            set tSC = $$$ERROR($$$ObjectScriptError, "Failed to open temporary file '"_pFileName_"'") quit
        }
        set TooMuch = 0
        use pFileName
        for {
            // Keep reading through end of file; save only first 32,000 characters
            set tLine = "" read tLine:1
            if '$test && (tLine=$char(-1)) quit  // Exit by timeout
            if $length(tLine)<32000 {
                set pOutput($increment(pOutput)) = tLine
            } else {
                set pOutput($increment(pOutput)) = $extract(tLine,1,32000)_" (more...)"
            }
            if ($zeof=-1) quit  // Exit by EOF
        }
        close pFileName:"D"
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Evaluates an expression in a provided string. <br />
/// These special expressions are case-insensitive. <br />
/// Current valid expressions:
/// <ul>
/// 	<li>{$namespace} - the current namespace. </li>
/// 	<li>{$ns} - the current namespace. </li>
/// 	<li>{$namespaceLower} - the current namespace in lower case. </li>
/// 	<li>{$namespaceRoutineDB} - the default routines database for the current namespace. </li>
/// 	<li>{$namespaceGlobalsDB} - the default globals database for the current namespace. </li>
/// 	<li>{$installDir} - the instance's install directory </li>
/// 	<li>{$dataDir} - the instance's data directory </li>
/// 	<li>{$mgrDir} - the instance's mgr directory. </li>
/// 	<li>{$cspDir} - the instance's root CSP directory. </li>
/// 	<li>{$binDir} - the instance's bin directory.</li>
/// 	<li>{$libDir} - the instance's lib directory.</li>
/// 	<li>{$webroot} - the instance's constructed url with host and port (e.g. http://123.45.678.90:52773/) </li>
/// 	<li>{$dbrole} - (deprecated in favor of {$globalsDbRole}) the current namespace's globals database role</li>
/// 	<li>{$globalsDbRole} - the current namespace's globals database role, functionally equivalent to {$dbrole} in legacy packages.</li>
/// 	<li>$$$macros - triple dollars ($$$) followed immediately by alphanumeric string will be substituted with corresponding macro value. If the macro is undefined on the instance, will return null ("") </li>
/// </ul>
/// For backward compatibility, supporting both ${var} and {$var}
ClassMethod %EvaluateSystemExpression(pString As %String) As %String [ Internal ]
{
    if (pString '[ "{") {
        return pString
    }
    set result = pString
    do ..GetDatabaseInfoForNamespace($namespace, .properties)
    set result = ..%RegExReplace(result,"namespace", $namespace)

    set result = ..%RegExReplace(result, "ns", $namespace)

    set result = ..%RegExReplace(result, "namespaceLower", $zconvert($namespace,"L"))

    set result = ..%RegExReplace(result, "namespaceRoutineDB", $get(properties("Routines")))

    set result = ..%RegExReplace(result, "namespaceGlobalsDB", $get(properties("Globals")))

    set installDir = $system.Util.InstallDirectory()
    set result = ..%RegExReplace(result,"installDir", installDir)

    set dataDir = $system.Util.DataDirectory()
    set result = ..%RegExReplace(result,"dataDir", dataDir)

    set mgrDir = ##class(%Library.File).ManagerDirectory()
    set result = ..%RegExReplace(result,"mgrDir", mgrDir)

    set cspDir = ##class(%Library.File).NormalizeDirectory($system.Util.InstallDirectory()_"csp")
    set result = ..%RegExReplace(result,"cspDir", cspDir)

    set binDir = $system.Util.BinaryDirectory()
    set result = ..%RegExReplace(result, "binDir", binDir)

    set libDir = ##class(%Library.File).NormalizeDirectory($system.Util.InstallDirectory()_"lib")
    set result = ..%RegExReplace(result, "libDir", libDir)

    do ##class(%Studio.General).GetWebServerPort(,,,.urlRoot)
    set result = ..%RegExReplace(result, "webroot", urlRoot)

    if '$get($$$DeprecationWarned("<expression>", "dbrole")) && ((result [ "${dbrole}") || (result [ "{$dbrole}")) {
        set $$$DeprecationWarned("<expression>", "dbrole") = 1
        write !, $$$FormattedLine($$$Red, "WARNING: The {$dbrole}/${dbrole} expression is deprecated. Please contact package developer to use {$globalsDbRole} instead.")
    }
    set dbRole = ..GetDatabaseRole()
    set result = ..%RegExReplace(result, "dbrole", dbRole)
    set result = ..%RegExReplace(result, "globalsDbRole", dbRole)

    return result
}

ClassMethod %EvaluateMacro(pString As %String) As %String [ Internal ]
{
    if pString '[ "$$$" {
        return pString // Return early for efficiency
    }
    set tString = pString
    set tPattern = "\$\$\$[a-zA-Z0-9]+"
    set tMatch = ##class(%Regex.Matcher).%New(tPattern, tString)
    while tMatch.Locate() {
        set group = tMatch.Group
        set macroVal = ..EvaluateMacroHelper($extract(group, 4, *))
        set tString = $replace(tString, group, macroVal)
    }
    return tString
}

/// Helper metohd to evaluate macro at runtime.
ClassMethod EvaluateMacroHelper(pMacro As %String) As %String [ Internal, Private ]
{
    set stream = ##class(%Stream.TmpCharacter).%New()
    do stream.WriteLine("Class %IPM.Generated.MacroEval")
    do stream.WriteLine("{")
    do stream.WriteLine("ClassMethod EvalMacro() [ CodeMode = objectgenerator ]")
    do stream.WriteLine("{")
    do stream.WriteLine("  Do %code.WriteLine(""#IfDef "_ pMacro _""")")
    do stream.WriteLine("  Do %code.WriteLine("" Quit $$$"_pMacro_""")")
    do stream.WriteLine("  Do %code.WriteLine(""#Else "")")
    do stream.WriteLine("  Do %code.WriteLine("" Quit """""""" "")")
    do stream.WriteLine("  Do %code.WriteLine(""#EndIf "")")
    do stream.WriteLine("  Quit $$$OK")
    do stream.WriteLine("}")
    do stream.WriteLine("}")

    // If it reaches here, pMacro is a valid expression (although may be undefined).
    // We should throw an error instead of failing silently.
    $$$ThrowOnError($system.OBJ.LoadStream(stream, "ck-d"))
    set value = $classmethod("%IPM.Generated.MacroEval", "EvalMacro")
    do $system.OBJ.Delete("%IPM.Generated.MacroEval", "-d")
    return value
}

/// Wrapper around Config.Namespaces:Get()
ClassMethod GetDatabaseInfoForNamespace(
	pNamespace As %String,
	Output pProperties) [ Internal ]
{
    kill pProperties
    new $namespace
    set $namespace = "%SYS"
    set sc = $classmethod("Config.Namespaces", "Get", pNamespace, .pProperties)
}

ClassMethod GetDatabaseRole()
{
    do ##class(%SYS.Namespace).GetNSInfo($namespace, .nsInfo)
    return $get(nsInfo("Resource"), "%DB_DEFAULT")
}

ClassMethod %RegExReplace(
	pString As %String,
	pName As %String,
	pValue As %String) As %String [ Internal ]
{
    set tString = pString
    set tRegEx = "(?i)\{\$" _ pName _ "\}"
    set tString =  ##class(%Regex.Matcher).%New(tRegEx, tString).ReplaceAll($replace(pValue,"\","\\"))
    set tRegEx = "(?i)\$\{" _ pName _ "\}"
    set tString =  ##class(%Regex.Matcher).%New(tRegEx, tString).ReplaceAll($replace(pValue,"\","\\"))
    quit tString
}

ClassMethod GetDeployedProjectPath(root As %String) As %String
{
    set deployedDirectory = ##class(%File).NormalizeDirectory($$$DeployedXMLDir, root)
    quit deployedDirectory_$$$DeployedXMLName
}

ClassMethod GetDeployedProjectName(moduleName As %String) As %String [ CodeMode = expression ]
{
moduleName_$$$DeployedProjectSuffix
}

}
