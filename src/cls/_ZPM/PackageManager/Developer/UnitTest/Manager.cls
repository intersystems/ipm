Class %ZPM.PackageManager.Developer.UnitTest.Manager Extends %UnitTest.Manager
{

/// Ensures the last run variable is cleared out, then just does the usual.
ClassMethod RunTest(testspec As %String, qspec As %String, ByRef userparam) As %Status
{
	Kill ^||%UnitTest.Manager.LastResult
	Quit ##super(.testspec,.qspec,.userparam)
}

/// Does the default behavior, then stashes the latest run index
Method SaveResult(duration)
{
	Do ##super(.duration)
	Set ^||%UnitTest.Manager.LastResult = i%LogIndex
	Quit
}

/// Loads unit test classes from a directory without compiling or running them. (Other debug loading approaches would compile them.)
ClassMethod LoadTestDirectory(pRootDirectory As %String, pVerbose As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(..GetSubDirectories(pRootDirectory,pRootDirectory,1,"",.tSubDirs))
		
		Set tDirectory = ""
		For {
			Set tDirectory = $Order(tSubDirs(tDirectory))
			If (tDirectory = "") {
				Quit
			}
			$$$ThrowOnError($System.OBJ.LoadDir(tDirectory,"k" _ $Select(pVerbose:"/display",1:"/nodisplay")))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns $$$OK if the last unit test run was successful, or an error if it was unsuccessful.
ClassMethod GetLastStatus(Output pFailureCount As %Integer) As %Status
{
	Set tSC = $$$OK
	Try {
		If $Data(^||%UnitTest.Manager.LastResult,tLogIndex) {
			Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select count(*) "_
				"from %UnitTest_Result.TestAssert where Status = 0 "_
				"and TestMethod->TestCase->TestSuite->TestInstance->InstanceIndex = ?",tLogIndex)
			If (tRes.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
			}
			Do tRes.%Next(.tSC)
			$$$ThrowOnError(tSC)
			Set pFailureCount = tRes.%GetData(1)
			If (pFailureCount > 0) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("%1 assertion(s) failed.",pFailureCount))
			} Else {
				// Double check that no other failures were reported - e.g., failures loading that would lead to no assertions passing or failing!
				Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select count(*) "_
					"from %UnitTest_Result.TestSuite where Status = 0 "_
					"and TestInstance->InstanceIndex = ?",tLogIndex)
				If (tRes.%SQLCODE < 0) {
					Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
				}
				Do tRes.%Next(.tSC)
				$$$ThrowOnError(tSC)
				Set pFailureCount = tRes.%GetData(1)
				If (pFailureCount > 0) {
					Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("%1 test suite(s) failed.",pFailureCount))
				}
			}
		} Else {
			Set tSC = $$$ERROR($$$GeneralError,"No unit test results recorded.")
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
