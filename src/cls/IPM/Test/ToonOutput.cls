Class %IPM.Test.ToonOutput Extends %IPM.Test.Abstract
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

        if caseStatus'="" {
            set result = ..FilteredTestResultsFunc(testIndex, caseStatus)
        } else {
            set result = ..GetAllTestResultsFunc(testIndex)
        }

        set currentID=""
        while result.%Next() {
            if currentID = "" {
                set currentID = testIndex
                do fileStream.WriteLine("unitTest:")
                do fileStream.WriteLine("  id: "_testIndex)
                do fileStream.WriteLine("  namespace: "_result.namespace)
                do fileStream.WriteLine("  duration: "_result.duration)
                do fileStream.WriteLine("  testDateTime: "_result.testDateTime)
                do fileStream.WriteLine()
                do fileStream.WriteLine("results["_result.TotalCounts_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:")
            }
            set data = "  "_result.suiteName_","_result.testcaseName_","_result.methodName_","_result.assertStatus_","_
                    result.assertAction_","_result.assertCounter_","""_$translate(result.assertDescription,"""")_""","""_result.assertLocation_""""
            do fileStream.WriteLine(data)
        }
        $$$ThrowOnError(fileStream.%Save())
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod OutputToDevice(
	testIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
	testStatus As %String = "") As %Status
{
    set sc = $$$OK
    try {
        if testStatus'="" {
            set result = ..FilteredTestResultsFunc(testIndex, testStatus)
        } else {
            set result = ..GetAllTestResultsFunc(testIndex)
        }
        set currentID=""
        while result.%Next() {
            if currentID = "" {
                set currentID = testIndex
                write !,"unitTest:"
                write !,"  id: "_testIndex
                write !,"  namespace: "_result.namespace
                write !,"  duration: "_result.duration
                write !,"  testDateTime: "_result.testDateTime
                write !
                write !,"results["_result.TotalCounts_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:"
            }
            set data = "  "_result.suiteName_","_result.testcaseName_","_result.methodName_","_result.assertStatus_","_
                    result.assertAction_","_result.assertCounter_","""_$translate(result.assertDescription,"""")_""","""_result.assertLocation_""""
            write !,data
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

}
