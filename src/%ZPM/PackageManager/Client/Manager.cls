Class %ZPM.PackageManager.Client.Manager Extends %ZPM.PackageManager.Core.Singleton
{

/// If set to 1, calls to %Get must return an instance of this class created in the current namespace; a new instance will be created if none exists.
Parameter NAMESPACESCOPE As BOOLEAN = 1;

/// Avoids constantly reinstantiating the package service objects, which may be expensive.
Property ServiceCache As array Of %ZPM.PackageManager.Core.IPackageService;

/// Keeps track of which repositories are unavailable (by name - the keys are important, values don't matter)
Property UnavailableNames As array Of %String;

/// Performance optimization for XSLTs
Property XSLTProvider As %ZPM.PackageManager.Core.XSLTProvider;

Method CheckServiceCache(pRepositoryName As %String, Output pAvailable As %Boolean) As %ZPM.PackageManager.Core.IPackageService
{
	Set pAvailable = 0
	If ..UnavailableNames.IsDefined(pRepositoryName) {
		Quit $$$NULLOREF
	}
	
	Set tClient = ..ServiceCache.GetAt(pRepositoryName)
	If '$IsObject(tClient) {
		Set tRepository = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(pRepositoryName,,.tSC)
		$$$ThrowOnError(tSC)
		
		If tRepository.Enabled {
			// Don't cache Enabled status; no reason to prohibit it from changing.
			Set tClient = tRepository.GetPackageService()
			If $IsObject(tClient) {
				Set pAvailable = tClient.IsAvailable()
				If pAvailable {
					Do ..ServiceCache.SetAt(tClient,tRepository.Name)
				} Else {
					Do ..UnavailableNames.SetAt("",tRepository.Name)
				}
			}
		}
	} Else {
		// If the client is available in the cache for this object, it is assumed to be available.
		Set pAvailable = 1
	}
	Quit tClient
}

/// Returns a list of all resolved module references matching the search criteria from configured repositories.
Method SearchRepositoriesForModule(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria, Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.QualifiedModuleReference"), pForceRemoteRepo As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResults = ##class(%Library.ListOfObjects).%New()
	Try {
    Set registry = pSearchCriteria.Registry
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
			
			Set tClient = ..CheckServiceCache(tServer.Name,.tAvailable)
			If 'tAvailable {
				Continue
			}
			
			#dim tClientCriteria as %ZPM.PackageManager.Core.SearchCriteria
			Set tClientCriteria = pSearchCriteria.%ConstructClone(1)
			Set tPrereleases = pSearchCriteria.IncludePrerelease
			If (tPrereleases = "") {
				Set tPrereleases = tServer.Prereleases
			}
			Set tSnapshots = pSearchCriteria.IncludeSnapshots
			If (tSnapshots = "") {
				Set tSnapshots = tServer.Snapshots
			}
			Set tClientCriteria.IncludePrerelease = tPrereleases
			Set tClientCriteria.IncludeSnapshots = tSnapshots
			Set tServerResults = tClient.ListModules(tClientCriteria)
			For i=1:1:tServerResults.Count() {
        Set item = tServerResults.GetAt(i)
        #; Sorting versions
        Set versions(tServer.Name, +item.Version.Major, +item.Version.Minor, +item.Version.Patch, " "_item.Version.Patch_"_"_item.Version.Prerelease) = item
			}
		}
    Set name = ""
    For {
      Set name = $Order(versions(name))
      Quit:name=""
      Set major = ""
      For {
        Set major = $Order(versions(name, major), -1)
        Quit:major=""
        Set minor = ""
        For  {
          Set minor = $Order(versions(name, major, minor), -1)
          Quit:minor=""
          Set patch = ""
          For  {
            Set patch = $Order(versions(name, major, minor, patch), -1)
            Quit:patch=""
            Set sub = ""
            For  {
              Set sub = $Order(versions(name, major, minor, patch, sub), 1, item)
              Quit:sub=""
              Do pResults.Insert(##class(%ZPM.PackageManager.Core.QualifiedModuleReference).%New(name, item))
            }
          }
        }
      }
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
Method RetrieveModuleManifest(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pManifestStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pManifestStream = $$$NULLOREF
	Try {
		Set tClient = ..CheckServiceCache(pQualifiedReference.ServerName,.tAvailable)
		If 'tAvailable {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pQualifiedReference.ServerName))
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
Method RetrieveModulePackage(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pPackageStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pPackageStream = $$$NULLOREF
	Try {
		Set tClient = ..CheckServiceCache(pQualifiedReference.ServerName,.tAvailable)
		If 'tAvailable {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pQualifiedReference.ServerName))
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
Method SearchRepositoriesForApplication(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria, Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.QualifiedModuleReference"), pForceRemoteRepo As %Boolean = 0) As %Status
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
			
			Set tClient = ..CheckServiceCache(tServer.Name,.tAvailable)
			If 'tAvailable {
				Continue
			}
			If 'tClient.Supports("ListApplications") {
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
Method RetrieveApplicationManifest(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pManifestStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pManifestStream = $$$NULLOREF
	Try {
		Set tClient = ..CheckServiceCache(pQualifiedReference.ServerName,.tAvailable)
		If 'tAvailable {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pQualifiedReference.ServerName))
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
Method RetrieveApplicationPackage(pQualifiedReference As %ZPM.PackageManager.Core.QualifiedModuleReference, Output pPackageStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Set pPackageStream = $$$NULLOREF
	Try {
		Set tClient = ..CheckServiceCache(pQualifiedReference.ServerName,.tAvailable)
		If 'tAvailable {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pQualifiedReference.ServerName))
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

/// Tracks the OREF of this instance in a PPG for later reference.
/// Subclasses of %ZPM.PackageManager.Core.Singleton that override this method *MUST* call ##super().
Method %OnNew() As %Status [ Private, ServerOnly = 1 ]
{
	Set ..XSLTProvider = ##class(%ZPM.PackageManager.Core.XSLTProvider).%Get(.tSC)
	$$$ThrowOnError(tSC)
	Set tSC = ##super()
	$$$ThrowOnError(tSC)
	Quit $$$OK
}

}
