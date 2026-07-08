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
            if logIndex '= "" {
                // Count failure rows to match what OutputFailuresForLogIndex displays:
                // one row per case error, one per method error, one per failed assertion
                set tree = ##class(%IPM.Test.Abstract).BuildResultTree(logIndex)
                set suiteIter = tree.suites.%GetIterator()
                while suiteIter.%GetNext(, .suiteObj) {
                    set caseIter = suiteObj.cases.%GetIterator()
                    while caseIter.%GetNext(, .caseObj) {
                        if caseObj.error '= "" {
                            set failureCount = failureCount + 1
                        }
                        set methodIter = caseObj.methods.%GetIterator()
                        while methodIter.%GetNext(, .methodObj) {
                            if methodObj.error '= "" {
                                set failureCount = failureCount + 1
                            }
                            set assertIter = methodObj.asserts.%GetIterator()
                            while assertIter.%GetNext(, .assertObj) {
                                if assertObj.status = "failed" {
                                    set failureCount = failureCount + 1
                                }
                            }
                        }
                    }
                }
            }
        }

        if failureCount > 0 {
            set sc = $$$ERROR($$$GeneralError, failureCount_" failure(s).")
        }

        // Always consume the entries this phase owned.
        // At top level (startIndex=0) kill everything; for nested phases, roll the count
        // back so the outer phase does not re-count entries the inner phase already handled.
        // Outer phases learn about inner failures via the Shell return status, not by
        // re-inspecting these entries.
        if startIndex = 0 {
            kill ^||%UnitTest.Manager.AllResults
            kill ^||%UnitTest.Manager.AllResultsCount
        } else {
            for i=(startIndex+1):1:testCount {
                kill ^||%UnitTest.Manager.AllResults(i)
            }
            set ^||%UnitTest.Manager.AllResultsCount = startIndex
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

        for i=(startIndex+1):1:testCount {
            set logIndex = $get(^||%UnitTest.Manager.AllResults(i))
            if (logIndex '= "") {
                do ..OutputFailuresForLogIndex(logIndex)
            }
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
    set tree = ##class(%IPM.Test.Abstract).BuildResultTree(logIndex)
    set suiteIter = tree.suites.%GetIterator()
    while suiteIter.%GetNext(, .suiteObj) {
        set caseIter = suiteObj.cases.%GetIterator()
        while caseIter.%GetNext(, .caseObj) {
            if caseObj.error '= "" {
                write !,$$$FormattedLine($$$Red, "FAILED " _ suiteObj.name _ ":" _ caseObj.name), ": " _ caseObj.error
            }
            set methodIter = caseObj.methods.%GetIterator()
            while methodIter.%GetNext(, .methodObj) {
                if methodObj.status '= "failed" { continue }
                if methodObj.error '= "" {
                    write !,$$$FormattedLine($$$Red, "FAILED " _ suiteObj.name _ ":" _ methodObj.name), ": " _ methodObj.error
                }
                set assertIter = methodObj.asserts.%GetIterator()
                while assertIter.%GetNext(, .assertObj) {
                    if assertObj.status '= "failed" { continue }
                    write !,$$$FormattedLine($$$Red, "FAILED " _ suiteObj.name _ ":" _ methodObj.name), ": " _ assertObj.action _ " - " _ assertObj.description
                }
            }
        }
    }
}

}
