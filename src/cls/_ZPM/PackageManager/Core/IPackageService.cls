Class %ZPM.PackageManager.Core.IPackageService [ Abstract ]
{

Method GetApplication(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Stream.Object [ Abstract ]
{
}

Method GetApplicationDirectory(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %String [ Abstract ]
{
}

Method GetApplicationManifest(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Stream.Object [ Abstract ]
{
}

Method GetModule(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference, Output AsArchive As %Boolean = 0) As %Stream.Object [ Abstract ]
{
}

Method GetModuleDirectory(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %String [ Abstract ]
{
}

Method GetModuleManifest(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Stream.Object [ Abstract ]
{
}

Method HasApplication(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Boolean [ Abstract ]
{
}

Method HasModule(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Boolean [ Abstract ]
{
}

Method ListApplications(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.ResolvedModuleReference") [ Abstract ]
{
}

Method ListModules(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.ResolvedModuleReference") [ Abstract ]
{
}

/// Returns 1 if the service supports a particular method.
ClassMethod Supports(pMethod As %String) As %Boolean
{
	Quit 0
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
	Quit 1
}

}
