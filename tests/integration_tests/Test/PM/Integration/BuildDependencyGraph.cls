Class Test.PM.Integration.BuildDependencyGraph Extends Test.PM.Integration.Base
{

Method OnBeforeOneTest() As %Status
{
    set sc = ##class(%IPM.Main).Shell("repo -n build-dependency-graph -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/build-dependency-graph-loop/")
    do $$$AssertStatusOK(sc, "Created build-dependency-graph repo successfully.")

    // Reset counter to track BuildDependencyGraph() number of calls
    kill ^CacheTemp.BuildDependencyGraph($job)

    // Open method definition
    set methodDef = ##class(%Dictionary.MethodDefinition).%OpenId("%IPM.Storage.Module||BuildDependencyGraph")

    // Save original implementation so we can restore it
    set ^CacheTemp.BuildDependencyGraph("orig", $job) = methodDef.Implementation.Read()

    // Build wrapped implementation
    set newImp = ##class(%Stream.TmpCharacter).%New()

    set sc = newImp.WriteLine(
        "    set ^CacheTemp.BuildDependencyGraph($job)=$increment(^CacheTemp.BuildDependencyGraph($job))"
    )
    do $$$AssertStatusOK(sc, "Wrote new line into BuildDependencyGraph() successfully.")

    // Rewind original and copy it
    do methodDef.Implementation.Rewind()
    while 'methodDef.Implementation.AtEnd {
        set sc = newImp.WriteLine(methodDef.Implementation.ReadLine())
        do $$$AssertStatusOK(sc, "Copied original line into new definition of BuildDependencyGraph() successfully.")
    }

    // Replace implementation
    set methodDef.Implementation = newImp
    set sc = methodDef.%Save()
    do $$$AssertStatusOK(sc, "Saved new method definition for BuildDependencyGraph() successfully.")

    // Recompile the class
    set sc = $system.OBJ.Compile("%IPM.Storage.Module", "cuk")
    do $$$AssertStatusOK(sc, "Compiled test definition of %IPM.Storage.Module successfully.")
    return sc
}

/// Counts the number of times that BuildDependencyGraph() gets invoked on test modules' installation to catch regressions
Method TestBuildDependencyGraphCount()
{
    kill params
    set params("IgnoreInstalled") = 1
    set params("UpdateSnapshots") = 1

    set sc = ##class(%IPM.Utils.Module).LoadNewModule(..GetModuleDir("build-dependency-graph-loop/module-a"), .params)
    do $$$AssertStatusOK(sc)

    do $$$AssertTrue($get(^CacheTemp.BuildDependencyGraph($job), 0) > 0)
    do $$$AssertTrue($get(^CacheTemp.BuildDependencyGraph($job), 0) < 4)
}

Method OnAfterOneTest() As %Status
{
    set methodDef = ##class(%Dictionary.MethodDefinition).%OpenId("%IPM.Storage.Module||BuildDependencyGraph")

    if $data(^CacheTemp.BuildDependencyGraph("orig", $job)) {
        set imp = ##class(%Stream.TmpCharacter).%New()
        set sc = imp.Write(^CacheTemp.BuildDependencyGraph("orig", $job))
        do $$$AssertStatusOK(sc, "Wrote back original method definition of BuildDependencyGraph() successfully.")
        set methodDef.Implementation = imp
        set sc = methodDef.%Save()
        do $$$AssertStatusOK(sc, "Saved original method definition of BuildDependencyGraph() successfully.")
        set sc = $system.OBJ.Compile("%IPM.Storage.Module", "cuk")
        do $$$AssertStatusOK(sc, "Compiled original definition of %IPM.Storage.Module successfully.")
    }

    kill ^CacheTemp.BuildDependencyGraph($job)

    set sc = ##class(%IPM.Main).Shell("repo -delete -name build-dependency-graph")
    do $$$AssertStatusOK(sc, "Deleted build-dependency-graph repo successfully.")
    return sc
}

}
