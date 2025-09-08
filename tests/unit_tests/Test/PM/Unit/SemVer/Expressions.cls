Class Test.PM.Unit.SemVer.Expressions Extends Test.PM.Unit.SemVer.Abstract
{

Method TestEvaluate()
{
  set tExpression = ">=1.2.7"
  do ..AssertSatisfied(tExpression,"1.2.7")
  do ..AssertSatisfied(tExpression,"1.2.8")
  do ..AssertSatisfied(tExpression,"2.5.3")
  do ..AssertSatisfied(tExpression,"1.3.9")
  do ..AssertNotSatisfied(tExpression,"1.2.6")
  do ..AssertNotSatisfied(tExpression,"1.1.0")

  set tExpression = ">=1.2.7 <1.3.0"
  do ..AssertSatisfied(tExpression,"1.2.7")
  do ..AssertSatisfied(tExpression,"1.2.8")
  do ..AssertSatisfied(tExpression,"1.2.99")
  do ..AssertNotSatisfied(tExpression,"1.2.6")
  do ..AssertNotSatisfied(tExpression,"1.3.0")
  do ..AssertNotSatisfied(tExpression,"1.1.0")

  set tExpression = "1.2.7 || >=1.2.9 <2.0.0"
  do ..AssertSatisfied(tExpression,"1.2.7")
  do ..AssertSatisfied(tExpression,"1.2.9")
  do ..AssertSatisfied(tExpression,"1.4.6")
  do ..AssertNotSatisfied(tExpression,"1.2.8")
  do ..AssertNotSatisfied(tExpression,"2.0.0")

  // Build metadata: should match only if explicitly requested
  do ..AssertSatisfied("=1.0.0+build123", "1.0.0+build123")
  do ..AssertNotSatisfied("=1.0.0+build123", "1.0.0+build456")
  do ..AssertNotSatisfied("=1.0.0+build123", "1.0.0")
  do ..AssertSatisfied("=1.0.0", "1.0.0+build123")

  // Build should be ignored with comparators
  do ..AssertSatisfied(">=1.0.0", "1.0.0+build123")
  do ..AssertSatisfied(">=1.0.0-alpha", "1.0.0-alpha+buildXYZ")
  do ..AssertSatisfied("<2.0.0", "1.5.0+something")
  do ..AssertNotSatisfied("<1.0.0", "1.0.0+build999")
  do ..AssertSatisfied("<2.0.0+build", "1.5.0")
  do ..AssertNotSatisfied("<1.0.0+build", "1.0.0+build999")
  do ..AssertNotSatisfied("<3.0.1+something", "4.1.0")
}

Method TestPrerelease()
{
  do ..AssertNotSatisfied(">=1.0.0", "1.0.0-1.m1")
  do ..AssertSatisfied("1.0.0-beta.1","1.0.0-beta.1")
  do ..AssertSatisfied("=1.0.0-beta.1","1.0.0-beta.1")
  do ..AssertSatisfied(">=1.0.0-beta.1","1.0.0-beta.1")
  do ..AssertSatisfied(">=1.0.0-beta.1","1.0.0-beta.2")
  do ..AssertSatisfied(">=1.0.0-alpha.1","1.0.0-beta.1")
  do ..AssertNotSatisfied("^1.0.0","1.0.0-1.m1")
  do ..AssertNotSatisfied(">=1.0.0-beta.2","1.0.0-beta.1")
  do ..AssertNotSatisfied(">=1.0.0-beta.1","1.0.0-alpha.1")

  // This is the problematic case without HSIEO-10520
  do ..AssertNotSatisfied("1.0.0-1.m1","1.0.0")
  do ..AssertNotSatisfied("=1.0.0-1.m1","1.0.0")

  // Issue #557: snapshots/prereleases shouldn't be considered as a lower version number
  // Even though 1.5.0-beta.1 is technically within the 1.x range, it's a prerelease and should not be considered satisfiable.
  // Similarly 1.1.5-beta.1 does not satisify 1.1.x. See https://github.com/npm/node-semver?tab=readme-ov-file#prerelease-tags
  do ..AssertNotSatisfied("1.x", "1.5.0-beta.1")
  do ..AssertNotSatisfied("1.x", "2.0.0-0")
  do ..AssertNotSatisfied("1.x", "2.0.0-SNAPSHOT")
  do ..AssertNotSatisfied("1.x", "2.0.0-alpha")
  do ..AssertNotSatisfied("1.1.x", "1.1.5-beta.1")
  do ..AssertNotSatisfied("1.1.x", "1.2.0-0")
  do ..AssertNotSatisfied("1.1.x", "1.2.0-SNAPSHOT")
  do ..AssertNotSatisfied("1.1.x", "1.2.0-alpha")
}

Method TestPostRelease()
{
  // With SemVerPostRelease enabled, post-release versions should be considered as a higher version number
  set tSC = ##class(%IPM.Repo.UniversalSettings).SetValue("SemVerPostRelease", 1)
  do ..AssertSatisfied(">=1.0.0", "1.0.0-1.m1")
  do ..AssertSatisfied("1.0.0-beta.1","1.0.0-beta.1")
  do ..AssertSatisfied("=1.0.0-beta.1","1.0.0-beta.1")
  do ..AssertSatisfied(">=1.0.0-beta.1","1.0.0-beta.1")
  do ..AssertSatisfied(">=1.0.0-beta.1","1.0.0-beta.2")
  do ..AssertSatisfied(">=1.0.0-alpha.1","1.0.0-beta.1")

  do ..AssertSatisfied("^1.0.0","1.0.0-1.m1")
  do ..AssertNotSatisfied(">=1.0.0-beta.2","1.0.0-beta.1")
  do ..AssertNotSatisfied(">=1.0.0-beta.1","1.0.0-alpha.1")

  // This is the problematic case without HSIEO-10520
  do ..AssertNotSatisfied("1.0.0-1.m1","1.0.0")
  do ..AssertNotSatisfied("=1.0.0-1.m1","1.0.0")

  // With SemVerPostRelease enabled, 1.5.0-beta.1 is within the 1.x range, because it's a post-release of 1.5.0.
  // Similarly, 1.1.5-beta.1 satisifies 1.1.x.
  do ..AssertSatisfied("1.x", "1.5.0-beta.1")
  do ..AssertNotSatisfied("1.x", "2.0.0-0")
  do ..AssertNotSatisfied("1.x", "2.0.0-SNAPSHOT")
  do ..AssertNotSatisfied("1.x", "2.0.0-alpha")
  do ..AssertSatisfied("1.1.x", "1.1.5-beta.1")
  do ..AssertNotSatisfied("1.1.x", "1.2.0-0")
  do ..AssertNotSatisfied("1.1.x", "1.2.0-SNAPSHOT")
  do ..AssertNotSatisfied("1.1.x", "1.2.0-alpha")
}

Method TestEquivalenceHyphenRanges()
{
  do ..AssertEquivalent("1.2.3 - 2.3.4", ">=1.2.3 <=2.3.4")
  do ..AssertEquivalent("1.2 - 2.3.4", ">=1.2.0 <=2.3.4")
  do ..AssertEquivalent("1.2.3 - 2.3", ">=1.2.3 <2.4.0")
  do ..AssertEquivalent("1.2.3 - 2", ">=1.2.3 <3.0.0")
}

Method TestEquivalenceXRanges()
{
  do ..AssertEquivalent("*", ">=0.0.0") // Do we want to allow pre-release versions?
  do ..AssertEquivalent("", ">=0.0.0")  // Do we want to allow pre-release versions?
  do ..AssertEquivalent("1", ">=1.0.0 <2.0.0-0")
  do ..AssertEquivalent("1.x", ">=1.0.0 <2.0.0-0")
  do ..AssertEquivalent("1.2", ">=1.2.0 <1.3.0-0")
  do ..AssertEquivalent("1.2.*", ">=1.2.0 <1.3.0-0")
  do ..AssertEquivalent("1.2.X", ">=1.2.0 <1.3.0-0")
}

Method TestEquivalenceTildeRanges()
{
  do ..AssertEquivalent("~1.2.3", ">=1.2.3 <1.3.0-0")
  do ..AssertEquivalent("~1.2", ">=1.2.0 <1.3.0-0")
  do ..AssertEquivalent("~1", ">=1.0.0 <2.0.0-0")
  do ..AssertEquivalent("~0.2.3", ">=0.2.3 <0.3.0-0")
  do ..AssertEquivalent("~0.2", ">=0.2.0 <0.3.0-0")
  do ..AssertEquivalent("~0", ">=0.0.0 <1.0.0-0")
  do ..AssertEquivalent("~1.2.3-beta.2", ">=1.2.3-beta.2 <1.3.0-0")
}

Method TestEquivalenceCaretRanges()
{
  do ..AssertEquivalent("^1.2.3", ">=1.2.3 <2.0.0-0")
  do ..AssertEquivalent("^0.2.3", ">=0.2.3 <0.3.0-0")
  do ..AssertEquivalent("^0.0.3", ">=0.0.3 <0.0.4-0")
  do ..AssertEquivalent("^1.2.3-beta.2", ">=1.2.3-beta.2 <2.0.0-0")
  do ..AssertEquivalent("^0.0.3-beta", ">=0.0.3-beta <0.0.4-0")
  do ..AssertEquivalent("^1.2.x", ">=1.2.0 <2.0.0-0")
  do ..AssertEquivalent("^0.0.x", ">=0.0.0 <0.1.0-0")
  do ..AssertEquivalent("^0.0", ">=0.0.0 <0.1.0-0")
  do ..AssertEquivalent("^1.x", ">=1.0.0 <2.0.0-0")
  do ..AssertEquivalent("^0.x", ">=0.0.0 <1.0.0-0")
}

Method TestEquivalenceBuildMetadata()
{
  do ..AssertEquivalent("=1.0.0+build.123", "=1.0.0+build.123")
  do ..AssertNotSatisfied("=1.0.0+build.123", "1.0.0+build.abc")
}

Method TestIRISVersions()
{
  do ..AssertSatisfied("2022.2", "2022.2")
  do ..AssertNotSatisfied("2022.2", "2022.1")
  do ..AssertNotSatisfied("2022.2", "2022.3")
  do ..AssertNotSatisfied("2022.2", "2023.1")

  do ..AssertSatisfied(">=2022.1", "2022.2")
  do ..AssertNotSatisfied(">=2022.1", "2021.2")
}

Method TestAndedOr()
{
  // Test simple expression by itself
  do ##class(%IPM.General.SemanticVersionExpression).FromString("^3.0.0",.sve1)
  do $$$AssertTrue(sve1.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("3.2.1")))
  do $$$AssertNotTrue(sve1.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("2.0.0")))
  do $$$AssertNotTrue(sve1.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("4.0.0")))

  // Test simple OR expression
  do ##class(%IPM.General.SemanticVersionExpression).FromString("^2.0.1 || ^3.0.0",.sve2)
  do $$$AssertTrue(sve2.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("3.2.1")))
  do $$$AssertTrue(sve2.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("2.4.0")))
  do $$$AssertNotTrue(sve2.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("2.0.0")))
  do $$$AssertNotTrue(sve2.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("4.0.0")))

  // Test AND'ed expression
  set sve3 = sve1.And(sve2)
  do $$$AssertTrue(sve3.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("3.2.1")))
  do $$$AssertNotTrue(sve3.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("2.4.0")))
  do $$$AssertNotTrue(sve3.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("2.0.0")))
  do $$$AssertNotTrue(sve3.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("4.0.0")))

  // Test that you cannot ExpressionSet() an AND expression
  do $$$AssertStatusNotOK(sve3.ExpressionSet(">3.0.0"))
}

