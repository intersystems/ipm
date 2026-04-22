Include %IPM.Formatting

Class %IPM.Test.Manager Extends %UnitTest.Manager
{

/// Ensures the last run variable is cleared out, then just does the usual.
ClassMethod RunTest(
	testspec As %String,
	qspec As %String,
	ByRef userparam) As %Status
{
    kill ^||%UnitTest.Manager.LastResult
    quit ##super(.testspec,.qspec,.userparam)
}

/// Does the default behavior, then stashes the latest run index
Method SaveResult(duration)
{
    do ##super(.duration)
    set ^||%UnitTest.Manager.LastResult = i%LogIndex
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

/// Returns $$$OK if the last unit test run was successful, or an error if it was unsuccessful.
/// Uses ^UnitTest.Result directly so that lifecycle/hook/throw failures are counted alongside assertion failures.
ClassMethod GetLastStatus(Output pFailureCount As %Integer) As %Status
{
    set tSC = $$$OK
    try {
        if '$data(^||%UnitTest.Manager.LastResult,tLogIndex)#2 {
            set tLogIndex = $order(^UnitTest.Result(""),-1)
        }
        kill ^||%UnitTest.Manager.LastResult // Clean up
        if tLogIndex {
            set summary = ##class(%IPM.Test.Abstract).GetSummary(tLogIndex)
            set pFailureCount = summary.methods.failed
            if (pFailureCount > 0) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("%1 failure(s).",pFailureCount))
            }
        } else {
            set tSC = $$$ERROR($$$GeneralError,"No unit test results recorded.")
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod OutputFailures()
{
    set tSC = $$$OK
    try {
        if '$data(^||%UnitTest.Manager.LastResult,tLogIndex)#2 {
            set tLogIndex = $order(^UnitTest.Result(""),-1)
        }
        kill ^||%UnitTest.Manager.LastResult // Clean up
        if 'tLogIndex {
            quit
        }
        set tree = ##class(%IPM.Test.Abstract).BuildResultTree(tLogIndex)
        set suiteIter = tree.suites.%GetIterator()
        while suiteIter.%GetNext(, .suiteObj) {
            set caseIter = suiteObj.cases.%GetIterator()
            while caseIter.%GetNext(, .caseObj) {
                // Case-level failure (e.g. OnBeforeAllTests) — no methods ran
                if caseObj.error '= "" {
                    write !,$$$FormattedLine($$$Red, "FAILED " _ suiteObj.name _ ":" _ caseObj.name), ": " _ caseObj.error
                }
                set methodIter = caseObj.methods.%GetIterator()
                while methodIter.%GetNext(, .methodObj) {
                    if methodObj.status '= "failed" { continue }
                    // Method-level lifecycle/throw failure (no assert row)
                    if methodObj.error '= "" {
                        write !,$$$FormattedLine($$$Red, "FAILED " _ suiteObj.name _ ":" _ methodObj.name), ": " _ methodObj.error
                    }
                    // Individual assertion failures
                    set assertIter = methodObj.asserts.%GetIterator()
                    while assertIter.%GetNext(, .assertObj) {
                        if assertObj.status '= "failed" { continue }
                        write !,$$$FormattedLine($$$Red, "FAILED " _ suiteObj.name _ ":" _ methodObj.name), ": " _ assertObj.action _ " - " _ assertObj.description
                    }
                }
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
