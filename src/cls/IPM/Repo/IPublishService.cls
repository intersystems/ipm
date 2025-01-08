Class %IPM.Repo.IPublishService [ Abstract ]
{

Method PublishModule(pModule As %IPM.Repo.Remote.ModuleInfo) As %Status [ Abstract ]
{
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
	Quit 1
}

Method Unpublish(packageName As %String, packageVersion As %String) As %Status [ Abstract ]
{
}

Method CheckUnpublishEnabled(packageName As %String, packageVersion As %String) As %Boolean
{
    Return 0
}

}
