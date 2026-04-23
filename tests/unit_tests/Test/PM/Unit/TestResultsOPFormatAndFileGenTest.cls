/// Unit tests for the ZPM test output format classes.
/// Verifies that each format produces structurally valid, non-trivial output
/// against the most recent test run at the time the tests execute.
Class Test.PM.Unit.TestResultsOPFormatAndFileGenTest Extends %UnitTest.TestCase
{

/// Temp directory for generated report files, created in OnBeforeAllTests.
Property ReportDir As %String(MAXLEN = 512);

/// Index of the most recent completed run before this test class starts.
/// Captured in OnBeforeAllTests so TestGetSummaryHasCounts is not sensitive
/// to which test method runs first.
Property PriorRunIndex As %Integer;

Method OnBeforeAllTests() As %Status
{
    set dir = ##class(%File).NormalizeDirectory($get(^UnitTestRoot)_"/test-reports/")
    if '##class(%File).DirectoryExists(dir) {
        set sc = ##class(%File).CreateDirectoryChain(dir)
        if $$$ISERR(sc) {
            return sc
        }
    }
    set ..ReportDir = dir
    // Walk back from the current (in-progress) run to find a completed run that
    // has at least one suite with test cases. Runs with no suites (e.g. aborted
    // or setup-only runs) produce empty result trees that break tree-structure tests.
    set currentIndex = $order(^UnitTest.Result(""), -1)
    set priorIndex = $order(^UnitTest.Result(currentIndex), -1)
    while priorIndex '= "" {
        if $order(^UnitTest.Result(priorIndex, "")) '= "" {
            quit
        }
        set priorIndex = $order(^UnitTest.Result(priorIndex), -1)
    }
    set ..PriorRunIndex = priorIndex
    return $$$OK
}

Method OnAfterAllTests() As %Status
{
    if ##class(%File).DirectoryExists(..ReportDir) {
        do ##class(%File).RemoveDirectoryTree(..ReportDir)
    }
    return $$$OK
}

