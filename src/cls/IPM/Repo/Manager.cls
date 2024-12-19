Class %IPM.Repo.Manager Extends %IPM.General.Singleton
{

/// If set to 1, calls to %Get must return an instance of this class created in the current namespace; a new instance will be created if none exists.
Parameter NAMESPACESCOPE As BOOLEAN = 1;

/// Avoids constantly reinstantiating the package service objects, which may be expensive.
Property ServiceCache As array Of %IPM.Repo.IPackageService;

/// Keeps track of which repositories are unavailable (by name - the keys are important, values don't matter)
Property UnavailableNames As array Of %String;

/// Performance optimization for XSLTs
Property XSLTProvider As %IPM.Repo.XSLTProvider;

Method CheckServiceCache(pRepositoryName As %String, Output pAvailable As %Boolean) As %IPM.Repo.IPackageService
{
	Set pAvailable = 0
	If ..UnavailableNames.IsDefined(pRepositoryName) {
		Quit $$$NULLOREF
	}
	
	Set tClient = ..ServiceCache.GetAt(pRepositoryName)
	If '$IsObject(tClient) {
		Set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(pRepositoryName,,.tSC)
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
Method SearchRepositoriesForModule(pSearchCriteria As %IPM.Repo.SearchCriteria, Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%IPM.Storage.QualifiedModuleInfo"), pForceRemoteRepo As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResults = ##class(%Library.ListOfObjects).%New()
	Try {
    Set registry = pSearchCriteria.Registry
	Set pSearchCriteria.Name = $$$lcase(pSearchCriteria.Name)
    Set tRes = ##class(%SQL.Statement).%ExecDirect(,
		"select ID from %IPM_Repo.Definition "_
		"where Enabled = 1 "_
		"and (? is null or Name = ?) order by %IPM_Repo.Definition_SortOrder(ID)",
		registry,registry)
		If (tRes.%SQLCODE < 0) {
			Set tSC = $$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message)
			Quit
		}
		While (tRes.%Next(.tSC)) {
			If $$$ISERR(tSC) {
				Quit
			}
			Set repoID = tRes.%Get("ID")
			Set tServer = ##class(%IPM.Repo.Definition).%OpenId(repoID,,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Only remote repositories support keywords, for now.
			If (pSearchCriteria.Keywords.Count() > 0) && tServer.%IsA("%IPM.Repo.Filesystem.Definition") {
				Continue
			}
			
			Set tClient = ..CheckServiceCache(tServer.Name,.tAvailable)
			If 'tAvailable {
				Continue
			}
			
			#dim tClientCriteria As %IPM.Repo.SearchCriteria
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
        Set versions(+item.Version.Major, +item.Version.Minor, +item.Version.Patch, " "_item.Version.Patch_"_"_item.Version.Prerelease, repoID, tServer.Name) = item
			}
		}
	Set major = ""
    // Sorting direction for prereleases/postreleases. Only set once outside of the whole loop.
    Set subDirection = $SELECT(+##class(%IPM.Repo.UniversalSettings).GetValue("SemVerPostRelease"): -1, 1: 1)
	For {
		Set major = $Order(versions(major), -1)
		Quit:major=""
		Set minor = ""
		For  {
          Set minor = $Order(versions(major, minor), -1)
          Quit:minor=""
          Set patch = ""
          For  {
            Set patch = $Order(versions(major, minor, patch), -1)
            Quit:patch=""
            Set sub = ""
            For  {
              Set sub = $Order(versions(major, minor, patch, sub), subDirection)
              Quit:sub=""
              Set repoOrder = ""
              For {
	              Set repoOrder = $Order(versions(major, minor, patch, sub, repoOrder), 1)
	              Quit:repoOrder=""
	              Set name = ""
	              For {
		              Set name = $Order(versions(major, minor, patch, sub, repoOrder, name), 1, item)
		              Quit:name=""
		              Do pResults.Insert(##class(%IPM.Storage.QualifiedModuleInfo).%New(name, item))
	              }
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
Method RetrieveModuleManifest(pQualifiedReference As %IPM.Storage.QualifiedModuleInfo, Output pManifestStream As %Stream.Object) As %Status
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
Method RetrieveModulePackage(pQualifiedReference As %IPM.Storage.QualifiedModuleInfo, Output pPackageStream As %Stream.Object) As %Status
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

/// Tracks the OREF of this instance in a PPG for later reference.
/// Subclasses of %IPM.General.Singleton that override this method *MUST* call ##super().
Method %OnNew() As %Status [ Private, ServerOnly = 1 ]
{
	Set ..XSLTProvider = ##class(%IPM.Repo.XSLTProvider).%Get(.tSC)
	$$$ThrowOnError(tSC)
	Set tSC = ##super()
	$$$ThrowOnError(tSC)
	Quit $$$OK
}

}
