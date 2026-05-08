/// Demonstrates OnBeforeAllTests throwing; no test methods run.
Class Test.Output.Format.BeforeAllThrow Extends %UnitTest.TestCase
{

Method OnBeforeAllTests() As %Status
{
    $$$ThrowStatus($$$ERROR($$$GeneralError, "deliberate OnBeforeAllTests throw"))
}

Method TestWouldPass()
{
    do $$$AssertTrue(1, "this would pass if OnBeforeAllTests had not thrown")
}

}
