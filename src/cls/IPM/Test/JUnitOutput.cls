Class %IPM.Test.JUnitOutput
{

ClassMethod ToFile(pFileName As %String, pTestIndex As %Integer = {$Order(^UnitTest.Result(""),-1)}) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tFile = ##class(%Stream.FileCharacter).%New()
		Do tFile.LinkToFile(pFileName)
		
		Kill ^||TMP // results global
		Set tSuite=""
		For {
			Set tSuite=$Order(^UnitTest.Result(pTestIndex,tSuite),1,tSuiteData)
			Quit:tSuite=""
			Set ^||TMP("S",tSuite,"time")=$ListGet(tSuiteData,2)
			
			Set tCase=""
			For {
				Set tCase=$Order(^UnitTest.Result(pTestIndex,tSuite,tCase),1,tCaseData)
				Quit:tCase=""
				
				if $Increment(^||TMP("S",tSuite,"tests"))
				Set ^||TMP("S",tSuite,"C",tCase,"time")=$ListGet(tCaseData,2)
				Set tMethod=""
				For {
					Set tMethod=$Order(^UnitTest.Result(pTestIndex,tSuite,tCase,tMethod),1,tMethodData)
					Quit:tMethod=""
					
					Set ^||TMP("S",tSuite,"C",tCase,"M",tMethod,"time")=$ListGet(tMethodData,2)
					Set tAssert=""
					For {
						Set tAssert=$Order(^UnitTest.Result(pTestIndex,tSuite,tCase,tMethod,tAssert),1,tAssertData)
						Quit:tAssert=""
						
						If $Increment(^||TMP("S",tSuite,"assertions"))
						If $Increment(^||TMP("S",tSuite,"C",tCase,"assertions"))
						If $Increment(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"assertions"))
						If $ListGet(tAssertData)=0 {
							If $Increment(^||TMP("S",tSuite,"failures"))
							If $Increment(^||TMP("S",tSuite,"C",tCase,"failures"))
							Set tIndex = $Increment(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures"))
							Set ^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures",tIndex) =
								$ListGet(tAssertData,2) _ ": " _ $ListGet(tAssertData,3)
						}
					}
					If ($ListGet(tMethodData)=0)
					&& ('$data(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures"))) {
						If $Increment(^||TMP("S",tSuite,"failures"))
						If $Increment(^||TMP("S",tSuite,"C",tCase,"failures"))
						Set tIndex = $Increment(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures"))
						Set ^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures",tIndex) = 
							$ListGet(tMethodData,3) _ ": " _ $ListGet(tMethodData,4)
					}
				}
				
				If $ListGet(tCaseData)=0
				&& ('$data(^||TMP("S",tSuite,"C",tCase,"failures"))) {
					If $Increment(^||TMP("S",tSuite,"failures"))
					If $Increment(^||TMP("S",tSuite,"C",tCase,"failures"))
					Set tIndex = $Increment(^||TMP("S",tSuite,"C",tCase,"M",tCase,"failures"))
					Set ^||TMP("S",tSuite,"C",tCase,"M",tCase,"failures",tIndex) =
						$ListGet(tCaseData,3) _ ": " _ $ListGet(tCaseData,4)
				}
			}
		}
		
		Do tFile.WriteLine("<?xml version=""1.0"" encoding=""UTF-8"" ?>")
		Do tFile.WriteLine("<testsuites>")
		Set tSuite=""
		For {
			Set tSuite=$Order(^||TMP("S",tSuite))
			Quit:tSuite=""
			
			Do tFile.Write("<testsuite")
			Do tFile.Write(" name="""_$zconvert(tSuite,"O","XML")_"""")
			Do tFile.Write(" assertions="""_$get(^||TMP("S",tSuite,"assertions"))_"""")
			Do tFile.Write(" time="""_$get(^||TMP("S",tSuite,"time"))_"""")
			Do tFile.Write(" tests="""_$get(^||TMP("S",tSuite,"tests"))_"""")
			Do tFile.WriteLine(">")
			
			Set tCase=""
			For {
				Set tCase=$Order(^||TMP("S",tSuite,"C",tCase))
				Quit:tCase=""
				
				Do tFile.Write("<testsuite")
				Do tFile.Write(" name="""_$zconvert(tCase,"O","XML")_"""")
				Do tFile.Write(" assertions="""_$get(^||TMP("S",tSuite,"C",tCase,"assertions"))_"""")
				Do tFile.Write(" time="""_$get(^||TMP("S",tSuite,"C",tCase,"time"))_"""")
				Do tFile.Write(" tests="""_$get(^||TMP("S",tSuite,"C",tCase,"tests"))_"""")
				Do tFile.WriteLine(">")
				
				Set tMethod=""
				For {
					Set tMethod=$Order(^||TMP("S",tSuite,"C",tCase,"M",tMethod))
					Quit:tMethod=""
					
					Do tFile.Write("<testcase")
					Do tFile.Write(" name="""_$zconvert(tMethod,"O","XML")_"""")
					Do tFile.Write(" assertions="""_$get(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"assertions"))_"""")
					Do tFile.Write(" time="""_$get(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"time"))_"""")
					Do tFile.WriteLine(">")
					Set tFailureKey = ""
					For {
						Set tFailureKey = $Order(^||TMP("S",tSuite,"C",tCase,"M",tMethod,"failures",tFailureKey),1,tMessage)
						If (tFailureKey = "") {
							Quit
						}
						Set tMessage = $zstrip(tMessage,"*C")
						Set tMessage = $zconvert($zconvert(tMessage,"O","UTF8"),"O","XML")
						// Also encode newlines - $zconvert doesn't do this.
						Set tMessage = $replace(tMessage,$c(10),"&#10;")
						Set tMessage = $replace(tMessage,$c(13),"&#13;")
						Do tFile.Write("<failure type=""cache-error"" message="""_tMessage_""">")
						Do tFile.WriteLine("</failure>")
					}
					Do tFile.WriteLine("</testcase>")
				}
				Do tFile.WriteLine("</testsuite>")
			}
			Do tFile.WriteLine("</testsuite>")
		}
		Do tFile.WriteLine("</testsuites>")
		Kill ^||TMP
		
		$$$ThrowOnError(tFile.%Save())
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit $$$OK
}

}
