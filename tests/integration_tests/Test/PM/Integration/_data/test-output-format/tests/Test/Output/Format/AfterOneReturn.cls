/// Demonstrates OnAfterOneTest returning an error status; assertions are recorded before teardown fails.
Class Test.Output.Format.AfterOneReturn Extends %UnitTest.TestCase
{

Method OnAfterOneTest(testName As %String) As %Status
{
    return $$$ERROR($$$GeneralError, "deliberate OnAfterOneTest return-error for "_testName)
}

Method TestMethodBodyPasses()
{
    do $$$AssertTrue(1, "the method body runs and this assertion is recorded before teardown fails")
}

}
