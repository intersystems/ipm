Class %IPM.Test.ToonOutput Extends %IPM.Test.Abstract
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
        if pTestStatus'=""{
            set tResult = ..FilteredTestResultsFunc(pTestIndex, pTestStatus)
        } else {
            set tResult = ..GetAllTestResultsFunc(pTestIndex)
        }
        set currentID=""
        while tResult.%Next() {
            if currentID = "" {
                set currentID = pTestIndex
                do fileStream.WriteLine("unitTest:")
                do fileStream.WriteLine("  id: "_pTestIndex)
                do fileStream.WriteLine("  namespace: "_tResult.namespace)
                do fileStream.WriteLine("  duration: "_tResult.duration)
                do fileStream.WriteLine("  testDateTime: "_tResult.testDateTime)
                do fileStream.WriteLine()
                do fileStream.WriteLine("results["_tResult.TotalCounts_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:")
            }
            set data = "  "_tResult.suiteName_","_tResult.testcaseName_","_tResult.methodName_","_pTestIndex_","_
                    tResult.assertAction_","_tResult.assertCounter_","""_$translate(tResult.assertDescription,"""")_""","""_tResult.assertLocation_""""
            do fileStream.WriteLine(data)
	    }
        $$$ThrowOnError(fileStream.%Save())
    } catch e {
        set tSC = e.AsStatus()
    }
    return tSC
}

ClassMethod OutputToDevice(
	pTestIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
	pTestStatus As %String = "") As %Status
{
    set tSC = $$$OK
    try {
        if pTestStatus'=""{
            set tResult = ..FilteredTestResultsFunc(pTestIndex, pTestStatus)
        } else {
            set tResult = ..GetAllTestResultsFunc(pTestIndex)
        }
        set currentID=""
        while tResult.%Next() {
            if currentID = "" {
                set currentID = pTestIndex
                write !,"unitTest:"
                write !,"  id: "_pTestIndex
                write !,"  namespace: "_tResult.namespace
                write !,"  duration: "_tResult.duration
                write !,"  testDateTime: "_tResult.testDateTime
                write !
                write !,"results["_tResult.TotalCounts_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:"
            }
            set data = "  "_tResult.suiteName_","_tResult.testcaseName_","_tResult.methodName_","_pTestIndex_","_
                    tResult.assertAction_","_tResult.assertCounter_","""_$translate(tResult.assertDescription,"""")_""","""_tResult.assertLocation_""""
            write !,data
	    }
    } catch e {
        set tSC = e.AsStatus()
    }
    return tSC
}

}
