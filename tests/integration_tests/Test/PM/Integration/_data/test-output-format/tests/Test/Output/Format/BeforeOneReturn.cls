/// Demonstrates OnBeforeOneTest returning an error status; each method is individually aborted.
Class Test.Output.Format.BeforeOneReturn Extends %UnitTest.TestCase
{

Method OnBeforeOneTest(testName As %String) As %Status
{
    return $$$ERROR($$$GeneralError, "deliberate OnBeforeOneTest return-error for "_testName)
}

Method TestFirstMethod()
{
    do $$$AssertTrue(1, "this would pass if OnBeforeOneTest had not failed")
}

Method TestSecondMethod()
{
    do $$$AssertTrue(1, "this would also pass if OnBeforeOneTest had not failed")
}

}
