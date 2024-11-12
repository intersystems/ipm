Include (%occInclude, %occErrors, %syConfig, %syPrompt, %IPM.Common, %IPM.Formatting)

Class %IPM.Utils.Module [ System = 3 ]
{

/// SSL/TLS config to use for HTTPS requests made by package manager code.
Parameter DefaultSSLConfigName As STRING [ Internal ] = "ZPMSSLConfig";

/// Returns the name of the default SSL config after creating if it it does not already exist.
ClassMethod CreateAndGetSSLConfig(ByRef pProperties) As %String
{
	Set name = ..#DefaultSSLConfigName
	New $Namespace
	Set $Namespace = "%SYS"
	If '##class(Security.SSLConfigs).Exists(name) {
		Set pProperties("Description") = "Default SSL Config to be used by HealthShare Package Manager"
		Set sc = ##class(Security.SSLConfigs).Create(name, .pProperties)
		$$$ThrowOnError(sc)
	}
	Return name
}

/// Format of <var>pDependencyGraph</var>:
/// pDependencyGraph("module name") = $ListBuild(<depth>,<server name>,<version>)
/// pDependencyGraph("module name","<dependent module> <dependent module version>") = <irrelevant>
ClassMethod LoadDependencies(ByRef pDependencyGraph, ByRef pParams, pWorkQueue As %SYSTEM.WorkMgr)
{
	// Suspend the error count to avoid spurious messages about errors being detected in load/compile.
	$$$SuspendErrorCount
	Set tSC = $$$OK
	Set tLocked = 0
	Set tRestoreParams = 0
	Try {
		Set initWorkQueueManager = '$Data(pParams("Multicompile","CacheTempIndex"),tCacheTempIndex) || '$IsObject($Get(pWorkQueue))
		If initWorkQueueManager {
			If '$IsObject($Get(pWorkQueue)) {
				// There may be one at a higher stack level.
				// Deal with dependencies here, and ensure that previous CacheTempIndex can be restored at the end.
				Merge tParamBackup = pParams
				Set tRestoreParams = 1
			}
			
			If ($Get(pParams("Threads")) = 1) || ($TLevel > 0) {
				Set tNumWorkers = -1 // Disable multithreading.
			} Else {
				Set tNumWorkers = $Get(pParams("Threads"),1) // Enable multicompile
			}
			
			Set pWorkQueue = ##class(%SYSTEM.WorkMgr).Initialize("/multicompile="_tNumWorkers,.tSC)
			$$$ThrowOnError(tSC)
			
			Set tModuleName = ""
			For {
				Set tModuleName = $Order(pDependencyGraph(tModuleName),1,tData)
				Quit:tModuleName=""
				
				// List modules to avoid duplicate loads.
				Set pParams("Multicompile","ModuleContext",tModuleName) = $ListBuild("Activate")
				
				// Invert dependency graph, subscripts (<module>,<depends on>)
				Set tInvertedDependencyGraph(tModuleName) = $List(tData,2,*)
				
				Set tDependentKey = ""
				For {
					Set tDependentKey = $Order(pDependencyGraph(tModuleName,tDependentKey))
					Quit:tDependentKey=""
					
					Set tInvertedDependencyGraph($Piece(tDependentKey," "),tModuleName) = ""
				}
			}
			
			Set tCacheTempIndex = $Increment($$$ZPMTempLoadGraphRoot)
			Set pParams("Multicompile","CacheTempIndex") = tCacheTempIndex
			Kill $$$ZPMTempLoadGraph(tCacheTempIndex)
			Merge $$$ZPMTempLoadGraph(tCacheTempIndex) = tInvertedDependencyGraph
		} Else {
			Lock +$$$ZPMTempLoadGraph(tCacheTempIndex):$$$LockTimeout
			If $Test {
				Set tLocked = 1
			} Else {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to obtain lock on dependency graph."))
			}
			Merge tInvertedDependencyGraph = $$$ZPMTempLoadGraph(tCacheTempIndex)
		}
		
		// Queue load of modules without uninstalled dependencies.
		Set tModuleName = ""
		For {
			Set tModuleName = $Order(tInvertedDependencyGraph(tModuleName),1,tData)
			Quit:tModuleName=""
			
			// Check if ALL subnode modules have no server name in the top level node of those modules
			// in the inverted dependency graph (which means they are already installed)
			// ONLY want to check on the initial version of the graph because nodes are killed as modules are installed
			If initWorkQueueManager {
				Set tHasUninstalledDependency = 0
				Set tSubnode = ""
				While 1 {
					Set tSubnode = $Order(tInvertedDependencyGraph(tModuleName, tSubnode))
					If (tSubnode = "") {
						Quit
					}
					// Check if subnode exists. If it doesn't, then its already been installed because subnodes are killed
					Set tSubnodeServerName = $ListGet($Get(tInvertedDependencyGraph(tSubnode)), 1)
					If (tSubnodeServerName '= "") {
						Set tHasUninstalledDependency = 1
						Quit
					}
				}
			} Else {
				Set tHasUninstalledDependency = ($Data(tInvertedDependencyGraph(tModuleName)) >= 10)
			}
			// If no uninstalled dependencies remain...
			If 'tHasUninstalledDependency {
				Set $ListBuild(tServerName, tVersion, tDeployed, tPlatformVersion) = tData
				ZKill $$$ZPMTempLoadGraph(tCacheTempIndex,tModuleName)
				
				// Missing server name indicates that it's already present locally; nothing to do in that case.
				If (tServerName '= "") {
					If ($TLevel = 0) && ($Get(pParams("Multicompile","Verbose"),$Get(pParams("Verbose"),0))) {
						Write !,"Queuing module load: ",tModuleName," ",tVersion," @ ",tServerName
					}
					Set tSC = pWorkQueue.QueueCallback(
						"##class("_$ClassName()_").LoadModuleReference",
						"##class("_$ClassName()_").LoadCompleted",
						tServerName, tModuleName, tVersion, $Get(tDeployed), $Get(tPlatformVersion), .pParams, .pDependencyGraph)
					$$$ThrowOnError(tSC)
				} Else {
					// Remove this module from dependencies.
					Set tDependentKey = ""
					For {
						Set tDependentKey = $Order($$$ZPMTempLoadGraph(tCacheTempIndex,tDependentKey))
						Quit:tDependentKey=""
						
						Kill $$$ZPMTempLoadGraph(tCacheTempIndex,tDependentKey,tModuleName)
					}
				}
			}
		}
		If (tLocked) {
			Lock -$$$ZPMTempLoadGraph(tCacheTempIndex)
			Set tLocked = 0
		} Else {
			// Only call WaitForComplete once (!!!)
			// Recursive calls will do repeat execution of previously-queued jobs.
			Set tSC = pWorkQueue.WaitForComplete()
			$$$ThrowOnError(tSC)
		}
		
		Merge $$$ZPMHandledModules($Namespace) = pParams("Multicompile","ModuleContext")
	} Catch e {
		If (e.Name["ZSOAP") {
			Set tSC = $Get(%objlasterror,e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	If tRestoreParams {
		Kill pParams
		Merge pParams = tParamBackup
	}
	If (tLocked) {
		Lock -$$$ZPMTempLoadGraph(tCacheTempIndex)
	}
	Quit tSC
}

/// Intended to be invoked only as a work queue callback (so %status and %workqueue will be defined)
/// Signature must match <method>LoadModuleReference</method> per work queue manager conventions.
ClassMethod LoadCompleted(pServerName As %String, pModuleName As %String, pVersion As %String, pDeployed As %String, pPlatformVersion As %String, ByRef pParams, ByRef pDependencyGraph) As %Status
{
	// Suspend the error count to avoid spurious messages about errors being detected in load/compile.
	$$$SuspendErrorCount
	Set tSC = $$$OK
	Set tLocked = 0
	Try {
		$$$ThrowOnError(%status)
		If $$$ISOK(tSC) && $Data(pParams("Multicompile","CacheTempIndex"),tCacheTempIndex) {
			// Remove loaded dependency from dependencies subscript.
			Lock +$$$ZPMTempLoadGraph(tCacheTempIndex):$$$LockTimeout
			If $Test {
				Set tLocked = 1
			} Else {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to obtain lock on dependency graph."))
			}
			Set tDependentKey = ""
			For {
				Set tDependentKey = $Order($$$ZPMTempLoadGraph(tCacheTempIndex,tDependentKey))
				Quit:tDependentKey=""
				
				Kill $$$ZPMTempLoadGraph(tCacheTempIndex,tDependentKey,pModuleName)
			}
			Lock -$$$ZPMTempLoadGraph(tCacheTempIndex)
			Set tLocked = 0
			
			// Schedule load of any other modules that may need to be scheduled.
			Set tSC = ..LoadDependencies(.pDependencyGraph,.pParams,%workqueue)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If (tLocked) {
		Lock -$$$ZPMTempLoadGraph(tCacheTempIndex)
	}
	Quit tSC
}

ClassMethod LoadQualifiedReference(pReference As %IPM.Storage.QualifiedModuleInfo, ByRef pParams, ByRef pDependencyGraph) As %Status
{
	Set tSC = $$$OK
	Try {
		#dim tReference As %IPM.Storage.QualifiedModuleInfo
		Set tReference = pReference.%ConstructClone()
		Set tSC = ..LoadModuleReference(tReference.ServerName, tReference.Name, tReference.VersionString, tReference.Deployed, tReference.PlatformVersion, .pParams, .pDependencyGraph)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod LoadModuleReference(pServerName As %String, pModuleName As %String, pVersion As %String, pDeployed As %Boolean, pPlatformVersion As %String, ByRef pParams, ByRef pDependencyGraph) As %Status
{
	// Suspend the error count to avoid spurious messages about errors being detected in load/compile.
	$$$SuspendErrorCount
	#dim tExpression As %IPM.General.SemanticVersionExpression
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
		
		// Use % variables that intentionally leak in worker processes, to avoid duplicate work when they go out of scope.
		#dim %installcontext As %IPM.General.InstallContext
		#dim %manager As %IPM.Repo.Manager
		If '$$$IsISCWorker {
			New %installcontext
			New %manager
		}
		Set %installcontext = ##class(%IPM.General.InstallContext).%Get(.tSC)
		$$$ThrowOnError(tSC)
		Do %installcontext.SetGraph(.pDependencyGraph)
		Merge tIndex = pParams("Multicompile","CacheTempIndex")
		Do %installcontext.SetCacheTempIndex(.tIndex)
		
		Set %manager = $Select($IsObject($Get(%manager)):%manager,1:##class(%IPM.Repo.Manager).%Get(.tSC))
		$$$ThrowOnError(tSC)
		
		Set tClient = %manager.CheckServiceCache(pServerName,.tAvailable)
		If 'tAvailable {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pServerName))
			Quit
		}
		Set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
		Set tModRef.Name = pModuleName
		Set tModRef.VersionString = pVersion
    Set tModRef.Deployed = pDeployed
		
		// Make sure we're not downgrading.
		If '$Get(pParams("PermitDowngrade")) {
			If ##class(%IPM.Storage.Module).NameExists(pModuleName) {
				Set tInstModule = ##class(%IPM.Storage.Module).NameOpen(pModuleName,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
        If $Get(pParams("Install")),pModuleName'=$$$IPMModuleName,tInstModule.DeveloperMode,'$Get(pParams("DeveloperMode"),0) {
					Set tSC = $$$ERROR($$$GeneralError, $$$FormatText("Cannot install '%1' over previously installed in developer mode", tInstModule.Name))
					Quit
        }
				If tInstModule.Version.Follows(tModRef.Version) {
					Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Cannot downgrade %1 from version %2 to %3",tInstModule.Name,tInstModule.VersionString,pVersion))
					Quit
				}
			}
		}
		
		// Ensure requested versions match those required by other modules in the namespace, excluding versions currently being installed
		// (the requirements of such modules are already known to be satisfied)
		Set tSC = ..GetRequiredVersionExpression(pModuleName,%installcontext.GetPendingModuleList(),.tExpression,.tSourceList)
		If $$$ISERR(tSC) {
			Quit
		}
		If 'tExpression.IsSatisfiedBy(tModRef.Version) {
			Set tSourceString = $ListToString(tSourceList,"; ")
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Requested version (%1 %2) does not satisfy the requirements of other modules installed in the current namespace (%3).",tModRef.Name,pVersion,tSourceString))
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
			Set tSC = ..LoadModuleFromDirectory(tDirectory,.pParams,tDeveloperMode,pServerName)
		} Else {
			Set tAsArchive = -1
			Set tPayload = tClient.GetModule(tModRef, .tAsArchive)
			If (tVerbose) {
				Set serverDef = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(pServerName)
				Write !,"Module "_pModuleName_" was downloaded from " _ pServerName
				If $IsObject(serverDef) {
					Write " (",serverDef.Details,")"
				}
			}
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
				Set tSC = ..LoadModuleFromArchive(tModRef.Name,tModRef.VersionString,tTmpStream,.pParams, pServerName)
			} Else {
				// Old format (TODO: officially deprecate): try loading a .xml file

				// Load without compiling -> Update legacy superclasses -> Compile
				If $Data(qstruct) \ 2 = 1 {
					Set qstruct = $Translate(qstruct,"c","")
				} ElseIf $Data(qstruct("/compile")) {
					Kill qstruct("/compile")	
				}
				Set tSC = $System.OBJ.Load(tTmpStream.Filename,.qstruct, , .tLoaded)
				Set tSC = $$$ADDSC(tSC, ##class(%IPM.Utils.LegacyCompat).UpdateSuperclassAndCompile(.tLoaded, .qstruct))
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
	} Catch e {
		If (e.Name["ZSOAP") {
			Set tSC = $Get(%objlasterror,e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

ClassMethod LoadModuleFromArchive(pModuleName As %String, pModuleVersion As %String, pArchiveStream As %Stream.Object, ByRef pParams, pRepository As %String = "") As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		
		Set tTargetDirectory = ##class(%File).ManagerDirectory()_".modules\"_$Namespace_"\"_pModuleName_"\"_pModuleVersion_"\"
		Set tTargetDirectory = ##class(%File).NormalizeDirectory(tTargetDirectory)
		If ##class(%File).DirectoryExists(tTargetDirectory) {
			// Delete it.
			Set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tTargetDirectory)
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
		Set tSC = ##class(%IPM.General.Archive).Extract(pArchiveStream.Filename,tTargetDirectory,.tOutput)
		If $$$ISERR(tSC) {
			Quit
		}
		For i=1:1:$Get(tOutput) {
			Write:tVerbose !,tOutput(i)
		}
		
		Set tSC = ..LoadModuleFromDirectory(tTargetDirectory, .pParams, , pRepository)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod LoadModuleFromDirectory(pDirectory As %String, ByRef pParams, pOverrideDeveloperMode As %Boolean = 0, pRepository As %String = "") As %Status
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
			Set tParams("cmd") = "install"
			Merge tParams("NoLock") = pParams("NoLock")
			Merge tParams("NoMapping") = pParams("NoMapping")
			Merge tParams("NoTransaction") = pParams("NoTransaction")
			Merge tParams("NoJournal") = pParams("NoJournal")
			Merge tParams("Multicompile") = pParams("Multicompile")
			Merge tParams("Threads") = pParams("Threads")
			Merge tParams("NoStudioProject") = pParams("NoStudioProject")
			Merge tParams("AngularBuild") = pParams("AngularBuild")
			Merge tParams("Artifactory") = pParams("Artifactory")
			Merge tParams("AngularArtifact") = pParams("AngularArtifact")
		}
		Set tSC = ..LoadNewModule(pDirectory,.tParams,pRepository)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Given a path to a module.xml file (directory), tries to correlate it to an instance of <class>%IPM.Storage.Module</class>.
/// Throws errors.
ClassMethod GetModuleObjectFromPath(pPath As %String, Output pFound As %Boolean) As %IPM.Storage.Module
{
	Set pFound = 0
	Set pPath = ##class(%Library.File).NormalizeDirectory(pPath)
	Set modulePath = pPath_"module.xml"
	If '##class(%Library.File).Exists(modulePath) {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"File not found to obtain module object: "_modulePath))
	}
	Set stream = ##class(%Stream.FileCharacter).%New()
	$$$ThrowOnError(stream.LinkToFile(modulePath))
	Return ..GetModuleObjectFromStream(stream,.pFound)
}

/// Given a stream, tries to correlate it to an instance of <class>%IPM.Storage.Module</class>.
/// Throws errors.
ClassMethod GetModuleObjectFromStream(pStream As %Stream.Object, Output pFound As %Boolean) As %IPM.Storage.Module
{
	Set pFound = 0
	Set reader = ##class(%XML.Reader).%New()
	Set sc = reader.OpenStream(pStream)
	$$$ThrowOnError(sc)
	Do reader.Correlate("Module","%IPM.Storage.Module")
	Set pFound = (reader.Next(.moduleObj, .sc) > 0)
	$$$ThrowOnError(sc)
	Return $Get(moduleObj)
}

/// Returns a semantic version expression capturing all version requirements for a given module name in the current namespace.
/// A list of modules to exclude may be provided (for example, if these modules would be updated at the same time).
ClassMethod GetRequiredVersionExpression(pModuleName As %String, pExcludeModules As %List = "", Output pExpression As %IPM.General.SemanticVersionExpression, Output pSourceList As %List) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pExpression = ##class(%IPM.General.SemanticVersionExpression).%New()
		Set pSourceList = ""
		
		Set tResult = ##class(%IPM.Storage.Module).VersionRequirementsFunc(pModuleName,pExcludeModules)
		If (tResult.%SQLCODE < 0) {
			$$$ThrowStatus($$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message))
		}
		
		While tResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tVersion = tResult.%Get("Version")
			$$$ThrowOnError(##class(%IPM.General.SemanticVersionExpression).FromString(tVersion,.tVersionExpr))
			Set pExpression = pExpression.And(tVersionExpr)
			Set pSourceList = pSourceList_$ListBuild($ListToString(tResult.%Get("ModuleNames"),", ")_": "_tVersion)
		}
		$$$ThrowOnError(tSC)
	} Catch e {
		Set pExpression = $$$NULLOREF
		Set pSourceList = ""
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a flat list of dependents for a given module name (and optional version) <br />
/// <var>pRepoNames</var> is a $ListBuild list of repositories in which to search for dependents; if blank, only currently-installed modules (and any missing dependencies) are considered. <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod GetDependentsList(Output pList As %Library.ListOfObjects(ELEMENTTYPE="%IPM.Storage.QualifiedModuleInfo"), Output pErrorList, pModuleName As %String, pModuleVersion As %String = "", pRepoNames As %List = "") As %Status
{
	Set tSC = $$$OK
	Kill pErrorList
	Set pList = ##class(%Library.ListOfObjects).%New()
  If $Get(pModuleName)="" {
    Quit $$$OK
  }
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
				
				Set tQualRef = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
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
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod GetDependentsAsTree(Output pTree, Output pErrorList, pModuleName As %String, pModuleVersion As %String = "", pRepoNames As %List = "") As %Status
{
	New %DepTree
  If $Get(pModuleName)="" {
    Quit $$$OK
  }
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
	Set pTree=""
	Set tSource = ""
	If ($ListGet(pGraph,2) = pNodeName) {
		Set tKey = $ListBuild(pNodeName,$ListGet(pGraph,3),$ListGet(pGraph,1))
		Set pTree(tKey) = ""
	} Else {
		Set tKey = $ListBuild(pNodeName,$ListGet(pGraph(pNodeName),3),$ListGet(pGraph(pNodeName),2))
		For {
			Set tSource = $Order(pGraph(pNodeName,tSource))
      Set pTree(tKey) = ""
			Quit:(tSource="")
			
			Do ..InvertDependencies($Piece(tSource," "),.pGraph,.tTree)
			Merge pTree(tKey) = tTree
		}
	}
}

ClassMethod BuildAllDependencyGraphs(pRepoNames As %List = "", Output pGraphs, Output pErrorList) As %Status [ Internal ]
{
	#dim tModule As %IPM.Storage.Module
	Set tSC = $$$OK
	Kill pGraphs
	Kill pErrorList
	Try {
		If '$ListLength(pRepoNames) {
			Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name from %IPM_Storage.ModuleItem")
			If (tRes.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
			}
			While tRes.%Next(.tSC) {
				If $$$ISERR(tSC) {
					Quit
				}
				
				Set tModule = ##class(%IPM.Storage.Module).NameOpen(tRes.%Get("Name"),,.tSC)
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
				Set tRepo = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tRepoName,,.tSC)
				If $$$ISERR(tSC) {
					// Fatal error: repository name invalid
					Quit
				}
				
				If 'tRepo.Enabled {
					Continue
				}
				
				#dim tPackageService As %IPM.Repo.IPackageService
				Set tPackageService = tRepo.GetPackageService()
				Set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
				Set tSearchCriteria.IncludePrerelease = tRepo.Prereleases
				Set tSearchCriteria.IncludeSnapshots = tRepo.Snapshots
				Set tList = tPackageService.ListModules(tSearchCriteria)
				For i=1:1:tList.Count() {
					#dim tModRef As %IPM.Storage.ModuleInfo
					Set tModRef = tList.GetAt(i)
					
					// Retrieve module manifest
					Set tManifest = tPackageService.GetModuleManifest(tModRef)
					
					Set tReader = ##class(%XML.Reader).%New()
					Set tSC = tReader.OpenStream(tManifest)
					If $$$ISERR(tSC) {
						Quit
					}
					Do tReader.Correlate("Module","%IPM.Storage.Module")
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

/// Uninstalls all modules from the current namespace
ClassMethod UninstallAll(pForce As %Boolean, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		// Get all dependency graphs for the namespace.
		Set tSC = ..BuildAllDependencyGraphs(,.tGraphs)
		$$$ThrowOnError(tSC)
		
		// Build arrays mapping dependencies in both directions.
		// Doesn't need to be recursive.
		For tIndex=1:1:$Get(tGraphs) {
			Set tModuleName = $ListGet(tGraphs(tIndex),2)
			Set tModuleNames(tModuleName) = ""
			Set tDependency = ""
			For {
				Set tDependency = $Order(tGraphs(tIndex,tDependency),1,tData)
				If (tDependency = "") {
					Quit
				}
				If ($ListGet(tData,2) '= "") {
					// This is not actually installed locally.
					Continue
				}
				Set tDependsOn(tModuleName,tDependency) = ""
				Set tModuleNames(tDependency,tModuleName) = ""
			}
		}
		
		Set tProgressMade = 1
		For {
			If '$Data(tModuleNames) {
				Quit
			}
			If 'tProgressMade {
				Set tFirstSC = $$$ERROR($$$GeneralError,"Unable to uninstall all modules.")
				Set tSC = $System.Status.AppendStatus(tFirstSC,tSC) // Append any previous errors (which may be causes or unrelated)
				$$$ThrowStatus(tSC)
			}
			Set tProgressMade = 0
			
			// Loop over "dependents" array to delete each module that has nothing left that depends on it.
			// If a module fails to uninstall, modules that it depends on will not be uninstalled, unless
			// pForce is true.
			Set tModuleName = ""
			For {
				Set tModuleName = $Order(tModuleNames(tModuleName))
				If (tModuleName = "") {
					Quit
				}
				
				If ($Data(tModuleNames(tModuleName)) > 1) {
					// If there are dependencies left that have not been uninstalled yet, skip this module.
					Continue
				}
				
				If $Data(tFailedModules(tModuleName)) {
					// If we have already tried unsuccessfully to uninstall a given module, don't try again.
					Continue
				}
				
				Kill tParams
				Merge tParams = pParams
				Write !,"Uninstalling ",tModuleName
				Set tOneSC = ##class(%IPM.Storage.Module).Uninstall(tModuleName,pForce,,.tParams)
				If $$$ISOK(tOneSC) || pForce {
					// If we are forcing uninstallation of everything that can be uninstalled,
					// treat the module in question as uninstalled even if something went fatally wrong.
					Set tDependentModule = ""
					For {
						Set tDependentModule = $Order(tDependsOn(tModuleName,tDependentModule))
						If (tDependentModule = "") {
							Quit
						}
						Kill tModuleNames(tDependentModule,tModuleName)
					}
					Kill tDependsOn(tModuleName)
					Kill tModuleNames(tModuleName)
					Set tProgressMade = 1
				}
				If $$$ISERR(tOneSC) {
					Write !,"Error uninstalling ",tModuleName,": ",$System.Status.GetErrorText(tOneSC)
					Set tSC = $System.Status.AppendStatus(tSC,tOneSC)
					Set tFailedModules(tModuleName) = ""
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// If <var>pSnapshots</var> is empty, lists all modules.
/// If 1, only snapshots; if 0, only non-snapshots.
ClassMethod GetInstalledModuleListSQL(Output pSQL As %String, pSnapshots As %Boolean = "") As %Status
{
	Set pSQL = "select Name from %IPM_Storage.ModuleItem"
	If (pSnapshots = 0) {
		Set pSQL = pSQL_" where Version_Build <> 'snapshot'"
	} ElseIf (pSnapshots = 1) {
		Set pSQL = pSQL_" where Version_Build = 'snapshot'"
	}
	Set pSQL = pSQL_" order by Name"
	Quit $$$OK
}

ClassMethod GetModuleListSQL(Output pSQL As %String) As %Status
{
	Try {
		Set tSC = $$$OK
		Set pSQL = "select * from %IPM_Utils.Module_GetAvailableModuleNames()"

	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

Query GetAvailableModuleNames() As %Query(ROWSPEC = "Name:%String") [ SqlProc ]
{
}

ClassMethod GetAvailableModuleNamesExecute(ByRef qHandle As %Binary) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
		Set tSC = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(tSearchCriteria,.tResults)
		If $$$ISERR(tSC) {
			Quit
		}
		
		For i=1:1:tResults.Count() {
			#dim tRef As %IPM.Storage.QualifiedModuleInfo = tResults.GetAt(i)
			Set qHandle(tRef.Name) = ""
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod GetAvailableModuleNamesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = GetAvailableModuleNamesExecute ]
{
	Set qHandle = $Order(qHandle($Get(qHandle)))
	If (qHandle = "") {
		Set AtEnd = 1
	} Else {
		Set Row = $ListBuild(qHandle)
	}
	Quit $$$OK
}

ClassMethod GetAvailableModuleNamesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = GetAvailableModuleNamesExecute ]
{
	Quit $$$OK
}

Query GetModuleList(pServer As %String, pShowAllVersions As %Boolean) As %Query(ROWSPEC = "Name:%String,Version:%String,Repository:%String,Description:%String,Origin:%String,AllVersions:%String") [ SqlProc ]
{
}

ClassMethod GetModuleListExecute(ByRef qHandle As %Binary, pServer As %String, pShowAllVersions As %Boolean = 0) As %Status
{
	If (pServer = "") {
		Set qHandle = ""
		Quit $$$OK
	}
	Set tSC = $$$OK
	Try {
		Set tServer = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(pServer,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tClient = tServer.GetPackageService()
		If tClient.IsAvailable() {
			Set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
			Set tSearchCriteria.IncludePrerelease = tServer.Prereleases
			Set tSearchCriteria.IncludeSnapshots = tServer.Snapshots
      Set tSearchCriteria.AllVersions = pShowAllVersions
			Set tList = tClient.ListModules(tSearchCriteria)
			For i=1:1:tList.Count() {
				Set tMod = tList.GetAt(i)
				Set qHandle($Increment(qHandle)) = $ListBuild(tMod.Name,tMod.Version.ToString(),tMod.Repository,tMod.Description, tMod.Origin, tMod.AllVersions)
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

Query ListProcessorAttributes(pProcessorClass As %String) As %Query(ROWSPEC = "Name:%String,Type:%String,Description:%String,Default:%String,Required:%Boolean,VALUELIST:%String,DISPLAYLIST:%String,MINLEN:%String,MAXLEN:%String,MINVAL:%Integer,MAXVAL:%Integer") [ SqlProc ]
{
}

ClassMethod ListProcessorAttributesExecute(ByRef qHandle As %Binary, pProcessorClass As %String = "") As %Status
{
	Set tSC = $$$OK
	Try {
		Set qHandle("pointer") = ""
		Set tSuper = "%IPM.ResourceProcessor.Abstract"
		If '$$$comClassDefined(pProcessorClass) && $$$comClassDefined($$$DefaultProcessorPackageDot_pProcessorClass) {
			Set pProcessorClass = $$$DefaultProcessorPackageDot_pProcessorClass
		}
		If '$ClassMethod(pProcessorClass,"%Extends",tSuper) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Class '%1' does not extend '%2'",pProcessorClass,tSuper))
			Quit
		}
		Set tSC = $ClassMethod(pProcessorClass,"GetAttributeMetadata",.tMetadata)
		If $$$ISERR(tSC) {
			Quit
		}
		Merge qHandle("data") = tMetadata
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ListProcessorAttributesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ListAttributesExecute ]
{
	Set qHandle("pointer") = $Order(qHandle("data",qHandle("pointer")),1,Row)
	If (qHandle("pointer") = "") {
		Set AtEnd = 1
	}
	Quit $$$OK
}

ClassMethod ListProcessorAttributesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ListAttributesExecute ]
{
	Quit $$$OK
}

ClassMethod GetModuleNameFromXML(pDirectory As %String, Output name As %String) As %Status
{
	Set stream=##class(%Stream.FileBinary).%New()
	Set tSC = stream.LinkToFile(pDirectory_"module.xml")
	Return:$$$ISERR(tSC) tSC 
	Set tSC = ##class(%XML.XPATH.Document).CreateFromStream(stream, .tDocument)
	Return:$$$ISERR(tSC) tSC 	
	Set tSC = tDocument.EvaluateExpression("/Export/Document/Module/Name", "text()", .tRes)
    If $$$ISERR(tSC) Return tSC
	Set name = $$$lcase(tRes.GetAt(1).Value)
	Return $$$OK
}

ClassMethod ExportDocumentForObject(pSourceModule As %IPM.Storage.Module, Output pSourceControlOutput) As %Status
{
	Set tSC = $$$OK
	Set tCookie = ""
	Try {
		New %SourceControl
		
		Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)
		
		Do ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		
		Set tDocName = pSourceModule.Name_".ZPM"
		
		Set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tDocName,.tIsInSourceControl,.tIsEditable)
		$$$ThrowOnError(tSC)
		
		If tIsInSourceControl && 'tIsEditable {
			// Try to make the document editable.
			Set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnMakeModuleEditable(pSourceModule)
			$$$ThrowOnError(tSC)
		}
		
		// Did we actually make the document editable?
		Set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tDocName,,.tIsEditable)
		$$$ThrowOnError(tSC)
		
		// If still not editable, error out.
		If 'tIsEditable {
			$$$ThrowStatus($$$ERROR($$$ItemNotCheckedOut,tDocName))
		}
		
		Set tModuleStream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen(pSourceModule.Name,,.tSC)
		If $ListFind($ListFromString($System.Status.GetErrorCodes(tSC)),$$$KeyValueNotFoundOpen) {
			// It's possible that only the module exists - we'll skip the merge with the document's content if it does.
			Set tSC = $$$OK
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		If $IsObject(tModuleStream) {
			// Extract comments from existing document stream
			Set tHandler = ##class(%IPM.Utils.XMLCommentHandler).%New()
			Set tReader = ##class(%XML.SAX.Parser).%New()
			Set tSC = ##Class(%XML.SAX.Parser).ParseStream(tModuleStream.Contents,tHandler)
			$$$ThrowOnError(tSC)
		}
		
		// Use document API
		#dim tExportStream As %Stream.Object
		Set tSC = pSourceModule.XMLExportToStream(.tExportStream,,"literal,indent")
		If $$$ISERR(tSC) {
			Quit
		}
		
		If $IsObject(tModuleStream) {
			// Reapply comments to exported XML stream
			Set tSC = tHandler.Reapply(.tExportStream)
			$$$ThrowOnError(tSC)
		}
		
		// Save the document.
		Set tRtn = ##class(%Library.RoutineMgr).%OpenId(tDocName)
		If (tRtn = $$$NULLOREF) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Module %1 does not exist.",pModuleName))
			Quit
		}
		
		// NOTE: tRtn.Code is a %IPM.StudioDocument.Module
		Do tRtn.Code.Code.Clear()
		Set tHeader = tExportStream.ReadLine()
		If ($Extract(tHeader,1,2) '= "<?") {
			Do tRtn.Code.Code.WriteLine("<?xml version=""1.0""?>")
		}
		Do tExportStream.Rewind()
		Set tSC = tRtn.Code.Code.CopyFrom(tExportStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = tRtn.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	
	// Ensure I/O redirection ends.
	Do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pSourceControlOutput)
	Quit tSC
}

ClassMethod LoadNewModule(pDirectory As %String, ByRef pParams, pRepository As %String = "", pSynchronous As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tUseTransactions = '($Get(pParams("NoTransaction"),0) || $Get(pParams("NoJournal"),0))
		If '$Data(pParams("qstruct")) {
			Set qstruct = "ck"_$Select(tVerbose:"d",1:"-d")
		}
		
		// Check for valid license key prior to top-level module load
		// This may throw an exception.
		If '$Data($$$ZPMHandledModules($Namespace)) {
			Set tLicenseIsValid = ..CheckLicenseKey()
			If 'tLicenseIsValid {
				Write !,"WARNING: Continuing module load without a valid license."
			}
		}
		
		// Create a singleton instance for logging of warnings/error messages
		Set tLogManager = ##class(%IPM.General.LogManager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		// Show INFO+ if verbose, WARNING+ if not.
		Set tMinLogLevel = $Select(tVerbose:1,1:2)
		If (tLogManager.Threshold > tMinLogLevel) {
			Set tLogManager.Threshold = tMinLogLevel
		}
		
		Set pDirectory = ##class(%File).NormalizeDirectory("",pDirectory)
		
		If ($Get(pParams("NoJournal"),0) '= 0) {
			// Disable journalling with process-level switch.
			Set tJournalMgr = ##class(%IPM.Utils.JournalManager).%New(0)
		} ElseIf tUseTransactions {
			TSTART
		}
		Set tSC = $system.OBJ.Load(pDirectory_"module.xml",$Select(tVerbose:"d",1:"-d"),,.tLoadedList)
		$$$ThrowOnError(tSC)
		
		Set tFirstLoaded = $Order(tLoadedList(""))
		If (tFirstLoaded = "") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No module definition found."))
		}
		If ($Order(tLoadedList(tFirstLoaded)) '= "") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"module.xml contains multiple documents."))
		}
		Set tFirstLoaded = $$$lcase(tFirstLoaded)
		If ($Piece(tFirstLoaded,".",*) '= "zpm") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No module definition found."))
		}

		Set tDisplayName = $Piece(tFirstLoaded, ".", 1, *-1)
		Set tModuleName = $$$lcase(tDisplayName)
		
		If (pRepository '= "") {
			// Force developer mode to be 0 if repository is read only.
			If ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(pRepository, .tRepositoryId) {
				If +##class(%IPM.Repo.Definition).ReadOnlyGetStored(tRepositoryId) {
					// Set in pParams directly so that this value gets transmitted downstream
					Set pParams("DeveloperMode") = 0
					If tVerbose {
						Write !, "Repository "_pRepository_" is Read-Only so "_tDisplayName_" will be loaded in non-developer mode"
					}
				}
			}
		}

		Set tModule = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
		$$$ThrowOnError(tSC)
		Set tModule.Repository = pRepository
		
		If $Data(pParams("DeveloperMode"),tDeveloperMode) {
      // Mark module as not deployed if installing with dev mode
      Set tModule.Deployed = 0
			Set tModule.DeveloperMode = tDeveloperMode
			Set tModule.Root = pDirectory
			Set tSC = tModule.%Save()
			$$$ThrowOnError(tSC)
		} Else {
			Set tDeveloperMode = +tModule.DeveloperMode
		}
		
		If (tDeveloperMode && tUseTransactions) {
			// In developer mode, save the module manifest so we can fix it even if errors occur afterward.
			TCOMMIT
			
			// Nested transactions in underlying calls to LoadNewModule during the dependency resolution process may be rolled back at the end of this method.
			// To debug a dependency, that module itself should be loaded in "developer mode"
			TSTART
		}
		
		If '$Data($$$ZPMHandledModules($Namespace)) {
			// The purpose of this NEW command is to make sure that the % variable $$$ZPMHandledModules refers to doesn't leak outside this scope.
			// This only happens for the first module to be loaded in a set of dependencies (using zpm "load ..." or zpm "install ...")
			// $$$ZPMHandledModules is also used in the ExecutePhases method of %IPM.Storage.Module to
			// cover cases where new dependencies are added and a module is compiled without reloading, and in the BuildDependencyGraph
			// method to treat installed snapshot versions as installed rather than forcing reload if they have been reloaded
			// as part of the same root module operation.
			New $$$ZPMHandledModules
			Set $$$ZPMHandledModules($Namespace) = "" //Initialize.
		}
		Merge $$$ZPMHandledModules($Namespace) = pParams("Multicompile","ModuleContext")

    $$$ThrowOnError(##class(%IPM.Storage.Module).CheckSystemRequirements(tModuleName))
  
		#dim tInstallContext As %IPM.General.InstallContext
		Set tInstallContext = ##class(%IPM.General.InstallContext).%Get(.tSC)
		$$$ThrowOnError(tSC)
		If 'tInstallContext.ModuleIsDependency(tModuleName) {
			If 'pSynchronous {
				// Regular async multi-threaded loading of dependencies
				Set tSC = tModule.LoadDependencies("",.pParams)
				$$$ThrowOnError(tSC)
			} Else {
				// Temporary custom loading of dependencies in a synchronous
				// manner to prevent lock timeouts until lifecycle rework
				// is complete (HSIEO-4450)
        Do ..SyncLoadDependencies(tModule, .pParams)
			}
		}
		
		Set tPath = pDirectory_"preload"
		If ##class(%File).DirectoryExists(tPath) {
			// Load first, update legacy superclasses, then compile
			Set tSC = $system.OBJ.ImportDir(tPath,,$Select(tVerbose:"d",1:"-d")_$Select($TLevel:"/multicompile=0",1:""),,1,.tImported)
			$$$ThrowOnError(tSC)
			Set tSC = ##class(%IPM.Utils.LegacyCompat).UpdateSuperclassAndCompile(.tImported)
			$$$ThrowOnError(tSC)
		} Else {
			Write:tVerbose !,"Skipping preload - directory does not exist."
		}
  
		Set tSC = $system.OBJ.Load(pDirectory_"module.xml",$Select(tVerbose:"d",1:"-d"),,.tLoadedList)
		$$$ThrowOnError(tSC)
		Set tSC = tModule.%Reload()
		$$$ThrowOnError(tSC)
		
		If (tDeveloperMode && tUseTransactions) {
			// In developer mode, commit load of dependencies (if all went well) and don't wrap reload/compile of this module's code
			// in a transaction; we want to be able to debug!
			TCOMMIT
		}
		Set pParams("RootDirectory") = pDirectory
		If tVerbose || $Get(pParams("Multicompile","Verbose"),0) {
			Write !,"Loading "_tDisplayName_" in process "_$Job
		}
		Set tSC = ##class(%IPM.Storage.Module).ExecutePhases(tModuleName,$lb("Activate"),1,.pParams)
		If $$$ISOK(tSC) && 'tDeveloperMode && tUseTransactions {
			TCOMMIT
		}
		$$$ThrowOnError(tSC)
		Do tModule.WriteAfterInstallMessage()
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

/// Temporary workaround to synchronously load dependencies. Can be removed once
/// HSIEO-4450 is complete.
ClassMethod SyncLoadDependencies(pModule As %IPM.Storage.Module, ByRef pParams)
{
	Set isVerbose = $Get(pParams("Verbose"),0)

	/* 
	 * Call to BuildDependencyGraph copied from %IPM.Storage.Module:LoadDependencies
	 */

	Set reloadSnapshots = +$Get(pParams("UpdateSnapshots"))
	Set permitDowngrade = +$Get(pParams("PermitDowngrade"))
	Set ignoreInstalled = +$Get(pParams("IgnoreInstalled"))
	Write !, "Building dependency graph..." // Intentionally always write even in non-verbose mode
	Set sc = pModule.BuildDependencyGraph(.depdendencyGraph,,reloadSnapshots,,"",,,,ignoreInstalled,,permitDowngrade)
	$$$ThrowOnError(sc)
	Write "Done."

	/* This setting is copied from %IPM.Main:Install */
	Set pParams("Install") = 1
	
	Do ..ConstructInvertedDependencyGraph(.depdendencyGraph, .invertedDependencyGraph)
	If isVerbose {
		Write !, "Created inverted dependency graph from dependency graph"
	}

	#dim flatDepList As %Library.ListOfObjects
	Set flatDepList = ..GetFlatDependencyListFromInvertedDependencyGraph(.invertedDependencyGraph)
	If isVerbose {
		Write !, "Constructed flat dependency list from inverted dependency graph"
		Write !, "Starting installation of dependencies..."
		Write !	
	}
	For i = 1:1:flatDepList.Count() {
		#dim moduleReference As %IPM.Storage.QualifiedModuleInfo
		Set moduleReference = flatDepList.GetAt(i)
		If (moduleReference.ServerName = "") {
			// Ignore modules already installed that do not need to be installed again
			Continue
		}
		Set sc = ..LoadModuleReference(moduleReference.ServerName, moduleReference.Name, moduleReference.VersionString,$Get(tDeployed), $Get(tPlatformVersion), .pParams)
		$$$ThrowOnError(sc)
	}
}

/// Construct an inverted dependency graph from the dependency graph of a module. <br />
/// @Argument	pDependencyGraph			Dependency graph constructed. <br />
/// @Argument	pInvertedDependencyGraph	Inverted dependency graph constructed. <br />
ClassMethod ConstructInvertedDependencyGraph(ByRef pDependencyGraph, Output pInvertedDependencyGraph)
{
	Set moduleName = ""
	While 1 {
		Set moduleName = $Order(pDependencyGraph(moduleName), 1, data)
		If (moduleName = "") {
			Quit
		}
		// Invert dependency graph, subscripts (<module>, <depends on>)
		Set pInvertedDependencyGraph(moduleName) = $List(data, 2, 3)
		Set dependentKey = ""
		For {
			Set dependentKey = $Order(pDependencyGraph(moduleName, dependentKey))
			If (dependentKey = "") {
				Quit
			}
			Set pInvertedDependencyGraph($Piece(dependentKey, " "), moduleName) = ""
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
	Set orderedDependencyList = ##class(%Library.ListOfObjects).%New()
	Set moduleName = ""
	While 1 {
		// Note that all nodes have to be killed eventually because no cyclic dependencies
		// are allowed to exist
		If '$Data(pInvertedDependencyGraph) {
			Quit
		}
		Set moduleName = $Order(pInvertedDependencyGraph(moduleName))
		If (moduleName = "") {
			Set moduleName = $Order(pInvertedDependencyGraph(moduleName))
		}
		
		// If it has no remaining dependencies
		If $Data(pInvertedDependencyGraph(moduleName)) < 10 {
			Set $ListBuild(repositoryName, versionString) = $Get(pInvertedDependencyGraph(moduleName))
			// Create qualified module reference to add to list
			Set moduleReference = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
			Set moduleReference.Name = moduleName
			Set moduleReference.VersionString = versionString
			Set moduleReference.ServerName = repositoryName
			$$$ThrowOnError(orderedDependencyList.Insert(moduleReference))
			// Remove node from graph
			Kill pInvertedDependencyGraph(moduleName)
			// Remove from all entries in graph
			Set dependencyName = ""
			While 1 {
				Set dependencyName = $Order(pInvertedDependencyGraph(dependencyName))
				If (dependencyName = "") {
					Quit
				}
				ZKill pInvertedDependencyGraph(dependencyName, moduleName)
			}
		}
	}
	Return orderedDependencyList
}

ClassMethod CheckLicenseKey() As %Boolean
{
	// Limit the number of attempts in case this somehow ends up running in a non-interactive process.
	#define MaxTries 5
	Set tValidLicense = ($System.License.GetKeyStatus() '= "Invalid")
	While ('tValidLicense) && $$$InProgrammerMode && ('$$$IsISCWorker) && ($Increment(tTries) <= $$$MaxTries) {
		Write !!,"Your system has no (valid) license key present"
		Write !,"Copy a valid license key into "_$System.Util.ManagerDirectory()
		Write !,"and then enter 'y' to activate it. Enter 'n' to continue without a license key, "
		Write !,"or 'q' to quit."
		Set tValue = 1
		Set tResponse = ##class(%Library.Prompt).GetYesNo("Action >",.tValue,,$$$DisableHelpCharMask + $$$DisableBackupCharMask + $$$EnableQuitCharMask)
		If (tResponse '= $$$SuccessResponse) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Installation cancelled due to lack of license key."))
		}
		If ('tValue) {
			// The user wants to keep going anyway.
			Quit
		}
		
		// Try to activate the license.
		Set tSC = $System.License.Upgrade()
		If $$$ISERR(tSC) {
			Write !!,"ERROR activating license: ",!,$System.Status.GetErrorText(tSC)
		} Else {
			Write !,"License activated."
			Set tValidLicense = 1
		}
	}
	Quit tValidLicense
}

ClassMethod AddPackageMapping(pNamespace As %String, pMapping As %String, pFrom As %String, pSkipActivation As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		If $$$ucase(pNamespace) = "%ALL" {
			Set tSC = ..CreateAllNamespace()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		Set tPrevNS = $namespace
		New $namespace
		Set $namespace = "%SYS"
		If '##class(Config.MapPackages).Exists(pNamespace,pMapping) {
			Set tProps("Database") = pFrom
			$$$ThrowOnError(##class(Config.MapPackages).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
			If 'pSkipActivation {
				New $namespace
				Set $namespace = tPrevNS
				$$$ThrowOnError(..ActivateMappings(pNamespace))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod RemovePackageMapping(pNamespace As %String, pMapping As %String, pSkipActivation As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tPrevNS = $namespace
		New $namespace
		Set $namespace = "%SYS"
		If ##class(Config.MapPackages).Exists(pNamespace,pMapping) {
			$$$ThrowOnError(##class(Config.MapPackages).Delete(pNamespace,pMapping,,$$$CPFSave))
			If 'pSkipActivation {
				New $namespace
				Set $namespace = tPrevNS
				$$$ThrowOnError(..ActivateMappings(pNamespace))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod AddRoutineMapping(pNamespace As %String, pMapping As %String, pType As %String = "ALL", pFrom As %String, pSkipActivation As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		If $$$ucase(pNamespace) = "%ALL" {
			Set tSC = ..CreateAllNamespace()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		Set tPrevNS = $namespace
		New $namespace
		Set $namespace = "%SYS"
		Set pMapping = pMapping_$S(pType="ALL":"",1:"_"_pType)
		If '##class(Config.MapRoutines).Exists(pNamespace,pMapping) {
			Set tProps("Database") = pFrom
			$$$ThrowOnError(##class(Config.MapRoutines).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
			If 'pSkipActivation {
				New $namespace
				Set $namespace = tPrevNS
				$$$ThrowOnError(..ActivateMappings(pNamespace))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod RemoveRoutineMapping(pNamespace As %String, pMapping As %String, pType As %String = "ALL", pSkipActivation As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tPrevNS = $namespace
		New $namespace
		Set $namespace = "%SYS"
		Set pMapping = pMapping_$S(pType="ALL":"",1:"_"_pType)
		If ##class(Config.MapRoutines).Exists(pNamespace,pMapping) {
			$$$ThrowOnError(##class(Config.MapRoutines).Delete(pNamespace,pMapping,,$$$CPFSave))
			If 'pSkipActivation {
				New $namespace
				Set $namespace = tPrevNS
				$$$ThrowOnError(..ActivateMappings(pNamespace))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod AddGlobalMapping(pNamespace As %String, pMapping As %String, pFrom As %String, pSetCollation As %Boolean = 0, pSkipActivation As %Boolean = 0, ByRef pChanged As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		If $$$ucase(pNamespace) = "%ALL" {
			Set tSC = ..CreateAllNamespace()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		Set tPrevNS = $namespace
    	New $namespace
	 	Set $namespace = "%SYS"
		If (pMapping [ ":(") {
			// 2008 has glo:(subs), 2009 has glo(subs)
			Set pMapping=$Piece(pMapping,":(")_"("_$Piece(pMapping,":(",2,*)
		}
		
		If '##Class(Config.MapGlobals).Exists(pNamespace,pMapping) {
			Set tProps("Database") = pFrom
			If pSetCollation {
				Set tDB=##class(SYS.Database).%OpenId(##class(%Library.File).NormalizeDirectory($System.Util.InstallDirectory()_"mgr")_pFrom)
				If $IsObject(tDB) {
					Set tProps("Collation") = tDB.NewGlobalCollation
				}
			}
			$$$ThrowOnError(##class(Config.MapGlobals).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
			If pSkipActivation {
				Set pChanged = 1
			} Else {
				New $namespace
				Set $namespace = tPrevNS
				$$$ThrowOnError(..ActivateMappings(pNamespace))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod RemoveGlobalMapping(pNamespace As %String, pMapping As %String = "", pSkipActivation As %Boolean = 0, ByRef pChanged As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tPrevNS = $namespace
		New $namespace
		Set $namespace = "%SYS"
		If pMapping [ ":(" {
			// 2008 has glo:(subs), 2009 has glo(subs)
			Set pMapping=$Piece(pMapping,":(")_"("_$Piece(pMapping,":(",2,999) 
		} 
		If ##class(Config.MapGlobals).Exists(pNamespace,pMapping) {
			$$$ThrowOnError(##class(Config.MapGlobals).Delete(pNamespace,pMapping,,$$$CPFSave))
			If pSkipActivation {
				Set pChanged = 1
			} Else {
				New $namespace
				Set $namespace = tPrevNS
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
	New $namespace
	Set $namespace="%SYS"
	Quit ##class(Config.Namespaces).Open(pNamespace).Routines
}

ClassMethod GetGlobalDatabase(pNamespace As %String) As %String
{
	New $namespace
	Set $namespace="%SYS"
	Quit ##class(Config.Namespaces).Open(pNamespace).Globals
}

ClassMethod GetRoutineDatabaseDir(pNamespace As %String) As %String
{
	New $namespace
	Set $namespace="%SYS"
	Quit ..GetDatabaseDirectory(..GetRoutineDatabase(pNamespace))
}

ClassMethod GetGlobalDatabaseDir(pNamespace As %String) As %String
{
	New $namespace
	Set $namespace="%SYS"
	Quit ..GetDatabaseDirectory(..GetGlobalDatabase(pNamespace))
}

ClassMethod GetDatabaseDirectory(pDatabase As %String) As %String
{
	New $namespace
	Set $namespace="%SYS"
	Quit ##class(Config.Databases).Open(pDatabase).Directory
}

ClassMethod ActivateMappings(pNamespace = {$Namespace}) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Set tInterruptManager = ##class(%IPM.Utils.InterruptManager).%New()
		Do tInterruptManager.DisableInterrupts()
		New $Namespace
		Set $Namespace = "%SYS"
		$$$ThrowOnError(##class(Config.CPF).Write())
		$$$ThrowOnError(##class(Config.Map).MoveToActive())
		$$$ThrowOnError(##class(Config.Namespaces).Load(pNamespace))
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// Copy a package from one namespace to another. This works whether or not the contents of
/// the package are deployed. <br />
/// This copies classes and include files in the package. <br />
ClassMethod CopyItemsInPackage(pPackage As %String, pFromNamespace As %String, pToNamespace As %String)
{
	#define CopyTempGlobal ^CacheTemp.CopyPercentItems
	If $Extract(pPackage, "*") '= "." {
		Set pPackage = pPackage_"."
	}
	
	New $Namespace
	Set $Namespace = pFromNamespace
	
	// Create Studio project
	Set project = ##class(%Studio.Project).%New()
	
	// Add classes to project
	Set sc = project.AddItem(pPackage_"PKG")
	$$$ThrowOnError(sc)
	
	// Add include files to project
	Set key = pPackage
	While 1 {
		Set key = $Order(^rINC(key))
		If (key = "") || ($Extract(key, 1, $Length(pPackage)) '= pPackage) {
			Quit
		}
		Set sc = project.AddItem(key_".INC")
		$$$ThrowOnError(sc)
	}
	
	// Deploy project to temp global
	Kill $$$CopyTempGlobal
	Set globalName = $Name($$$CopyTempGlobal)
	Set sc = project.DeployToGbl(globalName)
	$$$ThrowOnError(sc)

	// Switch to pToNamespace and import project
	Set $Namespace = pToNamespace
	Set sc = ##class(%Studio.Project).InstallFromGbl(globalName)
	$$$ThrowOnError(sc)
}

/// This method exports items (classes, routines, etc.) and reloads it into a different namespace
/// The syntax for itemspec is the Name attribute in <Resource> tag and <Mapping> tag
ClassMethod CopyItems(itemspec, source, target, qspec)
{
    set tSC = $$$OK
    try {
        new $namespace
        set $namespace = target
		set tSC = ##class(%IPM.Utils.Module).ResolveItems(.itemlist,itemspec,source) quit:$$$ISERR(tSC)
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
			If '$IsObject(##class(%IPM.ExtensionBase.Utils).FindHomeModule(tName)) {
				Set ^||%IPM.OrphanedResources($i(^||%IPM.OrphanedResources)) = $ListBuild(tName)
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
		Set qHandle = $Order(^||%IPM.OrphanedResources(qHandle),1,tData)
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
	Kill ^||%IPM.OrphanedResources
	Quit $$$OK
}

/// Helper method to see if <var>pNamespace</var> has <var>pModule</var> (a module name) installed.
/// Returns false if the module is not installed (which may be because the namespace does not exist).
ClassMethod NamespaceHasModule(pNamespace As %String, pModuleName As %String) As %Boolean
{
	Set tModuleExists = 0
	New $Namespace
	Try {
		Set $Namespace = pNamespace // This might fail.
		Set tModuleExists = ##class(%IPM.Storage.Module).NameExists(pModuleName)
	} Catch e {
		// Ignore - this means the namespace does not exist.
	}
	Quit tModuleExists
}

/// Short-term approach to lock a module's dependencies within the module manifest (rather than using a separate file).
ClassMethod LockWithCurrentDependencies(pModuleName As %String) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		TSTART
		Set tModule = ##class(%IPM.Storage.Module).NameOpen(pModuleName,,.tSC)
		$$$ThrowOnError(tSC)
		
		Set tSC = tModule.BuildDependencyGraph(.tGraph,,,,,,,,1)
		$$$ThrowOnError(tSC)
		
		// Build map of dependency name to position in module's dependencies
		Set tDepKey = ""
		For {
			Set tDependency = tModule.Dependencies.GetNext(.tDepKey)
			If (tDepKey = "") {
				Quit
			}
			Set tDepMap(tDependency.Name) = tDepKey
		}
		
		// Add dependencies or update their versions as needed
		Set tModuleName = ""
		For {
			Set tModuleName = $Order(tGraph(tModuleName),1,tData)
			If (tModuleName = "") {
				Quit
			}
			Set tVersion = $ListGet(tData,3)
			If $Data(tDepMap(tModuleName),tDependencyKey) {
				// Lock down version.
				Write !,"Locking dependency: ",tModuleName," ",tVersion
				Set tModule.Dependencies.GetAt(tDependencyKey).VersionString = tVersion
			} Else {
				// Add new dependency for unlisted transitive dependency.
				Write !,"Adding dependency: ",tModuleName," ",tVersion
				Set tNewDependency = ##class(%IPM.Storage.ModuleReference).%New()
				Set tNewDependency.Name = tModuleName
				// Copy the actual version string (a semantic version) into the module manifest dependency's version string (a semantic version expression)
				// A semantic version is also a valid semantic version expression, but not vice versa.
				Set tNewDependency.VersionString = tVersion
				$$$ThrowOnError(tModule.Dependencies.Insert(tNewDependency))
			}
		}
		
		$$$ThrowOnError(tModule.%Save())
		
		// Use the API to update the module manifest on disk from the updated persistent object
		Set tStatus = ..ExportDocumentForObject(tModule,.tSourceControlOutput)
		
		// Always show any output (before checking tStatus)
		For tLine=1:1:$Get(tSourceControlOutput) {
			Write !,$Get(tSourceControlOutput(tLine))
		}
		$$$ThrowOnError(tStatus)
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

/// Creates (or updates) an include file with name <var>pName</var> and contents in an indexed
/// subscripted array <var>pLineArray</var>. <br />
/// @Argument	pName		Name of include file. <br />
/// @Argument	pLineArray	Subscripted array whose keys are indices and values correspond to
/// lines in the include file. The top level node should have the number of lines. <br />
ClassMethod CreateOrUpdateIncludeFile(pName As %String, ByRef pLineArray As %String)
{
	// Create include file
	Set routine = ##class(%Library.Routine).%New(pName_".INC")
	// Write lines
	For i = 1:1:$Get(pLineArray) {
		$$$ThrowOnError(routine.WriteLine(pLineArray(i)))
	}
	// Save the routine
	$$$ThrowOnError(routine.Save())
}

ClassMethod ConvertW3CToTimestampUTC(pDateTime As %String) As %TimeStamp
{
    Set date = $Piece(pDateTime, "T", 1)
    Set time = $Piece(pDateTime, "T", 2)
    
    // Validation
    Set containsPlus = ($Find(time, "+") > 0)
    Set containsMinus = ($Find(time, "-") > 0)
    Set containsZ = ($Find(time, "Z") > 0)
    If ((containsPlus + containsZ + containsMinus) > 1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid time format. Cannot contain multiple timezone offset formats"))
    }
    If ((containsPlus + containsZ + containsMinus) = 0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid time format. Missing timezone offset"))
    }
    
    Set parsedTime = ""
    Set dateAdd = ""
    
    // Obtain UTC time
    If containsZ {
        Set parsedTime = $Extract(time, 1, *-1)
    } Else {
	    Set operator = $Case(containsPlus, 1: "+", : "-")
	    
        Set absTime = $Piece(time, operator, 1)
        Set offset = $Piece(time, operator, 2)
        Set $ListBuild(offsetHours, offsetMinutes) = $ListFromString(offset, ":")
        Set offsetHours = "-"_operator_offsetHours
        Set offsetMinutes = "-"_operator_offsetMinutes
        Set $ListBuild(hours, minutes, seconds) = $ListFromString(absTime, ":")
        
        Set computedMinutes = minutes + offsetMinutes
        Set netMinutes = computedMinutes#60
        Set hoursAdd = $Case((computedMinutes < 0), 1: -1, : $Case((computedMinutes >= 60), 1: 1, : 0))
        Set computedHours = (hours + offsetHours + hoursAdd)
        Set netHours = computedHours#24
        Set dateAdd = $Case((computedHours < 0), 1: -1, : $Case((computedHours >= 24), 1: 1, : 0))
        
        // Add padding of 0's if needed
        If ($Length(netHours) = 1) {
        	Set netHours = "0"_netHours
        }
        If ($Length(netMinutes) = 1) {
        	Set netMinutes = "0"_netMinutes
        }
        
        Set parsedTime = netHours_":"_netMinutes_":"_seconds
    }
    Set dateTime = date_" "_parsedTime
    If (dateAdd '= "") {
	    // Adjust date
        Set dateTime = $System.SQL.DATEADD("day", dateAdd, dateTime)
    }
    Return dateTime
}

ClassMethod ConvertTimestampUTCToW3C(pDateTime As %TimeStamp) As %String
{
    Set date = $Piece(pDateTime, " ", 1)
    Set time = $Piece(pDateTime, " ", 2)    
    Return date_"T"_time_"Z"
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
/// Run a command using $ZF(-1) and an external temporary file to store the command output. <br>
/// If <var>pDeleteTempFile</var> is 0 (false), the temporary file is not deleted; in this case, it is up to the caller to delete it when done with it.
ClassMethod RunCommandViaZF(pCmd As %String, Output pLogOutput, Output pErrOutput, pTimeout As %Integer = 10, Output pRetCode As %String, pArgs... As %String) As %Status
{
	Set tSC = $$$OK
	Set pRetCode = ""
	Set IO = $IO
	Set ZEOFMode = $ZU(68,40,1)

	Try {
		Set tFile = ##class(%File).TempFilename("txt")
		If tFile="" Set tSC = $$$ERROR($$$ObjectScriptError, "Failed to obtain a temporary file name") Quit
		Set tErrFile = ##class(%File).TempFilename("txt")
		If tErrFile="" Set tSC = $$$ERROR($$$ObjectScriptError, "Failed to obtain a temporary file name") Quit
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

/// Run command with $ZF(-100) <br />
/// <var>pCwd</var> - Working folder<br/ >
/// <var>pCmd</var> - $ListBuild for command with arguments<br/ >
/// <var>pLogOutput</var> - Pass filename or stream object, to get all output, empty string to ignore and have output from command in default output<br/ >
/// <vr>pErrOutput</var> - if not specified, gets the value from pLogOutput<br/ >
/// <vr>pRetCode</var> - Code returned by OS<br/ >
ClassMethod RunCommand(pCwd As %String = "", pCmd As %List = "", ByRef pLogOutput As %Stream.Object, ByRef pErrOutput As %Stream.Object, Output pRetCode As %String) As %Status
{
  If (pCmd="") || ('$ListValid(pCmd)) || ($ListGet(pCmd) = "") {
    Quit $$$ERROR($$$GeneralError,"Wrong command.")
  }
  If pCwd="", '##class(%File).DirectoryExists(pCwd) {
    Quit $$$ERROR($$$GeneralError,"Working folder does not exists or inaccessible.")
  }
  Set tSC = $$$OK
  Try {
    Set currentDirectory = ##class(%SYSTEM.Process).CurrentDirectory(pCwd)
    Set flags = ""
    Set cmd = $ListGet(pCmd)
    Set args = 0
    For i = 2:1:$ListLength(pCmd) {
      Set args($Increment(args)) = $ListGet(pCmd, i)
    }
    If '$Data(pLogOutput),$Data(pErrOutput) {
      Set pLogOutput = pErrOutput
    }
    Set stdout = ..GetFilename4Output(.pLogOutput, .stdoutTmp)
    Set stderr = ..GetFilename4Output(.pErrOutput, .stderrTmp)
    If stdout '= "", stderr = "" {
      Set stderr = stdout
    }
    If stdout '= "" {
      Set flags = flags _ "/STDOUT=""" _ stdout _ """"
    }
    If stderr '= "" {
      Set flags = flags _ "/STDERR=""" _ stderr _ """"
    }
    Set pRetCode = $Zf(-100, flags, cmd, args...)
    $$$ThrowOnError(..ReadFileToStream(stdout, .pLogOutput, $Get(stdoutTmp)))
    $$$ThrowOnError(..ReadFileToStream(stderr, .pErrOutput, $Get(stderrTmp)))

    If pRetCode'=0 {
      $$$ThrowStatus($$$ERROR($$$GeneralError, "Running command returned error."))
    }
  } Catch (ex) {
    If ex.Code = 34 {
      Set tSC = $$$ERROR($$$GeneralError, "Command " _ $Get(cmd) _ " not found.")
    } 
    else {
      Set tSC = ex.AsStatus()
    }
  }
  If $Get(currentDirectory)'="" {
    Do ##class(%SYSTEM.Process).CurrentDirectory(currentDirectory)
  }
  Quit tSC
}

ClassMethod GetFilename4Output(pOutput As %Stream.Object, Output pAsTemporary = 0) As %String
{
  If '$Data(pOutput) {
    Quit ""
  }
  Set filename = ##class(%Library.Device).GetNullDevice()
  If $IsObject(pOutput),pOutput.%IsA("%Stream.Object") {
    Do pOutput.Clear()
    If pOutput.%IsA("%Stream.FileBinary") {
      Set filename = pOutput.Filename
    }
    Else {
      Set filename = ##class(%File).TempFilename()
      Set pAsTemporary = 1
    }
  }
  ElseIf '$IsObject(pOutput),pOutput'="",##class(%File).DirectoryExists(##class(%File).GetDirectory(pOutput)) {
    Set filename = pOutput
  }
  Quit filename
}

ClassMethod ReadFileToStream(pFileName As %String = "", ByRef pOutput As %Stream.Object, pDeleteAfter As %Boolean = 0) As %Status
{
  If (pFileName="") || (pFileName=##class(%Library.Device).GetNullDevice()) {
    Quit $$$OK
  }
  If '$Data(pOutput) || '$IsObject(pOutput) || (pFileName = pOutput) {
    Quit $$$OK
  }
  If pOutput.%IsA("%Stream.FileBinary"), pOutput.Filename = pFileName {
    Quit $$$OK
  } 
  Set tStream = $Select(pOutput.IsCharacter(): ##class(%Stream.FileCharacter).%New(), 1: ##class(%Stream.FileBinary).%New())
  $$$QuitOnError(tStream.LinkToFile(pFileName))
  $$$QuitOnError(pOutput.CopyFrom(tStream))
  If pDeleteAfter {
    Do ##class(%File).Delete(pFileName)
  }
  Quit $$$OK
}

ClassMethod GetFileLines(pFileName As %String, Output pOutput) As %Status [ Internal, Private ]
{
	Set tSC = $$$OK
	Try {
		Kill pOutput
		Close pFileName Open pFileName:("RS"):5
		If '$T Set tSC = $$$ERROR($$$ObjectScriptError, "Failed to open temporary file '"_pFileName_"'") Quit
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
	If (pString '[ "{") {
		Return pString
	}
	Set result = pString
	Do ..GetDatabaseInfoForNamespace($Namespace, .properties)
	Set result = ..%RegExReplace(result,"namespace", $Namespace)
	
	Set result = ..%RegExReplace(result, "ns", $Namespace)

	Set result = ..%RegExReplace(result, "namespaceLower", $ZConvert($Namespace,"L"))
	
	Set result = ..%RegExReplace(result, "namespaceRoutineDB", $Get(properties("Routines")))
	
	Set result = ..%RegExReplace(result, "namespaceGlobalsDB", $Get(properties("Globals")))

	Set installDir = $System.Util.InstallDirectory()
	Set result = ..%RegExReplace(result,"installDir", installDir)

	Set dataDir = $System.Util.DataDirectory()
	Set result = ..%RegExReplace(result,"dataDir", dataDir)

	Set mgrDir = ##class(%Library.File).ManagerDirectory()
	Set result = ..%RegExReplace(result,"mgrDir", mgrDir)

	Set cspDir = ##class(%Library.File).NormalizeDirectory($System.Util.InstallDirectory()_"csp")
	Set result = ..%RegExReplace(result,"cspDir", cspDir)
	
	Set binDir = $System.Util.BinaryDirectory()
	Set result = ..%RegExReplace(result, "binDir", binDir)

	Set libDir = ##class(%Library.File).NormalizeDirectory($System.Util.InstallDirectory()_"lib")
	Set result = ..%RegExReplace(result, "libDir", libDir)

	Do ##class(%Studio.General).GetWebServerPort(,,,.urlRoot)
	Set result = ..%RegExReplace(result, "webroot", urlRoot)

	If '$Get($$$DeprecationWarned("<expression>", "dbrole")) && ((result [ "${dbrole}") || (result [ "{$dbrole}")) {
		Set $$$DeprecationWarned("<expression>", "dbrole") = 1
		Write !, $$$FormattedLine($$$Red, "WARNING: The {$dbrole}/${dbrole} expression is deprecated. Please contact package developer to use {$globalsDbRole} instead.")
	}
	Set dbRole = ..GetDatabaseRole()
	Set result = ..%RegExReplace(result, "dbrole", dbRole)
	Set result = ..%RegExReplace(result, "globalsDbRole", dbRole)

	Return result
}

ClassMethod %EvaluateMacro(pString As %String) As %String [ Internal ]
{
	If pString '[ "$$$" {
		Return pString // Return early for efficiency
	}
	Set tString = pString
	Set tPattern = "\$\$\$[a-zA-Z0-9]+"
	Set tMatch = ##class(%Regex.Matcher).%New(tPattern, tString)
	While tMatch.Locate() {
		Set group = tMatch.Group
		Set macroVal = ..EvaluateMacroHelper($Extract(group, 4, *))
		set tString = $Replace(tString, group, macroVal)
	}
	Return tString
}

/// Helper metohd to evaluate macro at runtime. 
ClassMethod EvaluateMacroHelper(pMacro As %String) As %String [ Internal, Private ]
{
    Set stream = ##class(%Stream.TmpCharacter).%New()
    Do stream.WriteLine("Class %IPM.Generated.MacroEval")
    Do stream.WriteLine("{")
    Do stream.WriteLine("ClassMethod EvalMacro() [ CodeMode = objectgenerator ]")
    Do stream.WriteLine("{")
    Do stream.WriteLine("  Do %code.WriteLine(""#IfDef "_ pMacro _""")")
    Do stream.WriteLine("  Do %code.WriteLine("" Quit $$$"_pMacro_""")")
    Do stream.WriteLine("  Do %code.WriteLine(""#Else "")")
    Do stream.WriteLine("  Do %code.WriteLine("" Quit """""""" "")")
    Do stream.WriteLine("  Do %code.WriteLine(""#EndIf "")")
    Do stream.WriteLine("  Quit $$$OK") 
    Do stream.WriteLine("}")
    Do stream.WriteLine("}")

    // If it reaches here, pMacro is a valid expression (although may be undefined). 
	// We should throw an error instead of failing silently.
    $$$ThrowOnError($system.OBJ.LoadStream(stream, "ck-d"))
    Set value = $ClassMethod("%IPM.Generated.MacroEval", "EvalMacro")
    Do $system.OBJ.Delete("%IPM.Generated.MacroEval", "-d")
    Return value
}

/// Wrapper around Config.Namespaces:Get()
ClassMethod GetDatabaseInfoForNamespace(pNamespace As %String, Output pProperties) [ Internal ]
{
	Kill pProperties
	New $Namespace
	Set $Namespace = "%SYS"
	Set sc = $ClassMethod("Config.Namespaces", "Get", pNamespace, .pProperties)
}

ClassMethod GetDatabaseRole()
{
	Do ##class(%SYS.Namespace).GetNSInfo($NAMESPACE, .nsInfo)
	Return $Get(nsInfo("Resource"), "%DB_DEFAULT")
}

ClassMethod %RegExReplace(pString As %String, pName As %String, pValue As %String) As %String [ Internal ]
{
	Set tString = pString
	Set tRegEx = "(?i)\{\$" _ pName _ "\}"
	Set tString =  ##class(%Regex.Matcher).%New(tRegEx, tString).ReplaceAll($Replace(pValue,"\","\\"))
	Set tRegEx = "(?i)\$\{" _ pName _ "\}"
	Set tString =  ##class(%Regex.Matcher).%New(tRegEx, tString).ReplaceAll($Replace(pValue,"\","\\"))
	Quit tString
}

}
