Class %ZPM.PackageManager.Client.P4Workspace Extends %ZPM.PackageManager.Client.FilesystemServerDefinition
{

Parameter DISPLAYNAME As STRING = "Perforce";

Parameter MONIKER As STRING = "p4";

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {Set {*} = {Root}_".../module.xml"_{FileSpec}}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

/// The last changelist included when building the repository cache.
Property LastChangelistCached As %Integer;

/// File spec to use while syncing files in the repository.
Property FileSpec As %String [ InitialExpression = "#head" ];

/// Shelved changelists to unshelve before building the repository cache.
Property Shelves As %Library.List;

/// Prompt to use for Root in interactive configuration of this repository type
Parameter RootPromptString = {$$$Text("Perforce Branch:","ZPM")};

/// This is actually an instance of <class>%ZPM.PackageManager.Client.P4Workspace.PackageService</class>, but must be
/// declared as %Library.RawString to support i% syntax in its accessor.
Property PackageService As %Library.RawString [ Private, Transient ];

/// Client specification for the current workspace - cached to allow workspace to be used while Perforce is unavailable
Property ClientSpec As %ZPM.PackageManager.Client.P4Workspace.ClientSpec;

/// Recursive - if set to true, will also find modules underneath other modules. The default is false.
Property Recurse As %Boolean [ InitialExpression = 0 ];

Method RootSet(%val) As %Status
{
	If (..Root '= %val) {
		Set ..LastChangelistCached = ""
		If $IsObject(..PackageService) && (..Root '= "") {
			Set ..PackageService = ##class(%ZPM.PackageManager.Client.P4Workspace.PackageService).CreateForWorkspace($This)
		}
	}
	Set i%Root = %val
	Quit $$$OK
}

Method FileSpecSet(%val) As %Status
{
	If (..FileSpec '= %val) {
		Set ..LastChangelistCached = ""
		If $IsObject(..PackageService) && (..Root '= "") {
			Set ..PackageService = ##class(%ZPM.PackageManager.Client.P4Workspace.PackageService).CreateForWorkspace($This)
		}
	}
	Set i%FileSpec = %val
	Quit $$$OK
}

Method PackageServiceGet() As %ZPM.PackageManager.Client.P4Workspace.PackageService
{
	Quit ..GetPackageService()
}

Trigger SpecChanged [ Event = UPDATE, Foreach = row/object ]
{
	If ({Root*C} || {FileSpec*C}) {
		Set {LastChangelistCached} = ""
	}
}

/// Returns a service instance used to retrieve modules from this repository
Method GetPackageService(pPurge As %Boolean = 0, pVerbose As %Boolean = 0) As %ZPM.PackageManager.Core.IPackageService
{
	If '$IsObject(i%PackageService) {
		Set i%PackageService = ##class(%ZPM.PackageManager.Client.P4Workspace.PackageService).CreateForWorkspace($This)
		If '$$$IsISCWorker && $IsObject(i%PackageService) && i%PackageService.IsAvailable() {
			$$$ThrowOnError(..BuildCache(pPurge,pVerbose))
		}
	}
	Quit i%PackageService
}

