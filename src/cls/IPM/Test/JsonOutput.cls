Class %IPM.Test.JsonOutput Extends %IPM.Test.Abstract
{

ClassMethod ToFile(
	fileName As %String,
	caseStatus As %String = "",
	testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status
{
    set sc = $$$OK
    try {
        set fileStream = ##class(%Stream.FileCharacter).%New()
        set fileStream.TranslateTable = "UTF8"
        $$$ThrowOnError(fileStream.LinkToFile(fileName))
        set responseJson = ..JSON(testIndex, caseStatus)
        if $isobject(responseJson) {
            do fileStream.Write(responseJson.%ToJSON())
        }
        $$$ThrowOnError(fileStream.%Save())
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod OutputToDevice(
	testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status
{
    set sc = $$$OK
    try {
        set summary = ..GetSummary(testIndex)
        set failures = ..JSON(testIndex, "failed")
        set output = {
            "summary": (summary),
            "failures": (failures.results)
        }
        write !
        do output.%ToJSON()
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod JSON(
	testIndex As %Integer,
	testStatus As %String) As %DynamicObject
{
    if testStatus'="" {
        set result = ..FilteredTestResultsFunc(testIndex, testStatus)
    } else {
         set result = ..GetAllTestResultsFunc(testIndex)
    }
    set unitTest = {}
    set unitTest.results = []
    set (previousID,currentSuite,currentTestcase,suiteObj,testcaseObj) = ""

    while result.%Next() {
        if previousID = "" {
            set unitTest.id = testIndex
            set unitTest.namespace = result.namespace
            set unitTest.duration = result.duration
            set unitTest.testDateTime = result.testDateTime
        }
        set previousID = testIndex
        if result.suiteName '= currentSuite {
            set currentSuite = result.suiteName
            set suiteObj = {
                "suiteName": (currentSuite),
                "testcases": []
            }
            do unitTest.results.%Push(suiteObj)
            set currentTestcase = ""
        }
        if result.testcaseName '= currentTestcase {
            set currentTestcase = result.testcaseName
            set testcaseObj = {
                "testcaseName": (currentTestcase),
                "methods": []
            }
            do suiteObj.testcases.%Push(testcaseObj)
        }
        set methodObj = {
            "methodName": (result.methodName),
            "testMethod": (result.testMethod),
            "assertAction": (result.assertAction),
            "assertCounter": (result.assertCounter),
            "assertDescription": (result.assertDescription),
            "assertLocation": (result.assertLocation),
            "assertStatus": (result.assertStatus)
        }
        do testcaseObj.methods.%Push(methodObj)
    }
	return unitTest
}

}