Method TestOnTheFlyMigration()
{
  // Tests that, with legacy storage missing CLASSNAME=1 on AnyOf (formerly Options), we properly interpret it as a range.
  set expr = ##class(%IPM.General.SemanticVersionExpression).%Open($listbuild($listbuild(">=2022.1",$listbuild($listbuild($listbuild($listbuild($listbuild($listbuild(">=",2022,1,0,,">=2022.1.0","",""))),">=2022.1")))),"%IPM.General.SemanticVersionExpression"))
  do $$$AssertEquals(expr.AnyOf.GetAt(1).%ClassName(1),"%IPM.General.SemanticVersionExpression.Range")
  do $$$AssertEquals(expr.AnyOf.GetAt(1).ToResolvedString(),">=2022.1.0")
}

Method AssertEquivalent(
	pVersionExpression1 As %String,
	pVersionExpression2 As %String,
	pVerbose As %Boolean = 0) As %Boolean [ Internal, Private ]
{
  set tEquivalent = 0
  try {
    do:pVerbose $$$LogMessage("First expression: "_pVersionExpression1)
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression1,.tExpr1)
    if $$$ISERR(tSC) {
      do:'pVerbose $$$LogMessage("Error parsing expression: "_pVersionExpression1)
      do $$$AssertStatusOK(tSC)
      quit
    }
    do:pVerbose $$$LogMessage("Second expression: "_pVersionExpression2)
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression2,.tExpr2)
    if $$$ISERR(tSC) {
      do:'pVerbose $$$LogMessage("Problem expression: "_pVersionExpression2)
      do $$$AssertStatusOK(tSC)
      quit
    }
    set tResolved1 = tExpr1.ToResolvedString()
    set tResolved2 = tExpr2.ToResolvedString()
    if $$$AssertEquals(tResolved1,tResolved2,"'"_pVersionExpression1_"' resolved to '"_tResolved2_"'") {
      set tEquivalent = 1
    } else {
      do $$$LogMessage("Detail: '"_tExpr1.Expression_"' resolved to '"_tExpr1.ToResolvedString()_"' rather than '"_tExpr2.ToResolvedString()_"'")
    }
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
  quit tEquivalent
}

