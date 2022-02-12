Class Test.PM.Unit.SemVer.Expressions Extends %UnitTest.TestCase
{

Method TestEvaluate()
{
	Set tExpression = ">=1.2.7"
	Do ..AssertSatisfied(tExpression,"1.2.7")
	Do ..AssertSatisfied(tExpression,"1.2.8")
	Do ..AssertSatisfied(tExpression,"2.5.3")
	Do ..AssertSatisfied(tExpression,"1.3.9")
	Do ..AssertNotSatisfied(tExpression,"1.2.6")
	Do ..AssertNotSatisfied(tExpression,"1.1.0")
	
	Set tExpression = ">=1.2.7 <1.3.0"
	Do ..AssertSatisfied(tExpression,"1.2.7")
	Do ..AssertSatisfied(tExpression,"1.2.8")
	Do ..AssertSatisfied(tExpression,"1.2.99")
	Do ..AssertNotSatisfied(tExpression,"1.2.6")
	Do ..AssertNotSatisfied(tExpression,"1.3.0")
	Do ..AssertNotSatisfied(tExpression,"1.1.0")
	
	Set tExpression = "1.2.7 || >=1.2.9 <2.0.0"
	Do ..AssertSatisfied(tExpression,"1.2.7")
	Do ..AssertSatisfied(tExpression,"1.2.9")
	Do ..AssertSatisfied(tExpression,"1.4.6")
	Do ..AssertNotSatisfied(tExpression,"1.2.8")
	Do ..AssertNotSatisfied(tExpression,"2.0.0")
}

Method TestEquivalenceHyphenRanges()
{
	Do ..AssertEquivalent("1.2.3 - 2.3.4", ">=1.2.3 <=2.3.4")
	Do ..AssertEquivalent("1.2 - 2.3.4", ">=1.2.0 <=2.3.4")
	Do ..AssertEquivalent("1.2.3 - 2.3", ">=1.2.3 <2.4.0")
	Do ..AssertEquivalent("1.2.3 - 2", ">=1.2.3 <3.0.0")
}

Method TestEquivalenceXRanges()
{
	Do ..AssertEquivalent("*", ">=0.0.0")
	Do ..AssertEquivalent("", ">=0.0.0")
	Do ..AssertEquivalent("1", ">=1.0.0 <2.0.0")
	Do ..AssertEquivalent("1.x", ">=1.0.0 <2.0.0")
	Do ..AssertEquivalent("1.2", ">=1.2.0 <1.3.0")
	Do ..AssertEquivalent("1.2.*", ">=1.2.0 <1.3.0")
	Do ..AssertEquivalent("1.2.X", ">=1.2.0 <1.3.0")
}

Method TestEquivalenceTildeRanges()
{
	Do ..AssertEquivalent("~1.2.3", ">=1.2.3 <1.3.0")
	Do ..AssertEquivalent("~1.2", ">=1.2.0 <1.3.0")
	Do ..AssertEquivalent("~1", ">=1.0.0 <2.0.0")
	Do ..AssertEquivalent("~0.2.3", ">=0.2.3 <0.3.0")
	Do ..AssertEquivalent("~0.2", ">=0.2.0 <0.3.0")
	Do ..AssertEquivalent("~0", ">=0.0.0 <1.0.0")
	Do ..AssertEquivalent("~1.2.3-beta.2", ">=1.2.3-beta.2 <1.3.0")
}

Method TestEquivalenceCaretRanges()
{
	Do ..AssertEquivalent("^1.2.3", ">=1.2.3 <2.0.0")
	Do ..AssertEquivalent("^0.2.3", ">=0.2.3 <0.3.0")
	Do ..AssertEquivalent("^0.0.3", ">=0.0.3 <0.0.4")
	Do ..AssertEquivalent("^1.2.3-beta.2", ">=1.2.3-beta.2 <2.0.0")
	Do ..AssertEquivalent("^0.0.3-beta", ">=0.0.3-beta <0.0.4")
	Do ..AssertEquivalent("^1.2.x", ">=1.2.0 <2.0.0")
	Do ..AssertEquivalent("^0.0.x", ">=0.0.0 <0.1.0")
	Do ..AssertEquivalent("^0.0", ">=0.0.0 <0.1.0")
	Do ..AssertEquivalent("^1.x", ">=1.0.0 <2.0.0")
	Do ..AssertEquivalent("^0.x", ">=0.0.0 <1.0.0")
}

Method AssertEquivalent(pVersionExpression1 As %String, pVersionExpression2 As %String, pVerbose As %Boolean = 0) As %Boolean [ Internal, Private ]
{
	Set tEquivalent = 0
	Try {
		Do:pVerbose $$$LogMessage("First expression: "_pVersionExpression1)
		Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression1,.tExpr1)
		If $$$ISERR(tSC) {
			Do:'pVerbose $$$LogMessage("Error parsing expression: "_pVersionExpression1)
			Do $$$AssertStatusOK(tSC)
			Quit
		}
		Do:pVerbose $$$LogMessage("Second expression: "_pVersionExpression2)
		Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression2,.tExpr2)
		If $$$ISERR(tSC) {
			Do:'pVerbose $$$LogMessage("Problem expression: "_pVersionExpression2)
			Do $$$AssertStatusOK(tSC)
			Quit
		}
		Set tResolved1 = tExpr1.ToResolvedString()
		Set tResolved2 = tExpr2.ToResolvedString()
		If $$$AssertEquals(tResolved1,tResolved2,"'"_pVersionExpression1_"' resolved to '"_tResolved2_"'") {
			Set tEquivalent = 1
		} Else {
			Do $$$LogMessage("Detail: '"_tExpr1.Expression_"' resolved to '"_tExpr1.ToResolvedString()_"' rather than '"_tExpr2.ToResolvedString()_"'")
		}
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
	Quit tEquivalent
}

Method AssertSatisfied(pVersionExpression As %String, pVersion As %String) As %Boolean [ Internal, Private ]
{
	Set tSatisfied = 0
	Try {
		Set tVersion = ##class(%IPM.General.SemanticVersion).FromString(pVersion)
		Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression,.tVersionExpression)
		If $$$ISERR(tSC) {
			Do $$$AssertStatusOK(tSC,"Error evaluating expression: '"_pVersionExpression_"'")
			Quit
		}
		Set tSatisfied = $$$AssertTrue(tVersion.Satisfies(tVersionExpression),"'"_pVersion_"' satisfies expression '"_pVersionExpression_"'")
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
	Quit tSatisfied
}

Method AssertNotSatisfied(pVersionExpression As %String, pVersion As %String) As %Boolean [ Internal, Private ]
{
	Set tUnsatisfied = 0
	Try {
		Set tVersion = ##class(%IPM.General.SemanticVersion).FromString(pVersion)
		Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression,.tVersionExpression)
		If $$$ISERR(tSC) {
			Do $$$AssertStatusOK(tSC,"Error evaluating expression: '"_pVersionExpression_"'")
			Quit
		}
		Set tUnsatisfied = $$$AssertNotTrue(tVersion.Satisfies(tVersionExpression),"'"_pVersion_"' does not satisfy expression '"_pVersionExpression_"'")
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
	Quit tUnsatisfied
}

}
