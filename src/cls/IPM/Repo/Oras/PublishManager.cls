Class %IPM.Repo.Oras.PublishManager Extends %IPM.General.Singleton
{

Method CheckServiceCache(
	pRepositoryName As %String,
	Output pAvailable As %Boolean) As %IPM.Repo.IPublishService
{
	// TODO actually implement cache
	Set pAvailable = 0
	Set tClient = ""

	Set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(pRepositoryName,,.tSC)
	$$$ThrowOnError(tSC)

	If tRepository.Enabled {
		Set tClient = tRepository.GetPublishService()
		Set pAvailable = tClient.IsAvailable()
	}
	Return tClient
}

Method CheckUnpublishEnabled(
	Output isEnabled As %Boolean,
	pRepositoryName As %String,
	pPackageName As %String,
	pPackageVersion As %String) As %Status
{
    Set tSC = $$$OK
	Set isEnabled = 0
	Try {
		Set tClient = ..CheckServiceCache(pRepositoryName, .tAvailable)
		If 'tAvailable {
			Set tSC = $$$ERROR($$$GeneralError, $$$FormatText("Repository '%1' is unavailable.", pRepositoryName))
			Quit
		}
		Set isEnabled = tClient.CheckUnpublishEnabled(pPackageName, pPackageVersion)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Return tSC
}

Method Unpublish(
	pRepositoryName As %String,
	pPackageName As %String,
	pPackageVersion As %String) As %Status
{
	Set tSC = $$$OK

	Set tClient = ..CheckServiceCache(pRepositoryName, .tAvailable)
	If 'tAvailable {
		Set tSC = $$$ERROR($$$GeneralError, $$$FormatText("Repository '%1' is unavailable.", pRepositoryName))
		Quit
	}
	$$$ThrowOnError(tClient.Unpublish(pPackageName, pPackageVersion))

	Return tSC
}

}
