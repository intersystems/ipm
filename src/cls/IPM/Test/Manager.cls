Include %IPM.Formatting

Class %IPM.Test.Manager Extends %UnitTest.Manager
{

/// Ensures the last run variable is cleared out, then just does the usual.
ClassMethod RunTest(
	testspec As %String,
	qspec As %String,
	ByRef userparam) As %Status
{
    quit ##super(.testspec,.qspec,.userparam)
}

/// Does the default behavior, then accumulates the test run index
Method SaveResult(duration)
{
    do ##super(.duration)

    // Accumulate ALL test LogIndexes in an array
    // Uses $increment to append so nested calls add to the array
    set count = $increment(^||%UnitTest.Manager.AllResultsCount)
    set ^||%UnitTest.Manager.AllResults(count) = i%LogIndex

    quit
}

/// Loads unit test classes from a directory without compiling or running them. (Other debug loading approaches would compile them.)
ClassMethod LoadTestDirectory(
	pRootDirectory As %String,
	pVerbose As %Boolean = 0,
	Output pLoadedList As %String,
	pFormat As %String = "") As %Status
{
    set tSC = $$$OK
    set pLoadedList = ""
    try {
        $$$ThrowOnError(..GetSubDirectories(pRootDirectory,pRootDirectory,1,"",.tSubDirs))

        set tDirectory = ""
        for {
            set tDirectory = $order(tSubDirs(tDirectory))
            if (tDirectory = "") {
                quit
            }
            // If no format provided, load only XML to support backwards compatability
            $$$ThrowOnError($system.OBJ.LoadDir(tDirectory, "k" _ $select(pVerbose:"/display",1:"/nodisplay"),,,.pLoadedList))
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Check all test LogIndexes accumulated in AllResults and return aggregated status
/// Returns error if any test had failures
/// startIndex: Only check results from this index onwards (for nested phases, e.g. calling `zpm verify` inside `zpm verify`)
ClassMethod GetAllTestsStatus(
	Output failureCount As %Integer,
	startIndex As %Integer = 0) As %Status
{
    set sc = $$$OK
    set failureCount = 0
    try {
        set testCount = $get(^||%UnitTest.Manager.AllResultsCount, 0)

        // Check tracked test LogIndexes from startIndex onwards
        // This ensures nested phases only see their own results, not parent's
        for i=(startIndex+1):1:testCount {
            set logIndex = $get(^||%UnitTest.Manager.AllResults(i))
            if (logIndex '= "") {
                // Query for assertion failures in this test run
                set res = ##class(%SQL.Statement).%ExecDirect(,"select count(*) "_
                    "from %UnitTest_Result.TestAssert where Status = 0 "_
                    "and TestMethod->TestCase->TestSuite->TestInstance->InstanceIndex = ?",logIndex)
                if (res.%SQLCODE < 0) {
                    throw ##class(%Exception.SQL).CreateFromSQLCODE(res.%SQLCODE,res.%Message)
                }
                do res.%Next(.sc)
                $$$ThrowOnError(sc)
                set failures = res.%GetData(1)
                set failureCount = failureCount + failures

                // Also check for test suite failures (e.g., loading errors)
                if (failures = 0) {
                    set res = ##class(%SQL.Statement).%ExecDirect(,"select count(*) "_
                        "from %UnitTest_Result.TestSuite where Status = 0 "_
                        "and TestInstance->InstanceIndex = ?",logIndex)
                    if (res.%SQLCODE < 0) {
                        throw ##class(%Exception.SQL).CreateFromSQLCODE(res.%SQLCODE,res.%Message)
                    }
                    do res.%Next(.sc)
                    $$$ThrowOnError(sc)
                    set failures = res.%GetData(1)
                    set failureCount = failureCount + failures
                }
            }
        }

        if (failureCount > 0) {
            set sc = $$$ERROR($$$GeneralError, failureCount_" assertion(s) failed.")
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Output test failures from accumulated results
/// startIndex: Only output failures from this index onwards (for nested phases)
ClassMethod OutputFailures(startIndex As %Integer = 0)
{
    set sc = $$$OK
    try {
        set testCount = $get(^||%UnitTest.Manager.AllResultsCount, 0)

        // Output failures from all tracked test LogIndexes from startIndex onwards
        // This ensures parent phase outputs failures from both parent and nested tests
        for i=(startIndex+1):1:testCount {
            set logIndex = $get(^||%UnitTest.Manager.AllResults(i))
            if (logIndex '= "") {
                do ..OutputFailuresForLogIndex(logIndex)
            }
        }

        // Only clean up AllResults at top level (startIndex=0), not in nested phases
        if (startIndex = 0) {
            kill ^||%UnitTest.Manager.AllResults
            kill ^||%UnitTest.Manager.AllResultsCount
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Helper method to output failures for a single LogIndex
ClassMethod OutputFailuresForLogIndex(logIndex As %Integer)
{
    if 'logIndex {
        quit
    }
    set logGN = $name(^UnitTest.Result(logIndex))
    set root = ""
    for {
        set root = $order(@logGN@(root))
        quit:root=""
        set suite = ""
        for {
            set suite = $order(@logGN@(root, suite))
            quit:suite=""
            set method = ""
            for {
                set method = $order(@logGN@(root, suite, method))
                quit:method=""

                set assert = ""
                for {
                    set assert = $order(@logGN@(root, suite, method, assert), 1, assertInfo)
                    quit:assert=""
                    set $listbuild(status, type, text) = assertInfo
                    continue:status
                    write !,$$$FormattedLine($$$Red, "FAILED " _ suite _ ":" _ method), ": " _ type _ " - " _ text
                }
            }
        }
    }
}

}
