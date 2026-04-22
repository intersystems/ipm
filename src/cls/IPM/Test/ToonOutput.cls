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

        if caseStatus '= "" {
            set result = ..FilteredTestResultsFunc(testIndex, caseStatus)
        } else {
            set result = ..GetAllTestResultsFunc(testIndex)
        }

        set rowCount = 0
        set (ns, duration, testDateTime) = ""
        set rowStream = ##class(%Stream.TmpCharacter).%New()
        while result.%Next() {
            if rowCount = 0 {
                set ns = result.namespace
                set duration = result.duration
                set testDateTime = result.testDateTime
            }
            set rowCount = rowCount + 1
            set data = "  "_result.suiteName_","_result.testcaseName_","_result.methodName_","_result.assertStatus_","_
                    result.assertAction_","_result.assertCounter_","""_$translate(result.assertDescription,"""")_""","""_result.assertLocation_""""
            do rowStream.WriteLine(data)
        }

        do fileStream.WriteLine("unitTest:")
        do fileStream.WriteLine("  id: "_testIndex)
        do fileStream.WriteLine("  namespace: "_ns)
        do fileStream.WriteLine("  duration: "_duration)
        do fileStream.WriteLine("  testDateTime: "_testDateTime)
        do fileStream.WriteLine()
        do fileStream.WriteLine("results["_rowCount_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:")
        do fileStream.CopyFrom(rowStream)
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
        write !
        write !,"summary:"
        write !,"  id: "_summary.id_"  namespace: "_summary.namespace_"  duration: "_summary.duration_"  testDateTime: "_summary.testDateTime
        write !,"  methods["_summary.methods.total_"]: "_summary.methods.passed_" passed, "_summary.methods.failed_" failed"
        write !,"  assertions["_summary.assertions.total_"]: "_summary.assertions.passed_" passed, "_summary.assertions.failed_" failed"

        if summary.methods.failed > 0 {
            set result = ..FilteredTestResultsFunc(testIndex, "failed")
            set currentID = ""
            write !
            write !,"failures["_summary.assertions.failed_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:"
            while result.%Next() {
                set data = "  "_result.suiteName_","_result.testcaseName_","_result.methodName_","_result.assertStatus_","_
                        result.assertAction_","_result.assertCounter_","""_$translate(result.assertDescription,"""")_""","""_result.assertLocation_""""
                write !,data
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

}
