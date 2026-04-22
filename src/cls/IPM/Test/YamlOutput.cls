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
	testIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
	testStatus As %String = "") As %Status
{
    set sc = $$$OK
    try {
        set yamlStream = ..YAML(testIndex, testStatus)
        write !
        while 'yamlStream.AtEnd {
            write yamlStream.Read()
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod YAML(
	testIndex = {$order(^UnitTest.Result(""),-1)},
	testStatus As %String = "") As %Stream.TmpCharacter
{
	if testStatus'="" {
        set result = ..FilteredTestResultsFunc(testIndex, testStatus)
    } else {
        set result = ..GetAllTestResultsFunc(testIndex)
    }
    set yamlStream = ##class(%Stream.TmpCharacter).%New()
    set (currentID,currentSuite,currentTestcase) = ""
    while result.%Next() {
        if currentID = "" {
            set currentID = testIndex
            do yamlStream.WriteLine("unitTest:")
            do yamlStream.WriteLine("  id: "_testIndex)
            do yamlStream.WriteLine("  namespace: """_result.namespace_"""")
            do yamlStream.WriteLine("  duration: "_result.duration)
            do yamlStream.WriteLine("  testDateTime: """_result.testDateTime_"""")
            do yamlStream.WriteLine()
            do yamlStream.WriteLine("  results:")
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
