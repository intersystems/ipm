Class %IPM.Test.YamlOutput Extends %IPM.Test.Abstract
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
        do fileStream.CopyFrom(..YAML(pTestIndex, pTestStatus))
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
        set yamlStream = ..YAML(pTestIndex, pTestStatus)
        write !
        while 'yamlStream.AtEnd {
            write yamlStream.Read()
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    return tSC
}

ClassMethod YAML(
	pTestIndex = {$order(^UnitTest.Result(""),-1)},
	pTestStatus As %String = "") As %Stream.TmpCharacter
{
	if pTestStatus'=""{
        set tResult= ..FilteredTestResultsFunc(pTestIndex, pTestStatus)
    } else {
        set tResult= ..GetAllTestResultsFunc(pTestIndex)
    }
    set yamlStream = ##class(%Stream.TmpCharacter).%New()
    set (yaml,currentID,currentSuite,currentTestcase) = ""
    while tResult.%Next() {
        if currentID = "" {
            set currentID = pTestIndex
            do yamlStream.WriteLine("unitTest:")
            do yamlStream.WriteLine("  id: "_pTestIndex)
            do yamlStream.WriteLine("  namespace: """_tResult.namespace_"""")
            do yamlStream.WriteLine("  duration: "_tResult.duration)
            do yamlStream.WriteLine("  testDateTime: """_tResult.testDateTime_"""")
            do yamlStream.WriteLine( "")
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
        //do yamlStream.WriteLine("              testMethod: """_tResult.testMethod_"""")
        do yamlStream.WriteLine("              assertAction: """_tResult.assertAction_"""")
        do yamlStream.WriteLine("              assertCounter: "_tResult.assertCounter)
        //do yamlStream.WriteLine("              assertDescription: |")
        //do yamlStream.WriteLine("                "_$replace(tResult.assertDescription, $c(10), $c(10)_"                "))
        do yamlStream.WriteLine("              assertLocation: """_tResult.assertLocation_"""")
    }
    return yamlStream
}

}
