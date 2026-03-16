Class %IPM.Test.ToonOutput Extends %IPM.Test.Abstract
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

        if TestStatus'="" {
            set tResult = ..FilteredTestResultsFunc(TestIndex, TestStatus)
        } else {
            set tResult = ..GetAllTestResultsFunc(TestIndex)
        }

        set currentID=""
        while tResult.%Next() {
            if currentID = "" {
                set currentID = TestIndex
                do fileStream.WriteLine("unitTest:")
                do fileStream.WriteLine("  id: "_TestIndex)
                do fileStream.WriteLine("  namespace: "_tResult.namespace)
                do fileStream.WriteLine("  duration: "_tResult.duration)
                do fileStream.WriteLine("  testDateTime: "_tResult.testDateTime)
                do fileStream.WriteLine()
                do fileStream.WriteLine("results["_tResult.TotalCounts_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:")
            }
            set data = "  "_tResult.suiteName_","_tResult.testcaseName_","_tResult.methodName_","_TestIndex_","_
                    tResult.assertAction_","_tResult.assertCounter_","""_$translate(tResult.assertDescription,"""")_""","""_tResult.assertLocation_""""
            do fileStream.WriteLine(data)
	    }
        $$$ThrowOnError(fileStream.%Save())
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod OutputToDevice(
	TestIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
	TestStatus As %String = "") As %Status
{
    set sc = $$$OK
    try {
        if TestStatus'="" {
            set tResult = ..FilteredTestResultsFunc(TestIndex, TestStatus)
        } else {
            set tResult = ..GetAllTestResultsFunc(TestIndex)
        }
        set currentID=""
        while tResult.%Next() {
            if currentID = "" {
                set currentID = TestIndex
                write !,"unitTest:"
                write !,"  id: "_TestIndex
                write !,"  namespace: "_tResult.namespace
                write !,"  duration: "_tResult.duration
                write !,"  testDateTime: "_tResult.testDateTime
                write !
                write !,"results["_tResult.TotalCounts_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:"
            }
            set data = "  "_tResult.suiteName_","_tResult.testcaseName_","_tResult.methodName_","_TestIndex_","_
                    tResult.assertAction_","_tResult.assertCounter_","""_$translate(tResult.assertDescription,"""")_""","""_tResult.assertLocation_""""
            write !,data
	    }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

}
