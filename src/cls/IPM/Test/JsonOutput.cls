Class %IPM.Test.JsonOutput Extends %IPM.Test.Abstract
{

ClassMethod ToFile(
	FileName As %String,
	TestStatus As %String = "",
	TestIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status
{
    set sc = $$$OK
    try {
        set fileStream = ##class(%Stream.FileCharacter).%New()
        set fileStream.TranslateTable = "UTF8"
        $$$ThrowOnError(fileStream.LinkToFile(FileName))
        set responseJson = ..JSON(TestIndex, TestStatus)
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
	TestIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
	pCaseStatus As %String = "") As %Status
{
    set sc = $$$OK
    try {
        set responseJson = ..JSON(TestIndex, pCaseStatus)
        write !
        if $isobject(responseJson) {
            do responseJson.%ToJSON()
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod JSON(
	TestIndex As %Integer,
	TestStatus As %String) As %DynamicObject
{
    if TestStatus'="" {
        set tResult = ..FilteredTestResultsFunc(TestIndex, TestStatus)
    } else {
         set tResult = ..GetAllTestResultsFunc(TestIndex)
    }
    set unitTest = {}
    set unitTest.results = []
    set (previousID,currentSuite,currentTestcase,suiteObj,testcaseObj) = ""

    while tResult.%Next() {
        if previousID = "" {
            set unitTest.id = TestIndex
            set unitTest.namespace = tResult.namespace
            set unitTest.duration = tResult.duration
            set unitTest.testDateTime = tResult.testDateTime
        }
        set previousID = TestIndex
        if tResult.suiteName '= currentSuite {
            set currentSuite = tResult.suiteName
            set suiteObj = {
                "suiteName": (currentSuite),
                "testcases": []
            }
            do unitTest.results.%Push(suiteObj)
            set currentTestcase = ""
        }
        if tResult.testcaseName '= currentTestcase {
            set currentTestcase = tResult.testcaseName
            set testcaseObj = {
                "testcaseName": (currentTestcase),
                "methods": []
            }
            do suiteObj.testcases.%Push(testcaseObj)
        }
        set methodObj = {
            "methodName": (tResult.methodName),
            "testMethod": (tResult.testMethod),
            "assertAction": (tResult.assertAction),
            "assertCounter": (tResult.assertCounter),
            "assertDescription": (tResult.assertDescription),
            "assertLocation": (tResult.assertLocation)
        }
        do testcaseObj.methods.%Push(methodObj)
    }
	return unitTest
}

}
