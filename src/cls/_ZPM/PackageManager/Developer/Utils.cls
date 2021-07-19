Include (%occInclude, %occErrors, %syConfig, %syPrompt, %ZPM.PackageManager.Common)

Class %ZPM.PackageManager.Developer.Utils [ System = 3 ]
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
ClassMethod LoadDependencies(ByRef pDependencyGraph, ByRef pParams, pWorkQueue As %ZPM.PackageManager.Core.WorkMgr)
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
			
			Set pWorkQueue = ##class(%ZPM.PackageManager.Core.WorkMgr).Initialize("/multicompile="_tNumWorkers,.tSC)
			$$$ThrowOnError(tSC)
			
			Set tModuleName = ""
			For {
				Set tModuleName = $Order(pDependencyGraph(tModuleName),1,tData)
				Quit:tModuleName=""
				
				// List modules to avoid duplicate loads.
				Set pParams("Multicompile","ModuleContext",tModuleName) = $ListBuild("Activate")
				
				// Invert dependency graph, subscripts (<module>,<depends on>)
				Set tInvertedDependencyGraph(tModuleName) = $List(tData,2,3)
				
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
				Set $ListBuild(tServerName,tVersion) = tData
				ZKill $$$ZPMTempLoadGraph(tCacheTempIndex,tModuleName)
				
				// Missing server name indicates that it's already present locally; nothing to do in that case.
				If (tServerName '= "") {
					If ($TLevel = 0) && ($Get(pParams("Multicompile","Verbose"),$Get(pParams("Verbose"),0))) {
						Write !,"Queuing module load: ",tModuleName," ",tVersion," @ ",tServerName
					}
					Set tSC = pWorkQueue.QueueCallback(
						"##class("_$classname()_").LoadModuleReference",
						"##class("_$classname()_").LoadCompleted",
						tServerName,tModuleName,tVersion,.pParams,.pDependencyGraph)
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
ClassMethod LoadCompleted(pServerName As %String, pModuleName As %String, pVersion As %String, ByRef pParams, ByRef pDependencyGraph) As %Status
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

ClassMethod LoadQualifiedReference(pReference As %ZPM.PackageManager.Core.QualifiedModuleReference, ByRef pParams, ByRef pDependencyGraph) As %Status
{
	Set tSC = $$$OK
	Try {
		#dim tReference As %ZPM.PackageManager.Core.QualifiedModuleReference
		Set tReference = pReference.%ConstructClone()
		If (tReference.ServerName = "") && ##class(%ZPM.PackageManager.Client.LocalServerDefinition).SingletonExists(1,.tID) {
			Set tServer = ##class(%ZPM.PackageManager.Client.LocalServerDefinition).%OpenId(tID)
			Set tReference.ServerName = tServer.Name
		}
		Set tSC = ..LoadModuleReference(tReference.ServerName, tReference.Name, tReference.VersionString, .pParams, .pDependencyGraph)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod LoadModuleReference(pServerName As %String, pModuleName As %String, pVersion As %String, ByRef pParams, ByRef pDependencyGraph) As %Status
{
	// Suspend the error count to avoid spurious messages about errors being detected in load/compile.
	$$$SuspendErrorCount
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
		
		// Use % variables that intentionally leak in worker processes, to avoid duplicate work when they go out of scope.
		#dim %installcontext As %ZPM.PackageManager.Core.InstallContext
		#dim %manager As %ZPM.PackageManager.Client.Manager
		If '$$$IsISCWorker {
			New %installcontext
			New %manager
		}
		Set %installcontext = ##class(%ZPM.PackageManager.Core.InstallContext).%Get(.tSC)
		$$$ThrowOnError(tSC)
		Do %installcontext.SetGraph(.pDependencyGraph)
		Merge tIndex = pParams("Multicompile","CacheTempIndex")
		Do %installcontext.SetCacheTempIndex(.tIndex)
		
		Set %manager = $Select($IsObject($Get(%manager)):%manager,1:##class(%ZPM.PackageManager.Client.Manager).%Get(.tSC))
		$$$ThrowOnError(tSC)
		
		Set tClient = %manager.CheckServiceCache(pServerName,.tAvailable)
		If 'tAvailable {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pServerName))
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
				Write !,"Module "_pModuleName_" was downloaded from " _ pServerName _ " " _ tClient.Location
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
			If (tLocalServer.Name '= pServerName) && $IsObject($Get(tPayload)) && '##class(%ZPM.PackageManager.Server.Module).NameVersionExists(pModuleName, pVersion) {
				Set tCacheMod = ##class(%ZPM.PackageManager.Core.Module).%New()
				Set tCacheMod.Name = pModuleName
				Set tCacheMod.VersionString = pVersion
				Set tCacheMod.Manifest = tClient.GetModuleManifest(tModRef)
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

/// Given a path to a module.xml file (directory), tries to correlate it to an instance of <class>%ZPM.PackageManager.Developer.Module</class>.
/// Throws errors.
ClassMethod GetModuleObjectFromPath(pPath As %String, Output pFound As %Boolean) As %ZPM.PackageManager.Developer.Module
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

/// Given a stream, tries to correlate it to an instance of <class>%ZPM.PackageManager.Developer.Module</class>.
/// Throws errors.
ClassMethod GetModuleObjectFromStream(pStream As %Stream.Object, Output pFound As %Boolean) As %ZPM.PackageManager.Developer.Module
{
	Set pFound = 0
	Set reader = ##class(%XML.Reader).%New()
	Set sc = reader.OpenStream(pStream)
	$$$ThrowOnError(sc)
	Do reader.Correlate("Module","%ZPM.PackageManager.Developer.Module")
	Set pFound = (reader.Next(.moduleObj, .sc) > 0)
	$$$ThrowOnError(sc)
	Return $Get(moduleObj)
}

/// Returns a semantic version expression capturing all version requirements for a given module name in the current namespace.
/// A list of modules to exclude may be provided (for example, if these modules would be updated at the same time).
ClassMethod GetRequiredVersionExpression(pModuleName As %String, pExcludeModules As %List = "", Output pExpression As %ZPM.PackageManager.Core.SemanticVersionExpression, Output pSourceList As %List) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pExpression = ##class(%ZPM.PackageManager.Core.SemanticVersionExpression).%New()
		Set pSourceList = ""
		
		Set tResult = ##class(%ZPM.PackageManager.Developer.Module).VersionRequirementsFunc(pModuleName,pExcludeModules)
		If (tResult.%SQLCODE < 0) {
			$$$ThrowStatus($$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message))
		}
		
		While tResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tVersion = tResult.%Get("Version")
			$$$ThrowOnError(##class(%ZPM.PackageManager.Core.SemanticVersionExpression).FromString(tVersion,.tVersionExpr))
			Set pExpression = pExpression.And(tVersionExpr)
			Set pSourceList = pSourceList_$ListBuild($ListToString(tResult.%Get("Names"),", ")_": "_tVersion)
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
/// @API.Method
/// @Modifier Availability InterSystems
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
				Set tOneSC = ##class(%ZPM.PackageManager.Developer.Module).Uninstall(tModuleName,pForce,,.tParams)
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

Query GetModuleList(pServer As %String) As %Query(ROWSPEC = "Name:%String,Version:%String,Repository:%String,Description:%String") [ SqlProc ]
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
				Set qHandle($i(qHandle)) = $ListBuild(tMod.Name,tMod.Version.ToString(),tMod.Repository,tMod.Description)
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

ClassMethod LoadNewModule(pDirectory As %String, ByRef pParams, pRepository As %String = "") As %Status
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
		Set tLogManager = ##class(%ZPM.PackageManager.Core.LogManager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		// Show INFO+ if verbose, WARNING+ if not.
		Set tMinLogLevel = $Select(tVerbose:1,1:2)
		If (tLogManager.Threshold > tMinLogLevel) {
			Set tLogManager.Threshold = tMinLogLevel
		}
		
		Set pDirectory = ##class(%File).NormalizeDirectory("",pDirectory)
		
		If ($Get(pParams("NoJournal"),0) '= 0) {
			// Disable journalling with process-level switch.
			Set tJournalMgr = ##class(%ZPM.PackageManager.Core.JournalManager).%New(0)
		} ElseIf tUseTransactions {
			TSTART
		}
		Set tSC = $system.OBJ.Load(pDirectory_"module.xml",$Select(tVerbose:"d",1:"-d"),,.tLoadedList)
		$$$ThrowOnError(tSC)
		
		Set tFirstLoaded = $$$lcase($Order(tLoadedList("")))
    
		If (tFirstLoaded = "") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No module definition found."))
		}
		If ($Order(tLoadedList(tFirstLoaded)) '= "") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"module.xml contains multiple documents."))
		}
		If ($Piece(tFirstLoaded,".",*) '= "zpm") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No module definition found."))
		}
		
		Set tModuleName = $Piece(tFirstLoaded,".",1,*-1)
		
		If (pRepository '= "") {
			// Force developer mode to be 0 if repository is read only.
			If ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyExists(pRepository, .tRepositoryId) {
				If +##class(%ZPM.PackageManager.Client.ServerDefinition).ReadOnlyGetStored(tRepositoryId) {
					// Set in pParams directly so that this value gets transmitted downstream
					Set pParams("DeveloperMode") = 0
					If tVerbose {
						Write !, "Repository "_pRepository_" is Read-Only so "_tModuleName_" will be loaded in non-developer mode"
					}
				}
			}
		}
		
		// If we have specified developer mode, but do not have a source control extension enabled, then set up a reasonable default.
		If $Get(pParams("DeveloperMode"),0) {
			Set tCurrentSourceControl = ##class(%Studio.SourceControl.Interface).SourceControlClassGet()
			If (tCurrentSourceControl = "") {
				Set tCompositeSCClass = "%ZPM.PackageManager.Developer.Extension.Composite"
				$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tCompositeSCClass))
				Set tPrimaryExtension = "%ZPM.PackageManager.Developer.Extension.SourceControl.ISC"
				Set tSecondaryExtensions = $ListBuild("%ZPM.PackageManager.Developer.Extension.PackageManager")
				$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Extension.Composite).SetExtensionClasses(tPrimaryExtension,tSecondaryExtensions))
			}
		}
		
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModuleName,,.tSC)
		$$$ThrowOnError(tSC)
		Set tModule.Repository = pRepository
		
		If $Data(pParams("DeveloperMode"),tDeveloperMode) {
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
			// $$$ZPMHandledModules is also used in the ExecutePhases method of %ZPM.PackageManager.Developer.Module to
			// cover cases where new dependencies are added and a module is compiled without reloading, and in the BuildDependencyGraph
			// method to treat installed snapshot versions as installed rather than forcing reload if they have been reloaded
			// as part of the same root module operation.
			New $$$ZPMHandledModules
			Set $$$ZPMHandledModules($Namespace) = "" //Initialize.
		}
		Merge $$$ZPMHandledModules($Namespace) = pParams("Multicompile","ModuleContext")

    $$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Module).CheckSystemRequirements(tModuleName))
		
		#dim tInstallContext As %ZPM.PackageManager.Core.InstallContext
		Set tInstallContext = ##class(%ZPM.PackageManager.Core.InstallContext).%Get(.tSC)
		$$$ThrowOnError(tSC)
		If 'tInstallContext.ModuleIsDependency(tModuleName) {
			Set tSC = tModule.LoadDependencies("",.pParams)
			$$$ThrowOnError(tSC)
		}
		
		Set tPath = pDirectory_"preload"
		If ##class(%File).DirectoryExists(tPath) {
			New $Namespace
			Set tInitNamespace = $Namespace
			// Ensure we load "preload" resources into the correct code database (the namespace default one), since this is before mappings are set up.
			Set $Namespace = "^^"_##class(%ZPM.PackageManager.Developer.Utils).GetRoutineDatabaseDir($Namespace)
			Set tSC = $system.OBJ.LoadDir(tPath,,$Select(tVerbose:"d",1:"-d")_"/compile"_$Select($TLevel:"/multicompile=0",1:""),,1)
			$$$ThrowOnError(tSC)
			Set $Namespace = tInitNamespace
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
			Write !,"Loading "_tModuleName_" in process "_$Job
		}
		Set tSC = ##class(%ZPM.PackageManager.Developer.Module).ExecutePhases(tModuleName,$lb("Activate"),1,.pParams)
		If $$$ISOK(tSC) && 'tDeveloperMode && tUseTransactions {
			TCOMMIT
		}
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

