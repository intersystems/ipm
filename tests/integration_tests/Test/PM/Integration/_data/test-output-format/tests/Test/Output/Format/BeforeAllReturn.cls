/// Demonstrates OnBeforeAllTests returning an error status; no test methods run.
Class Test.Output.Format.BeforeAllReturn Extends %UnitTest.TestCase
{

Method OnBeforeAllTests() As %Status
{
    return $$$ERROR($$$GeneralError, "deliberate OnBeforeAllTests return-error")
}

Method TestWouldPass()
{
    do $$$AssertTrue(1, "this would pass if OnBeforeAllTests had not failed")
}

}
