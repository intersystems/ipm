Class %IPM.Test.YamlOutput Extends %IPM.Test.Abstract
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
        do fileStream.CopyFrom(..YAML(testIndex, caseStatus))
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
        write !,"  id: "_summary.id
        write !,"  namespace: """_summary.namespace_""""
        write !,"  duration: "_summary.duration
        write !,"  testDateTime: """_summary.testDateTime_""""
        write !,"  methods:"
        write !,"    total: "_summary.methods.total
        write !,"    passed: "_summary.methods.passed
        write !,"    failed: "_summary.methods.failed
        write !,"  assertions:"
        write !,"    total: "_summary.assertions.total
        write !,"    passed: "_summary.assertions.passed
        write !,"    failed: "_summary.assertions.failed

        if summary.methods.failed > 0 {
            write !
            write !,"failures:"
            set failureStream = ..YAML(testIndex, "failed", 0)
            do failureStream.Rewind()
            while 'failureStream.AtEnd {
                write !,failureStream.ReadLine()
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod YAML(
	testIndex = {$order(^UnitTest.Result(""),-1)},
	testStatus As %String = "",
	includeHeader As %Boolean = 1) As %Stream.TmpCharacter
{
    if testStatus '= "" {
        set result = ..FilteredTestResultsFunc(testIndex, testStatus)
    } else {
        set result = ..GetAllTestResultsFunc(testIndex)
    }
    set yamlStream = ##class(%Stream.TmpCharacter).%New()
    set (currentID, currentSuite, currentTestcase) = ""
    while result.%Next() {
        if currentID = "" {
            set currentID = testIndex
            if includeHeader {
                do yamlStream.WriteLine("unitTest:")
                do yamlStream.WriteLine("  id: "_testIndex)
                do yamlStream.WriteLine("  namespace: """_result.namespace_"""")
                do yamlStream.WriteLine("  duration: "_result.duration)
                do yamlStream.WriteLine("  testDateTime: """_result.testDateTime_"""")
                do yamlStream.WriteLine()
                do yamlStream.WriteLine("  results:")
            }
        }
        if result.suiteName '= currentSuite {
            set currentSuite = result.suiteName
            set currentTestcase = ""
            do yamlStream.WriteLine("    - suiteName: """_result.suiteName_"""")
            do yamlStream.WriteLine("      testcases:")
        }
        if result.testcaseName '= currentTestcase {
            set currentTestcase = result.testcaseName
            do yamlStream.WriteLine("        - testcaseName: """_result.testcaseName_"""")
            do yamlStream.WriteLine("          methods:")
        }
        do yamlStream.WriteLine("            - methodName: """_result.methodName_"""")
        do yamlStream.WriteLine("              testMethod: """_result.testMethod_"""")
        do yamlStream.WriteLine("              assertAction: """_result.assertAction_"""")
        do yamlStream.WriteLine("              assertCounter: "_result.assertCounter)
        do yamlStream.WriteLine("              assertStatus: """_result.assertStatus_"""")
        do yamlStream.WriteLine("              assertDescription: |")
        do yamlStream.WriteLine("                "_$replace(result.assertDescription, $char(10), $char(10)_"                "))
        do yamlStream.WriteLine("              assertLocation: """_result.assertLocation_"""")
    }
    return yamlStream
}

}
