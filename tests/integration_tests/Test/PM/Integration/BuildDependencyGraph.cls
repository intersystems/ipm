Class Test.PM.Integration.BuildDependencyGraph Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
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

    do newImp.WriteLine(
        "    set ^CacheTemp.BuildDependencyGraph($job)=$increment(^CacheTemp.BuildDependencyGraph($job))"
    )

    // Rewind original and copy it
    do methodDef.Implementation.Rewind()
    while 'methodDef.Implementation.AtEnd {
        do newImp.WriteLine(methodDef.Implementation.ReadLine())
    }

    // Replace implementation
    set methodDef.Implementation = newImp
    do methodDef.%Save()

    // Recompile the class
    do $system.OBJ.Compile("%IPM.Storage.Module", "cuk")
    return $$$OK
}

/// Counts the number of times that BuildDependencyGraph() gets invoked on test modules' installation to catch regressions
Method TestBuildDependencyGraphCount()
{
    kill params
    set params("IgnoreInstalled") = 1
    set params("UpdateSnapshots") = 1

    write !, "TTTTT", !
    zwrite $get(^CacheTemp.BuildDependencyGraph($job),0)

    set sc = ##class(%IPM.Utils.Module).LoadNewModule(..GetModuleDir("build-dependency-graph-loop/module-a"), .params)
    do $$$AssertStatusOK(sc)

    write !, "SSSSSSS", !
    zwrite $get(^CacheTemp.BuildDependencyGraph($job),0)

    do $$$AssertTrue($get(^CacheTemp.BuildDependencyGraph($job), 0) > 0)
    do $$$AssertTrue($get(^CacheTemp.BuildDependencyGraph($job), 0) < 4)
}

Method OnAfterAllTests() As %Status
{
    set methodDef = ##class(%Dictionary.MethodDefinition).%OpenId("%IPM.Storage.Module||BuildDependencyGraph")

    if $data(^CacheTemp.BuildDependencyGraph("orig", $job)) {
        set imp = ##class(%Stream.TmpCharacter).%New()
        do imp.Write(^CacheTemp.BuildDependencyGraph("orig", $job))
        set methodDef.Implementation = imp
        do methodDef.%Save()
        do $system.OBJ.Compile("%IPM.Storage.Module", "cuk")
    }

    kill ^CacheTemp.BuildDependencyGraph($job)

    set sc = ##class(%IPM.Main).Shell("repo -delete -name build-dependency-graph")
    do $$$AssertStatusOK(sc, "Deleted build-dependency-graph repo successfully.")
    return $$$OK
}

}
