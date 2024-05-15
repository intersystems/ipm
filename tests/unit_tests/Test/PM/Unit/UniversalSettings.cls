Class Test.PM.Unit.UniversalSettings Extends %UnitTest.TestCase
{

Parameter TestIndx As STRING = "TestIndx";

Method TestSetValueOverwrite()
{
    Do ##class(%IPM.Repo.UniversalSettings).SetValue(..#TestIndx, "new value a", )
    Set value = ##class(%IPM.Repo.UniversalSettings).GetValue(..#TestIndx)
    Do $$$AssertEquals(value, "new value a")

    Do ##class(%IPM.Repo.UniversalSettings).SetValue(..#TestIndx, "new value b", 1)
    Set value = ##class(%IPM.Repo.UniversalSettings).GetValue(..#TestIndx)
    Do $$$AssertEquals(value, "new value b")
}

Method TestSetValueNoOverwrite()
{
    Do ##class(%IPM.Repo.UniversalSettings).SetValue(..#TestIndx, "new value c", 0)
    Set value = ##class(%IPM.Repo.UniversalSettings).GetValue(..#TestIndx)
    Do $$$AssertEquals(value, "default value")
}

/// Run by <B>RunTest</B> immediately after each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required. 
/// </dl> 
Method OnAfterOneTest(testname As %String) As %Status
{
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Kill ^IPM.settings(..#TestIndx)
    Quit $$$OK
}

/// Run by <B>RunTest</B> immediately before each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required. 
/// </dl> 
Method OnBeforeOneTest(testname As %String) As %Status
{
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set ^IPM.settings(..#TestIndx) = "default value"
    Quit $$$OK
}

}
