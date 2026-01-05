Class Test.PM.Integration.BuildDependencyGraph Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
{
    set sc = $$$OK
    kill ^IPMTest
    set ^IPMTest("BuildDependencyGraphCount") = 0
    return sc
}

/// Counts the number of times that BuildDependencyGraph() gets invoked on test modules' installation to catch regressions
Method TestBuildDependencyGraphCount()
{
    // Install base module C
    set moduleDir = ..GetModuleDir("build-dependency-graph-loop/module-c")
    set status = ##class(%IPM.Main).Shell("load -verbose "_moduleDir)
    do $$$AssertStatusOK(status,"Module module-c successfully installed")

    // Install module A (which has dependencies B-snapshot-version and C) with hidden flags UpdateSnapshots and IgnoreInstalled
    kill params
    set params("UpdateSnapshots") = 1
    set params("IgnoreInstalled") = 1
    set params("Verbose") = 1

    set moduleDir = ..GetModuleDir("build-dependency-graph-loop/module-a")
    set sc = ##class(%IPM.Utils.Module).LoadNewModule(moduleDir, .params)
    do $$$AssertStatusOK(sc)

    // TODO: Note that this number 4 is just what the number of BuildDependencyGraphCount gets cut down to with the fix for #1011. Without #1011 the number is 5. This is just to ensure no regressions for the future, but will be an even lower number with #998.
    do $$$AssertTrue(^IPMTest("BuildDependencyGraphCount") <= 4)
}

Method OnAfterAllTests() As %Status
{
    set sc = $$$OK
    kill ^IPMTest
    return sc
}

}