/// Returns a service instance used to publish modules to this repository
Method GetPublishService() As %ZPM.PackageManager.Core.IPublishService
{
	Quit ##class(%ZPM.PackageManager.Client.P4Workspace.PublishService).%New($This)
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %ZPM.PackageManager.Client.P4Workspace, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
{
	Set tSC = $$$OK
	Try {
		// Set FileSpec property before building the cache (which ##super() does)
		If $Data(pModifiers("spec"),tFileSpec) {
			Set pInstance.FileSpec = tFileSpec
		}
		If $Data(pModifiers("force-update")) {
			Set pInstance.LastChangelistCached = ""
		}
		If $Data(pModifiers("recurse"),tRecurse) {
			Set pInstance.Recursive = $Get(tRecurse,1)
		}
		If $Data(pModifiers("shelves"),tShelves) {
			Set pInstance.Shelves = $ListFromString(tShelves, ",")
		}
		
		$$$ThrowOnError(##super(pInstance,pInteractive,.pModifiers,.pData))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method BuildCache(pPurge As %Boolean = {'$$$IsISCWorker}, pVerbose As %Integer = 0, pAutoDetectDepth As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tLogManager = ##class(%ZPM.PackageManager.Core.LogManager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		// Instantiate at this level for the performance benefit
		Set tXSLTProvider = ##class(%ZPM.PackageManager.Core.XSLTProvider).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		If (..FileSpec = "") {
			Set ..FileSpec = "#head"
		}
		
		Set tPerforceAvailable = ..GetPackageService(pPurge,pVerbose).PerforceIsAvailable()
		If tPerforceAvailable {
			// Populate client spec and see if it's changed.
			Set tSC = ..ClientSpec.UpdateForCurrentWorkspace(.tModified)
			$$$ThrowOnError(tSC)
			If (tModified) {
				// If client workspace changed, our cache is invalid!
				Set ..LastChangelistCached = ""
			}
						
			// See what the latest change under our workspace root is.
			Set tSC = ##class(%Studio.SourceControl.ISC).RunCmd("p4 -ztag changes -m 1 -s submitted "_..Root_"...",.tLastChange,0)
			If $$$ISERR(tSC) {
				Quit
			}
			
			If $Data(tLastChange) {
				// format:
				/*
					... change 2699359
					... time 1492174605
					... user tleavitt
					... client tleavitt_TLEAVITT6430_HSDEMO
					... status submitted
					... changeType public
					... path //healthshare/...
					... oldChange 2699318
					... desc HSAI-107: Moving include files
				*/
				Set tLastChange = $Piece(tLastChange(1)," ",3)
				
				If (..LastChangelistCached '= "") && (tLastChange = ..LastChangelistCached) {
					// If there haven't been any changes since we last checked, don't bother purging + updating the cache.
					Quit
				}
			} Else {
				Set tLastChange = ""
			}
			Set ..LastChangelistCached = tLastChange
		}
		
		TSTART
		If (pPurge) && (..%Id() '= "") {
			Set tLockManager = ##class(%ZPM.PackageManager.Core.LockManager).%New()
			$$$ThrowOnError(tLockManager.LockClassId($classname(),..%Id()))
			#dim tResult As %SQL.StatementResult
			Set tResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %ZPM_PackageManager_Client_Filesystem.Cache where Root = ?",..Root)
			If (tResult.%SQLCODE < 0) {
				Set tSC = $$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message)
				Quit
			}
		}
		
		// Force save so that root foreign key for items will exist.
		Set ..Depth = 0 // Depth doesn't matter - p4 files is fast!
		Set tSC = ..%Save()
		If $$$ISERR(tSC) {
			Quit
		}
		
		If tPerforceAvailable {
			Do ..UnshelveChanges(pVerbose)
			Set tSC = ..ScanPerforceBranch(..Root,..FileSpec,.tFilenameList)
			$$$ThrowOnError(tSC)
		} Else {
			If pVerbose {
				Write !,"WARNING: Perforce is unavailable; using local workspace instead."
			}
			
			// Fall back to filesystem-based approach
			Set tSC = ..ClientSpec.GetLocalPathForDepot(..Root,.tLocalRoot)
			$$$ThrowOnError(tSC)
			Set tSC = ..ScanDirectory(tLocalRoot,.tFilesystemList,,,pVerbose)
			$$$ThrowOnError(tSC)
			
			// Convert filesystem search results to format expected below (from ScanPerforceBranch)
			For tFileIndex=1:1:$Get(tFilesystemList) {
				Set tFile = tFilesystemList(tFileIndex)
				$$$ThrowOnError(..ClientSpec.GetDepotPathForLocal(tFile,.tDepotPath))
				Set tFilenameList(tDepotPath) = $ListBuild(1 /*Use local file instead of p4 print*/, tFile)
			}
		}
		
		// In non-recursive mode, eliminate nested modules
		If '..Recurse {
			Set tFilename = ""
			For {
				Set tFilename = $Order(tFilenameList(tFilename))
				Quit:(tFilename="")
				
				Set tEliminated = 1
				While tEliminated {
					Set tEliminated = 0
					Set tBranch = $Piece(tFilename,"/",1,*-1)_"/"
					Set tPrevious = $Order(tFilenameList(tFilename),-1)
					Set tNext = $Order(tFilenameList(tFilename))
					If (tPrevious '= "") && ($Extract(tPrevious,1,$Length(tBranch)) = tBranch) {
						Kill tFilenameList(tPrevious)
						Set tEliminated = 1
					}
					If (tNext '= "") && ($Extract(tNext,1,$Length(tBranch)) = tBranch) {
						Kill tFilenameList(tNext)
						Set tEliminated = 1
					}
				}
			}
		}
		
		// Clean up any temp files created
		Set tTempFileManager = ##class(%ZPM.PackageManager.Core.TempFileManager).%Get(.tSC)
		
		// Clear out events on the current PID (in case an earlier run was interrupted)
		While $ListGet($System.Event.WaitMsg("",0)) {}
		
		// Ensure that we're looking at valid MODULE documents (as opposed to classes named Module, which the package manager has!)
		Set tAggSC = $$$OK
		Set tFilename = ""
		Set tJobCounter = 0
		// Keep any temp streams created in scope to use later
		#dim tStreamOIDToObjectArray As %Stream.FileCharacter
		For {
			Set tFilename = $Order(tFilenameList(tFilename),1,tFileData)
			Quit:(tFilename="")
			
			Set tUseLocal = $ListGet(tFileData)
			Set tLocalPath = $ListGet(tFileData,2)
			
			If tUseLocal {
				Set tManifestFile = tLocalPath
				Set tSubDirectory = $Piece($Piece(tFilename,..Root,2,*),"module.xml",1,*-1)
				Set tAggSC = $$$ADDSC(tAggSC,..AddCacheItem(tManifestFile,tSubDirectory,.tName,.tVersionString))
				Write:pVerbose !,tName," ",tVersionString," @ ",..Root_tSubDirectory
			} Else {
				Set tManifestFile = tTempFileManager.GetTempFileName("xml")
				Set tManifestFileStream = ##class(%Stream.FileCharacter).%New()
				$$$ThrowOnError(tManifestFileStream.LinkToFile(tManifestFile))
				$$$ThrowOnError(tManifestFileStream.%Save())
				Set tStreamOID = tManifestFileStream."%%OID"
				Set tStreamOIDToObjectArray(tStreamOID) = tManifestFileStream
				Job ..DoPrint(tStreamOID, tFilename_..FileSpec)
				Set tManifestArray(tFilename) = tManifestFile
				Set tJobCounter = tJobCounter + 1
			}
		}
		
		// Wait for jobbed p4 prints to finish
		For tCount=1:1:tJobCounter {
			Set tResult = $System.Event.WaitMsg("",5)
			// TODO: Decide what to do with this status or have a comment stating why we aren't doing anything with it
			Set tFlag = $ListGet(tResult)
			Set tMessage = $ListGet(tResult,2)
			Set $ListBuild(tFilename,tManifestFileStreamOID,tSC) = tMessage
			$$$ThrowOnError(tSC)
			Set tSubDirectory = $Piece($Piece(tFilename,..Root,2,*),"module.xml",1,*-1)
			Set tManifestFile = tStreamOIDToObjectArray(tManifestFileStreamOID).Filename
			Set tAggSC = $$$ADDSC(tAggSC,..AddCacheItem(tManifestFile,tSubDirectory,.tName,.tVersionString))
			Write:pVerbose !,tName," ",tVersionString," @ ",..Root_tSubDirectory," [not synced]"
		}
		$$$ThrowOnError(tAggSC)
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

/// Print the contents of <var>pDepotFileNameWithRevision</var> into the file linked to
/// the OID of the stream <var>pManifestFileStreamOID</var>. <br />
/// Signals the parent process with the depot file location (without revision specifier)
/// and the OID of the file stream to which the module manifest contents have been written. <br />
/// @Argument	pManifestFileStreamOID		OID of the file stream to use to write the module manifest to. <br />
/// @Argument	pDepotFileNameWithRevision	Perforce depot location of the module file (appended with a revision specifier). <br />
ClassMethod DoPrint(pManifestFileStreamOID As %String, pDepotFileNameWithRevision As %String) [ Internal ]
{
	Set tManifestFileStream = ##class(%Stream.FileCharacter).%Open(pManifestFileStreamOID, , .tOpenSC)
	Set tManifestFile = tManifestFileStream.Filename
	Set tPrintSC = ##class(%Studio.SourceControl.ISC).RunCmd("p4 print -o "_tManifestFile_" -q "_pDepotFileNameWithRevision, , 0)
	// Remove revision specifier
	Set tDepotFileName = $Piece(pDepotFileNameWithRevision, "#", 1)
	Set tMessageToParent = $ListBuild(tDepotFileName, pManifestFileStreamOID, $$$ADDSC(tOpenSC, tPrintSC))
	Do $System.Event.Signal($ZParent, tMessageToParent)
}

/// Unshelve the changes in the <property>Shelves</property> property and resolve. <br />
/// @Argument	pVerbose		Optionally do verbose logging. <br />
Method UnshelveChanges(pVerbose As %Boolean = 0)
{
	If ($ListLength(..Shelves) = 0) {
		Return
	}
	Set description = "Unshelving changes in the following changelists: "_$ListToString(..Shelves)
	Set sc = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC).CreateChangelist(description, .changelist)
	$$$ThrowOnError(sc)
	// Determine whether the regex %str matches the error string in status %sc
	#define DoesErrorMatch(%sc, %str) $Match($ZStrip($System.Status.GetErrorText(%sc), "<>CW"), "(?i).*"_%str_".*")
	// Revert any changes that could be present in this changelist
	// Deliberately ignore errors because it could error if there were no changes to revert
	Do ##class(%Studio.SourceControl.ISC).RunCmd("p4 revert -c "_changelist, , pVerbose)
	Set ptr = 0
	While $ListNext(..Shelves, ptr, shelve) {
		// Ensure only files in this repositary are unshelved
		Set sc = ##class(%Studio.SourceControl.ISC).RunCmd("p4 unshelve -s "_shelve_" -f -c "_changelist_" "_..Root_"...", .unshelveInfo, pVerbose)
		// Ignore certain errors
		If $$$ISERR(sc) {
			If '$$$DoesErrorMatch(sc, "No such file\(s\)") && '$$$DoesErrorMatch(sc, "Can't clobber writable file") && '$$$DoesErrorMatch(sc, "File\(s\) not in client view") {
				$$$ThrowStatus(sc)
			}
			Continue
		}
		If pVerbose {
			For i = 1:1:$Get(unshelveInfo) {
				Write !, $Get(unshelveInfo(i))
			}
			Write !
		}
		// Resolve files after each unshelved change
		Set sc = ##class(%Studio.SourceControl.ISC).RunCmd("p4 resolve -am -c "_changelist, .resolveInfo, pVerbose)
		If $$$ISERR(sc) {
			If '$$$DoesErrorMatch(sc, "No file\(s\) to resolve") {
				$$$ThrowStatus(sc)
			}
			Continue
		}
		If pVerbose {
			For i = 1:1:$Get(resolveInfo) {
				Write !, $Get(resolveInfo(i))
			}
			Write !
		}
	}
}

