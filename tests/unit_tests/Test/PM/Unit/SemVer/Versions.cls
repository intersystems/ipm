Class Test.PM.Unit.SemVer.Versions Extends %UnitTest.TestCase
{

Method TestVersions()
{
	Do ..AssertVersionValid("1.0.0-alpha")
	Do ..AssertVersionValid("1.0.0-alpha.1")
	Do ..AssertVersionValid("1.0.0-0.3.7")
	Do ..AssertVersionValid("1.0.0-x.7.z.92")
	
	Do ..AssertVersionValid("1.0.0-alpha+001")
	Do ..AssertVersionValid("1.0.0+20130313144700")
	Do ..AssertVersionValid("1.0.0-beta+exp.sha.5114f85")
	Do ..AssertVersionValid("1.0.0-beta-alpha-delta+exp.sha-5114f85")
	
	Do ..AssertVersionNotValid("1.0")
	Do ..AssertVersionNotValid("01.1.0")
	Do ..AssertVersionNotValid("1.01.0")
	Do ..AssertVersionNotValid("1.1.01")
	Do ..AssertVersionNotValid("1.1.1-007.alpha")
	Do ..AssertVersionNotValid("1.1.1-bond...james-bond")
	Do ..AssertVersionNotValid("1.1.1-alpha?")
}

Method AssertVersionValid(pVersion As %String)
{
	Set tSC = ##class(%IPM.General.SemanticVersion).IsValid(pVersion)
	If '$$$AssertStatusOK(tSC,pVersion_" is accepted as a valid semantic version.") {
		Do $$$LogMessage($System.Status.GetErrorText(tSC))
	}
}

Method AssertVersionNotValid(pVersion As %String)
{
	Do $$$AssertStatusNotOK(##class(%IPM.General.SemanticVersion).IsValid(pVersion),pVersion_" is not accepted as a valid semantic version.")
}

}
