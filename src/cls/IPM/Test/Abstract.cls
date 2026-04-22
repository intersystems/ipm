/// The class serves as the base class for all the unit test result formatting.
Class %IPM.Test.Abstract Extends %RegisteredObject
{

ClassMethod ToFile(
	fileName As %String,
	caseStatus As %String = "",
	testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status [ Abstract ]
{
}

ClassMethod OutputToDevice(
	testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status [ Abstract ]
{
}

/// Returns a summary %DynamicObject with run metadata and method/assertion counts.
/// A method is counted as "failed" if any of its assertions failed.
ClassMethod GetSummary(testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %DynamicObject
{
    set result = ..GetAllTestResultsFunc(testIndex)
    set (ns, duration, testDateTime) = ""
    set (assertTotal, assertPassed, assertFailed) = 0

    while result.%Next() {
        if ns = "" {
            set ns = result.namespace
            set duration = result.duration
            set testDateTime = result.testDateTime
        }
        if result.assertStatus = "passed" {
            set assertTotal = assertTotal + 1
            set assertPassed = assertPassed + 1
        } elseif result.assertStatus = "failed" {
            set assertTotal = assertTotal + 1
            set assertFailed = assertFailed + 1
        }
        // Track method status — once "failed", stays "failed" even if later assertions pass
        set methodKey = result.suiteName_"||"_result.testcaseName_"||"_result.methodName
        if '$data(seenMethods(methodKey)) {
            set seenMethods(methodKey) = ""
        }
        if result.assertStatus = "failed" {
            set seenMethods(methodKey) = "failed"
        } elseif (result.assertStatus = "passed") && (seenMethods(methodKey) '= "failed") {
            set seenMethods(methodKey) = "passed"
        }
    }

    set (methodTotal, methodPassed, methodFailed) = 0
    set key = ""
    for {
        set key = $order(seenMethods(key), 1, status)
        quit:key=""
        if status = "passed" {
            set methodTotal = methodTotal + 1
            set methodPassed = methodPassed + 1
        } elseif status = "failed" {
            set methodTotal = methodTotal + 1
            set methodFailed = methodFailed + 1
        }
    }

    return {
        "id": (testIndex),
        "namespace": (ns),
        "duration": (duration),
        "testDateTime": (testDateTime),
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

Query FilteredTestResults(
	instance As %Integer,
	testStatus) As %SQLQuery(ROWSPEC = "namespace:%String,duration:%String,testDateTime:%String,suiteName:%String,testcaseName:%String,methodName:%String,testMethod:%String,assertAction:%String,assertCounter:%Integer,assertDescription:%String,assertLocation:%String,assertStatus:%String", SELECTMODE = "DISPLAY")
{
SELECT
    inst.Namespace AS namespace,
    inst.Duration AS duration,
    inst.DateTime AS testDateTime,
    suite.Name AS suiteName,
    testCase.Name AS testcaseName,
    method.Name AS methodName,
    testAssert.TestMethod AS testMethod,
    testAssert.Action AS assertAction,
    testAssert.Counter AS assertCounter,
    testAssert.Description AS assertDescription,
    testAssert.Location AS assertLocation,
    testAssert.Status AS assertStatus
FROM
%UnitTest_Result.TestInstance inst
JOIN %UnitTest_Result.TestSuite suite ON suite.TestInstance=inst.ID
JOIN %UnitTest_Result.TestCase testCase ON testCase.TestSuite=suite.ID
JOIN %UnitTest_Result.TestMethod method ON method.TestCase=testCase.ID
JOIN %UnitTest_Result.TestAssert testAssert ON testAssert.TestMethod=method.ID
WHERE inst.ID=:instance AND testAssert.Status=:testStatus
}

Query GetAllTestResults(instance As %Integer) As %SQLQuery(ROWSPEC = "namespace:%String,duration:%String,testDateTime:%String,suiteName:%String,testcaseName:%String,methodName:%String,testMethod:%String,assertAction:%String,assertCounter:%Integer,assertDescription:%String,assertLocation:%String,assertStatus:%String", SELECTMODE = "DISPLAY")
{
SELECT
    inst.Namespace AS namespace,
    inst.Duration AS duration,
    inst.DateTime AS testDateTime,
    suite.Name AS suiteName,
    testCase.Name AS testcaseName,
    method.Name AS methodName,
    testAssert.TestMethod AS testMethod,
    testAssert.Action AS assertAction,
    testAssert.Counter AS assertCounter,
    testAssert.Description AS assertDescription,
    testAssert.Location AS assertLocation,
    testAssert.Status AS assertStatus
FROM
%UnitTest_Result.TestInstance inst
JOIN %UnitTest_Result.TestSuite suite ON suite.TestInstance=inst.ID
JOIN %UnitTest_Result.TestCase testCase ON testCase.TestSuite=suite.ID
JOIN %UnitTest_Result.TestMethod method ON method.TestCase=testCase.ID
JOIN %UnitTest_Result.TestAssert testAssert ON testAssert.TestMethod=method.ID
WHERE inst.ID=:instance
}

}
