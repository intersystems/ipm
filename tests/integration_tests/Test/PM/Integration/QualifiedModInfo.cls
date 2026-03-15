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

Method OnAfterOneTest() As %Status
{
    // Uninstall all modules after each test for clean state
    set sc = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(sc,"Uninstalled all modules after test.")
    quit sc
}

/// SearchRepositoriesForModule should return a list where each entry
/// is a modile reference with AllVersions set
Method SearchRepositoriesForModule()
{
    // Set searchCriteria
    set searchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
	set searchCriteria.Name = ..#REPONAME
	set searchCriteria.AllVersions = 1

    // Search repos
    set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(searchCriteria, .resultList)
	$$$ThrowOnError(sc)


    // Make sure returned moduleReferences have AllVersions set
    for i=1:1:resultList.Count() {
        set moduleReference = resultList.GetAt(i)
        do $$$AssertTrue((moduleReference.AllVersions '= ""), "moduleReference.AllVersions is not empty")
    }
}

}
