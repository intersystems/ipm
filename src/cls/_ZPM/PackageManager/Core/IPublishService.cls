Class %ZPM.PackageManager.Core.IPublishService [ Abstract ]
{

Method PublishModule(pModule As %ZPM.PackageManager.Core.Module) As %Boolean [ Abstract ]
{
}

Method PublishApplication(pApplication As %ZPM.PackageManager.Core.Application) As %Boolean [ Abstract ]
{
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
	Quit 1
}

}
