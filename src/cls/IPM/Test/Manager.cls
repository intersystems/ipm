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
        if '$data(^||%UnitTest.Manager.LastResult,tLogIndex)#2 {
            set tLogIndex = $order(^UnitTest.Result(""),-1)
        }
        kill ^||%UnitTest.Manager.LastResult // Clean up
        if tLogIndex {
            set tRes = ##class(%SQL.Statement).%ExecDirect(,"select count(*) "_
                "from %UnitTest_Result.TestAssert where Status = 0 "_
                "and TestMethod->TestCase->TestSuite->TestInstance->InstanceIndex = ?",tLogIndex)
            if (tRes.%SQLCODE < 0) {
                throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
            }
            do tRes.%Next(.tSC)
            $$$ThrowOnError(tSC)
            set pFailureCount = tRes.%GetData(1)
            if (pFailureCount > 0) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("%1 assertion(s) failed.",pFailureCount))
            } else {
                // Double check that no other failures were reported - e.g., failures loading that would lead to no assertions passing or failing!
                set tRes = ##class(%SQL.Statement).%ExecDirect(,"select count(*) "_
                    "from %UnitTest_Result.TestSuite where Status = 0 "_
                    "and TestInstance->InstanceIndex = ?",tLogIndex)
                if (tRes.%SQLCODE < 0) {
                    throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
                }
                do tRes.%Next(.tSC)
                $$$ThrowOnError(tSC)
                set pFailureCount = tRes.%GetData(1)
                if (pFailureCount > 0) {
                    set tSC = $$$ERROR($$$GeneralError,$$$FormatText("%1 test suite(s) failed.",pFailureCount))
                }
            }
        } else {
            set tSC = $$$ERROR($$$GeneralError,"No unit test results recorded.")
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
        if '$data(^||%UnitTest.Manager.LastResult,tLogIndex)#2 {
            set tLogIndex = $order(^UnitTest.Result(""),-1)
        }
        kill ^||%UnitTest.Manager.LastResult // Clean up
        if 'tLogIndex {
            quit
        }
        set tLogGN = $name(^UnitTest.Result(tLogIndex))
        set tRoot = ""
        for {
            set tRoot = $order(@tLogGN@(tRoot))
            quit:tRoot=""
            set tSuite = ""
            for {
                set tSuite = $order(@tLogGN@(tRoot, tSuite))
                quit:tSuite=""
                set tMethod = ""
                for {
                    set tMethod = $order(@tLogGN@(tRoot, tSuite, tMethod))
                    quit:tMethod=""

                    set tAssert = ""
                    for {
                        set tAssert = $order(@tLogGN@(tRoot, tSuite, tMethod, tAssert), 1, tAssertInfo)
                        quit:tAssert=""
                        set $listbuild(status, type, text) = tAssertInfo
                        continue:status
                        write !,$$$FormattedLine($$$Red, "FAILED " _ tSuite _ ":" _ tMethod), ": " _ type _ " - " _ text
                    }
                }
            }
        }
    }
}

}
