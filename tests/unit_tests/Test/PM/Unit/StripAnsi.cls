Include %IPM.Common

/// Unit tests for %IPM.General.OutputLog:StripAnsi.
Class Test.PM.Unit.StripAnsi Extends %UnitTest.TestCase
{

Parameter NEEDSREGISTRY As BOOLEAN = 0;

Method TestPlainTextUnchanged()
{
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi(""), "", "Empty string")
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi("hello"), "hello", "No escapes")
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi("a[0mb"), "a[0mb", "Bracket text without ESC kept")
}

Method TestColorSequencesRemoved()
{
    set esc = $char(27)
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi(esc_"[39mhelp"_esc_"[0m"), "help", "Single-parameter color codes")
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi(esc_"[1;31mred"_esc_"[0m"), "red", "Multi-parameter color code")
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi("a"_esc_"[0mb"_esc_"[0mc"), "abc", "Interleaved with text")
}

/// Two-byte escapes such as ESC M (reverse index) are consumed whole.
Method TestNonCSIEscapes()
{
    set esc = $char(27)
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi(esc_"Mtext"), "text", "ESC M consumed")
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi("a"_esc_"7b"), "ab", "ESC 7 consumed")
}

/// A sequence cut off mid-parameter must not leave the ESC or spill past the end.
Method TestTruncatedSequence()
{
    set esc = $char(27)
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi("text"_esc_"[1;3"), "text", "Unterminated CSI consumed")
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi("text"_esc), "text", "Trailing ESC consumed")
}

Method TestPreservesNonAscii()
{
    set esc = $char(27)
    set square = $char(9632)
    do $$$AssertEquals(##class(%IPM.General.OutputLog).StripAnsi(esc_"[39m"_square_" Flags:"), square_" Flags:", "Wide characters kept")
}

}
