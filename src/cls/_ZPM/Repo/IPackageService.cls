Class %ZPM.Repo.IPackageService [ Abstract ]
{

Method GetModule(pModuleReference As %ZPM.Storage.ModuleInfo, Output AsArchive As %Boolean = 0) As %Stream.Object [ Abstract ]
{
}

Method GetModuleDirectory(pModuleReference As %ZPM.Storage.ModuleInfo) As %String [ Abstract ]
{
}

Method GetModuleManifest(pModuleReference As %ZPM.Storage.ModuleInfo) As %Stream.Object [ Abstract ]
{
}

Method HasModule(pModuleReference As %ZPM.Storage.ModuleInfo) As %Boolean [ Abstract ]
{
}

Method ListModules(pSearchCriteria As %ZPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%ZPM.Storage.ModuleInfo") [ Abstract ]
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
