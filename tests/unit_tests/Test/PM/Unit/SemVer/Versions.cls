Class Test.PM.Unit.SemVer.Versions Extends Test.PM.Unit.SemVer.Abstract
{

Method TestPrereleaseComparison()
{
	do ..AssertFollows("1.0.0", "1.0.0-beta")
	do ..AssertFollows("1.0.0-beta", "1.0.0-alpha.1")
	do ..AssertFollows("1.0.0-alpha.1", "1.0.0-alpha")
	do ..AssertFollows("2.0.0", "1.0.0-alpha")

	do ..AssertNotFollows("1.0.0-alpha", "1.0.0-alpha.1")
	do ..AssertNotFollows("1.0.0-alpha", "1.0.0-alpha.beta")
	do ..AssertNotFollows("1.0.0-beta", "1.0.0")
	do ..AssertNotFollows("2.0.0-alpha", "1.0.0-alpha")

	// Build metadata should not affect order precedence
	do ..AssertNotFollows("1.0.0+build1", "1.0.0+build2")
	do ..AssertNotFollows("1.0.0+build1", "1.0.0")
	do ..AssertNotFollows("1.0.0", "1.0.0+build2")
}

/// Test that wildcard range intersection works correctly with prerelease upper bounds.
/// This is a regression test for a bug where Range.Intersect() failed to correctly
/// compare upper bounds with "-0" prerelease suffixes (per X-range spec).
/// When intersecting "1.*" (>=1.0.0 <2.0.0-0) and "1.0.*" (>=1.0.0 <1.1.0-0),
/// the result should be >=1.0.0 <1.1.0-0 (more restrictive bound).
Method TestWildcardRangeIntersection()
{
	// Test that wildcard ranges parse with prerelease tags per X-range spec
	set sc = ##class(%IPM.General.SemanticVersionExpression.Range).FromString("1.*", .r1)
	do $$$AssertStatusOK(sc, "1.* parses successfully")
	do $$$AssertEquals(r1.ToResolvedString(), ">=1.0.0 <2.0.0-0", "1.* resolves to >=1.0.0 <2.0.0-0")

	set sc = ##class(%IPM.General.SemanticVersionExpression.Range).FromString("1.0.*", .r2)
	do $$$AssertStatusOK(sc, "1.0.* parses successfully")
	do $$$AssertEquals(r2.ToResolvedString(), ">=1.0.0 <1.1.0-0", "1.0.* resolves to >=1.0.0 <1.1.0-0")

	// Test that intersection correctly selects the more restrictive upper bound
	set merged = ##class(%IPM.General.SemanticVersionExpression.Range).Intersect(r1, r2)
	do $$$AssertTrue($isobject(merged), "Intersect returns an object")
	do $$$AssertEquals(merged.ToResolvedString(), ">=1.0.0 <1.1.0-0", "1.* AND 1.0.* = >=1.0.0 <1.1.0-0")
}

Method TestPostreleaseComparison()
{
	do ##class(%IPM.Repo.UniversalSettings).SetValue("SemVerPostRelease", 1)
	do ..AssertFollows("1.0.0-1.m1", "1.0.0")
	do ..AssertFollows("1.0.0-1.m2", "1.0.0-1.m1")

	// Regular release should not follow post-release (we are treating -alpha as a post-release)
	do ..AssertNotFollows("1.0.0", "1.0.0-alpha")
}

Method TestVersions()
{
	do ..AssertVersionValid("1.0.0-alpha", 1, 0, 0, "alpha")
	do ..AssertVersionValid("1.0.0-alpha.1", 1, 0, 0, "alpha.1")
	do ..AssertVersionValid("1.0.0-0.3.7", 1, 0, 0, "0.3.7")
	do ..AssertVersionValid("1.0.0-x.7.z.92", 1, 0, 0, "x.7.z.92")
	do ..AssertVersionValid("1.0", 1, 0, 0)
	do ..AssertVersionValid("2022.2.0.311.0", 2022, 2, 0, , 311)

	do ..AssertVersionValid("1.0.0-alpha+001", 1, 0, 0, "alpha", "001")
	do ..AssertVersionValid("1.0.0+20130313144700", 1, 0, 0, , "20130313144700")
	do ..AssertVersionValid("1.0.0-beta+exp.sha.5114f85", 1, 0, 0, "beta", "exp.sha.5114f85")
	do ..AssertVersionValid("1.0.0-beta-alpha-delta+exp.sha-5114f85", 1, 0, 0, "beta-alpha-delta", "exp.sha-5114f85")
	do ..AssertVersionValid("1.0.0-test-C0008", 1, 0, 0, "test-C0008")
	do ..AssertVersionValid("1.0.0-0008ABC", 1, 0, 0, "0008ABC")

	do ..AssertVersionNotValid("01.1.0")
	do ..AssertVersionNotValid("1.01.0")
	do ..AssertVersionNotValid("1.1.01")
	do ..AssertVersionNotValid("1.1.1-007.alpha")
	do ..AssertVersionNotValid("1.1.1-bond...james-bond")
	do ..AssertVersionNotValid("1.1.1-alpha?")

	// Valid versions with only build metadata
	do ..AssertVersionValid("1.2.3+build.meta", 1, 2, 3, "", "build.meta")
	do ..AssertVersionValid("0.0.1+001", 0, 0, 1, "", "001")
}

Method AssertVersionValid(
	pVersion As %String,
	pMajor As %String = "",
	pMinor As %String = "",
	pPatch As %String = "",
	pPrerelease As %String = "",
	pBuild As %String = "")
{
	set tSC = ##class(%IPM.General.SemanticVersion).IsValid(pVersion, .tSemVer)
	if '$$$AssertStatusOK(tSC,pVersion_" is accepted as a valid semantic version.") {
		do $$$LogMessage($system.Status.GetErrorText(tSC))
	}
  elseif pMajor'="" {
    do $$$AssertEquals(tSemVer.Major, pMajor)
    do $$$AssertEquals(tSemVer.Minor, pMinor)
    do $$$AssertEquals(tSemVer.Patch, pPatch)
    do $$$AssertEquals(tSemVer.Prerelease, pPrerelease)
    do $$$AssertEquals(tSemVer.Build, pBuild)
  }
}

Method AssertVersionNotValid(pVersion As %String)
{
	do $$$AssertStatusNotOK(##class(%IPM.General.SemanticVersion).IsValid(pVersion),pVersion_" is not accepted as a valid semantic version.")
}

Method AssertFollows(
	pVersion1 As %String,
	pVersion2 As %String)
{
	set tSemVer1 = ##class(%IPM.General.SemanticVersion).FromString(pVersion1)
	set tSemVer2 = ##class(%IPM.General.SemanticVersion).FromString(pVersion2)
	do $$$AssertEquals(tSemVer1.Follows(tSemVer2), 1, pVersion1_" follows "_pVersion2)
}

Method AssertNotFollows(
	pVersion1 As %String,
	pVersion2 As %String)
{
	set tSemVer1 = ##class(%IPM.General.SemanticVersion).FromString(pVersion1)
	set tSemVer2 = ##class(%IPM.General.SemanticVersion).FromString(pVersion2)
	do $$$AssertEquals(tSemVer1.Follows(tSemVer2), 0, pVersion1_" does not follow "_pVersion2)
}

}
