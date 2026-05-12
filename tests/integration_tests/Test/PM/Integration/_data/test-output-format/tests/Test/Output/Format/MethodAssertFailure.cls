/// Demonstrates assertion failures in test method bodies.
Class Test.Output.Format.MethodAssertFailure Extends %UnitTest.TestCase
{

Method TestPassingAssertions()
{
    do $$$AssertTrue(1, "one is true")
    do $$$AssertEquals("hello", "hello", "strings match")
}

Method TestFailingAssertions()
{
    do $$$AssertTrue(1, "this passes")
    do $$$AssertTrue(0, "deliberate failure: zero is not true")
    do $$$AssertEquals("expected", "actual", "deliberate mismatch")
}

Method TestAnotherPass()
{
    do $$$AssertNotTrue(0, "zero is not true")
}

}
