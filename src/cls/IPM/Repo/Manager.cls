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

Method CheckServiceCache(
	pRepositoryName As %String,
	Output pAvailable As %Boolean) As %IPM.Repo.IPackageService
{
    set pAvailable = 0
    if ..UnavailableNames.IsDefined(pRepositoryName) {
        quit $$$NULLOREF
    }

    set tClient = ..ServiceCache.GetAt(pRepositoryName)
    if '$isobject(tClient) {
        set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(pRepositoryName,,.tSC)
        $$$ThrowOnError(tSC)

        if tRepository.Enabled {
            // Don't cache Enabled status; no reason to prohibit it from changing.
            set tClient = tRepository.GetPackageService()
            if $isobject(tClient) {
                set pAvailable = tClient.IsAvailable()
                if pAvailable {
                    do ..ServiceCache.SetAt(tClient,tRepository.Name)
                } else {
                    do ..UnavailableNames.SetAt("",tRepository.Name)
                }
            }
        }
    } else {
        // If the client is available in the cache for this object, it is assumed to be available.
        set pAvailable = 1
    }
    quit tClient
}

/// Returns a list of all resolved module references matching the search criteria from configured repositories.
Method SearchRepositoriesForModule(
	pSearchCriteria As %IPM.Repo.SearchCriteria,
	Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%IPM.Storage.QualifiedModuleInfo"),
	pForceRemoteRepo As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set pResults = ##class(%Library.ListOfObjects).%New()
    try {
        set registry = pSearchCriteria.Registry
        set pSearchCriteria.Name = $$$lcase(pSearchCriteria.Name)
        set tRes = ##class(%SQL.Statement).%ExecDirect(,
            "select ID from %IPM_Repo.Definition "_
            "where Enabled = 1 "_
            "and (? is null or Name = ?) order by %IPM_Repo.Definition_SortOrder(ID)",
            registry,registry)
        if (tRes.%SQLCODE < 0) {
            set tSC = $$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message)
            quit
        }
        while (tRes.%Next(.tSC)) {
            if $$$ISERR(tSC) {
                quit
            }
            set repoID = tRes.%Get("ID")
            set tServer = ##class(%IPM.Repo.Definition).%OpenId(repoID,0,.tSC)
            if $$$ISERR(tSC) {
                quit
            }

            // Only remote repositories support keywords, for now.
            if (pSearchCriteria.Keywords.Count() > 0) && tServer.%IsA("%IPM.Repo.Filesystem.Definition") {
                continue
            }

            set tClient = ..CheckServiceCache(tServer.Name,.tAvailable)
            if 'tAvailable {
                continue
            }

            #dim tClientCriteria As %IPM.Repo.SearchCriteria
            set tClientCriteria = pSearchCriteria.%ConstructClone(1)
            set tPrereleases = pSearchCriteria.IncludePrerelease
            if (tPrereleases = "") {
                set tPrereleases = tServer.Prereleases
            }
            set tSnapshots = pSearchCriteria.IncludeSnapshots
            if (tSnapshots = "") {
                set tSnapshots = tServer.Snapshots
            }
            set tClientCriteria.IncludePrerelease = tPrereleases
            set tClientCriteria.IncludeSnapshots = tSnapshots
            set tServerResults = tClient.ListModules(tClientCriteria)
            for i=1:1:tServerResults.Count() {
                set item = tServerResults.GetAt(i)
                #; Sorting versions
                set versions(+item.Version.Major, +item.Version.Minor, +item.Version.Patch, " "_item.Version.Patch_"_"_item.Version.Prerelease, repoID, tServer.Name) = item
            }
        }
        set major = ""
        // Sorting direction for prereleases/postreleases. Only set once outside of the whole loop.
        set subDirection = $select(+##class(%IPM.Repo.UniversalSettings).GetValue("SemVerPostRelease"): -1, 1: 1)
        for {
            set major = $order(versions(major), -1)
            quit:major=""
            set minor = ""
            for  {
                set minor = $order(versions(major, minor), -1)
                quit:minor=""
                set patch = ""
                for  {
                    set patch = $order(versions(major, minor, patch), -1)
                    quit:patch=""
                    set sub = ""
                    for  {
                        set sub = $order(versions(major, minor, patch, sub), subDirection)
                        quit:sub=""
                        set repoOrder = ""
                        for {
                            set repoOrder = $order(versions(major, minor, patch, sub, repoOrder), 1)
                            quit:repoOrder=""
                            set name = ""
                            for {
                                set name = $order(versions(major, minor, patch, sub, repoOrder, name), 1, item)
                                quit:name=""
                                do pResults.Insert(##class(%IPM.Storage.QualifiedModuleInfo).%New(name, item))
                            }
                        }
                    }
                }
            }
        }
    } catch e {
        if (e.Name["ZSOAP") && $data(%objlasterror) {
            set tSC = %objlasterror
        } else {
            set tSC = e.AsStatus()
        }
    }
    quit tSC
}

/// Loads the module reference
Method RetrieveModuleManifest(
	pQualifiedReference As %IPM.Storage.QualifiedModuleInfo,
	Output pManifestStream As %Stream.Object) As %Status
{
    set tSC = $$$OK
    set pManifestStream = $$$NULLOREF
    try {
        set tClient = ..CheckServiceCache(pQualifiedReference.ServerName,.tAvailable)
        if 'tAvailable {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pQualifiedReference.ServerName))
            quit
        }

        set pManifestStream = tClient.GetModuleManifest(pQualifiedReference)
    } catch e {
        if (e.Name["ZSOAP") && $data(%objlasterror) {
            set tSC = %objlasterror
        } else {
            set tSC = e.AsStatus()
        }
    }
    quit tSC
}

/// Loads the module reference
Method RetrieveModulePackage(
	pQualifiedReference As %IPM.Storage.QualifiedModuleInfo,
	Output pPackageStream As %Stream.Object) As %Status
{
    set tSC = $$$OK
    set pPackageStream = $$$NULLOREF
    try {
        set tClient = ..CheckServiceCache(pQualifiedReference.ServerName,.tAvailable)
        if 'tAvailable {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pQualifiedReference.ServerName))
            quit
        }

        set pPackageStream = tClient.GetModule(pQualifiedReference)
    } catch e {
        if (e.Name["ZSOAP") && $data(%objlasterror) {
            set tSC = %objlasterror
        } else {
            set tSC = e.AsStatus()
        }
    }
    quit tSC
}

/// Tracks the OREF of this instance in a PPG for later reference.
/// Subclasses of %IPM.General.Singleton that override this method *MUST* call ##super().
Method %OnNew() As %Status [ Private, ServerOnly = 1 ]
{
    set ..XSLTProvider = ##class(%IPM.Repo.XSLTProvider).%Get(.tSC)
    $$$ThrowOnError(tSC)
    set tSC = ##super()
    $$$ThrowOnError(tSC)
    quit $$$OK
}

}
