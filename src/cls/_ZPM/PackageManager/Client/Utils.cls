Include %occErrors

Class %ZPM.PackageManager.Client.Utils
{

/// Returns a list of all resolved module references matching the search criteria from configured repositories.
ClassMethod SearchRepositoriesForModule(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria, Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.QualifiedModuleReference"), pForceRemoteRepo As %Boolean = 0) As %Status [ PublicList = registry ]
{
	Set tSC = $$$OK
	Set pResults = ##class(%Library.ListOfObjects).%New()
	Try {
		set registry = pSearchCriteria.Registry
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select ID from %ZPM_PackageManager_Client.ServerDefinition where Enabled = 1 and (:registry is null or Name = :registry) order by %ZPM_PackageManager_Client.ServerDefinition_SortOrder(ID)")
		If (tRes.%SQLCODE < 0) {
			Set tSC = $$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message)
			Quit
		}
		While (tRes.%Next(.tSC)) {
			If $$$ISERR(tSC) {
				Quit
			}
			
			Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).%OpenId(tRes.%Get("ID"),,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
			
			If pForceRemoteRepo && tServer.%IsA("%ZPM.PackageManager.Client.LocalServerDefinition") {
				Continue
			}
			
			// Only remote repositories support keywords, for now.
			If (pSearchCriteria.Keywords.Count() > 0) && tServer.%IsA("%ZPM.PackageManager.Client.FilesystemServerDefinition") {
				Continue
			}
			
			Set tClient = tServer.GetPackageService()
			If 'tClient.IsAvailable() {
				Continue
			}
			
			#dim tClientCriteria as %ZPM.PackageManager.Core.SearchCriteria
			Set tClientCriteria = pSearchCriteria.%ConstructClone(1)
			Set tClientCriteria.IncludePrerelease = tServer.Prereleases
			Set tClientCriteria.IncludeSnapshots = tServer.Snapshots
			Set tServerResults = tClient.ListModules(tClientCriteria)
			For i=1:1:tServerResults.Count() {
				Do pResults.Insert(##class(%ZPM.PackageManager.Core.QualifiedModuleReference).%New(tServer.Name,tServerResults.GetAt(i)))
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		If (e.Name["ZSOAP") && $Data(%objlasterror) {
			Set tSC = %objlasterror
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

/// Loads the module reference 
ClassMethod RetrieveModuleManifest(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pManifestStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pManifestStream = $$$NULLOREF
	Try {
		Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(pQualifiedReference.ServerName,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tClient = tServer.GetPackageService()
		If 'tClient.IsAvailable() {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",tServer.Name))
			Quit
		}
		
		Set pManifestStream = tClient.GetModuleManifest(pQualifiedReference)
	} Catch e {
		If (e.Name["ZSOAP") && $Data(%objlasterror) {
			Set tSC = %objlasterror
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

/// Loads the module reference 
ClassMethod RetrieveModulePackage(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pPackageStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pPackageStream = $$$NULLOREF
	Try {
		Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(pQualifiedReference.ServerName,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tClient = tServer.GetPackageService()
		If 'tClient.IsAvailable() {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",tServer.Name))
			Quit
		}
		
		Set pPackageStream = tClient.GetModule(pQualifiedReference)
	} Catch e {
		If (e.Name["ZSOAP") && $Data(%objlasterror) {
			Set tSC = %objlasterror
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

/// Returns a list of all resolved module references matching the search criteria from configured repositories.
ClassMethod SearchRepositoriesForApplication(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria, Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.QualifiedModuleReference"), pForceRemoteRepo As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResults = ##class(%Library.ListOfObjects).%New()
	Try {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select ID from %ZPM_PackageManager_Client.ServerDefinition where Enabled = 1 order by %ZPM_PackageManager_Client.ServerDefinition_SortOrder(ID)")
		If (tRes.%SQLCODE < 0) {
			Set tSC = $$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message)
			Quit
		}
		While (tRes.%Next(.tSC)) {
			If $$$ISERR(tSC) {
				Quit
			}
			
			Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).%OpenId(tRes.%Get("ID"),,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
			
			If pForceRemoteRepo && tServer.%IsA("%ZPM.PackageManager.Client.LocalServerDefinition") {
				Continue
			}
			
			Set tClient = tServer.GetPackageService()
			If 'tClient.Supports("ListApplications") {
				Continue
			}
			If 'tClient.IsAvailable() {
				Continue
			}
			
			#dim tClientCriteria as %ZPM.PackageManager.Core.SearchCriteria
			Set tClientCriteria = pSearchCriteria.%ConstructClone()
			Set tClientCriteria.IncludePrerelease = tServer.Prereleases
			Set tClientCriteria.IncludeSnapshots = tServer.Snapshots
			Set tServerResults = tClient.ListApplications(tClientCriteria)
			For i=1:1:tServerResults.Count() {
				Do pResults.Insert(##class(%ZPM.PackageManager.Core.QualifiedModuleReference).%New(tServer.Name,tServerResults.GetAt(i)))
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		If (e.Name["ZSOAP") && $Data(%objlasterror) {
			Set tSC = %objlasterror
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

/// Loads the module reference 
ClassMethod RetrieveApplicationManifest(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pManifestStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pManifestStream = $$$NULLOREF
	Try {
		Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(pQualifiedReference.ServerName,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tClient = tServer.GetPackageService()
		If 'tClient.IsAvailable() {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",tServer.Name))
			Quit
		}
		
		Set pManifestStream = tClient.GetApplicationManifest(pQualifiedReference)
	} Catch e {
		If (e.Name["ZSOAP") && $Data(%objlasterror) {
			Set tSC = %objlasterror
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

/// Loads the application package 
ClassMethod RetrieveApplicationPackage(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pPackageStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pPackageStream = $$$NULLOREF
	Try {
		Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(pQualifiedReference.ServerName,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tClient = tServer.GetPackageService()
		If 'tClient.IsAvailable() {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",tServer.Name))
			Quit
		}
		
		Set pPackageStream = tClient.GetApplication(pQualifiedReference)
	} Catch e {
		If (e.Name["ZSOAP") && $Data(%objlasterror) {
			Set tSC = %objlasterror
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

/// Creates a local cache entry in the ServerDefinition table if none exists
ClassMethod InitializeLocalCache(Output pCreated As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tLocalCache = ##class(%ZPM.PackageManager.Client.LocalServerDefinition).SingletonOpen(1,,.tSC)
		If $$$ISERR(tSC) && ($System.Status.GetErrorCodes(tSC) '= $$$KeyValueNotFoundOpen) {
			Quit
		}
		If $IsObject(tLocalCache) {
			Set pCreated = 1
			Quit
		}
		Set tLocalCache = ##class(%ZPM.PackageManager.Client.LocalServerDefinition).%New()
		Set tLocalCache.Name = "(Local Cache)"
		Set tLocalCache.Prereleases = 1
		Set tLocalCache.Snapshots = 1
		Set tSC = tLocalCache.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
		Set pCreated = 1
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Does a fresh or upgrade installation
ClassMethod InstallApplication(pInstallInfo As %ZPM.PackageManager.Core.InstallationInfo) As %Status
{
	New $Namespace
	Set tSC = $$$OK
	Try {
		// TODO: Verbose/silent flags?
		// TODO: Logging to a file?
		
		// Get module manifest.
		Set tSC = ..RetrieveApplicationManifest(pInstallInfo.ModuleReference,.tManifestStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// TODO: Validate module manifest?
		
		// Download application package.
		Set tSC = ..RetrieveApplicationPackage(pInstallInfo.ModuleReference,.tPackageStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Extract application package.
		Set tTmpFileName = ##class(%File).TempFilename(".tgz")
		Set tFile = ##class(%Stream.FileBinary).%New()
		Set tSC = tFile.LinkToFile(tTmpFileName)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = tFile.CopyFromAndSave(tPackageStream)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tExtractDir = ##class(%File).NormalizeDirectory($Piece(tTmpFileName,".tgz"))
		Set tSC = ##class(%ZPM.PackageManager.Developer.Archive).Extract(tTmpFileName,tExtractDir,.tOutput)
		For i=1:1:$Get(tOutput) {
			Write !,tOutput(i)
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// TODO: Validate extracted package?
		
		// Configure databases - for now, just CODE and LOCAL may be configured.
		// CODE is always overridden. LOCAL and DATA may be copied if present, or otherwise will be
		// created blank.
		Set tDBDir = ##class(%File).NormalizeDirectory(tExtractDir_"db")
		For tDBName = "CODE","DATA","LOCAL" {
			Set tSourceFile = ""
			If ##class(%File).Exists(tDBDir_tDBName_".DAT") {
				Set tSourceFile = tDBDir_tDBName_".DAT"
			}
			Set tOverwrite = (tDBName="CODE")
			Set tName = pInstallInfo.Namespace_"-"_tDBName
			Set tSC = ##class(%ZPM.PackageManager.Developer.Build).CreateDatabase(tName,tSourceFile,tOverwrite,.tCreated)
			If $$$ISERR(tSC) {
				Quit
			}
			If (tCreated) {
				Write !,"Database ",tName," created."
			} ElseIf (tOverwrite) {
				Write !,"Database ",tName," overwritten."
			}
		}
		
		// Create new namespace.
		// TODO: Mappings for LOCAL database?
		Set tSC = ##class(%ZPM.PackageManager.Developer.Build).CreateNamespace(pInstallInfo.Namespace,pInstallInfo.Namespace_"-CODE",pInstallInfo.Namespace_"-DATA")
		If $$$ISERR(tSC) {
			Quit
		}
		Set $Namespace = pInstallInfo.Namespace
		
		// Import module.xml in that namespace without running "Compile"
		Set tSC = $System.OBJ.Load(tExtractDir_"module.xml","k",,.tLoaded)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Run application "Configure" phase (should not compile/activate, or need to compile).
		Set tModName = $Piece(tLoaded,".ZPM")
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModName,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Configure module
		Kill tParams
		Set tParams("RootDirectory") = tExtractDir
		Set tParams("Configure","DatabaseName") = pInstallInfo.Namespace_"-CODE"
		// TODO: Populate tParams("Configure","Parameters") as module expects.
		Set tSC = tModule.Lifecycle.Configure(.tParams)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	
	// TODO: if tSC is an error, do any necessary cleanup depending on where failure occurred.
	
	Quit tSC
}

ClassMethod UninstallApplication(pInstallInfo As %ZPM.PackageManager.Core.InstallationInfo) As %Status
{
	// $Namespace intentionally not New'd
	Set tInitNS = $Namespace
	Set tSC = $$$OK
	Try {
		// Unconfigure application
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(pInstallInfo.ModuleReference.Name,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Kill tParams
		Set tParams("Configure","DatabaseName") = pInstallInfo.Namespace_"-CODE"
		Set tSC = tModule.Lifecycle.Unconfigure(.tParams)
		
		// Clean up at the Caché/Ensemble level.
		Set $Namespace = "%SYS" //Protection from <NAMESPACE>/etc.
		
		// TODO: Make the following steps optional? (Particularly, the deletion of user data / local code?)
		Set tCodeDBName = pInstallInfo.Namespace_"-CODE"
		Set tDataDBName = pInstallInfo.Namespace_"-DATA"
		Set tLocalDBName = pInstallInfo.Namespace_"-LOCAL"
		
		// These can fail safely.
		Do ##class(%Library.EnsembleMgr).DisableNamespace(pInstallInfo.Namespace)
		Do ##class(%ZPM.PackageManager.Developer.Build).DeleteNamespace(pInstallInfo.Namespace)
		Do ##class(%ZPM.PackageManager.Developer.Build).DeleteDatabase(tCodeDBName)
		Do ##class(%ZPM.PackageManager.Developer.Build).DeleteDatabase(tDataDBName)
		Do ##class(%ZPM.PackageManager.Developer.Build).DeleteDatabase(tLocalDBName)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If ##class(%SYS.Namespace).Exists(tInitNS) {
		Set $Namespace = tInitNS
	}
	Quit tSC
}

}
