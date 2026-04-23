Class %IPM.Test.JsonOutput Extends %IPM.Test.Abstract
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
        do fileStream.Write(..BuildResultTree(testIndex).%ToJSON())
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
        set tree = ..BuildResultTree(testIndex)
        if verbose {
            set allMethods = []
            set suiteIter = tree.suites.%GetIterator()
            while suiteIter.%GetNext(, .suiteObj) {
                set caseIter = suiteObj.cases.%GetIterator()
                while caseIter.%GetNext(, .caseObj) {
                    if caseObj.error '= "" {
                        do allMethods.%Push({"suite": (suiteObj.name), "case": (caseObj.name), "status": "failed", "error": (caseObj.error)})
                    }
                    set methodIter = caseObj.methods.%GetIterator()
                    while methodIter.%GetNext(, .methodObj) {
                        do allMethods.%Push({"suite": (suiteObj.name), "case": (caseObj.name), "method": (methodObj.name), "status": (methodObj.status), "error": (methodObj.error)})
                    }
                }
            }
            set output = {"summary": (summary), "methods": (allMethods)}
        } else {
            set failedMethods = []
            if summary.methods.failed > 0 {
                set suiteIter = tree.suites.%GetIterator()
                while suiteIter.%GetNext(, .suiteObj) {
                    set caseIter = suiteObj.cases.%GetIterator()
                    while caseIter.%GetNext(, .caseObj) {
                        if caseObj.error '= "" {
                            do failedMethods.%Push({"suite": (suiteObj.name), "case": (caseObj.name), "error": (caseObj.error)})
                        }
                        set methodIter = caseObj.methods.%GetIterator()
                        while methodIter.%GetNext(, .methodObj) {
                            if methodObj.status = "failed" {
                                do failedMethods.%Push({"suite": (suiteObj.name), "case": (caseObj.name), "method": (methodObj.name), "error": (methodObj.error), "asserts": (methodObj.asserts)})
                            }
                        }
                    }
                }
            }
            set output = {"summary": (summary), "failures": (failedMethods)}
        }
        write !
        do output.%ToJSON()
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

}
