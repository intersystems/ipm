Class %IPM.Repo.IPublishService [ Abstract ]
{

Method PublishModule(pModule As %IPM.Repo.Remote.ModuleInfo) As %Boolean [ Abstract ]
{
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
	Quit 1
}

}
