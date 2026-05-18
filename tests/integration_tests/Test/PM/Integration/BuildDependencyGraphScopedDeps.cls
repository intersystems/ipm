Class Test.PM.Integration.BuildDependencyGraphScopedDeps Extends Test.PM.Integration.Base
{

Parameter REPONAME = "build-dependency-graph-scoped-dep";

Parameter MODNAME = "module-a";

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

/// BuildDependencyGraph should include scope information for scoped transitive dependencies
Method TestDependencyGraphScopedDependency()
{
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).LoadModuleFromDirectory(..RepoPath_..#MODNAME), "Successfully loaded module from directory.")
    set module = ##class(%IPM.Storage.Module).NameOpen(..#MODNAME,,.sc)
    do $$$AssertStatusOK(sc, "Succcessfully opened module object.")

    // Expected dependencyGraph format: dependencyGraph(<module name>) = $listbuild(<depth>, <server>, <version>, <display name>, <scope>)
    set scopes = $listbuild("test", "verify")
    set sc = module.BuildDependencyGraph(.dependencyGraph, , , ,scopes)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() call was successful.")

    // Check non-scoped dependency
    do $$$AssertTrue($data(dependencyGraph("module-b")))
    set $listbuild(,,,,moduleBScope) = dependencyGraph("module-b")
    do $$$AssertEquals(moduleBScope, "", "module-b scope succssfully checked to be empty.")

    // Check scoped dependency
    do $$$AssertTrue($data(dependencyGraph("module-c")))
    set $listbuild(,,,,moduleCScope) = dependencyGraph("module-c")
    do $$$AssertEquals(moduleCScope, "test", "module-c scope succssfully checked to be 'test'.")
}

}
