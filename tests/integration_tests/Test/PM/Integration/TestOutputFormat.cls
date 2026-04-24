Class Test.PM.Integration.TestOutputFormat Extends Test.PM.Integration.Base
{

/// The module is loaded once for the class rather than per-method because each `test` run
/// is fast and re-loading would dominate test time. This is safe because:
///   (1) each test method triggers its own `test` run, producing a new ^UnitTest.Result index,
///   (2) all tests that need the latest index use $order(^UnitTest.Result(""),-1), so they
///       always query their own run rather than a stale one,
///   (3) the test module has no side effects outside ^UnitTest.Result.
/// Adding new test methods: trigger a fresh `test` run or re-use the latest index — do not
/// rely on a specific index value from a previous test method.
Method OnBeforeAllTests() As %Status
{
    set sc = ##class(%IPM.Main).Shell("load " _ ..GetModuleDir("test-output-format"))
    do $$$AssertStatusOK(sc, "Loaded test-output-format module")
    return sc
}

Method OnAfterAllTests() As %Status
{
    do ##class(%IPM.Main).Shell("config delete TestReportFormat")
    do ##class(%IPM.Main).Shell("uninstall test-output-format")
    return $$$OK
}

/// Reset format config before each test so format-specific tests don't pollute each other.
Method OnBeforeOneTest(testName As %String) As %Status
{
    do ##class(%IPM.Main).Shell("config delete TestReportFormat")
    return $$$OK
}

/// Helper: join captured output array into a single string
ClassMethod JoinOutput(ByRef pOutput) As %String [ Private ]
{
    set result = ""
    set i = ""
    for {
        set i = $order(pOutput(i))
        quit:i=""
        set result = result _ pOutput(i) _ $char(10)
    }
    return result
}


/// Default (no -f, no config): summary + legacy FAILED lines, no formatted sections.
Method TestDefaultOutput()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set content = ..JoinOutput(.output)
    do $$$AssertTrue(content [ "12 failed", "summary reports 12 failed methods")
    do $$$AssertNotTrue(content [ "failures[", "no toon failures section without -f")
    do $$$AssertNotTrue(content [ "results[", "no toon results section without -f")
}

/// Verbose without -f: summary only (no results/failures section), plus legacy FAILED lines.
Method TestVerboseOutput()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -verbose")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set content = ..JoinOutput(.output)
    do $$$AssertTrue(content [ "12 failed", "summary reports 12 failed methods")
    do $$$AssertNotTrue(content [ "results[", "no results section without -f")
    do $$$AssertNotTrue(content [ "failures[", "no failures section without -f")
}

/// -f toon: summary + failures section with 13 rows.
Method TestOutputFormatToon()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -f toon")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set content = ..JoinOutput(.output)
    do $$$AssertTrue(content [ "12 failed", "summary reports 12 failed methods")
    do $$$AssertTrue(content [ "failures[13]", "failures section has 13 rows")
    do $$$AssertNotTrue(content [ "results[", "no results section in default mode")
}

/// -f toon -verbose: results section with all rows, no failures section.
Method TestVerboseOutputFormatToon()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -verbose -f toon")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set content = ..JoinOutput(.output)
    do $$$AssertTrue(content [ "12 failed", "summary reports 12 failed methods")
    do $$$AssertTrue(content [ "results[", "results section present with -verbose -f toon")
    do $$$AssertNotTrue(content [ "failures[", "no failures section in verbose mode")
}

/// -f json: summary + failures as JSON object.
Method TestOutputFormatJson()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -f json")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")

    set raw = ..JoinOutput(.output)
    set jsonStart = $find(raw, "{") - 1
    set jsonEnd = $length(raw) - $find($reverse(raw), "}") + 2
    set jsonStr = $extract(raw, jsonStart, jsonEnd)

    set parsed = ##class(%DynamicAbstractObject).%FromJSON(jsonStr)
    do $$$AssertTrue($isobject(parsed), "JSON output is parseable")
    do $$$AssertTrue($isobject(parsed.failures), "JSON output has failures array")
    do $$$AssertEquals(parsed.failures.%Size(), 13, "JSON failures array has 13 entries")
    do $$$AssertNotTrue($isobject(parsed.methods), "JSON output does not have methods array in default mode")
}

/// -f json -verbose: methods array with all methods, no failures array.
Method TestVerboseOutputFormatJson()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -verbose -f json")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")

    set raw = ..JoinOutput(.output)
    set jsonStart = $find(raw, "{") - 1
    set jsonEnd = $length(raw) - $find($reverse(raw), "}") + 2
    set jsonStr = $extract(raw, jsonStart, jsonEnd)

    set parsed = ##class(%DynamicAbstractObject).%FromJSON(jsonStr)
    do $$$AssertTrue($isobject(parsed), "Verbose JSON output is parseable")
    do $$$AssertTrue($isobject(parsed.methods), "Verbose JSON output has methods array")
    do $$$AssertTrue(parsed.methods.%Size() > 0, "Verbose JSON methods array is non-empty")
    do $$$AssertNotTrue($isobject(parsed.failures), "Verbose JSON output does not have failures array")
}

/// -f yaml: summary + failures block.
Method TestOutputFormatYaml()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -f yaml")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set content = ..JoinOutput(.output)
    do $$$AssertTrue(content [ "failed: 12", "YAML summary reports 12 failed methods")
    do $$$AssertTrue(content [ ($char(10)_"failures:"), "YAML output has failures block")
    do $$$AssertNotTrue(content [ ($char(10)_"results:"), "YAML output has no results block in default mode")
}

/// -f yaml -verbose: results block present, no failures block.
Method TestVerboseOutputFormatYaml()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -verbose -f yaml")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set content = ..JoinOutput(.output)
    do $$$AssertTrue(content [ ($char(10)_"results:"), "Verbose YAML output has results block")
    do $$$AssertNotTrue(content [ ($char(10)_"failures:"), "Verbose YAML output has no failures block")
}

/// Config default: setting TestReportFormat=json makes default output use json.
Method TestConfigDefault()
{
    do ##class(%IPM.Main).Shell("config set TestReportFormat json")
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set raw = ..JoinOutput(.output)
    set jsonStart = $find(raw, "{") - 1
    set jsonEnd = $length(raw) - $find($reverse(raw), "}") + 2
    set jsonStr = $extract(raw, jsonStart, jsonEnd)

    set parsed = ##class(%DynamicAbstractObject).%FromJSON(jsonStr)
    do $$$AssertTrue($isobject(parsed), "Config default JSON output is parseable")
    do $$$AssertTrue($isobject(parsed.failures), "Config default shows failures")
}

/// -f overrides config: config=yaml but -f json should produce JSON.
Method TestFormatOverridesConfig()
{
    do ##class(%IPM.Main).Shell("config set TestReportFormat yaml")
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -f json")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set raw = ..JoinOutput(.output)
    set jsonStart = $find(raw, "{") - 1
    set jsonEnd = $length(raw) - $find($reverse(raw), "}") + 2
    set jsonStr = $extract(raw, jsonStart, jsonEnd)

    set parsed = ##class(%DynamicAbstractObject).%FromJSON(jsonStr)
    do $$$AssertTrue($isobject(parsed), "-f json overrides config=yaml")
}

/// Quiet output: suppresses test runner noise, shows summary only (no failures section without -f).
/// Known gap: two pre-phase lines ([USER|ZPM] Test START, Building dependency graph) still escape suppression.
Method TestQuietOutput()
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -quiet")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    set content = ..JoinOutput(.output)
    do $$$AssertTrue(content [ "12 failed", "summary reports 12 failed methods in quiet mode")
    do $$$AssertNotTrue(content [ "failures[", "no failures section without -f")
}

/// -output-file .toon: ToFile always writes all rows under results[N], not failures-only.
Method TestOutputFileToon()
{
    set tmpFile = ##class(%Library.File).TempFilename() _ ".toon"
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -output-file """ _ tmpFile _ """")
    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    do $$$AssertTrue(##class(%File).GetFileSize(tmpFile) > 0, "Toon output file is non-empty")

    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(tmpFile))
    set content = ""
    while 'fileStream.AtEnd {
        set content = content _ fileStream.ReadLine() _ $char(10)
    }
    do $$$AssertTrue(content [ "unitTest:", "Toon file has unitTest header")
    do $$$AssertTrue(content [ "results[", "Toon file has results header")
    do $$$AssertTrue(content [ "deliberate failure", "Toon file contains known failure text")
    do ##class(%File).Delete(tmpFile)
}

/// -output-file .yaml: file contains unitTest header and results section.
Method TestOutputFileYaml()
{
    set tmpFile = ##class(%Library.File).TempFilename() _ ".yaml"
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -output-file """ _ tmpFile _ """")
    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    do $$$AssertTrue(##class(%File).GetFileSize(tmpFile) > 0, "YAML output file is non-empty")

    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(tmpFile))
    set content = ""
    while 'fileStream.AtEnd {
        set content = content _ fileStream.ReadLine() _ $char(10)
    }
    do $$$AssertTrue(content [ "unitTest:", "YAML file has unitTest header")
    do $$$AssertTrue(content [ "id: ", "YAML file has id field")
    do $$$AssertTrue(content [ "namespace:", "YAML file has namespace field")
    do $$$AssertTrue(content [ "results:", "YAML file has results section")
    do ##class(%File).Delete(tmpFile)
}

/// -output-file .json: file is valid JSON with expected structure.
Method TestOutputFileJson()
{
    set tmpFile = ##class(%Library.File).TempFilename() _ ".json"
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -output-file """ _ tmpFile _ """")
    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    do $$$AssertTrue(##class(%File).GetFileSize(tmpFile) > 0, "JSON output file is non-empty")

    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(tmpFile))
    set parsed = ##class(%DynamicAbstractObject).%FromJSON(fileStream)
    do $$$AssertTrue($isobject(parsed), "JSON file is parseable")
    do $$$AssertTrue(parsed.id '= "", "JSON file has id field")
    do $$$AssertTrue(parsed.namespace '= "", "JSON file has namespace field")
    do $$$AssertTrue($isobject(parsed.suites), "JSON file has suites array")
    do ##class(%File).Delete(tmpFile)
}

/// -output-file .xml: file is valid JUnit XML.
Method TestOutputFileXml()
{
    set tmpFile = ##class(%Library.File).TempFilename() _ ".xml"
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only -output-file """ _ tmpFile _ """")
    do $$$AssertStatusNotOK(sc, "test run returns error when failures exist")
    do $$$AssertTrue(##class(%File).GetFileSize(tmpFile) > 0, "XML output file is non-empty")

    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(tmpFile))
    set content = ""
    while 'fileStream.AtEnd {
        set content = content _ fileStream.ReadLine() _ $char(10)
    }
    do $$$AssertTrue(content [ "<testsuites>", "XML file has <testsuites> root element")
    do $$$AssertTrue(content [ "</testsuites>", "XML file has closing </testsuites>")
    do ##class(%File).Delete(tmpFile)
}

/// GetSummary returns correct counts for the test-output-format module run.
Method TestGetSummary()
{
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only")
    set testIndex = $order(^UnitTest.Result(""), -1)

    set summary = ##class(%IPM.Test.Abstract).GetSummary(testIndex)
    do $$$AssertTrue($isobject(summary), "GetSummary returns an object")
    do $$$AssertTrue($isobject(summary.methods), "Summary has a methods sub-object")
    do $$$AssertTrue($isobject(summary.assertions), "Summary has an assertions sub-object")
    do $$$AssertEquals(summary.methods.failed, 12, "Summary reports 12 failed methods")
    do $$$AssertEquals(summary.methods.passed, 6, "Summary reports 6 passed methods")
    do $$$AssertEquals(summary.methods.passed + summary.methods.failed, summary.methods.total, "Method counts add up")
    do $$$AssertEquals(summary.assertions.passed + summary.assertions.failed, summary.assertions.total, "Assertion counts add up")
}

/// BuildResultTree returns correct structure for the test-output-format module run.
Method TestBuildResultTree()
{
    set sc = ##class(%IPM.Main).Shell("test test-output-format -only")
    set testIndex = $order(^UnitTest.Result(""), -1)

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

}
