Include %occErrors

Class %ZPM.PackageManager.Client.Utils
{

/// Returns a list of all resolved module references matching the search criteria from configured repositories.
ClassMethod SearchRepositoriesForModule(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria, Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.QualifiedModuleReference"), pForceRemoteRepo As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResults = $$$NULLOREF
	Try {
		Set tManager = ##class(%ZPM.PackageManager.Client.Manager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		Set tSC = tManager.SearchRepositoriesForModule(pSearchCriteria,.pResults)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Loads the module reference 
ClassMethod RetrieveModuleManifest(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pManifestStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pManifestStream = $$$NULLOREF
	Try {
		Set tManager = ##class(%ZPM.PackageManager.Client.Manager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		Set tSC = tManager.RetrieveModuleManifest(pQualifiedReference,.pManifestStream)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Loads the module reference 
ClassMethod RetrieveModulePackage(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pPackageStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pPackageStream = $$$NULLOREF
	Try {
		Set tManager = ##class(%ZPM.PackageManager.Client.Manager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		Set tSC = tManager.RetrieveModulePackage(pQualifiedReference,.pPackageStream)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a list of all resolved module references matching the search criteria from configured repositories.
ClassMethod SearchRepositoriesForApplication(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria, Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.QualifiedModuleReference"), pForceRemoteRepo As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResults = $$$NULLOREF
	Try {
		Set tManager = ##class(%ZPM.PackageManager.Client.Manager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		Set tSC = tManager.SearchRepositoriesForApplication(pSearchCriteria,.pResults)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Loads the module reference 
ClassMethod RetrieveApplicationManifest(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pManifestStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pManifestStream = $$$NULLOREF
	Try {
		Set tManager = ##class(%ZPM.PackageManager.Client.Manager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		Set tSC = tManager.RetrieveApplicationManifest(pQualifiedReference,.pManifestStream)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Loads the application package 
ClassMethod RetrieveApplicationPackage(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pPackageStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pPackageStream = $$$NULLOREF
	Try {
		Set tManager = ##class(%ZPM.PackageManager.Client.Manager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		Set tSC = tManager.RetrieveApplicationPackage(pQualifiedReference,.pPackageStream)
	} Catch e {
		Set tSC = e.AsStatus()
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
	#dim tModule As %ZPM.PackageManager.Developer.Module
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
		
		// Validate manifest against module reference
		Set tSC = ##class(%ZPM.PackageManager.Developer.Module).ValidateStream(tManifestStream,pInstallInfo.ModuleReference,.tModule)
		If $$$ISERR(tSC) {
			Quit
		}
		
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
		Set tSC = ##class(%ZPM.General.Archive).Extract(tTmpFileName,tExtractDir,.tOutput)
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
			Set tOneDBSC = ##class(%ZPM.PackageManager.Developer.Build).CreateDatabase(tName,tSourceFile,tOverwrite,.tCreated)
			Set tSC = $System.Status.AppendStatus(tSC,tOneDBSC)
			If $$$ISERR(tOneDBSC) {
				Write !,"Error creating database ",tName,": ",$System.Status.GetErrorText(tOneDBSC)
			} ElseIf (tCreated) {
				Write !,"Database ",tName," created."
			} ElseIf (tOverwrite) {
				Write !,"Database ",tName," overwritten."
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Create new namespace.
		// TODO: Mappings for LOCAL database?
		Set tSC = ##class(%ZPM.PackageManager.Developer.Build).CreateNamespace(pInstallInfo.Namespace,pInstallInfo.Namespace_"-CODE",pInstallInfo.Namespace_"-DATA",,tModule.GetNamespaceConfig())
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
		Set tLogSC = tModule.Lifecycle.Unconfigure(.tParams)
		
		// Clean up at the Database level.
		Set $Namespace = "%SYS" //Protection from <NAMESPACE>/etc.
		
		// TODO: Make the following steps optional? (Particularly, the deletion of user data / local code?)
		Set tCodeDBName = pInstallInfo.Namespace_"-CODE"
		Set tDataDBName = pInstallInfo.Namespace_"-DATA"
		Set tLocalDBName = pInstallInfo.Namespace_"-LOCAL"
		
		// These can fail safely.
		Set tLogSC = $$$ADDSC(tLogSC,##class(%Library.EnsembleMgr).DisableNamespace(pInstallInfo.Namespace))
		Set tLogSC = $$$ADDSC(tLogSC,##class(%ZPM.PackageManager.Developer.Build).DeleteNamespace(pInstallInfo.Namespace))
		Set tLogSC = $$$ADDSC(tLogSC,##class(%ZPM.PackageManager.Developer.Build).DeleteDatabase(tCodeDBName))
		Set tLogSC = $$$ADDSC(tLogSC,##class(%ZPM.PackageManager.Developer.Build).DeleteDatabase(tDataDBName))
		Set tLogSC = $$$ADDSC(tLogSC,##class(%ZPM.PackageManager.Developer.Build).DeleteDatabase(tLocalDBName))
		If $$$ISERR(tLogSC) {
			Write !,"Error(s) uninstalling application from namespace ",pInstallInfo.Namespace,": ",$System.Status.GetErrorText(tLogSC)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If ##class(%SYS.Namespace).Exists(tInitNS) {
		Set $Namespace = tInitNS
	}
	Quit tSC
}

ClassMethod GetZPMVersion()
{
    New $Namespace
    Set $Namespace = "%SYS"
    Set module = ##class(%ZPM.PackageManager.Developer.Module).NameOpen("zpm")
    If ($IsObject(module)) {
        Return module.VersionString
    }
    Return ""
}

}
