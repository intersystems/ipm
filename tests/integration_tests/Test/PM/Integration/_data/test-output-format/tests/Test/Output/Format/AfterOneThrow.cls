/// Demonstrates OnAfterOneTest throwing; assertions are recorded before teardown throws.
Class Test.Output.Format.AfterOneThrow Extends %UnitTest.TestCase
{

Method OnAfterOneTest(testName As %String) As %Status
{
    $$$ThrowStatus($$$ERROR($$$GeneralError, "deliberate OnAfterOneTest throw for "_testName))
}

Method TestMethodBodyPasses()
{
    do $$$AssertTrue(1, "the method body runs and this assertion is recorded before teardown throws")
}

}
