Class %IPM.Test.YamlOutput Extends %IPM.Test.Abstract
{

ClassMethod WriteToFileStream(
    fileStream As %Stream.FileCharacter,
    testIndex As %Integer)
{
    do fileStream.CopyFrom(..BuildYaml(testIndex))
}

ClassMethod OutputToDevice(
    testIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
    verbose As %Boolean = 0,
    showDetail As %Boolean = 1) As %Status
{
    set sc = $$$OK
    try {
        set tree = ..BuildResultTree(testIndex)
        set summary = ..GetSummary(testIndex, tree)
        write !
        write !,"summary:"
        write !,"  id: "_summary.id
        write !,"  namespace: """_..EscapeYamlString(summary.namespace)_""""
        write !,"  duration: "_summary.duration_"s"
        write !,"  testDateTime: """_..EscapeYamlString(summary.testDateTime)_""""
        write !,"  methods:"
        write !,"    total: "_summary.methods.total
        write !,"    passed: "_summary.methods.passed
        write !,"    failed: "_summary.methods.failed
        write !,"  assertions:"
        write !,"    total: "_summary.assertions.total
        write !,"    passed: "_summary.assertions.passed
        write !,"    failed: "_summary.assertions.failed

        if showDetail && verbose {
            write !
            write !,"results:"
            set resultStream = ..BuildYamlRows(tree, 0)
            do resultStream.Rewind()
            while 'resultStream.AtEnd {
                write !,resultStream.ReadLine()
            }
        } elseif showDetail && (summary.methods.failed > 0) {
            write !
            write !,"failures:"
            set failStream = ..BuildYamlRows(tree, 1)
            do failStream.Rewind()
            while 'failStream.AtEnd {
                write !,failStream.ReadLine()
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Returns a stream with the full YAML document (header + all results).
ClassMethod BuildYaml(testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Stream.TmpCharacter
{
    set tree = ..BuildResultTree(testIndex)
    set yamlStream = ##class(%Stream.TmpCharacter).%New()

    do yamlStream.WriteLine("unitTest:")
    do yamlStream.WriteLine("  id: "_tree.id)
    do yamlStream.WriteLine("  namespace: """_..EscapeYamlString(tree.namespace)_"""")
    do yamlStream.WriteLine("  duration: "_tree.duration_"s")
    do yamlStream.WriteLine("  testDateTime: """_..EscapeYamlString(tree.testDateTime)_"""")
    do yamlStream.WriteLine()
    do yamlStream.WriteLine("  results:")
    do yamlStream.CopyFrom(..BuildYamlRows(tree, 0))
    return yamlStream
}

/// Escapes backslashes and double-quotes for use inside YAML double-quoted strings.
ClassMethod EscapeYamlString(val As %String) As %String [ Private ]
{
    set val = $replace(val, "\", "\\")
    set val = $replace(val, """", "\""")
    return val
}

/// Returns a stream of YAML rows. failuresOnly=1 skips passing methods/assertions.
/// Each method's assertions are emitted under an `asserts:` list to produce valid YAML.
ClassMethod BuildYamlRows(tree As %DynamicObject, failuresOnly As %Boolean) As %Stream.TmpCharacter [ Private ]
{
    set indent = $select(failuresOnly: "  ", 1: "    ")
    set stream = ##class(%Stream.TmpCharacter).%New()
    set (currentSuite, currentCase) = ""
    set suiteIter = tree.suites.%GetIterator()
    while suiteIter.%GetNext(, .suiteObj) {
        set caseIter = suiteObj.cases.%GetIterator()
        while caseIter.%GetNext(, .caseObj) {
            if caseObj.error '= "" {
                if suiteObj.name '= currentSuite {
                    set currentSuite = suiteObj.name
                    set currentCase = ""
                    do stream.WriteLine(indent_"- suiteName: """_..EscapeYamlString(suiteObj.name)_"""")
                    do stream.WriteLine(indent_"  testcases:")
                }
                do stream.WriteLine(indent_"    - testcaseName: """_..EscapeYamlString(caseObj.name)_"""")
                do stream.WriteLine(indent_"      error: |")
                do stream.WriteLine(indent_"        "_$replace(caseObj.error, $char(10), $char(10)_indent_"        "))
            }
            set methodIter = caseObj.methods.%GetIterator()
            while methodIter.%GetNext(, .methodObj) {
                if failuresOnly && (methodObj.status '= "failed") { continue }
                if suiteObj.name '= currentSuite {
                    set currentSuite = suiteObj.name
                    set currentCase = ""
                    do stream.WriteLine(indent_"- suiteName: """_..EscapeYamlString(suiteObj.name)_"""")
                    do stream.WriteLine(indent_"  testcases:")
                }
                if caseObj.name '= currentCase {
                    set currentCase = caseObj.name
                    do stream.WriteLine(indent_"    - testcaseName: """_..EscapeYamlString(caseObj.name)_"""")
                    do stream.WriteLine(indent_"      methods:")
                }
                do stream.WriteLine(indent_"        - methodName: """_..EscapeYamlString(methodObj.name)_"""")
                do stream.WriteLine(indent_"          status: """_methodObj.status_"""")
                if methodObj.error '= "" {
                    do stream.WriteLine(indent_"          error: |")
                    do stream.WriteLine(indent_"            "_$replace(methodObj.error, $char(10), $char(10)_indent_"            "))
                }
                if methodObj.asserts.%Size() > 0 {
                    do stream.WriteLine(indent_"          asserts:")
                    set assertIter = methodObj.asserts.%GetIterator()
                    while assertIter.%GetNext(, .assertObj) {
                        if failuresOnly && (assertObj.status '= "failed") { continue }
                        do stream.WriteLine(indent_"            - action: """_..EscapeYamlString(assertObj.action)_"""")
                        do stream.WriteLine(indent_"              counter: "_assertObj.counter)
                        do stream.WriteLine(indent_"              status: """_assertObj.status_"""")
                        do stream.WriteLine(indent_"              description: |")
                        do stream.WriteLine(indent_"                "_$replace(assertObj.description, $char(10), $char(10)_indent_"                "))
                        do stream.WriteLine(indent_"              location: """_..EscapeYamlString(assertObj.location)_"""")
                    }
                }
            }
        }
    }
    return stream
}

}
