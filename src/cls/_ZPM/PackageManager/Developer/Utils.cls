Include (%occInclude, %occErrors, %ZPM.PackageManager.Common)

Class %ZPM.PackageManager.Developer.Utils [ System = 3 ]
{

/// Format of <var>pDependencyGraph</var>:
/// pDependencyGraph("module name") = $ListBuild(depth, "server name")
ClassMethod LoadDependencies(ByRef pDependencyGraph, ByRef pParams)
{
	Set tSC = $$$OK
	Try {
		// Sort dependencies by depth.
		Set tKey = ""
		For {
			Set tKey = $Order(pDependencyGraph(tKey),1,tData)
			Quit:tKey=""
			
			Set $ListBuild(tDepth,tServerName,tVersion) = tData
			Set tDepthList(tDepth,$Increment(tDepthList(tDepth))) = $ListBuild(tServerName,tKey,tVersion)
		}
		
		// Load and install dependencies in reverse order by depth.
		Set tDepth = ""
		For {
			Set tDepth = $Order(tDepthList(tDepth),-1,tCount)
			Quit:tDepth=""
			For i=1:1:tCount {
				Set $ListBuild(tServerName,tModuleName,tVersion) = tDepthList(tDepth,i)
				
				// Missing server name indicates that it's already present locally.
				If (tServerName '= "") {
					Set tSC = ..LoadModuleReference(tServerName,tModuleName,tVersion,.pParams)
					If $$$ISERR(tSC) {
						Quit
					}
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		If (e.Name["ZSOAP") {
			Set tSC = $Get(%objlasterror,e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

ClassMethod LoadQualifiedReference(pReference As %ZPM.PackageManager.Core.QualifiedModuleReference, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		#dim tReference As %ZPM.PackageManager.Core.QualifiedModuleReference
		Set tReference = pReference.%ConstructClone()
		If (tReference.ServerName = "") && ##class(%ZPM.PackageManager.Client.LocalServerDefinition).SingletonExists(1,.tID) {
			Set tServer = ##class(%ZPM.PackageManager.Client.LocalServerDefinition).%OpenId(tID)
			Set tReference.ServerName = tServer.Name
    }
		Set tSC = ..LoadModuleReference(tReference.ServerName, tReference.Name, tReference.VersionString, .pParams)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod LoadModuleReference(pServerName As %String, pModuleName As %String, pVersion As %String, ByRef pParams) As %Status
{
	#dim tExpression As %ZPM.PackageManager.Core.SemanticVersionExpression
	Set tSC = $$$OK
	Try {
		// Backward-compatibility: if params isn't an array, use it as qstruct
		If $Data(pParams) = 1 {
			Set qstruct = pParams
		}
		
		Set tVerbose = $Get(pParams("Verbose"))
		
		If '$Data(pParams("qstruct")) {
			Set qstruct = "ck"_$Select(tVerbose:"d",1:"-d")
		} Else {
			Merge qstruct = pParams("qstruct")
		}
		
		Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(pServerName,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tClient = tServer.GetPackageService()
		If 'tClient.IsAvailable() {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",tServer.Name))
			Quit
		}
		Set tModRef = ##class(%ZPM.PackageManager.Core.ResolvedModuleReference).%New()
		Set tModRef.Name = pModuleName
		Set tModRef.VersionString = pVersion
		
		// Make sure we're not downgrading.
		If '$Get(pParams("PermitDowngrade")) {
			If ##class(%ZPM.PackageManager.Developer.Module).NameExists(pModuleName) {
				Set tInstModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(pModuleName,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
				
				If tInstModule.Version.Follows(tModRef.Version) {
					Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Cannot downgrade %1 from version %2 to %3",tInstModule.Name,tInstModule.VersionString,pVersion))
					Quit
				}
			}
		}
		
		Set tSC = ..GetRequiredVersionExpression(pModuleName,"",.tExpression)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If 'tExpression.IsSatisfiedBy(tModRef.Version) {
			Set tSC = $$$ERROR($$$GeneralError,"Requested version (%1) does not satisfy the requirements of other modules installed in the current namespace (%2).",pVersion,tExpression.ToString())
			Quit
		}
		
		If tClient.Supports("GetModuleDirectory") {
			Set tDirectory = tClient.GetModuleDirectory(tModRef)
			Set tDeveloperMode = 0
			If (tModRef.Version.IsSnapshot() && $Get(pParams("DeveloperMode"),0)) {
				// If we are loading a module in developer mode, and are loading a snapshot version of a dependency from disk,
				// also load the snapshot version of that dependency in developer mode.
				// This doesn't make sense if we're loading the dependency from a remote server.
				Set tDeveloperMode = 1
			}
			Set tSC = ..LoadModuleFromDirectory(tDirectory,.pParams,tDeveloperMode)
		} Else {
			Set tAsArchive = -1
			Set tPayload = tClient.GetModule(tModRef, .tAsArchive)
			Set tFileName = ""
			If ($ISOBJECT(tPayload)) && (tPayload.%IsA("%Stream.FileBinary") ) {
				Set tFileName = tPayload.Filename
			}
			
			If tAsArchive<0 {
				// Read the file header
				Set tHeader = tPayload.Read(2,.tSC)
				If (tHeader = $Char(31, 139)) {
					// This is a .tgz file
					set tAsArchive = 1
				}
			}
			If (tFileName="") {
				Set tFileName = "module." _ $SELECT(tAsArchive: "tgz", 1: "xml")
			}
			Do tPayload.Rewind()
			Set tTmpStream = ##class(%Stream.FileBinary).%New()
			Set tTmpStream.Filename = tFileName
			Do tTmpStream.CopyFromAndSave(tPayload)
			
			If (tAsArchive) {
				Set tSC = ..LoadModuleFromArchive(tModRef.Name,tModRef.VersionString,tTmpStream,.pParams)
			} Else {
				// Old format (TODO: officially deprecate): try loading a .xml file
				Set tSC = $System.OBJ.Load(tTmpStream.Filename,.qstruct)
			}
            Set errorMsg = "", success = 0
            If $$$ISOK(tSC) {
                Set success = 1
            } Else {
                Set success = 0
                Set errorMsg = $System.Status.GetErrorText(tSC)
            }
            if ($System.CLS.IsMthd(tClient, "CollectAnalytics")) {
              do tClient.CollectAnalytics("install", pModuleName, pVersion,success,errorMsg)
            }
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// If remote load is successful, also register the module in the local cache.
		If 'tModRef.Version.IsSnapshot() && ##class(%ZPM.PackageManager.Client.LocalServerDefinition).SingletonExists(1) {
			Set tLocalServer = ##class(%ZPM.PackageManager.Client.LocalServerDefinition).SingletonOpen(1,,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Don't need to register if loading from the local server.
			If (tLocalServer '= tServer) && $IsObject($Get(tPayload)) && '##class(%ZPM.PackageManager.Server.Module).NameVersionExists(pModuleName, pVersion) {
				Set tCacheMod = ##class(%ZPM.PackageManager.Core.Module).%New()
				Set tCacheMod.Name = pModuleName
				Set tCacheMod.VersionString = pVersion
				Set tCacheMod.Manifest = tServer.GetPackageService().GetModuleManifest(tModRef)
				Do tPayload.Rewind()
				Do tCacheMod.Payload.CopyFrom(tPayload)
				Do tLocalServer.GetPublishService().PublishModule(tCacheMod)
			}
		}
	} Catch e {
		If (e.Name["ZSOAP") {
			Set tSC = $Get(%objlasterror,e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

ClassMethod LoadModuleFromArchive(pModuleName As %String, pModuleVersion As %String, pArchiveStream As %Stream.Object, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		
		Set tTargetDirectory = ##class(%File).ManagerDirectory()_".modules\"_$Namespace_"\"_pModuleName_"\"_pModuleVersion_"\"
		Set tTargetDirectory = ##class(%File).NormalizeDirectory(tTargetDirectory)
		If ##class(%File).DirectoryExists(tTargetDirectory) {
			// Delete it.
			Set tSC = ##class(%ZPM.PackageManager.Developer.File).RemoveDirectoryTree(tTargetDirectory)
			If $$$ISERR(tSC) {
				Quit
			}
		}
		Set tCreated = ##class(%File).CreateDirectoryChain(tTargetDirectory,.tReturnValue)
		If 'tCreated {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",tTargetDirectory,tReturnValue))
			Quit
		}
		Set tTargetDirectory = ##class(%File).NormalizeFilenameWithSpaces(tTargetDirectory)
		Set tSC = ##class(%ZPM.PackageManager.Developer.Archive).Extract(pArchiveStream.Filename,tTargetDirectory,.tOutput)
		If $$$ISERR(tSC) {
			Quit
		}
		For i=1:1:$Get(tOutput) {
			Write:tVerbose !,tOutput(i)
		}
		
		Set tSC = ..LoadModuleFromDirectory(tTargetDirectory, .pParams)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod LoadModuleFromDirectory(pDirectory As %String, ByRef pParams, pOverrideDeveloperMode As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		// LoadNewModule goes all the way through Reload->Validate->Compile->Activate, also compiling the new module.
		Write:tVerbose !,"Loading from ",pDirectory,!
		If $Get(pParams("Install")) {
			// Propagate pParams fully.
			Merge tParams = pParams
			ZKill tParams("Install")
		} Else {
			// Only propagate selected settings that should apply to dependencies.
			Set tParams("DeveloperMode") = $Get(pOverrideDeveloperMode,0)
			Set tParams("Verbose") = tVerbose
		}
		Set tSC = ..LoadNewModule(pDirectory,.tParams)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a semantic version expression capturing all version requirements for a given module name in the current namespace.
/// A list of modules to exclude may be provided (for example, if these modules would be updated at the same time).
ClassMethod GetRequiredVersionExpression(pModuleName As %String, pExcludeModules As %List = "", Output pExpression As %ZPM.PackageManager.Core.SemanticVersionExpression) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pExpression = ##class(%ZPM.PackageManager.Core.SemanticVersionExpression).%New()
		
		Set tResult = ##class(%ZPM.PackageManager.Developer.Module).VersionRequirementsFunc(pModuleName,pExcludeModules)
		If (tResult.%SQLCODE < 0) {
			$$$ThrowStatus($$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message))
		}
		
		While tResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			$$$ThrowOnError(##class(%ZPM.PackageManager.Core.SemanticVersionExpression).FromString(tResult.%Get("Version"),.tVersionExpr))
			Set pExpression = pExpression.And(tVersionExpr)
		}
		$$$ThrowOnError(tSC)
	} Catch e {
		Set pExpression = $$$NULLOREF
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a flat list of dependents for a given module name (and optional version) <br />
/// <var>pRepoNames</var> is a $ListBuild list of repositories in which to search for dependents; if blank, only currently-installed modules (and any missing dependencies) are considered. <br />
/// @PrivateAPI
ClassMethod GetDependentsList(Output pList As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.QualifiedModuleReference"), Output pErrorList, pModuleName As %String, pModuleVersion As %String = "", pRepoNames As %List = "") As %Status
{
	Set tSC = $$$OK
	Kill pErrorList
	Set pList = ##class(%Library.ListOfObjects).%New()
	Try {
		Set tSC = ..BuildAllDependencyGraphs(pRepoNames,.tGraphs,.pErrorList)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Find subscripts containing the requested module name (and possibly version) as a dependency
		Set tDepList = ""
		For i=1:1:$Get(tGraphs) {
			If $Data(tGraphs(i,pModuleName),tInfo) {
				// Check for version match, if a version was specified.
				If (pModuleVersion '= "") && (pModuleVersion '= $ListGet(tInfo,3)) {
					Continue
				}
				
				Set tQualRef = ##class(%ZPM.PackageManager.Core.QualifiedModuleReference).%New()
				Set tQualRef.ServerName = $ListGet(tGraphs(i),1)
				Set tQualRef.Name = $ListGet(tGraphs(i),2)
				Set tQualRef.VersionString = $ListGet(tGraphs(i),3)
				Do pList.Insert(tQualRef)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a tree of dependents, with dependent modules at the root, for a given module name (and optional version) <br />
/// <var>pRepoNames</var> is a $ListBuild list of repositories in which to search for dependents; if blank, only currently-installed modules (and any missing dependencies) are considered. <br />
/// Tree subscripts are $lb(Name,VersionString,ServerName). <br />
/// @PrivateAPI
ClassMethod GetDependentsAsTree(Output pTree, Output pErrorList, pModuleName As %String, pModuleVersion As %String = "", pRepoNames As %List = "") As %Status
{
	New %DepTree
	Set tSC = $$$OK
	Kill pErrorList
	Kill pTree
	Try {
		Set tSC = ..BuildAllDependencyGraphs(pRepoNames,.tGraphs,.pErrorList)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Find subscripts containing the requested module name (and possibly version) as a dependency
		Set tDepList = ""
		For i=1:1:$Get(tGraphs) {
			If $Data(tGraphs(i,pModuleName),tInfo) {
				// Check for version match, if a version was specified.
				If (pModuleVersion '= "") && (pModuleVersion '= $ListGet(tInfo,3)) {
					Continue
				}
				
				Set tDepList = tDepList_$ListBuild(i)
			}
		}
		
		// TODO: Handle cyclic dependencies?
		Set tPointer = 0
		While $ListNext(tDepList,tPointer,tDepIndex) {
			Kill tInfo Merge tInfo = tGraphs(tDepIndex)
			Do ..InvertDependencies(pModuleName,.tInfo,.tTree)
			Merge %DepTree = tTree
		}
		
		// Trim extra nodes from tree (i.e., those also dependend on by another module)
		Set tRef = "%DepTree"
		For {
			Set tRef = $Query(@tRef)
			Quit:tRef=""
			
			If $Data(@tRef) > 10 {
				ZKill @tRef
			}
		}
		
		Merge pTree = %DepTree
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod InvertDependencies(pNodeName As %String, ByRef pGraph, Output pTree) [ Private ]
{
	Kill pTree
	Set tSource = ""
	If ($ListGet(pGraph,2) = pNodeName) {
		Set tKey = $ListBuild(pNodeName,$ListGet(pGraph,3),$ListGet(pGraph,1))
		Set pTree(tKey) = ""
	} Else {
		Set tKey = $ListBuild(pNodeName,$ListGet(pGraph(pNodeName),3),$ListGet(pGraph(pNodeName),2))
		For {
			Set tSource = $Order(pGraph(pNodeName,tSource))
			Quit:(tSource="")
			
			Do ..InvertDependencies($Piece(tSource," "),.pGraph,.tTree)
			Merge pTree(tKey) = tTree
		}
	}
}

ClassMethod BuildAllDependencyGraphs(pRepoNames As %List = "", Output pGraphs, Output pErrorList) As %Status [ Internal ]
{
	#dim tModule As %ZPM.PackageManager.Developer.Module
	Set tSC = $$$OK
	Kill pGraphs
	Kill pErrorList
	Try {
		If '$ListLength(pRepoNames) {
			Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name from %ZPM_PackageManager_Developer.""Module""")
			If (tRes.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
			}
			While tRes.%Next(.tSC) {
				If $$$ISERR(tSC) {
					Quit
				}
				
				Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tRes.%Get("Name"),,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
					
				// Build dependency graph. Unlike case below, do not force "reload"
				Kill tDependencyGraph,tSubModules
				Set tGraphSC = tModule.BuildDependencyGraph(.tDependencyGraph,,,,,.tSubModules)
				
				// If there's an error, note it and just move on.
				If $$$ISERR(tGraphSC) {
					// Non-fatal error
					Set pErrorList($i(pErrorList)) = $ListBuild("",tModule.Name,tModule.VersionString,tGraphSC)
					Continue
				}
				
				If '$Data(tDependencyGraph) {
					// No dependencies, don't bother recording anything.
					Continue
				}
				
				// Add dependency graph to pGraphs, subscripted by qualified module reference.
				Set pGraphs($Increment(pGraphs)) = $ListBuild("",tModule.Name,tModule.VersionString)
				Merge pGraphs(pGraphs) = tDependencyGraph
			}
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set tPointer = 0
			While $ListNext(pRepoNames,tPointer,tRepoName) {
				Set tRepo = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(tRepoName,,.tSC)
				If $$$ISERR(tSC) {
					// Fatal error: repository name invalid
					Quit
				}
				
				If 'tRepo.Enabled {
					Continue
				}
				
				#dim tPackageService As %ZPM.PackageManager.Core.IPackageService
				Set tPackageService = tRepo.GetPackageService()
				Set tSearchCriteria = ##class(%ZPM.PackageManager.Core.SearchCriteria).%New()
				Set tSearchCriteria.IncludePrerelease = tRepo.Prereleases
				Set tSearchCriteria.IncludeSnapshots = tRepo.Snapshots
				Set tList = tPackageService.ListModules(tSearchCriteria)
				For i=1:1:tList.Count() {
					#dim tModRef As %ZPM.PackageManager.Core.ResolvedModuleReference
					Set tModRef = tList.GetAt(i)
					
					// Retrieve module manifest
					Set tManifest = tPackageService.GetModuleManifest(tModRef)
					
					Set tReader = ##class(%XML.Reader).%New()
					Set tSC = tReader.OpenStream(tManifest)
					If $$$ISERR(tSC) {
						Quit
					}
					Do tReader.Correlate("Module","%ZPM.PackageManager.Developer.Module")
					Do tReader.Next(.tModule,.tCorrSC)
					If $$$ISERR(tCorrSC) {
						// Non-fatal error
						Set pErrorList($i(pErrorList)) = $ListBuild(tRepoName,tModRef.Name,tModRef.VersionString,tCorrSC)
						Continue
					}
					
					// Build dependency graph, ignoring currently-installed modules (the last argument)
					Kill tDependencyGraph,tSubModules
					Set tGraphSC = tModule.BuildDependencyGraph(.tDependencyGraph,,,,,.tSubModules,,,1)
					
					// If there's an error, note it and just move on.
					If $$$ISERR(tGraphSC) {
						// Non-fatal error
						Set pErrorList($i(pErrorList)) = $ListBuild(tRepoName,tModRef.Name,tModRef.VersionString,tGraphSC)
						Continue
					}
					
					If '$Data(tDependencyGraph) {
						// No dependencies, don't bother recording anything.
						Continue
					}
					
					// Add dependency graph to pGraphs, subscripted by qualified module reference.
					Set pGraphs($Increment(pGraphs)) = $ListBuild(tRepoName,tModRef.Name,tModRef.VersionString)
					Merge pGraphs(pGraphs) = tDependencyGraph
				}
				If $$$ISERR(tSC) {
					Quit
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Query GetModuleList(pServer As %String) As %Query(ROWSPEC = "Name:%String,Version:%String,Repo:%String") [ SqlProc ]
{
}

ClassMethod GetModuleListExecute(ByRef qHandle As %Binary, pServer As %String) As %Status
{
	If (pServer = "") {
		Set qHandle = ""
		Quit $$$OK
	}
	Set tSC = $$$OK
	Try {
		Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(pServer,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tClient = tServer.GetPackageService()
		If tClient.IsAvailable() {
			Set tSearchCriteria = ##class(%ZPM.PackageManager.Core.SearchCriteria).%New()
			Set tSearchCriteria.IncludePrerelease = tServer.Prereleases
			Set tSearchCriteria.IncludeSnapshots = tServer.Snapshots
			Set tList = tClient.ListModules(tSearchCriteria)
			For i=1:1:tList.Count() {
				Set tMod = tList.GetAt(i)
				Set qHandle($i(qHandle)) = $ListBuild(tMod.Name,tMod.Version.ToString(),tMod.Repo)
			}
		}
		
		Set qHandle = ""
	} Catch e {
		If (e.Name["ZSOAP") {
			Set tSC = $Get(%objlasterror,e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

ClassMethod GetModuleListFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = GetModuleListExecute ]
{
	Set qHandle = $Order(qHandle(qHandle),1,Row)
	Set:qHandle="" AtEnd = 1
	Quit $$$OK
}

ClassMethod GetModuleListClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = GetModuleListExecute ]
{
	Quit $$$OK
}

ClassMethod LoadNewModule(pDirectory As %String, ByRef pParams) As %Status
{
	set tSC = $$$OK
	try {
		set tVerbose = $Get(pParams("Verbose"))
		If '$Data(pParams("qstruct")) {
			Set qstruct = "ck"_$Select(tVerbose:"d",1:"-d")
		}
		set pDirectory = ##class(%File).NormalizeDirectory("",pDirectory)
		
		set tSC = $system.OBJ.Load(pDirectory_"module.xml",$Select(tVerbose:"d",1:"-d"),.error,.tLoadedList) quit:$$$ISERR(tSC)
		;
		set first = $Order(tLoadedList(""))
		if first=""                   set tSC = $$$ERROR($$$GeneralError,"No module definition found.") quit
		if $Order(tLoadedList(first))'="" set tSC = $$$ERROR($$$GeneralError,"module.xml is malformed.") quit
		set first = $$$lcase(first)
		if $p(first,".",*)'="zpm"  set tSC = $$$ERROR($$$GeneralError,"No module definition found.") quit
		;
		set name = $p(first,".",1,*-1)
		;
		set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(name,,.tSC) quit:$$$ISERR(tSC)
		if '$Data($$$ZPMHandledModules($Namespace)) {
			// The purpose of this NEW command is to make sure that the % variable $$$ZPMHandledModules refers to doesn't leak outside this scope.
			// This only happens for the first module to be loaded in a set of dependencies (using zpm "load ..." or zpm "install ...")
			// $$$ZPMHandledModules is also used in the ExecutePhases method of %ZPM.PackageManager.Developer.Module to
			// cover cases where new dependencies are added and a module is compiled without reloading, and in the BuildDependencyGraph
			// method to treat installed snapshot versions as installed rather than forcing reload if they have been reloaded
			// as part of the same root module operation.
			new $$$ZPMHandledModules
			set $$$ZPMHandledModules($Namespace) = "" //Initialize.
		}
		set tSC = tModule.LoadDependencies("",.pParams) quit:$$$ISERR(tSC)
		;
		set path = pDirectory_"preload"
		if ##class(%File).DirectoryExists(path) {
			set tSC = $system.OBJ.ImportDir(path,"*.inc",$Select(tVerbose:"d",1:"-d")_"/compile",,1) quit:$$$ISERR(tSC)
			set tSC = $system.OBJ.LoadDir(path,$Select(tVerbose:"d",1:"-d")_"/compile",,1) quit:$$$ISERR(tSC)
		} else {
			write:tVerbose !,"Skipping preload - directory does not exist."
		}
		;
		set tSC = $system.OBJ.Load(pDirectory_"module.xml",$Select(tVerbose:"d",1:"-d"),.error,.tLoadedList) quit:$$$ISERR(tSC)
		set tSC = tModule.%Reload() quit:$$$ISERR(tSC)
		if $Get(pParams("DeveloperMode"),0) {
			if tModule.GlobalScope {
				set ^%SYS("ModuleRoot","*",name) = pDirectory
				set ^%SYS("ModuleRoot","*",name,"DeveloperMode") = 1
			} else {
				set ^%SYS("ModuleRoot",$namespace,name) = pDirectory
				set ^%SYS("ModuleRoot",$namespace,name,"DeveloperMode") = 1
			}
		}
		;
		set pParams("RootDirectory") = pDirectory
		set tSC = ##class(%ZPM.PackageManager.Developer.Module).ExecutePhases(name,$lb("Activate"),1,.pParams) quit:$$$ISERR(tSC)
		;
	} catch e {
		set tSC = e.AsStatus()
	}
	;
	if $$$ISERR(tSC) do $system.OBJ.DisplayError(tSC)
	;
	quit tSC
}

ClassMethod AddPackageMapping(pNamespace As %String, pMapping As %String, pFrom As %String) As %Status
{
	set tSC = $$$OK
	try {
		If $$$ucase(pNamespace) = "%ALL" {
			Set tSC = ..CreateAllNamespace()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		new $namespace
		set $namespace = "%SYS"
		kill p set p("Database") = pFrom
		if '##Class(Config.MapPackages).Exists(pNamespace,pMapping) {
			set tSC = ##Class(Config.MapPackages).Create(pNamespace,pMapping,.p,,1) quit:$$$ISERR(tSC)
		}
		set tSC = ..ActivateMappings(pNamespace) quit:$$$ISERR(tSC)
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

ClassMethod RemovePackageMapping(pNamespace As %String, pMapping As %String) As %Status
{
	set tSC = $$$OK
	try {
		new $namespace
		set $namespace = "%SYS"
		if ##Class(Config.MapPackages).Exists(pNamespace,pMapping) {
			set tSC = ##Class(Config.MapPackages).Delete(pNamespace,pMapping) quit:$$$ISERR(tSC)
		}
		set tSC = ..ActivateMappings(pNamespace) quit:$$$ISERR(tSC)
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

ClassMethod AddRoutineMapping(pNamespace As %String, pMapping As %String, pType As %String = "ALL", pFrom As %String) As %Status
{
	set tSC = $$$OK
	try {
		If $$$ucase(pNamespace) = "%ALL" {
			Set tSC = ..CreateAllNamespace()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		new $namespace
		set $namespace = "%SYS"
		kill p set p("Database") = pFrom
		set pMapping = pMapping_$S(pType="ALL":"",1:"_"_pType)
		if '##Class(Config.MapRoutines).Exists(pNamespace,pMapping) {
			set tSC = ##Class(Config.MapRoutines).Create(pNamespace,pMapping,.p,,1) quit:$$$ISERR(tSC)
		}
		; work around bug that Config.MapRoutines doesn't map ^rINDEX for INC files
		if pType="INC" {
			set tSC = ..AddGlobalMapping(pNamespace,"rINDEX("""_$e(pMapping,1,*-4)_""",""INC"")",pFrom)
			quit:$$$ISERR(tSC)
		}
		set tSC = ..ActivateMappings(pNamespace) quit:$$$ISERR(tSC)
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

ClassMethod RemoveRoutineMapping(pNamespace As %String, pMapping As %String, pType As %String = "ALL") As %Status
{
	set tSC = $$$OK
	try {
		new $namespace
		set $namespace = "%SYS"
		set pMapping = pMapping_$S(pType="ALL":"",1:"_"_pType)
		if ##Class(Config.MapRoutines).Exists(pNamespace,pMapping) {
			set tSC = ##Class(Config.MapRoutines).Delete(pNamespace,pMapping) quit:$$$ISERR(tSC)
		}
		; work around bug that Config.MapRoutines doesn't map ^rINDEX for INC files
		if pType="INC" {
			set tSC = ..RemoveGlobalMapping(pNamespace,"rINDEX("""_$e(pMapping,1,*-4)_""",""INC"")")
			quit:$$$ISERR(tSC)
		}
		set tSC = ..ActivateMappings(pNamespace) quit:$$$ISERR(tSC)
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

ClassMethod AddGlobalMapping(pNamespace As %String, pMapping As %String, pFrom As %String, pSetCollation As %Boolean = 0) As %Status
{
	set tSC = $$$OK
	try {
		If $$$ucase(pNamespace) = "%ALL" {
			Set tSC = ..CreateAllNamespace()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		new $namespace
		set $namespace = "%SYS"
		kill p set p("Database") = pFrom
		If pSetCollation {
			Set tDB=##class(SYS.Database).%OpenId($ZU(12)_pFrom)
			Set:$IsObject(tDB) p("Collation") = tDB.NewGlobalCollation
		}
		if pMapping[":(" set pMapping=$p(pMapping,":(")_"("_$p(pMapping,":(",2,999) // 2008 has glo:(subs), 2009 has glo(subs)
		if '##Class(Config.MapGlobals).Exists(pNamespace,pMapping) {
			set tSC=##Class(Config.MapGlobals).Create(pNamespace,pMapping,.p,,1) quit:$$$ISERR(tSC)
		}
		set tSC = ..ActivateMappings(pNamespace) quit:$$$ISERR(tSC)
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

ClassMethod RemoveGlobalMapping(pNamespace As %String, pMapping As %String = "") As %Status
{
	set tSC = $$$OK
	try {
		new $namespace
		set $namespace = "%SYS"
		if pMapping[":(" set pMapping=$p(pMapping,":(")_"("_$p(pMapping,":(",2,999) // 2008 has glo:(subs), 2009 has glo(subs)
		if ##Class(Config.MapGlobals).Exists(pNamespace,pMapping) {
			set tSC = ##Class(Config.MapGlobals).Delete(pNamespace,pMapping) quit:$$$ISERR(tSC)
		}
		set tSC = ..ActivateMappings(pNamespace) quit:$$$ISERR(tSC)
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

ClassMethod CreateAllNamespace() As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"

	Set ns = "%All"
	Set tSC = $$$OK

	if ('##Class(Config.Namespaces).Exists(ns)) {

		Set dbPrefix = $select($ZVERSION["IRIS": "IRIS", 1: "CACHE")
		Set Properties("Globals") = dbPrefix _ "TEMP"
		Set Properties("Routines") = dbPrefix _ "TEMP"
		
		Set tSC = ##Class(Config.Namespaces).Create(ns, .Properties)
		If ($$$ISERR(tSC)) {
			Return tSC
		}
	}
	Return tSC
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
	quit ..GetDatabaseDirectory(..GetRoutineDatabase())
}

ClassMethod GetGlobalDatabaseDir(pNamespace As %String) As %String
{
	new $namespace
	set $namespace="%SYS"
	quit ..GetDatabaseDirectory(..GetGlobalDatabase())
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
		new $Namespace
		set $Namespace = "%SYS"
		set tSC = ##Class(Config.CPF).Write() Quit:$$$ISERR(tSC)
		set tSC = ##Class(Config.Map).MoveToActive() Quit:$$$ISERR(tSC)
		set tSC = ##Class(Config.Namespaces).Load(pNamespace) Quit:$$$ISERR(tSC)
	} Catch ex {
		set tSC = ex.AsStatus()
	}
	quit tSC
}

/// This method exports items (classes, routines, etc.) and reloads it into a different namespace
/// The syntax for itemspec is the Name attribute in <Resource> tag and <Mapping> tag
ClassMethod CopyItems(itemspec, source, target, qspec)
{
    set tSC = $$$OK
    try {
        new $namespace
        set $namespace = target
		set tSC = ##class(%ZPM.PackageManager.Developer.Utils).ResolveItems(.itemlist,itemspec,source) quit:$$$ISERR(tSC)
        set filestream=##class(%FileCharacterStream).%New()
        do filestream.Write("")
        set tSC = $$exportItems(source,.itemlist,filestream.Filename) quit:$$$ISERR(tSC)
        set tSC = $system.OBJ.Load(filestream.Filename,"/nocompile/checkuptodate"_qspec) quit:$$$ISERR(tSC)
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
ClassMethod ResolveItems(itemlist, itemspec, namespace) As %Status
{
    set tSC = $$$OK
    try {
        new $namespace
        set $namespace = namespace
        kill itemlist
        set type = $p(itemspec,".",*)
        if type="PKG" do getPackage(.itemlist,$p(itemspec,".",1,*-1)) quit
        if $lf($lb("CLS","MAC","INC"),type) set itemlist(itemspec) = "" quit
    } catch ex {
        set tSC = ex.AsStatus()
    }
    quit tSC
	;
getPackage(itemlist,package)
	set pplen = $l(package,".")
	set class = package_"."
	for  {
		set class = $o(^oddDEF(class)) quit:class=""  quit:$p(class,".",1,pplen)'=package
		set itemlist(class_".CLS") = ""
	}
	quit
	;
}

/// This method enables I/O redirection (see EndCaptureOutput for retrieval). <var>pCookie</var> has the previous I/O redirection info.
ClassMethod BeginCaptureOutput(Output pCookie As %String) As %Status [ ProcedureBlock = 0 ]
{
	New tSC,e

	#dim tSC As %Status = $$$OK
	#dim e As %Exception.AbstractException

	Try {
		#; This facility is not re-entrant
		If $Data(^||%capture) Set tSC=$$$ERROR($$$GeneralError,"Capture Already Active") Quit

		#; If re-direction is already active
		If $zutil(82,12) {
			#; Retain the name of the re-directed routine
			Set pCookie=$ZU(96,12)
		} else {
			Set pCookie=""
		}

		#; Use THIS routine for redirection
		Use $io::("^"_$ZNAME)

		#; Switch redirection on
		Do $zutil(82,12,1)

		Kill ^||%capture

	} Catch (e) {
	Set tSC=e.AsStatus()
	}
	Quit tSC
    
   #; Internal Entry points for device re-direction
rstr(sz,to) [rt] public {
	New rt Set vr="rt"
	Set rd=$zutil(82,12,0)
	Set:$data(sz) vr=vr_"#"_sz Set:$data(to) vr=vr_":"_to
	Read @vr
	Do:$data(to) $zutil(96,4,$t)
	Do $zutil(82,12,rd)
	Quit rt
  }
wchr(s)public { Do write($char(s)) }
wff() public { Do write($char(12)) }
wnl() public {
	If '$data(^||%capture(0)) Set ^||%capture(0)=1,^(1)=""
	Set ^||%capture($increment(^||%capture(0)))=""
  }
wstr(s) public { Do write(s) }
wtab(s) public { Do write($justify("",s-$x)) }
write(s) public {
	Set lf=$find(s,$C(10))
	While lf {
	    Do write($Extract(s,1,lf-2)),wnl()
	    Set s=$Extract(s,lf,*)
	    Set lf=$find(s,$C(10))
	}
	Set lno=$get(^||%capture(0)) Set:lno="" lno=1,^||%capture(0)=1
	Set ^||%capture(lno)=$get(^||%capture(lno))_$translate(s,$char(13))
  }
}

/// This method captures the output from a program and delivers it as an array of lines
ClassMethod EndCaptureOutput(pCookie As %String, Output pText) As %Status
{
	#dim tLast,tKey,tValue As %String

	If pCookie'="" {
		#; Use the original redirected routine
		Use $io::("^"_pCookie)
	} else {
		#; Otherwise switch redirection off
		Do $zutil(82,12,0)
	}

	Try {
		Set tLast=$Get(^||%capture(0),0)
		For tKey=1:1:tLast-1 {
			Set pText($i(pText)) = ^||%capture(tKey)
		}
		If tLast,^||%capture(tLast)'="" {
			Set pText($i(pText)) = ^||%capture(tLast)
		}
	} Catch {
		Set pText($i(pText)) = "Capture error: "_$ZE
	}

	Kill ^||%capture

	Quit $$$OK
}

Query OrphanedResources(pNamespace As %String = {$Namespace}, pType As %String = "") As %Query(ROWSPEC = "Name:%String") [ SqlProc ]
{
}

ClassMethod OrphanedResourcesExecute(ByRef qHandle As %Binary, pNamespace As %String = {$Namespace}, pType As %String = "") As %Status
{
	Set tSC = $$$OK
	Try {
		Set tFilter = $Case(pType,"":"",:"*."_pType)
		// (Spec,Dir,OrderBy,SystemFiles,Flat,NotStudio=0,ShowGenerated=1,Filter,RoundTime=0,Mapped=1)
		Set tResult = ##class(%Library.RoutineMgr).StudioOpenDialogFunc(tFilter,1,1,0,1,,0,,,0)
		If (tResult.%SQLCODE < 0) {
			Set tSC = $$$ERROR($$$SQLCode,qHandle.%SQLCODE,qHandle.Message)
		}
		While tResult.%Next(.tSC) {
			If $$$ISERR(tSC) {
				Quit
			}
			
			Set tName = tResult.%Get("Name")
			If '$IsObject(##class(%ZPM.PackageManager.Developer.Extension.Utils).FindHomeModule(tName)) {
				Set ^||%ZPM.OrphanedResources($i(^||%ZPM.OrphanedResources)) = $ListBuild(tName)
			}
		}
		
		Set qHandle=""
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod OrphanedResourcesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = OrphanedResourcesExecute ]
{
	Set tSC = $$$OK
	Try {
		Set qHandle = $Order(^||%ZPM.OrphanedResources(qHandle),1,tData)
		If (qHandle = "") {
			Set AtEnd = 1
		} Else {
			Set Row = tData
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod OrphanedResourcesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = OrphanedResourcesExecute ]
{
	Kill ^||%ZPM.OrphanedResources
	Quit $$$OK
}

ClassMethod GetInstallerProperties(pClass As %String = "", pExcept As %String = "") [ PublicList = (tExcept, tClass) ]
{
	Set tExcept = pExcept
	If '$LISTVALID(pExcept) {
		Set tExcept = $LISTFROMSTRING(pExcept)
	}
	Set tClass = "%Installer."_pClass
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,
		"SELECT LIST(Name) FROM %Dictionary.PropertyDefinition "_
		"WHERE Parent = :tClass AND (:tExcept IS NULL OR Name NOT %INLIST :tExcept) "_
		"ORDER BY SequenceNumber")
	Do tRes.%Next()
	set res = tRes.%GetData(1)
	Quit tRes.%GetData(1)
}

/// Copied from %Net.Remote.Utility:RunCommandViaCPIPE and modified slightly to fit these purposes:
/// Run a command using a CPIPE device.
/// The first unused CPIPE device is allocated and returned in pDevice.  Upon exit the device is open; 
/// it is up to the caller to close that device when done with it. <br/>
/// <var>pTimeout</var> indicates how long to wait for the initial OPEN and <var>pTimeoutRead</var> indicates how long to wait between reading the output chunks</var>. <br/>
/// Note that CPIPE (and PIPE) devices are supported on Unix and Windows, but not on VMS.  If this method is invoked
/// on an instance installed on VMS, execution flow will be diverted to method <method>RunCommandViaZF</method>
/// which uses a different technique.
ClassMethod RunCommandViaCPIPE(pCmd As %String, Output pOutput, pTimeout As %Integer = 10, pTimeoutRead As %Integer = 5) As %Status [ Private ]
{
	Kill pOutput
	
	If ($System.Version.GetBuildOS() = "VMS") {
		Quit ..RunCommandViaZF($G(pCmd), .pOutput, pTimeout)
	}

	Set tSC = $$$OK
	Set tIO = $IO
	Set tZEOFMode = $ZU(68,40,1)
	Set pDevice = "|CPIPE|"
	
	Try {
		Set p = ##class(%SYS.ProcessQuery).Open($J)
		Set od = ","_p.OpenDevices_","
		For x = "",1:1:100 If od'[(",|CPIPE|"_x_",") Set pDevice = "|CPIPE|"_x Quit
		Set p = ""
	}
	Catch {
	}
	
	Try {
		Open pDevice:(pCmd:"R"):pTimeout
		If '$T Set tSC = $$$ERROR($$$CacheError, "Failed to open |CPIPE| device in read mode for command: '"_pCmd_"'") Quit
		Use pDevice
		For {
			// Keep reading through end of input; save only first 32,000 characters
			Set tLine = "" Read tLine:pTimeoutRead
			If '$T && (tLine=$C(-1)) Quit  // Exit by timeout
			If $Length(tLine)<32000 {
				Set pOutput($i(pOutput)) = tLine
			} Else {
				Set pOutput($i(pOutput)) = $E(tLine,1,32000)_" (more...)"
			}
			If ($ZEOF=-1) Quit  // Exit by EOF
		}
	} Catch (ex) {
		Set tSC = ex.AsStatus()
	}
	
	Close pDevice
	
	If 'tZEOFMode {
		Do $ZU(68,40,0) // Restore ZEOF mode
	}
	Use tIO
	
	Quit tSC
}

/// Copied from %Net.Remote.Utility:RunCommandViaCPIPE and modified slightly to fit these purposes:
/// Run a command using $ZF(-1) and an external temporary file to store the command output. <br>
/// If <var>pDeleteTempFile</var> is 0 (false), the temporary file is not deleted; in this case, it is up to the caller to delete it when done with it.
ClassMethod RunCommandViaZF(pCmd As %String, Output pLogOutput, Output pErrOutput, pTimeout As %Integer = 10, Output pRetCode As %String) As %Status
{
	Set tSC = $$$OK
	Set pRetCode = ""
	Set IO = $IO
	Set ZEOFMode = $ZU(68,40,1)

	Try {
		Set tFile = ##class(%File).TempFilename("txt")
		If tFile="" Set tSC = $$$ERROR($$$CacheError, "Failed to obtain a temporary file name") Quit
		Set tErrFile = ##class(%File).TempFilename("txt")
		If tErrFile="" Set tSC = $$$ERROR($$$CacheError, "Failed to obtain a temporary file name") Quit
		If $System.Version.GetBuildOS()="VMS" {
			Set pRetCode = $ZF(-1,pCmd,tFile)
		} Else {
			Set:pCmd[" 2>&1" pCmd = $P(pCmd,"2>&1",1)
			Set pRetCode = $ZF(-1,pCmd_" > "_tFile_" 2> "_tErrFile)
		}
		
		$$$ThrowOnError(..GetFileLines(tFile,.pLogOutput))
		$$$ThrowOnError(..GetFileLines(tErrFile,.pErrOutput))
	} Catch (ex) {
		Set tSC = ex.AsStatus()
	}

	If 'ZEOFMode Do $ZU(68,40,0) // Restore ZEOF mode
	Use IO
	
	Quit tSC
}

ClassMethod GetFileLines(pFileName As %String, Output pOutput) As %Status [ Internal, Private ]
{
	Set tSC = $$$OK
	Try {
		Kill pOutput
		Close pFileName Open pFileName:("RS"):5
		If '$T Set tSC = $$$ERROR($$$CacheError, "Failed to open temporary file '"_pFileName_"'") Quit
		Set TooMuch = 0
		Use pFileName
		For {
			// Keep reading through end of file; save only first 32,000 characters
			Set tLine = "" Read tLine:1
			If '$T && (tLine=$C(-1)) Quit  // Exit by timeout
			If $Length(tLine)<32000 {
				Set pOutput($i(pOutput)) = tLine
			} Else {
				Set pOutput($i(pOutput)) = $E(tLine,1,32000)_" (more...)"
			}
			If ($ZEOF=-1) Quit  // Exit by EOF
		}
		Close pFileName:"D"
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
