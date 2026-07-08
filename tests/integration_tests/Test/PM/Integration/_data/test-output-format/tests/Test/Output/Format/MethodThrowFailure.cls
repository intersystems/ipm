/// Demonstrates a thrown error in a test method body.
Class Test.Output.Format.MethodThrowFailure Extends %UnitTest.TestCase
{

Method TestPassesNormally()
{
    do $$$AssertTrue(1, "this passes before the throwing method runs")
}

Method TestThrowsFromBody()
{
    do $$$AssertTrue(1, "this assertion runs before the throw")
    $$$ThrowStatus($$$ERROR($$$GeneralError, "deliberate throw from test body"))
}

Method TestAfterThrow()
{
    do $$$AssertTrue(1, "this method runs independently after the throwing method")
}

}