/// Output format:
/// pFilenameList(<depot path>) = $listbuild(<use local file?>,<local file path>)
ClassMethod ScanPerforceBranch(pRootBranch As %String, pFileSpec As %String, ByRef pFilenameList, pVerbose As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		// Look for module.xml immediately under pRoot, and then
		// recursively in subdirectories.
		For tPostfix = "",".../" {
			Kill tP4Output
			Set tP4Cmd = "fstat " 
			// For #head and #have, don't include the file spec (to include workspace files marked for add/etc.)
			If (pFileSpec = "#have") {
				Set tP4Cmd = tP4Cmd _ "-Rh "
			}
			Set tP4Cmd = tP4Cmd _ pRootBranch _ tPostfix _ "module.xml"
			If ($Extract(pFileSpec) '= "#") {
				Set tP4Cmd = tP4Cmd _ pFileSpec
			}
			Set tSC = ##class(%Studio.SourceControl.ISC).P4Cmd(tP4Cmd,.tP4Output)
			If $$$ISERR(tSC) {
				// If there was nothing immediately under the root (or deeper), it's not actually an error.
				Set tErrorText = $System.Status.GetErrorText(tSC)
				If (tErrorText [ "no such file(s)") || (tErrorText [ "file(s) not on client") || (tErrorText [ "file(s) not opened on this client") {
					Set tSC = $$$OK
					Continue
				}
				Quit
			}
			
			For tResultIndex=1:1:$Get(tP4Output) {
				Kill tFileData
				Merge tFileData = tP4Output(tResultIndex)
				If ($Get(tFileData("headAction")) '[ "delete") {
					Set tPendingAction = $Get(tFileData("action"))
					Set tExists = ($Data(tFileData("clientFile"))#2) && ##class(%Library.File).Exists(tFileData("clientFile"))
					Set tHaveLatest = ($Get(tFileData("haveRev")) = $Get(tFileData("headRev")))
					
					// If the file exists, and either has a pending non-delete action or is present at the latest revision, use the local file instead of issuing p4 print.
					Set tHasPendingAddEdit = (tPendingAction '= "") && (tPendingAction '[ "delete")
					Set tLocal = tExists && (tHasPendingAddEdit || tHaveLatest)
					Set pFilenameList(tFileData("depotFile")) = $lb(tLocal,tFileData("clientFile"))
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// This callback method is invoked by the <METHOD>%ConstructClone</METHOD> method to 
/// provide notification that a clone of an object is being created. It passes in the
/// oref of the object that was cloned in <var>object</var>.
/// 
/// <P>If this method returns an error then the object will not be created.
Method %OnConstructClone(object As %ZPM.PackageManager.Client.P4Workspace, deep As %Boolean = 0, ByRef cloned As %String) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..LastChangelistCached = ""
	Quit $$$OK
}

Storage Default
{
<Data name="P4WorkspaceDefaultData">
<Subscript>"P4Workspace"</Subscript>
<Value name="1">
<Value>LastChangelistCached</Value>
</Value>
<Value name="2">
<Value>FileSpec</Value>
</Value>
<Value name="3">
<Value>ClientSpec</Value>
</Value>
<Value name="4">
<Value>Recurse</Value>
</Value>
<Value name="5">
<Value>Shelves</Value>
</Value>
</Data>
<DefaultData>P4WorkspaceDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
