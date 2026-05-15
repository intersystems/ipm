/// Demonstrates OnAfterAllTests throwing; all test methods run first.
Class Test.Output.Format.AfterAllThrow Extends %UnitTest.TestCase
{

Method OnAfterAllTests() As %Status
{
    $$$ThrowStatus($$$ERROR($$$GeneralError, "deliberate OnAfterAllTests throw"))
}

Method TestPassesNormally()
{
    do $$$AssertTrue(1, "this runs and passes; failure occurs only in OnAfterAllTests")
}

}
