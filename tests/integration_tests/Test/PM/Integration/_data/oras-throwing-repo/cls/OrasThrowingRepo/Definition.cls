/// ORAS repo whose lookups always fail, with a system error if the URL contains "system-error".
Class OrasThrowingRepo.Definition Extends %IPM.Repo.Oras.Definition
{

/// Its own moniker, so repo -oras keeps creating %IPM.Repo.Oras.Definition while this module is installed.
Parameter MONIKER As STRING = "oras-throwing";

Method GetPackageService() As %IPM.Repo.IPackageService
{
    set service = ##class(OrasThrowingRepo.PackageService).%New()
    set service.Location = ..URL
    set service.RepoName = ..Name
    return service
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
