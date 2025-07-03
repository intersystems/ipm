Class %IPM.Repo.Remote.PublishManager Extends %IPM.General.Singleton
{

Parameter NAMESPACESCOPE As BOOLEAN = 1;

/// Avoids constantly reinstantiating the package service objects, which may be expensive.
Property ServiceCache As array Of %IPM.Repo.IPublishService;

/// Keeps track of which repositories are unavailable (by name - the keys are important, values don't matter)
Property UnavailableNames As array Of %String;

Method CheckServiceCache(
	pRepositoryName As %String,
	Output pAvailable As %Boolean) As %IPM.Repo.IPublishService
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
            set tClient = tRepository.GetPublishService()
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

Method CheckUnpublishEnabled(
	Output isEnabled As %Boolean,
	pRepositoryName As %String,
	pPackageName As %String,
	pPackageVersion As %String) As %Status
{
    set tSC = $$$OK
    set isEnabled = 0
    try {
        set tClient = ..CheckServiceCache(pRepositoryName,.tAvailable)
        if 'tAvailable {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pRepositoryName))
            quit
        }
        set isEnabled = tClient.CheckUnpublishEnabled(pPackageName, pPackageVersion)
    } catch e {
        set tSC = e.AsStatus()
    }
    return tSC
}

Method Unpublish(
	pRepositoryName As %String,
	pPackageName As %String,
	pPackageVersion As %String) As %Status
{
    set tSC = $$$OK

    set tClient = ..CheckServiceCache(pRepositoryName,.tAvailable)
    if 'tAvailable {
        set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pRepositoryName))
        quit
    }
    $$$ThrowOnError(tClient.Unpublish(pPackageName, pPackageVersion))

    return tSC
}

}
