Class %IPM.Test.JsonOutput Extends %IPM.Test.Abstract
{

ClassMethod ToFile(
	pFileName As %String,
	pTestStatus As %String = "",
	pTestIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status
{
    set tSC = $$$OK
    try {
        set fileStream = ##class(%Stream.FileCharacter).%New()
        set fileStream.TranslateTable="UTF8"
        do fileStream.LinkToFile(pFileName)
        set responseJson = ..JSON(pTestIndex, pTestStatus)
        do fileStream.Write(responseJson.%ToJSON())
        $$$ThrowOnError(fileStream.%Save())
    } catch e {
        set tSC = e.AsStatus()
    }
    return tSC
}

ClassMethod OutputToDevice(
	pTestIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
	pCaseStatus As %String = "") As %Status
{
    set tSC = $$$OK
    try {
        set responseJson= ..JSON(pTestIndex, pCaseStatus)
        write !
        do responseJson.%ToJSON()
    } catch e {
        set tSC = e.AsStatus()
    }
    return tSC
}

ClassMethod JSON(
	pTestIndex,
	pTestStatus) As %DynamicObject
{
    if pTestStatus'=""{
        set tResult = ..FilteredTestResultsFunc(pTestIndex,pTestStatus)
    } else {
         set tResult = ..GetAllTestResultsFunc(pTestIndex)
    }
    set unitTest = {}
    set unitTest.results = []
    set (previousID,currentSuite,currentTestcase,suiteObj,testcaseObj) = ""

    while tResult.%Next() {
        if previousID = "" {
            set unitTest.id = pTestIndex
            set unitTest.namespace = tResult.namespace
            set unitTest.duration = tResult.duration
            set unitTest.testDateTime = tResult.testDateTime
        }
        set previousID = pTestIndex
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
