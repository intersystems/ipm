Class %IPM.Test.YamlOutput Extends %IPM.Test.Abstract
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
        do fileStream.CopyFrom(..YAML(TestIndex, TestStatus))
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
        set yamlStream = ..YAML(TestIndex, TestStatus)
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
	TestIndex = {$order(^UnitTest.Result(""),-1)},
	TestStatus As %String = "") As %Stream.TmpCharacter
{
	if TestStatus'="" {
        set tResult = ..FilteredTestResultsFunc(TestIndex, TestStatus)
    } else {
        set tResult = ..GetAllTestResultsFunc(TestIndex)
    }
    set yamlStream = ##class(%Stream.TmpCharacter).%New()
    set (yaml,currentID,currentSuite,currentTestcase) = ""
    while tResult.%Next() {
        if currentID = "" {
            set currentID = TestIndex
            do yamlStream.WriteLine("unitTest:")
            do yamlStream.WriteLine("  id: "_TestIndex)
            do yamlStream.WriteLine("  namespace: """_tResult.namespace_"""")
            do yamlStream.WriteLine("  duration: "_tResult.duration)
            do yamlStream.WriteLine("  testDateTime: """_tResult.testDateTime_"""")
            do yamlStream.WriteLine()
            do yamlStream.WriteLine("  results:")
        }
        if tResult.suiteName '= currentSuite {
            set currentSuite = tResult.suiteName
            set currentTestcase = ""
            do yamlStream.WriteLine("    - suiteName: """_tResult.suiteName_"""")
            do yamlStream.WriteLine("      testcases:")
        }
        if tResult.testcaseName '= currentTestcase {
            set currentTestcase = tResult.testcaseName
            do yamlStream.WriteLine("        - testcaseName: """_tResult.testcaseName_"""")
            do yamlStream.WriteLine("          methods:")
        }
        do yamlStream.WriteLine("            - methodName: """_tResult.methodName_"""")
        do yamlStream.WriteLine("              testMethod: """_tResult.testMethod_"""")
        do yamlStream.WriteLine("              assertAction: """_tResult.assertAction_"""")
        do yamlStream.WriteLine("              assertCounter: "_tResult.assertCounter)
        do yamlStream.WriteLine("              assertDescription: |")
        do yamlStream.WriteLine("                "_$replace(tResult.assertDescription, $char(10), $char(10)_"                "))
        do yamlStream.WriteLine("              assertLocation: """_tResult.assertLocation_"""")
    }
    return yamlStream
}

}
