Class %IPM.Test.ToonOutput Extends %IPM.Test.Abstract
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

        set tree = ..BuildResultTree(testIndex)
        set rowStream = ##class(%Stream.TmpCharacter).%New()
        set rowCount = 0

        set suiteIter = tree.suites.%GetIterator()
        while suiteIter.%GetNext(, .suiteObj) {
            set caseIter = suiteObj.cases.%GetIterator()
            while caseIter.%GetNext(, .caseObj) {
                if caseObj.error '= "" {
                    set rowCount = rowCount + 1
                    do rowStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_caseObj.name_",failed,OnBeforeAllTests,0,"""_$translate(caseObj.error,"""")_""",""""")
                }
                set methodIter = caseObj.methods.%GetIterator()
                while methodIter.%GetNext(, .methodObj) {
                    if methodObj.error '= "" {
                        set rowCount = rowCount + 1
                        do rowStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_methodObj.name_",failed,error,0,"""_$translate(methodObj.error,"""")_""",""""")
                    }
                    set assertIter = methodObj.asserts.%GetIterator()
                    while assertIter.%GetNext(, .assertObj) {
                        set rowCount = rowCount + 1
                        set row = "  "_suiteObj.name_","_caseObj.name_","_methodObj.name_","_assertObj.status_","_assertObj.action_","_assertObj.counter_","""_$translate(assertObj.description,"""")_""","""_assertObj.location_""""
                        do rowStream.WriteLine(row)
                    }
                }
            }
        }

        do fileStream.WriteLine("unitTest:")
        do fileStream.WriteLine("  id: "_tree.id)
        do fileStream.WriteLine("  namespace: "_tree.namespace)
        do fileStream.WriteLine("  duration: "_tree.duration_"s")
        do fileStream.WriteLine("  testDateTime: "_tree.testDateTime)
        do fileStream.WriteLine()
        do fileStream.WriteLine("results["_rowCount_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:")
        do rowStream.Rewind()
        do fileStream.CopyFrom(rowStream)
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
        write !,"  id: "_summary.id_"  namespace: "_summary.namespace_"  duration: "_summary.duration_"s  testDateTime: "_summary.testDateTime
        write !,"  methods["_summary.methods.total_"]: "_summary.methods.passed_" passed, "_summary.methods.failed_" failed"
        write !,"  assertions["_summary.assertions.total_"]: "_summary.assertions.passed_" passed, "_summary.assertions.failed_" failed"

        if verbose {
            set tree = ..BuildResultTree(testIndex)
            set rowCount = 0
            set rowStream = ##class(%Stream.TmpCharacter).%New()
            set suiteIter = tree.suites.%GetIterator()
            while suiteIter.%GetNext(, .suiteObj) {
                set caseIter = suiteObj.cases.%GetIterator()
                while caseIter.%GetNext(, .caseObj) {
                    if caseObj.error '= "" {
                        set rowCount = rowCount + 1
                        do rowStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_caseObj.name_",failed,OnBeforeAllTests,0,"""_$translate(caseObj.error,"""")_""",""""")
                    }
                    set methodIter = caseObj.methods.%GetIterator()
                    while methodIter.%GetNext(, .methodObj) {
                        if methodObj.error '= "" {
                            set rowCount = rowCount + 1
                            do rowStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_methodObj.name_",failed,error,0,"""_$translate(methodObj.error,"""")_""",""""")
                        }
                        set assertIter = methodObj.asserts.%GetIterator()
                        while assertIter.%GetNext(, .assertObj) {
                            set rowCount = rowCount + 1
                            set row = "  "_suiteObj.name_","_caseObj.name_","_methodObj.name_","_assertObj.status_","_assertObj.action_","_assertObj.counter_","""_$translate(assertObj.description,"""")_""","""_assertObj.location_""""
                            do rowStream.WriteLine(row)
                        }
                        if methodObj.asserts.%Size() = 0 {
                            set rowCount = rowCount + 1
                            do rowStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_methodObj.name_","_methodObj.status_",,,,""""")
                        }
                    }
                }
            }
            write !
            write !,"results["_rowCount_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:"
            do rowStream.Rewind()
            while 'rowStream.AtEnd {
                write !,rowStream.ReadLine()
            }
        } elseif summary.methods.failed > 0 {
            set tree = ..BuildResultTree(testIndex)
            set failCount = 0
            set failStream = ##class(%Stream.TmpCharacter).%New()
            set suiteIter = tree.suites.%GetIterator()
            while suiteIter.%GetNext(, .suiteObj) {
                set caseIter = suiteObj.cases.%GetIterator()
                while caseIter.%GetNext(, .caseObj) {
                    if caseObj.error '= "" {
                        set failCount = failCount + 1
                        do failStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_caseObj.name_",failed,OnBeforeAllTests,0,"""_$translate(caseObj.error,"""")_""",""""")
                    }
                    set methodIter = caseObj.methods.%GetIterator()
                    while methodIter.%GetNext(, .methodObj) {
                        if methodObj.error '= "" {
                            set failCount = failCount + 1
                            do failStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_methodObj.name_",failed,error,0,"""_$translate(methodObj.error,"""")_""",""""")
                        }
                        set assertIter = methodObj.asserts.%GetIterator()
                        while assertIter.%GetNext(, .assertObj) {
                            if assertObj.status = "failed" {
                                set failCount = failCount + 1
                                set row = "  "_suiteObj.name_","_caseObj.name_","_methodObj.name_",failed,"_assertObj.action_","_assertObj.counter_","""_$translate(assertObj.description,"""")_""","""_assertObj.location_""""
                                do failStream.WriteLine(row)
                            }
                        }
                    }
                }
            }
            write !
            write !,"failures["_failCount_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:"
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

}