Method AssertSatisfied(
	pVersionExpression As %String,
	pVersion As %String) As %Boolean [ Internal, Private ]
{
  set tSatisfied = 0
  try {
    set tVersion = ##class(%IPM.General.SemanticVersion).FromString(pVersion)
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression,.tVersionExpression)
    if $$$ISERR(tSC) {
      do $$$AssertStatusOK(tSC,"Error evaluating expression: '"_pVersionExpression_"'")
      quit
    }
    set tSatisfied = $$$AssertTrue(tVersion.Satisfies(tVersionExpression),"'"_pVersion_"' satisfies expression '"_ tVersionExpression.ToResolvedString() _"'")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
  quit tSatisfied
}

Method AssertNotSatisfied(
	pVersionExpression As %String,
	pVersion As %String) As %Boolean [ Internal, Private ]
{
  set tUnsatisfied = 0
  try {
    set tVersion = ##class(%IPM.General.SemanticVersion).FromString(pVersion)
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression,.tVersionExpression)
    if $$$ISERR(tSC) {
      do $$$AssertStatusOK(tSC,"Error evaluating expression: '"_pVersionExpression_"'")
      quit
    }
    set tUnsatisfied = $$$AssertNotTrue(tVersion.Satisfies(tVersionExpression),"'"_pVersion_"' does not satisfy expression '"_ tVersionExpression.ToResolvedString() _ "'")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
  quit tUnsatisfied
}

}
