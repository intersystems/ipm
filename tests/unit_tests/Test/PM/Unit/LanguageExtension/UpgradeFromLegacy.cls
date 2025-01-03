/// Simulate upgrading from an older version of the language extension, assuming the routine contains only the older language extension.
Class Test.PM.Unit.LanguageExtension.UpgradeFromLegacy Extends Test.PM.Unit.LanguageExtension.Abstract
{

Parameter IsAbstractTestCase As Boolean = 0;

/// Construct the expected content of the routine after the language extension is updated.
/// Also construct the expected "found" value indicating if an older language extension was found.
ClassMethod GetExpected(Output content, Output found)
{
    Set found = 1

    Do ..AppendStart(.content)
    Do ..AppendLangExt2(.content)
    Do ..AppendEnd(.content)
}

/// Construct the initial content of the routine. Could be empty.
ClassMethod GetInitial(Output content)
{
    Do ..AppendStart(.content)
    Do ..AppendLangExt1(.content)
    Do ..AppendEnd(.content)
}

}