ClassMethod CheckLicenseKey() As %Boolean
{
	// Limit the number of attempts in case this somehow ends up running in a non-interactive process.
	#define MaxTries 5
	Set tValidLicense = ($System.License.GetKeyStatus() '= "Invalid")
	While ('tValidLicense) && $$$InProgrammerMode && ('$$$IsISCWorker) && ($Increment(tTries) <= $$$MaxTries) {
		Write !!,"Your system has no (valid) license key present"
		Write !,"Copy a valid license key into "_$System.Util.InstallDirectory()_"mgr"
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
		New $namespace
		Set $namespace = "%SYS"
		If '##class(Config.MapPackages).Exists(pNamespace,pMapping) {
			Set tProps("Database") = pFrom
			$$$ThrowOnError(##class(Config.MapPackages).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
			If 'pSkipActivation {
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
		New $namespace
		Set $namespace = "%SYS"
		If ##class(Config.MapPackages).Exists(pNamespace,pMapping) {
			$$$ThrowOnError(##class(Config.MapPackages).Delete(pNamespace,pMapping,,$$$CPFSave))
			If 'pSkipActivation {
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
		New $namespace
		Set $namespace = "%SYS"
		Set pMapping = pMapping_$S(pType="ALL":"",1:"_"_pType)
		If '##class(Config.MapRoutines).Exists(pNamespace,pMapping) {
			Set tProps("Database") = pFrom
			$$$ThrowOnError(##class(Config.MapRoutines).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
			If 'pSkipActivation {
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
		New $namespace
		Set $namespace = "%SYS"
		Set pMapping = pMapping_$S(pType="ALL":"",1:"_"_pType)
		If ##class(Config.MapRoutines).Exists(pNamespace,pMapping) {
			$$$ThrowOnError(##class(Config.MapRoutines).Delete(pNamespace,pMapping,,$$$CPFSave))
			If 'pSkipActivation {
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
    New $namespace
	 	Set $namespace = "%SYS"
		If (pMapping [ ":(") {
			// 2008 has glo:(subs), 2009 has glo(subs)
			Set pMapping=$Piece(pMapping,":(")_"("_$Piece(pMapping,":(",2,*)
		}
		
		If '##Class(Config.MapGlobals).Exists(pNamespace,pMapping) {
			Set tProps("Database") = pFrom
			If pSetCollation {
				Set tDB=##class(SYS.Database).%OpenId($ZU(12)_pFrom)
				If $IsObject(tDB) {
					Set tProps("Collation") = tDB.NewGlobalCollation
				}
			}
			$$$ThrowOnError(##class(Config.MapGlobals).Create(pNamespace,pMapping,.tProps,,$$$CPFSave))
			If pSkipActivation {
				Set pChanged = 1
			} Else {
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
		Set tInterruptManager = ##class(%ZPM.PackageManager.Core.InterruptManager).%New()
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

/// Helper method to see if <var>pNamespace</var> has <var>pModule</var> (a module name) installed.
/// Returns false if the module is not installed (which may be because the namespace does not exist).
ClassMethod NamespaceHasModule(pNamespace As %String, pModuleName As %String) As %Boolean
{
	Set tModuleExists = 0
	New $Namespace
	Try {
		Set $Namespace = pNamespace // This might fail.
		Set tModuleExists = ##class(%ZPM.PackageManager.Developer.Module).NameExists(pModuleName)
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
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(pModuleName,,.tSC)
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
				Set tNewDependency = ##class(%ZPM.PackageManager.Core.ModuleReference).%New()
				Set tNewDependency.Name = tModuleName
				// Copy the actual version string (a semantic version) into the module manifest dependency's version string (a semantic version expression)
				// A semantic version is also a valid semantic version expression, but not vice versa.
				Set tNewDependency.VersionString = tVersion
				$$$ThrowOnError(tModule.Dependencies.Insert(tNewDependency))
			}
		}
		
		$$$ThrowOnError(tModule.%Save())
		
		// Use the API to update the module manifest on disk from the updated persistent object
		Set tStatus = ##class(%ZPM.PackageManager.Developer.API).ExportDocumentForObject(tModule,.tSourceControlOutput)
		
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
ClassMethod RunCommandViaZF(pCmd As %String, Output pLogOutput, Output pErrOutput, pTimeout As %Integer = 10, Output pRetCode As %String) As %Status
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

}
