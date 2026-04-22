/// Base class for all unit test result formatters.
Class %IPM.Test.Abstract Extends %RegisteredObject
{

ClassMethod ToFile(
    fileName As %String,
    testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status [ Abstract ]
{
}

ClassMethod OutputToDevice(
    testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status [ Abstract ]
{
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
ClassMethod GetSummary(testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %DynamicObject
{
    set tree = ..BuildResultTree(testIndex)
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
            // Case-level error (e.g. OnBeforeAllTests failure) — no methods ran
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
