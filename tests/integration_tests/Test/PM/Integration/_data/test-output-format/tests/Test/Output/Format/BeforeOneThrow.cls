/// Demonstrates OnBeforeOneTest throwing; each method is individually aborted.
Class Test.Output.Format.BeforeOneThrow Extends %UnitTest.TestCase
{

Method OnBeforeOneTest(testName As %String) As %Status
{
    $$$ThrowStatus($$$ERROR($$$GeneralError, "deliberate OnBeforeOneTest throw for "_testName))
}

Method TestFirstMethod()
{
    do $$$AssertTrue(1, "this would pass if OnBeforeOneTest had not thrown")
}

Method TestSecondMethod()
{
    do $$$AssertTrue(1, "this would also pass if OnBeforeOneTest had not thrown")
}

}
