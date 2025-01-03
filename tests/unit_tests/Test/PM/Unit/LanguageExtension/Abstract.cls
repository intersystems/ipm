Include %IPM.Common

Class Test.PM.Unit.LanguageExtension.Abstract Extends %UnitTest.TestCase
{

/// Controls whether the test case will be run. Only the Abstract case should have this set to 1.
Parameter IsAbstractTestCase As Boolean = 1;

/// Name of the routine to be tested.
Parameter TestRoutine = "DummyRoutineForIPMTest.MAC";

/// Constant string to be used as custom code in the test cases.
Parameter CustomCode = " // This is some custom code";

/// Run by <B>RunTest</B> immediately before each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required. 
/// </dl> 
Method OnBeforeOneTest(testname As %String) As %Status
{
    If ##class(%Routine).Exists(..#TestRoutine) {
        Quit ##class(%Routine).Delete(..#TestRoutine)
    }
    Quit $$$OK
}

/// Run by <B>RunTest</B> immediately after each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required. 
/// </dl> 
Method OnAfterOneTest(testname As %String) As %Status
{
    Quit ..OnBeforeOneTest(testname)
}

ClassMethod AppendLangExt1(ByRef content)
{
    Set content($Increment(content)) = "ZPMDUMMYLANGUAGEEXTENSION(pArgs...)"
    Set content($Increment(content)) = " Set x = 1"
}

ClassMethod AppendLangExt2(ByRef content)
{
    Set content($Increment(content)) = "ZPMDUMMYLANGUAGEEXTENSION(pArgs...)"
    Set content($Increment(content)) = " Set y = 2"
}

ClassMethod AppendLegacyStart(ByRef content)
{
    Set content($Increment(content)) = $Replace($$$STARTTAGQ, "%IPM.Main", "%ZPM.PackageManager")
}

ClassMethod AppendLegacyEnd(ByRef content)
{
    Set content($Increment(content)) = $Replace($$$ENDTAGQ, "%IPM.Main", "%ZPM.PackageManager")
}

ClassMethod AppendStart(ByRef content)
{
    Set content($Increment(content)) = $$$STARTTAGQ
}

ClassMethod AppendEnd(ByRef content)
{
    Set content($Increment(content)) = $$$ENDTAGQ
}

ClassMethod AppendContent(ByRef dest, ByRef src)
{
    For i = 1:1:$Get(src) {
        Set dest($Increment(dest)) = src(i)
    }
}

/// Open TestRoutine, clear it, and write to it. The input should be a multi-dimensional array.
ClassMethod WriteToRoutine(ByRef input)
{
    // Creating and saving an empty routine causes the routine to contain a whitespace, which causes tests to fail.
    If '$Data(input) {
        Quit
    }
    Set routine = ##class(%Routine).%New(..#TestRoutine)
    Do routine.Clear()
    For i = 1:1:$Get(input) {
        Do routine.WriteLine(input(i))
    }
    $$$ThrowOnError(routine.Save())
}

/// Get the content of TestRoutine as a multi-dimensional array
ClassMethod ReadFromRoutine(Output output)
{
    Kill output

    If '##class(%Routine).Exists(..#TestRoutine) {
        Quit
    }
    Set routine = ##class(%Routine).%New(..#TestRoutine)
    While ('routine.AtEnd) {
        Set output($Increment(output)) = routine.ReadLine()
    }
}

ClassMethod CompareContents(ByRef content1, ByRef content2) As %Boolean
{
    If $Data(content1) '= $Data(content2) {
        Quit 0
    }
    For i = 1:1:$Get(content1) {
        If content1(i) '= content2(i) {
            Return 0
        }
    }
    Return 1
}

ClassMethod ContentToString(ByRef content, LineSep As %String = "\n") As %String
{
    Set str = ""
    For i = 1:1:$Get(content) {
        Set str = str _ content(i) _ LineSep
    }
    Quit str
}

Method TestLanguageExtension()
{
    If ..#IsAbstractTestCase {
        Do $$$AssertSkipped($classname() _ "is an abstract test case")
        Quit
    }
    // Get initial content and write to it
    Do ..GetInitial(.initialContent)
    Do ..WriteToRoutine(.initialContent)

    // Update language extension
    Do ..AppendStart(.routineContent)
    Do ..AppendLangExt2(.routineContent)
    Do ..AppendEnd(.routineContent)
    Do ##class(%IPM.Main).UpdateLanguageExtensionsOne(..#TestRoutine, 0, .found, .routineContent)

    // Get expected content, and expected found
    Do ..GetExpected(.expectedContent, .expectedFound)
    
    // Compare against routine content
    Do ..ReadFromRoutine(.outputContent)
    Do $$$AssertEquals((''found), (''expectedFound))
    If '$$$AssertTrue(..CompareContents(.outputContent, .expectedContent)) {
        Do $$$LogMessage("Output and expected content do not match !!!")
        Do $$$LogMessage("Output    : " _ ..ContentToString(.outputContent))
        Do $$$LogMessage("Expected  : " _ ..ContentToString(.expectedContent))
    }
}

/// Construct the initial content of the routine. Could be empty.
ClassMethod GetInitial(Output content)
{
}

/// Construct the expected content of the routine after the language extension is updated.
/// Also construct the expected "found" value indicating if an older language extension was found.
ClassMethod GetExpected(Output content, Output found)
{
}

}
