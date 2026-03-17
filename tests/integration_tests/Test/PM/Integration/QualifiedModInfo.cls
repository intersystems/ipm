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

/// SearchRepositoriesForModule should return a module reference
/// will AllVersions set to all three versions of the module when no version specified in search criteria
Method SearchModuleNoVersionSpecified()
{
    // Set searchCriteria
    set searchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
	set searchCriteria.Name = ..#REPONAME
	set searchCriteria.AllVersions = 1

    // Search repos
    set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(searchCriteria, .resultList)
	do $$$AssertStatusOK(sc, "SearchRepositoriesForModule call was successful.")
    do $$$AssertTrue((resultList.Count() = 1), "Found module.")

    // Get the first module reference
    set moduleReference = resultList.GetAt(1)

    // Make sure AllVersions is set and contains all three versions of the module
    set versionsString = moduleReference.AllVersions
    do $$$AssertTrue((versionsString = "3.0.0, 2.0.0, 1.0.0"), "AllVersions contains all versions of the module.")

    // Make sure VersionString is set to the latest version of the module
    do $$$AssertTrue((moduleReference.VersionString = "3.0.0"), "VersionString is set to the latest version of the module.")
}

/// SearchRepositoriesForModule should return a module reference
/// will AllVersions set to all versions of the module that match the version expression in search criteria
Method SearchModuleVersionSpecified()
{
    // Set searchCriteria
    set searchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
	set searchCriteria.Name = ..#REPONAME
	set searchCriteria.AllVersions = 1
    set searchCriteria.VersionExpression = "<3.0.0"

    // Search repos
    set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(searchCriteria, .resultList)
	do $$$AssertStatusOK(sc, "SearchRepositoriesForModule call was successful.")
    do $$$AssertTrue((resultList.Count() = 1), "Found module.")

    // Get the first module reference
    set moduleReference = resultList.GetAt(1)

    // Make sure AllVersions is set and contains all three versions of the module
    set versionsString = moduleReference.AllVersions
    do $$$AssertTrue((versionsString = "2.0.0, 1.0.0"), "AllVersions contains all matching versions of the module.")

    // Make sure VersionString is set to specified version of the module
    do $$$AssertTrue((moduleReference.VersionString = "2.0.0"), "VersionString is set to the specified version of the module.")
}

}