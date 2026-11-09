Class OrasThrowingRepo.PackageService Extends %IPM.Repo.Oras.PackageService
{

Method IsAvailable() As %Boolean
{
    return 1
}

Method ListModules(pSearchCriteria As %IPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%IPM.Storage.ModuleInfo")
{
    if ..Location [ "system-error" {
        // Stands in for a system error such as <INTERRUPT> from Ctrl+C
        set x = 1 / 0
    }
    $$$ThrowStatus($$$ERROR($$$GeneralError, "Simulated registry failure [x:y]"))
}

}