Method TestJsonOutputStructure()
{
    set testIndex = $order(^UnitTest.Result(""), -1)
    set fileName = ##class(%File).NormalizeFilename(..ReportDir_"test.json")

    set status = ##class(%IPM.Test.JsonOutput).ToFile(fileName, testIndex)
    do $$$AssertStatusOK(status, "JsonOutput.ToFile succeeded")
    do $$$AssertTrue(##class(%File).GetFileSize(fileName) > 0, "JSON file is non-empty")

    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(fileName))
    set parsed = ##class(%DynamicAbstractObject).%FromJSON(fileStream)
    do $$$AssertTrue($isobject(parsed), "JSON output is parseable")
    do $$$AssertTrue(parsed.id '= "", "JSON output has an id field")
    do $$$AssertTrue(parsed.namespace '= "", "JSON output has a namespace field")
    do $$$AssertTrue($isobject(parsed.suites), "JSON output has a suites array")
}

Method TestYamlOutputStructure()
{
    set testIndex = $order(^UnitTest.Result(""), -1)
    set fileName = ##class(%File).NormalizeFilename(..ReportDir_"test.yaml")

    set status = ##class(%IPM.Test.YamlOutput).ToFile(fileName, testIndex)
    do $$$AssertStatusOK(status, "YamlOutput.ToFile succeeded")
    do $$$AssertTrue(##class(%File).GetFileSize(fileName) > 0, "YAML file is non-empty")

    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(fileName))
    set content = ""
    while 'fileStream.AtEnd {
        set content = content _ fileStream.ReadLine() _ $char(10)
    }
    do $$$AssertTrue(content [ "unitTest:", "YAML output has unitTest header")
    do $$$AssertTrue(content [ "id: ", "YAML output has id field")
    do $$$AssertTrue(content [ "namespace:", "YAML output has namespace field")
    do $$$AssertTrue(content [ "results:", "YAML output has results section")
}

Method TestToonOutputStructure()
{
    set testIndex = $order(^UnitTest.Result(""), -1)
    set fileName = ##class(%File).NormalizeFilename(..ReportDir_"test.toon")

    set status = ##class(%IPM.Test.ToonOutput).ToFile(fileName, testIndex)
    do $$$AssertStatusOK(status, "ToonOutput.ToFile succeeded")
    do $$$AssertTrue(##class(%File).GetFileSize(fileName) > 0, "Toon file is non-empty")

    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(fileName))
    set content = ""
    while 'fileStream.AtEnd {
        set content = content _ fileStream.ReadLine() _ $char(10)
    }
    do $$$AssertTrue(content [ "unitTest:", "Toon output has unitTest header")
    do $$$AssertTrue(content [ "results[", "Toon output has results header with row count")
    do $$$AssertTrue(content [ "{suiteName,", "Toon output has column header line")
}

Method TestJUnitOutputStructure()
{
    set testIndex = $order(^UnitTest.Result(""), -1)
    set fileName = ##class(%File).NormalizeFilename(..ReportDir_"test.xml")

    set status = ##class(%IPM.Test.JUnitOutput).ToFile(fileName, testIndex)
    do $$$AssertStatusOK(status, "JUnitOutput.ToFile succeeded")
    do $$$AssertTrue(##class(%File).GetFileSize(fileName) > 0, "JUnit XML file is non-empty")

    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(fileName))
    set content = ""
    while 'fileStream.AtEnd {
        set content = content _ fileStream.ReadLine() _ $char(10)
    }
    do $$$AssertTrue(content [ "<?xml", "JUnit output starts with XML declaration")
    do $$$AssertTrue(content [ "<testsuites>", "JUnit output has <testsuites> root element")
    do $$$AssertTrue(content [ "<testsuite", "JUnit output has at least one <testsuite> element")
    do $$$AssertTrue(content [ "</testsuites>", "JUnit output has closing </testsuites> element")
}

Method TestGetSummaryHasCounts()
{
    set testIndex = ..PriorRunIndex
    if testIndex = "" {
        do $$$LogMessage("No prior test run available; skipping GetSummary count check")
        quit
    }

    set summary = ##class(%IPM.Test.Abstract).GetSummary(testIndex)
    do $$$AssertTrue($isobject(summary), "GetSummary returns an object")
    do $$$AssertTrue($isobject(summary.methods), "Summary has a methods sub-object")
    do $$$AssertTrue($isobject(summary.assertions), "Summary has an assertions sub-object")
    do $$$AssertTrue(summary.methods.total > 0, "Summary reports at least one method")
    do $$$AssertTrue(summary.assertions.total > 0, "Summary reports at least one assertion")
    do $$$AssertEquals(summary.methods.passed + summary.methods.failed, summary.methods.total, "Method counts add up")
    do $$$AssertEquals(summary.assertions.passed + summary.assertions.failed, summary.assertions.total, "Assertion counts add up")
}

Method TestBuildResultTreeStructure()
{
    set testIndex = ..PriorRunIndex
    if testIndex = "" {
        do $$$LogMessage("No prior test run available; skipping tree structure check")
        quit
    }

    set tree = ##class(%IPM.Test.Abstract).BuildResultTree(testIndex)
    do $$$AssertTrue($isobject(tree), "BuildResultTree returns an object")
    do $$$AssertTrue(tree.id '= "", "Tree has an id")
    do $$$AssertTrue(tree.namespace '= "", "Tree has a namespace")
    do $$$AssertTrue($isobject(tree.suites), "Tree has a suites array")
    do $$$AssertTrue(tree.suites.%Size() > 0, "Tree has at least one suite")

    set suiteObj = tree.suites.%Get(0)
    do $$$AssertTrue($isobject(suiteObj), "First suite is an object")
    do $$$AssertTrue(suiteObj.name '= "", "Suite has a name")
    do $$$AssertTrue($isobject(suiteObj.cases), "Suite has a cases array")

    set caseObj = suiteObj.cases.%Get(0)
    do $$$AssertTrue($isobject(caseObj), "First case is an object")
    do $$$AssertTrue($isobject(caseObj.methods), "Case has a methods array")
}

Method TestOutputToDeviceVerboseJson()
{
    set testIndex = ..PriorRunIndex
    if testIndex = "" {
        do $$$LogMessage("No prior test run available; skipping")
        quit
    }
    $$$ThrowOnError(##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie))
    set sc = ##class(%IPM.Test.JsonOutput).OutputToDevice(testIndex, 1)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .captured)
    $$$ThrowOnError(sc)

    set jsonStr = ""
    set i = ""
    for {
        set i = $order(captured(i))
        quit:i=""
        set jsonStr = jsonStr _ captured(i)
    }
    set parsed = ##class(%DynamicAbstractObject).%FromJSON(jsonStr)
    do $$$AssertTrue($isobject(parsed.methods), "Verbose JSON output has 'methods' key")
    do $$$AssertTrue(parsed.methods.%Size() > 0, "Verbose JSON 'methods' array is non-empty")
    do $$$AssertTrue('$isobject(parsed.failures), "Verbose JSON output does not have 'failures' key")
}

Method TestOutputToDeviceDefaultJson()
{
    set testIndex = ..PriorRunIndex
    if testIndex = "" {
        do $$$LogMessage("No prior test run available; skipping")
        quit
    }
    $$$ThrowOnError(##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie))
    set sc = ##class(%IPM.Test.JsonOutput).OutputToDevice(testIndex, 0)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .captured)
    $$$ThrowOnError(sc)

    set jsonStr = ""
    set i = ""
    for {
        set i = $order(captured(i))
        quit:i=""
        set jsonStr = jsonStr _ captured(i)
    }
    set parsed = ##class(%DynamicAbstractObject).%FromJSON(jsonStr)
    do $$$AssertTrue($isobject(parsed.failures), "Default JSON output has 'failures' key")
    do $$$AssertTrue('$isobject(parsed.methods), "Default JSON output does not have 'methods' key")
}

Method TestOutputToDeviceVerboseYaml()
{
    set testIndex = ..PriorRunIndex
    if testIndex = "" {
        do $$$LogMessage("No prior test run available; skipping")
        quit
    }
    $$$ThrowOnError(##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie))
    set sc = ##class(%IPM.Test.YamlOutput).OutputToDevice(testIndex, 1)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .captured)
    $$$ThrowOnError(sc)

    set content = ""
    set i = ""
    for {
        set i = $order(captured(i))
        quit:i=""
        set content = content _ captured(i) _ $char(10)
    }
    do $$$AssertTrue(content [ ($char(10)_"results:"), "Verbose YAML output contains 'results:' block")
    do $$$AssertTrue('(content [ ($char(10)_"failures:")), "Verbose YAML output does not contain 'failures:' block")
}

Method TestOutputToDeviceDefaultYaml()
{
    set testIndex = ..PriorRunIndex
    if testIndex = "" {
        do $$$LogMessage("No prior test run available; skipping")
        quit
    }
    set summary = ##class(%IPM.Test.Abstract).GetSummary(testIndex)
    $$$ThrowOnError(##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie))
    set sc = ##class(%IPM.Test.YamlOutput).OutputToDevice(testIndex, 0)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .captured)
    $$$ThrowOnError(sc)

    set content = ""
    set i = ""
    for {
        set i = $order(captured(i))
        quit:i=""
        set content = content _ captured(i) _ $char(10)
    }
    do $$$AssertTrue('(content [ ($char(10)_"results:")), "Default YAML output does not contain 'results:' block")
    if summary.methods.failed > 0 {
        do $$$AssertTrue(content [ ($char(10)_"failures:"), "Default YAML output contains 'failures:' block when failures exist")
    }
}

}
