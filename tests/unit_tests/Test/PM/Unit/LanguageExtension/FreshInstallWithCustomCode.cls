/// Simulate a fresh install of the language extension, assuming the routine contains only custom code at the time of install.
Class Test.PM.Unit.LanguageExtension.FreshInstallWithCustomCode Extends Test.PM.Unit.LanguageExtension.Abstract
{

Parameter IsAbstractTestCase As Boolean = 0;

/// Construct the expected content of the routine after the language extension is updated.
/// Also construct the expected "found" value indicating if an older language extension was found.
ClassMethod GetExpected(
	Output content,
	Output found)
{
    Set found = 0

    Set content($Increment(content)) = ..#CustomCode
    Do ..AppendStart(.content)
    Do ..AppendLangExt2(.content)
    Do ..AppendEnd(.content)
}

/// Construct the initial content of the routine. Could be empty.
ClassMethod GetInitial(Output content)
{
    Set content($Increment(content)) = ..#CustomCode
}

}
