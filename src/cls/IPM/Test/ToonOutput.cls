Class %IPM.Test.ToonOutput Extends %IPM.Test.Abstract
{

ClassMethod WriteToFileStream(
    fileStream As %Stream.FileCharacter,
    testIndex As %Integer)
{
    set tree = ..BuildResultTree(testIndex)
    set rowStream = ..BuildToonRows(tree, 0, .rowCount)

    do fileStream.WriteLine("unitTest:")
    do fileStream.WriteLine("  id: "_tree.id)
    do fileStream.WriteLine("  namespace: "_tree.namespace)
    do fileStream.WriteLine("  duration: "_tree.duration_"s")
    do fileStream.WriteLine("  testDateTime: "_tree.testDateTime)
    do fileStream.WriteLine()
    do fileStream.WriteLine("results["_rowCount_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:")
    do rowStream.Rewind()
    do fileStream.CopyFrom(rowStream)
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
        write !,"  id: "_summary.id_"  namespace: "_summary.namespace_"  duration: "_summary.duration_"s  testDateTime: "_summary.testDateTime
        write !,"  methods["_summary.methods.total_"]: "_summary.methods.passed_" passed, "_summary.methods.failed_" failed"
        write !,"  assertions["_summary.assertions.total_"]: "_summary.assertions.passed_" passed, "_summary.assertions.failed_" failed"

        if showDetail {
            if verbose {
                set rowStream = ..BuildToonRows(tree, 0, .rowCount)
                write !
                write !,"results["_rowCount_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:"
                do rowStream.Rewind()
                while 'rowStream.AtEnd {
                    write !,rowStream.ReadLine()
                }
            } elseif summary.methods.failed > 0 {
                set failStream = ..BuildToonRows(tree, 1, .failCount)
                write !
                write !,"failures["_failCount_"]{suiteName,testcaseName,methodName,status,assertAction,assertCounter,assertDescription,assertLocation}:"
                do failStream.Rewind()
                while 'failStream.AtEnd {
                    write !,failStream.ReadLine()
                }
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// RFC 4180 quoting: doubles internal quotes, wraps in quotes if value contains comma/quote/newline.
ClassMethod EscapeToonField(val As %String) As %String [ Private ]
{
    if val [ """" || (val [ ",") || (val [ $char(10)) {
        return """"_$replace(val, """", """""")_""""
    }
    return """"_val_""""
}

/// Returns a %Stream.TmpCharacter containing Toon result rows.
/// failuresOnly=0: all methods (for ToFile and verbose OutputToDevice).
/// failuresOnly=1: failed methods and assert failures only (for non-verbose OutputToDevice).
ClassMethod BuildToonRows(tree As %DynamicObject, failuresOnly As %Boolean, Output rowCount As %Integer) As %Stream.TmpCharacter [ Private ]
{
    set rowStream = ##class(%Stream.TmpCharacter).%New()
    set rowCount = 0

    set suiteIter = tree.suites.%GetIterator()
    while suiteIter.%GetNext(, .suiteObj) {
        set caseIter = suiteObj.cases.%GetIterator()
        while caseIter.%GetNext(, .caseObj) {
            if caseObj.error '= "" {
                set rowCount = rowCount + 1
                do rowStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_caseObj.name_",failed,OnBeforeAllTests,0,"_..EscapeToonField(caseObj.error)_",""""")
            }
            set methodIter = caseObj.methods.%GetIterator()
            while methodIter.%GetNext(, .methodObj) {
                if failuresOnly && (methodObj.status '= "failed") { continue }
                if methodObj.error '= "" {
                    set rowCount = rowCount + 1
                    do rowStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_methodObj.name_",failed,error,0,"_..EscapeToonField(methodObj.error)_",""""")
                }
                set assertIter = methodObj.asserts.%GetIterator()
                while assertIter.%GetNext(, .assertObj) {
                    if failuresOnly && (assertObj.status '= "failed") { continue }
                    set rowCount = rowCount + 1
                    set row = "  "_suiteObj.name_","_caseObj.name_","_methodObj.name_","_assertObj.status_","_assertObj.action_","_assertObj.counter_","_..EscapeToonField(assertObj.description)_","_..EscapeToonField(assertObj.location)
                    do rowStream.WriteLine(row)
                }
                if 'failuresOnly && (methodObj.asserts.%Size() = 0) {
                    set rowCount = rowCount + 1
                    do rowStream.WriteLine("  "_suiteObj.name_","_caseObj.name_","_methodObj.name_","_methodObj.status_",,,,""""")
                }
            }
        }
    }
    return rowStream
}

}
