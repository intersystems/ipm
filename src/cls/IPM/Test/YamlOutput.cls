Class %IPM.Test.YamlOutput Extends %IPM.Test.Abstract
{

ClassMethod ToFile(
    fileName As %String,
    testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status
{
    set sc = $$$OK
    try {
        set fileStream = ##class(%Stream.FileCharacter).%New()
        set fileStream.TranslateTable = "UTF8"
        $$$ThrowOnError(fileStream.LinkToFile(fileName))
        do fileStream.CopyFrom(..YAML(testIndex))
        $$$ThrowOnError(fileStream.%Save())
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod OutputToDevice(
    testIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
    verbose As %Boolean = 0) As %Status
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

        if verbose {
            write !
            write !,"results:"
            set tree = ..BuildResultTree(testIndex)
            set resultStream = ..YAMLResults(tree)
            do resultStream.Rewind()
            while 'resultStream.AtEnd {
                write !,resultStream.ReadLine()
            }
        } elseif summary.methods.failed > 0 {
            write !
            write !,"failures:"
            set failStream = ..YAMLFailures(testIndex)
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
ClassMethod YAML(testIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Stream.TmpCharacter
{
    set tree = ..BuildResultTree(testIndex)
    set yamlStream = ##class(%Stream.TmpCharacter).%New()

    do yamlStream.WriteLine("unitTest:")
    do yamlStream.WriteLine("  id: "_tree.id)
    do yamlStream.WriteLine("  namespace: """_tree.namespace_"""")
    do yamlStream.WriteLine("  duration: "_tree.duration)
    do yamlStream.WriteLine("  testDateTime: """_tree.testDateTime_"""")
    do yamlStream.WriteLine()
    do yamlStream.WriteLine("  results:")
    do yamlStream.CopyFrom(..YAMLResults(tree))
    return yamlStream
}

/// Returns a stream of YAML result rows for all entries in the tree (no header).
/// Used by ToFile via YAML, and by OutputToDevice for the failures section.
ClassMethod YAMLResults(tree As %DynamicObject) As %Stream.TmpCharacter [ Private ]
{
    set resultStream = ##class(%Stream.TmpCharacter).%New()
    set (currentSuite, currentCase) = ""
    set suiteIter = tree.suites.%GetIterator()
    while suiteIter.%GetNext(, .suiteObj) {
        set caseIter = suiteObj.cases.%GetIterator()
        while caseIter.%GetNext(, .caseObj) {
            if caseObj.error '= "" {
                if suiteObj.name '= currentSuite {
                    set currentSuite = suiteObj.name
                    set currentCase = ""
                    do resultStream.WriteLine("    - suiteName: """_suiteObj.name_"""")
                    do resultStream.WriteLine("      testcases:")
                }
                do resultStream.WriteLine("        - testcaseName: """_caseObj.name_"""")
                do resultStream.WriteLine("          error: |")
                do resultStream.WriteLine("            "_$replace(caseObj.error, $char(10), $char(10)_"            "))
            }
            set methodIter = caseObj.methods.%GetIterator()
            while methodIter.%GetNext(, .methodObj) {
                if suiteObj.name '= currentSuite {
                    set currentSuite = suiteObj.name
                    set currentCase = ""
                    do resultStream.WriteLine("    - suiteName: """_suiteObj.name_"""")
                    do resultStream.WriteLine("      testcases:")
                }
                if caseObj.name '= currentCase {
                    set currentCase = caseObj.name
                    do resultStream.WriteLine("        - testcaseName: """_caseObj.name_"""")
                    do resultStream.WriteLine("          methods:")
                }
                do resultStream.WriteLine("            - methodName: """_methodObj.name_"""")
                do resultStream.WriteLine("              status: """_methodObj.status_"""")
                if methodObj.error '= "" {
                    do resultStream.WriteLine("              error: |")
                    do resultStream.WriteLine("                "_$replace(methodObj.error, $char(10), $char(10)_"                "))
                }
                set assertIter = methodObj.asserts.%GetIterator()
                while assertIter.%GetNext(, .assertObj) {
                    do resultStream.WriteLine("              assertAction: """_assertObj.action_"""")
                    do resultStream.WriteLine("              assertCounter: "_assertObj.counter)
                    do resultStream.WriteLine("              assertStatus: """_assertObj.status_"""")
                    do resultStream.WriteLine("              assertDescription: |")
                    do resultStream.WriteLine("                "_$replace(assertObj.description, $char(10), $char(10)_"                "))
                    do resultStream.WriteLine("              assertLocation: """_assertObj.location_"""")
                }
            }
        }
    }
    return resultStream
}

/// Returns a stream of YAML failure rows only (no header). Used by OutputToDevice.
ClassMethod YAMLFailures(testIndex As %Integer) As %Stream.TmpCharacter [ Private ]
{
    set tree = ..BuildResultTree(testIndex)
    set failStream = ##class(%Stream.TmpCharacter).%New()
    set (currentSuite, currentCase) = ""
    set suiteIter = tree.suites.%GetIterator()
    while suiteIter.%GetNext(, .suiteObj) {
        set caseIter = suiteObj.cases.%GetIterator()
        while caseIter.%GetNext(, .caseObj) {
            if caseObj.error '= "" {
                if suiteObj.name '= currentSuite {
                    set currentSuite = suiteObj.name
                    set currentCase = ""
                    do failStream.WriteLine("  - suiteName: """_suiteObj.name_"""")
                    do failStream.WriteLine("    testcases:")
                }
                do failStream.WriteLine("      - testcaseName: """_caseObj.name_"""")
                do failStream.WriteLine("        error: |")
                do failStream.WriteLine("          "_$replace(caseObj.error, $char(10), $char(10)_"          "))
            }
            set methodIter = caseObj.methods.%GetIterator()
            while methodIter.%GetNext(, .methodObj) {
                if methodObj.status '= "failed" { continue }
                if suiteObj.name '= currentSuite {
                    set currentSuite = suiteObj.name
                    set currentCase = ""
                    do failStream.WriteLine("  - suiteName: """_suiteObj.name_"""")
                    do failStream.WriteLine("    testcases:")
                }
                if caseObj.name '= currentCase {
                    set currentCase = caseObj.name
                    do failStream.WriteLine("      - testcaseName: """_caseObj.name_"""")
                    do failStream.WriteLine("        methods:")
                }
                do failStream.WriteLine("          - methodName: """_methodObj.name_"""")
                if methodObj.error '= "" {
                    do failStream.WriteLine("            error: |")
                    do failStream.WriteLine("              "_$replace(methodObj.error, $char(10), $char(10)_"              "))
                }
                set assertIter = methodObj.asserts.%GetIterator()
                while assertIter.%GetNext(, .assertObj) {
                    if assertObj.status '= "failed" { continue }
                    do failStream.WriteLine("            assertAction: """_assertObj.action_"""")
                    do failStream.WriteLine("            assertCounter: "_assertObj.counter)
                    do failStream.WriteLine("            assertDescription: |")
                    do failStream.WriteLine("              "_$replace(assertObj.description, $char(10), $char(10)_"              "))
                    do failStream.WriteLine("            assertLocation: """_assertObj.location_"""")
                }
            }
        }
    }
    return failStream
}

}
