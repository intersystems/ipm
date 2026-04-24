Class %IPM.Test.JUnitOutput Extends %IPM.Test.Abstract
{

ClassMethod WriteToFileStream(
    fileStream As %Stream.FileCharacter,
    testIndex As %Integer)
{
    set tree = ..BuildResultTree(testIndex)

    do fileStream.WriteLine("<?xml version=""1.0"" encoding=""UTF-8"" ?>")
    do fileStream.WriteLine("<testsuites>")

    set suiteIter = tree.suites.%GetIterator()
    while suiteIter.%GetNext(, .suiteObj) {
        set suiteTests = 0
        set suiteFailures = 0
        set suiteAssertions = 0
        set suiteDuration = 0
        set caseIter2 = suiteObj.cases.%GetIterator()
        while caseIter2.%GetNext(, .caseObj2) {
            set methodIter2 = caseObj2.methods.%GetIterator()
            while methodIter2.%GetNext(, .methodObj2) {
                set suiteTests = suiteTests + 1
                if methodObj2.status = "failed" { set suiteFailures = suiteFailures + 1 }
                set suiteDuration = suiteDuration + methodObj2.duration
                set assertIter2 = methodObj2.asserts.%GetIterator()
                while assertIter2.%GetNext(, .unused) { set suiteAssertions = suiteAssertions + 1 }
            }
            if caseObj2.error '= "" {
                set suiteTests = suiteTests + 1
                set suiteFailures = suiteFailures + 1
            }
        }

        do fileStream.Write("<testsuite")
        do fileStream.Write(" name="""_$zconvert(suiteObj.name,"O","XML")_"""")
        do fileStream.Write(" tests="""_suiteTests_"""")
        do fileStream.Write(" failures="""_suiteFailures_"""")
        do fileStream.Write(" assertions="""_suiteAssertions_"""")
        do fileStream.Write(" time="""_suiteDuration_"""")
        do fileStream.WriteLine(">")

        set caseIter = suiteObj.cases.%GetIterator()
        while caseIter.%GetNext(, .caseObj) {
            do fileStream.Write("<testsuite")
            do fileStream.Write(" name="""_$zconvert(caseObj.name,"O","XML")_"""")
            do fileStream.WriteLine(">")

            if caseObj.error '= "" {
                do fileStream.Write("<testcase name="""_$zconvert(caseObj.name,"O","XML")_""">")
                set msg = ..EncodeXMLAttr(caseObj.error)
                do fileStream.Write("<failure type=""cache-error"" message="""_msg_""">")
                do fileStream.WriteLine("</failure></testcase>")
            }

            set methodIter = caseObj.methods.%GetIterator()
            while methodIter.%GetNext(, .methodObj) {
                set methodAssertions = methodObj.asserts.%Size()
                do fileStream.Write("<testcase")
                do fileStream.Write(" name="""_$zconvert(methodObj.name,"O","XML")_"""")
                do fileStream.Write(" assertions="""_methodAssertions_"""")
                do fileStream.Write(" time="""_methodObj.duration_"""")
                do fileStream.WriteLine(">")

                set assertIter = methodObj.asserts.%GetIterator()
                while assertIter.%GetNext(, .assertObj) {
                    if assertObj.status = "failed" {
                        set msg = ..EncodeXMLAttr(assertObj.action_": "_assertObj.description)
                        do fileStream.Write("<failure type=""cache-error"" message="""_msg_""">")
                        do fileStream.WriteLine("</failure>")
                    }
                }
                if (methodObj.status = "failed") && (methodObj.error '= "") {
                    set msg = ..EncodeXMLAttr(methodObj.error)
                    do fileStream.Write("<failure type=""cache-error"" message="""_msg_""">")
                    do fileStream.WriteLine("</failure>")
                }
                do fileStream.WriteLine("</testcase>")
            }
            do fileStream.WriteLine("</testsuite>")
        }
        do fileStream.WriteLine("</testsuite>")
    }
    do fileStream.WriteLine("</testsuites>")
}

ClassMethod EncodeXMLAttr(msg As %String) As %String [ Private ]
{
    set msg = $zstrip(msg, "*C")
    set msg = $zconvert($zconvert(msg, "O", "UTF8"), "O", "XML")
    set msg = $replace(msg, $char(10), "&#10;")
    set msg = $replace(msg, $char(13), "&#13;")
    return msg
}

}
