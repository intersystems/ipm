/// Ill-formed test case with only start tag but no end tag.
Class Test.PM.Unit.LanguageExtension.IllFormedTags Extends Test.PM.Unit.LanguageExtension.Abstract
{

Parameter IsAbstractTestCase As Boolean = 0;

/// Construct the expected content of the routine after the language extension is updated.
/// Also construct the expected "found" value indicating if an older language extension was found.
ClassMethod GetExpected(Output content, Output found)
{
    Set found = 1

    Set content($Increment(content)) = ..#CustomCode
    Do ..AppendStart(.content)
    Do ..AppendLangExt2(.content)
    Do ..AppendEnd(.content)
}

/// Construct the initial content of the routine. Could be empty.
ClassMethod GetInitial(Output content)
{
    Set content($Increment(content)) = ..#CustomCode
    Do ..AppendStart(.content)
    Do ..AppendLangExt1(.content)
    Set content($Increment(content)) = ..#CustomCode
}

}
