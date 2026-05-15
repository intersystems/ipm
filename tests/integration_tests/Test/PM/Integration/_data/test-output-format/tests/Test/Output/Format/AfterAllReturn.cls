/// Demonstrates OnAfterAllTests returning an error status; all test methods run first.
Class Test.Output.Format.AfterAllReturn Extends %UnitTest.TestCase
{

Method OnAfterAllTests() As %Status
{
    return $$$ERROR($$$GeneralError, "deliberate OnAfterAllTests return-error")
}

Method TestPassesNormally()
{
    do $$$AssertTrue(1, "this runs and passes; failure occurs only in OnAfterAllTests")
}

}
