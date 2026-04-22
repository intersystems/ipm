Class %IPM.Test.JUnitOutput Extends %IPM.Test.Abstract
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

        kill ^||TMP
        set suite = ""
        for {
            set suite = $order(^UnitTest.Result(testIndex, suite), 1, suiteData)
            quit:suite=""
            set ^||TMP("S", suite, "time") = $listget(suiteData, 2)

            set testCase = ""
            for {
                set testCase = $order(^UnitTest.Result(testIndex, suite, testCase), 1, testCaseData)
                quit:testCase=""

                do $increment(^||TMP("S", suite, "tests"))
                set ^||TMP("S", suite, "C", testCase, "time") = $listget(testCaseData, 2)
                set method = ""
                for {
                    set method = $order(^UnitTest.Result(testIndex, suite, testCase, method), 1, methodData)
                    quit:method=""

                    set ^||TMP("S", suite, "C", testCase, "M", method, "time") = $listget(methodData, 2)
                    set assert = ""
                    for {
                        set assert = $order(^UnitTest.Result(testIndex, suite, testCase, method, assert), 1, assertData)
                        quit:assert=""

                        do $increment(^||TMP("S", suite, "assertions"))
                        do $increment(^||TMP("S", suite, "C", testCase, "assertions"))
                        do $increment(^||TMP("S", suite, "C", testCase, "M", method, "assertions"))
                        if $listget(assertData) = 0 {
                            do $increment(^||TMP("S", suite, "failures"))
                            do $increment(^||TMP("S", suite, "C", testCase, "failures"))
                            set failureIndex = $increment(^||TMP("S", suite, "C", testCase, "M", method, "failures"))
                            set ^||TMP("S", suite, "C", testCase, "M", method, "failures", failureIndex) =
                                $listget(assertData, 2) _ ": " _ $listget(assertData, 3)
                        }
                    }
                    if ($listget(methodData) = 0)
                    && ('$data(^||TMP("S", suite, "C", testCase, "M", method, "failures"))) {
                        do $increment(^||TMP("S", suite, "failures"))
                        do $increment(^||TMP("S", suite, "C", testCase, "failures"))
                        set failureIndex = $increment(^||TMP("S", suite, "C", testCase, "M", method, "failures"))
                        set ^||TMP("S", suite, "C", testCase, "M", method, "failures", failureIndex) =
                            $listget(methodData, 3) _ ": " _ $listget(methodData, 4)
                    }
                }

                if $listget(testCaseData) = 0
                && ('$data(^||TMP("S", suite, "C", testCase, "failures"))) {
                    do $increment(^||TMP("S", suite, "failures"))
                    do $increment(^||TMP("S", suite, "C", testCase, "failures"))
                    set failureIndex = $increment(^||TMP("S", suite, "C", testCase, "M", testCase, "failures"))
                    set ^||TMP("S", suite, "C", testCase, "M", testCase, "failures", failureIndex) =
                        $listget(testCaseData, 3) _ ": " _ $listget(testCaseData, 4)
                }
            }
        }

        do fileStream.WriteLine("<?xml version=""1.0"" encoding=""UTF-8"" ?>")
        do fileStream.WriteLine("<testsuites>")
        set suite = ""
        for {
            set suite = $order(^||TMP("S", suite))
            quit:suite=""

            do fileStream.Write("<testsuite")
            do fileStream.Write(" name="""_$zconvert(suite,"O","XML")_"""")
            do fileStream.Write(" assertions="""_$get(^||TMP("S",suite,"assertions"))_"""")
            do fileStream.Write(" time="""_$get(^||TMP("S",suite,"time"))_"""")
            do fileStream.Write(" tests="""_$get(^||TMP("S",suite,"tests"))_"""")
            do fileStream.WriteLine(">")

            set testCase = ""
            for {
                set testCase = $order(^||TMP("S", suite, "C", testCase))
                quit:testCase=""

                do fileStream.Write("<testsuite")
                do fileStream.Write(" name="""_$zconvert(testCase,"O","XML")_"""")
                do fileStream.Write(" assertions="""_$get(^||TMP("S",suite,"C",testCase,"assertions"))_"""")
                do fileStream.Write(" time="""_$get(^||TMP("S",suite,"C",testCase,"time"))_"""")
                do fileStream.Write(" tests="""_$get(^||TMP("S",suite,"C",testCase,"tests"))_"""")
                do fileStream.WriteLine(">")

                set method = ""
                for {
                    set method = $order(^||TMP("S", suite, "C", testCase, "M", method))
                    quit:method=""

                    do fileStream.Write("<testcase")
                    do fileStream.Write(" name="""_$zconvert(method,"O","XML")_"""")
                    do fileStream.Write(" assertions="""_$get(^||TMP("S",suite,"C",testCase,"M",method,"assertions"))_"""")
                    do fileStream.Write(" time="""_$get(^||TMP("S",suite,"C",testCase,"M",method,"time"))_"""")
                    do fileStream.WriteLine(">")
                    set failureKey = ""
                    for {
                        set failureKey = $order(^||TMP("S",suite,"C",testCase,"M",method,"failures",failureKey),1,message)
                        quit:failureKey=""
                        set message = $zstrip(message,"*C")
                        set message = $zconvert($zconvert(message,"O","UTF8"),"O","XML")
                        // $zconvert does not encode newlines.
                        set message = $replace(message,$char(10),"&#10;")
                        set message = $replace(message,$char(13),"&#13;")
                        do fileStream.Write("<failure type=""cache-error"" message="""_message_""">")
                        do fileStream.WriteLine("</failure>")
                    }
                    do fileStream.WriteLine("</testcase>")
                }
                do fileStream.WriteLine("</testsuite>")
            }
            do fileStream.WriteLine("</testsuite>")
        }
        do fileStream.WriteLine("</testsuites>")
        kill ^||TMP

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
        write !,"JUnit Test Run #"_summary.id_" ("_summary.namespace_") "_summary.duration_"s "_summary.testDateTime
        write !,"Methods: "_summary.methods.total_" total, "_summary.methods.passed_" passed, "_summary.methods.failed_" failed"
        write !,"Assertions: "_summary.assertions.total_" total, "_summary.assertions.passed_" passed, "_summary.assertions.failed_" failed"

        if summary.methods.failed > 0 {
            set result = ..GetAllTestResultsFunc(testIndex)
            write !
            while result.%Next() {
                write !,result.suiteName_"/"_result.testcaseName_"/"_result.methodName_" "_result.assertAction_" ["_result.assertStatus_"]"
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

}
