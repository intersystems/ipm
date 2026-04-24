/// Base class for all unit test result formatters.
Class %IPM.Test.Abstract Extends %RegisteredObject
{

/// Comma-separated list of valid output format names (lowercase).
/// Must stay in sync with the valueList on the format modifier in %IPM.Main.
Parameter VALIDFORMATS = "json,yaml,toon";

ClassMethod ToFile(
    fileName As %String,
    testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status
{
    set sc = $$$OK
    try {
        set fileStream = ##class(%Stream.FileCharacter).%New()
        set fileStream.TranslateTable = "UTF8"
        $$$ThrowOnError(fileStream.LinkToFile(fileName))
        do ..WriteToFileStream(fileStream, testIndex)
        $$$ThrowOnError(fileStream.%Save())
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod WriteToFileStream(
    fileStream As %Stream.FileCharacter,
    testIndex As %Integer) [ Abstract ]
{
}

/// verbose: show all methods (not just failures) in the detail section.
/// showDetail: show the results/failures section at all; when 0 only the summary is written.
ClassMethod OutputToDevice(
    testIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
    verbose As %Boolean = 0,
    showDetail As %Boolean = 1) As %Status
{
    set sc = $$$OK
    try {
        set tree = ..BuildResultTree(testIndex)
        set summary = ..GetSummary(testIndex, tree)
        write !!,"Test Run #"_summary.id_" ("_summary.namespace_") "_summary.duration_"s "_summary.testDateTime
        write !,"Methods: "_summary.methods.total_" total, "_summary.methods.passed_" passed, "_summary.methods.failed_" failed"
        write !,"Assertions: "_summary.assertions.total_" total, "_summary.assertions.passed_" passed, "_summary.assertions.failed_" failed"

        if showDetail && verbose {
            write !
            set suiteIter = tree.suites.%GetIterator()
            while suiteIter.%GetNext(, .suiteObj) {
                set caseIter = suiteObj.cases.%GetIterator()
                while caseIter.%GetNext(, .caseObj) {
                    if caseObj.error '= "" {
                        write !,suiteObj.name_"/"_caseObj.name_" [failed] "_caseObj.error
                    }
                    set methodIter = caseObj.methods.%GetIterator()
                    while methodIter.%GetNext(, .methodObj) {
                        write !,suiteObj.name_"/"_caseObj.name_"/"_methodObj.name_" ["_methodObj.status_"]"
                        if methodObj.error '= "" { write " "_methodObj.error }
                    }
                }
            }
        } elseif showDetail && (summary.methods.failed > 0) {
            write !
            set suiteIter = tree.suites.%GetIterator()
            while suiteIter.%GetNext(, .suiteObj) {
                set caseIter = suiteObj.cases.%GetIterator()
                while caseIter.%GetNext(, .caseObj) {
                    if caseObj.error '= "" {
                        write !,suiteObj.name_"/"_caseObj.name_" [failed] "_caseObj.error
                    }
                    set methodIter = caseObj.methods.%GetIterator()
                    while methodIter.%GetNext(, .methodObj) {
                        if methodObj.status = "failed" {
                            write !,suiteObj.name_"/"_caseObj.name_"/"_methodObj.name_" [failed]"
                            if methodObj.error '= "" { write " "_methodObj.error }
                        }
                    }
                }
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Walks ^UnitTest.Result and returns a fully-populated result tree.
/// Non-assertion failures (thrown errors, lifecycle hook failures) appear
/// as non-empty "error" fields on method and case nodes rather than as
/// assert entries.
///
/// ^UnitTest.Result global structure:
///   (testIndex, suite)                        → $list(status, time)
///   (testIndex, suite, case)                  → $list(status, time, errCategory, errMsg)
///   (testIndex, suite, case, method)          → $list(status, time, errCategory, errMsg)
///   (testIndex, suite, case, method, counter) → $list(assertPassed, action, description, location)
/// status/assertPassed: 1=pass, 0=fail
/// errCategory/errMsg: non-empty only when a lifecycle hook or thrown error caused the failure
/// Instance metadata (Namespace, Duration, DateTime) lives in %UnitTest_Result.TestInstance
ClassMethod BuildResultTree(testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %DynamicObject
{
    set meta = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Namespace,Duration,DateTime FROM %UnitTest_Result.TestInstance WHERE ID=?",
        testIndex)
    set ns = ""
    set duration = ""
    set testDateTime = ""
    if meta.%Next() {
        set ns = meta.%Get("Namespace")
        set duration = meta.%Get("Duration")
        set testDateTime = meta.%Get("DateTime")
    }

    set tree = {
        "id": (testIndex),
        "namespace": (ns),
        "duration": (duration),
        "testDateTime": (testDateTime),
        "suites": []
    }

    set suite = ""
    for {
        set suite = $order(^UnitTest.Result(testIndex, suite), 1, suiteData)
        quit:suite=""

        set suiteObj = {"name": (suite), "status": "passed", "cases": []}
        do tree.suites.%Push(suiteObj)

        set testCase = ""
        for {
            set testCase = $order(^UnitTest.Result(testIndex, suite, testCase), 1, caseData)
            quit:testCase=""

            set caseStatus = $select($listget(caseData, 1) '= 0: "passed", 1: "failed")
            set caseError = ""
            if caseStatus = "failed" {
                set errCat = $listget(caseData, 3)
                // Only set when errCat is non-empty; errMsg alone is IRIS's own aggregation
                // string ("There are failed TestMethods") and not a real error message.
                if errCat '= "" {
                    set caseError = errCat_": "_$listget(caseData, 4)
                }
            }
            set caseObj = {"name": (testCase), "status": (caseStatus), "error": (caseError), "methods": []}
            do suiteObj.cases.%Push(caseObj)

            if caseStatus = "failed" {
                set suiteObj.status = "failed"
            }

            set method = ""
            for {
                set method = $order(^UnitTest.Result(testIndex, suite, testCase, method), 1, methodData)
                quit:method=""

                set methodStatus = $select($listget(methodData, 1) '= 0: "passed", 1: "failed")
                set methodError = ""
                if methodStatus = "failed" {
                    set errCat = $listget(methodData, 3)
                    if errCat '= "" {
                        set methodError = errCat_": "_$listget(methodData, 4)
                    }
                }
                set methodObj = {
                    "name": (method),
                    "status": (methodStatus),
                    "duration": ($listget(methodData, 2)),
                    "error": (methodError),
                    "asserts": []
                }
                do caseObj.methods.%Push(methodObj)

                set assert = ""
                for {
                    set assert = $order(^UnitTest.Result(testIndex, suite, testCase, method, assert), 1, assertData)
                    quit:assert=""
                    set assertObj = {
                        "counter": (assert),
                        "status": ($select($listget(assertData, 1) '= 0: "passed", 1: "failed")),
                        "action": ($listget(assertData, 2)),
                        "description": ($listget(assertData, 3)),
                        "location": ($listget(assertData, 4))
                    }
                    do methodObj.asserts.%Push(assertObj)
                }
            }
        }
    }
    return tree
}

/// Returns a summary %DynamicObject with run metadata and method/assertion counts.
/// Counts methods as failed if any assert failed OR if a non-assertion error occurred.
/// Pass a pre-built tree to avoid a second ^UnitTest.Result traversal.
ClassMethod GetSummary(testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}, tree As %DynamicObject = "") As %DynamicObject
{
    if tree = "" {
        set tree = ..BuildResultTree(testIndex)
    }
    set (assertTotal, assertPassed, assertFailed) = 0
    set (methodTotal, methodPassed, methodFailed) = 0

    set suiteIter = tree.suites.%GetIterator()
    while suiteIter.%GetNext(, .suiteObj) {
        set caseIter = suiteObj.cases.%GetIterator()
        while caseIter.%GetNext(, .caseObj) {
            set methodIter = caseObj.methods.%GetIterator()
            while methodIter.%GetNext(, .methodObj) {
                set methodTotal = methodTotal + 1
                if methodObj.status = "passed" {
                    set methodPassed = methodPassed + 1
                } else {
                    set methodFailed = methodFailed + 1
                }
                set assertIter = methodObj.asserts.%GetIterator()
                while assertIter.%GetNext(, .assertObj) {
                    set assertTotal = assertTotal + 1
                    if assertObj.status = "passed" {
                        set assertPassed = assertPassed + 1
                    } else {
                        set assertFailed = assertFailed + 1
                    }
                }
            }
            // Case-level error from a lifecycle hook (OnBeforeAllTests, OnAfterAllTests) — count it as one failed method
            if caseObj.error '= "" {
                set methodTotal = methodTotal + 1
                set methodFailed = methodFailed + 1
            }
        }
    }

    return {
        "id": (testIndex),
        "namespace": (tree.namespace),
        "duration": (tree.duration),
        "testDateTime": (tree.testDateTime),
        "methods": {
            "total": (methodTotal),
            "passed": (methodPassed),
            "failed": (methodFailed)
        },
        "assertions": {
            "total": (assertTotal),
            "passed": (assertPassed),
            "failed": (assertFailed)
        }
    }
}

}
