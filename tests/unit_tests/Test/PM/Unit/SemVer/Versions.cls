Class Test.PM.Unit.SemVer.Versions Extends Test.PM.Unit.SemVer.Abstract
{

Method TestPrereleaseComparison()
{
	Do ..AssertFollows("1.0.0", "1.0.0-beta")
	Do ..AssertFollows("1.0.0-beta", "1.0.0-alpha.1")
	Do ..AssertFollows("1.0.0-alpha.1", "1.0.0-alpha")
	Do ..AssertFollows("2.0.0", "1.0.0-alpha")

	Do ..AssertNotFollows("1.0.0-alpha", "1.0.0-alpha.1")
	Do ..AssertNotFollows("1.0.0-alpha", "1.0.0-alpha.beta")
	Do ..AssertNotFollows("1.0.0-beta", "1.0.0")
	Do ..AssertNotFollows("2.0.0-alpha", "1.0.0-alpha")
}

Method TestPostreleaseComparison()
{
	Do ##class(%IPM.Repo.UniversalSettings).SetValue("SemVerPostRelease", 1)
	Do ..AssertFollows("1.0.0-1.m1", "1.0.0")
	Do ..AssertFollows("1.0.0-1.m2", "1.0.0-1.m1")

	// Regular release should not follow post-release (we are treating -alpha as a post-release)
	Do ..AssertNotFollows("1.0.0", "1.0.0-alpha")
}

Method TestVersions()
{
	Do ..AssertVersionValid("1.0.0-alpha", 1, 0, 0, "alpha")
	Do ..AssertVersionValid("1.0.0-alpha.1", 1, 0, 0, "alpha.1")
	Do ..AssertVersionValid("1.0.0-0.3.7", 1, 0, 0, "0.3.7")
	Do ..AssertVersionValid("1.0.0-x.7.z.92", 1, 0, 0, "x.7.z.92")
	Do ..AssertVersionValid("1.0", 1, 0, 0)
	Do ..AssertVersionValid("2022.2.0.311.0", 2022, 2, 0, , 311)
	
	Do ..AssertVersionValid("1.0.0-alpha+001", 1, 0, 0, "alpha", "001")
	Do ..AssertVersionValid("1.0.0+20130313144700", 1, 0, 0, , "20130313144700")
	Do ..AssertVersionValid("1.0.0-beta+exp.sha.5114f85", 1, 0, 0, "beta", "exp.sha.5114f85")
	Do ..AssertVersionValid("1.0.0-beta-alpha-delta+exp.sha-5114f85", 1, 0, 0, "beta-alpha-delta", "exp.sha-5114f85")
	Do ..AssertVersionValid("1.0.0-test-C0008", 1, 0, 0, "test-C0008")
	Do ..AssertVersionValid("1.0.0-0008ABC", 1, 0, 0, "0008ABC")
	
	Do ..AssertVersionNotValid("01.1.0")
	Do ..AssertVersionNotValid("1.01.0")
	Do ..AssertVersionNotValid("1.1.01")
	Do ..AssertVersionNotValid("1.1.1-007.alpha")
	Do ..AssertVersionNotValid("1.1.1-bond...james-bond")
	Do ..AssertVersionNotValid("1.1.1-alpha?")
}

Method AssertVersionValid(pVersion As %String, pMajor As %String = "", pMinor As %String = "", pPatch As %String = "", pPrerelease As %String = "", pBuild As %String = "")
{
	Set tSC = ##class(%IPM.General.SemanticVersion).IsValid(pVersion, .tSemVer)
	If '$$$AssertStatusOK(tSC,pVersion_" is accepted as a valid semantic version.") {
		Do $$$LogMessage($System.Status.GetErrorText(tSC))
	}
  ElseIf pMajor'="" {
    Do $$$AssertEquals(tSemVer.Major, pMajor)
    Do $$$AssertEquals(tSemVer.Minor, pMinor)
    Do $$$AssertEquals(tSemVer.Patch, pPatch)
    Do $$$AssertEquals(tSemVer.Prerelease, pPrerelease)
    Do $$$AssertEquals(tSemVer.Build, pBuild)
  }
}

Method AssertVersionNotValid(pVersion As %String)
{
	Do $$$AssertStatusNotOK(##class(%IPM.General.SemanticVersion).IsValid(pVersion),pVersion_" is not accepted as a valid semantic version.")
}

Method AssertFollows(pVersion1 As %String, pVersion2 As %String)
{
	Set tSemVer1 = ##class(%IPM.General.SemanticVersion).FromString(pVersion1)
	Set tSemVer2 = ##class(%IPM.General.SemanticVersion).FromString(pVersion2)
	Do $$$AssertEquals(tSemVer1.Follows(tSemVer2), 1, pVersion1_" follows "_pVersion2)
}

Method AssertNotFollows(pVersion1 As %String, pVersion2 As %String)
{
	Set tSemVer1 = ##class(%IPM.General.SemanticVersion).FromString(pVersion1)
	Set tSemVer2 = ##class(%IPM.General.SemanticVersion).FromString(pVersion2)
	Do $$$AssertEquals(tSemVer1.Follows(tSemVer2), 0, pVersion1_" does not follow "_pVersion2)
}

}
