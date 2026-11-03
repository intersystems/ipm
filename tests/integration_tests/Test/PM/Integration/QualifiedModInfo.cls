Class Test.PM.Integration.QualifiedModInfo Extends Test.PM.Integration.Base
{

Parameter REPONAME = "simplest-module";

Property RepoPath As %String;

Method OnBeforeAllTests() As %Status
{
    // Set up the repo path - use GetModuleDir utility
    set ..RepoPath = ..GetModuleDir(..#REPONAME)

    // Create filesystem repo pointing to test data
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -fs -path "_..RepoPath)
    do $$$AssertStatusOK(sc,"Created"_..#REPONAME_"repo successfully.")
    quit sc
}

Method OnAfterAllTests() As %Status
{
    // Remove test repository
    set sc = ##class(%IPM.Main).Shell("repo -delete -name "_..#REPONAME)
    do $$$AssertStatusOK(sc,"Deleted "_..#REPONAME_"repo successfully.")
    quit sc
}

/// SearchRepositoriesForModule returns each matching module version and preserves the version summary.
Method TestSearchModuleNoVersionSpecified()
{
    // Set searchCriteria
    set searchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
	set searchCriteria.Name = ..#REPONAME

    // Search repos
    set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(searchCriteria, .resultList)
	do $$$AssertStatusOK(sc, "SearchRepositoriesForModule call was successful.")
    do $$$AssertEquals(resultList.Count(), 3, "Search returns one reference per matching version.")

    // Get the newest module reference
    set moduleReference = resultList.GetAt(1)

    do $$$AssertEquals(moduleReference.VersionString, "3.0.0", "Newest version is first.")
    do $$$AssertEquals(moduleReference.AllVersions, "3.0.0, 2.0.0, 1.0.0", "Each result preserves the full version summary.")
    do $$$AssertEquals(resultList.GetAt(2).VersionString, "2.0.0", "Second version is returned.")
    do $$$AssertEquals(resultList.GetAt(3).VersionString, "1.0.0", "Third version is returned.")
}

/// SearchRepositoriesForModule returns every version matching the expression, with that filtered summary.
Method TestSearchModuleVersionSpecified()
{
    // Set searchCriteria
    set searchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
	set searchCriteria.Name = ..#REPONAME
    set searchCriteria.VersionExpression = "<3.0.0"

    // Search repos
    set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(searchCriteria, .resultList)
	do $$$AssertStatusOK(sc, "SearchRepositoriesForModule call was successful.")
    do $$$AssertEquals(resultList.Count(), 2, "Search returns both matching versions.")

    // Get the first module reference
    set moduleReference = resultList.GetAt(1)

    do $$$AssertEquals(moduleReference.VersionString, "2.0.0", "Highest matching version is first.")
    do $$$AssertEquals(moduleReference.AllVersions, "2.0.0, 1.0.0", "Summary contains only matching versions.")
    do $$$AssertEquals(resultList.GetAt(2).VersionString, "1.0.0", "The other matching version is returned.")
}

}