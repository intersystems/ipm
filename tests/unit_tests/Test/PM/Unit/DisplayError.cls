Class Test.PM.Unit.DisplayError Extends %UnitTest.TestCase
{

Method TestTrailingBracketKept()
{
    set sc = $$$ERROR($$$GeneralError, "Issue: {'errors': [{'status': 401}]} [a:b]")
    do $$$AssertEquals(##class(%IPM.Main).ErrorText(sc), "Issue: {'errors': [{'status': 401}]} [a:b]")
}

Method TestEmbeddedError()
{
    set sc = $$$EMBEDSC($$$ERROR($$$GeneralError, "outer [a:b]"), $$$ERROR($$$GeneralError, "inner [c:d]"))
    do $$$AssertEquals(##class(%IPM.Main).ErrorText(sc), "outer [a:b]" _ $char(13,10) _ "  > inner [c:d]")
}

Method TestAppendedErrors()
{
    set sc = $$$ADDSC($$$ERROR($$$GeneralError, "first [a:b]"), $$$ERROR($$$GeneralError, "second [c:d]"))
    do $$$AssertEquals(##class(%IPM.Main).ErrorText(sc), "first [a:b]" _ $char(13,10) _ "second [c:d]")
}

}
