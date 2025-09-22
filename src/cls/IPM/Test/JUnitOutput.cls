Class %IPM.Test.JUnitOutput
{

ClassMethod ToFile(
	pFileName As %String,
	pTestIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status
{
    set tSC = $$$OK
    try {
        set tFile = ##class(%Stream.FileCharacter).%New()
        set tFile.TranslateTable="UTF8"
        do tFile.LinkToFile(pFileName)

        kill ^||TMP // results global
        set tSuite=""
        for {
            set tSuite=$order(^UnitTest.Result(pTestIndex,tSuite),1,tSuiteData)
            quit:tSuite=""
            set ^||TMP("S",tSuite,"time")=$listget(tSuiteData,2)

            set tCase=""
            for {
                set tCase=$order(^UnitTest.Result(pTestIndex,tSuite,tCase),1,tCaseData)
                quit:tCase=""

                do $increment(^||TMP("S",tSuite,"tests"))
                set ^||TMP("S",tSuite,"C",tCase,"time")=$listget(tCaseData,2)
                set tMethod=""
                for {
                    set tMethod=$order(^UnitTest.Result(pTestIndex,tSuite,tCase,tMethod),1,tMethodData)
                    quit:tMethod=""

                    set ^||TMP("S",tSuite,"C",tCase,"M",tMethod,"time")=$listget(tMethodData,2)
                    set tAssert=""
                    for {
                        set tAssert=$order(^UnitTest.Result(pTestIndex,tSuite,tCase,tMethod,tAssert),1,tAssertData)
                        quit:tAssert=""

                        do $increment(^||TMP("S",tSuite,"assertions"))
                        do $increment(^||TMP("S",tSuite,"C",tCase,"assertions"))
                        do $increment(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"assertions"))
                        if $listget(tAssertData)=0 {
                            do $increment(^||TMP("S",tSuite,"failures"))
                            do $increment(^||TMP("S",tSuite,"C",tCase,"failures"))
                            set tIndex = $increment(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures"))
                            set ^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures",tIndex) =
                                $listget(tAssertData,2) _ ": " _ $listget(tAssertData,3)
                        }
                    }
                    if ($listget(tMethodData)=0)
                    && ('$data(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures"))) {
                        do $increment(^||TMP("S",tSuite,"failures"))
                        do $increment(^||TMP("S",tSuite,"C",tCase,"failures"))
                        set tIndex = $increment(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures"))
                        set ^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures",tIndex) =
                            $listget(tMethodData,3) _ ": " _ $listget(tMethodData,4)
                    }
                }

                if $listget(tCaseData)=0
                && ('$data(^||TMP("S",tSuite,"C",tCase,"failures"))) {
                    do $increment(^||TMP("S",tSuite,"failures"))
                    do $increment(^||TMP("S",tSuite,"C",tCase,"failures"))
                    set tIndex = $increment(^||TMP("S",tSuite,"C",tCase,"M",tCase,"failures"))
                    set ^||TMP("S",tSuite,"C",tCase,"M",tCase,"failures",tIndex) =
                        $listget(tCaseData,3) _ ": " _ $listget(tCaseData,4)
                }
            }
        }

        do tFile.WriteLine("<?xml version=""1.0"" encoding=""UTF-8"" ?>")
        do tFile.WriteLine("<testsuites>")
        set tSuite=""
        for {
            set tSuite=$order(^||TMP("S",tSuite))
            quit:tSuite=""

            do tFile.Write("<testsuite")
            do tFile.Write(" name="""_$zconvert(tSuite,"O","XML")_"""")
            do tFile.Write(" assertions="""_$get(^||TMP("S",tSuite,"assertions"))_"""")
            do tFile.Write(" time="""_$get(^||TMP("S",tSuite,"time"))_"""")
            do tFile.Write(" tests="""_$get(^||TMP("S",tSuite,"tests"))_"""")
            do tFile.WriteLine(">")

            set tCase=""
            for {
                set tCase=$order(^||TMP("S",tSuite,"C",tCase))
                quit:tCase=""

                do tFile.Write("<testsuite")
                do tFile.Write(" name="""_$zconvert(tCase,"O","XML")_"""")
                do tFile.Write(" assertions="""_$get(^||TMP("S",tSuite,"C",tCase,"assertions"))_"""")
                do tFile.Write(" time="""_$get(^||TMP("S",tSuite,"C",tCase,"time"))_"""")
                do tFile.Write(" tests="""_$get(^||TMP("S",tSuite,"C",tCase,"tests"))_"""")
                do tFile.WriteLine(">")

                set tMethod=""
                for {
                    set tMethod=$order(^||TMP("S",tSuite,"C",tCase,"M",tMethod))
                    quit:tMethod=""

                    do tFile.Write("<testcase")
                    do tFile.Write(" name="""_$zconvert(tMethod,"O","XML")_"""")
                    do tFile.Write(" assertions="""_$get(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"assertions"))_"""")
                    do tFile.Write(" time="""_$get(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"time"))_"""")
                    do tFile.WriteLine(">")
                    set tFailureKey = ""
                    for {
                        set tFailureKey = $order(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures",tFailureKey),1,tMessage)
                        if (tFailureKey = "") {
                            quit
                        }
                        set tMessage = $zstrip(tMessage,"*C")
                        set tMessage = $zconvert($zconvert(tMessage,"O","UTF8"),"O","XML")
                        // Also encode newlines - $zconvert doesn't do this.
                        set tMessage = $replace(tMessage,$char(10),"&#10;")
                        set tMessage = $replace(tMessage,$char(13),"&#13;")
                        do tFile.Write("<failure type=""cache-error"" message="""_tMessage_""">")
                        do tFile.WriteLine("</failure>")
                    }
                    do tFile.WriteLine("</testcase>")
                }
                do tFile.WriteLine("</testsuite>")
            }
            do tFile.WriteLine("</testsuite>")
        }
        do tFile.WriteLine("</testsuites>")
        kill ^||TMP

        $$$ThrowOnError(tFile.%Save())
    } catch e {
        set tSC = e.AsStatus()
    }
    quit $$$OK
}

}
