Class %ZPM.PackageManager.Client.PublishManager Extends %ZPM.PackageManager.Core.Singleton
{

Parameter NAMESPACESCOPE As BOOLEAN = 1;

/// Avoids constantly reinstantiating the package service objects, which may be expensive.
Property ServiceCache As array Of %ZPM.PackageManager.Core.IPackageService;

/// Keeps track of which repositories are unavailable (by name - the keys are important, values don't matter)
Property UnavailableNames As array Of %String;

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
			Set tClient = tRepository.GetPublishService()
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

Method CheckUnpublishEnabled(Output isEnabled As %Boolean, pRepositoryName As %String, pPackageName As %String, pPackageVersion As %String) As %Status
{
    Set tSC = $$$OK
	Set isEnabled = 0
	Try {
		Set tClient = ..CheckServiceCache(pRepositoryName,.tAvailable)
		If 'tAvailable {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pRepositoryName))
			Quit
		}
		Set isEnabled = tClient.CheckUnpublishEnabled(pPackageName, pPackageVersion)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Return tSC
}

Method Unpublish(pRepositoryName As %String, pPackageName As %String, pPackageVersion As %String) As %Status
{
    Set tSC = $$$OK

	Set tClient = ..CheckServiceCache(pRepositoryName,.tAvailable)
	If 'tAvailable {
		Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is unavailable.",pRepositoryName))
		Quit
	}
	$$$ThrowOnError(tClient.Unpublish(pPackageName, pPackageVersion))

	Return tSC
}

}
