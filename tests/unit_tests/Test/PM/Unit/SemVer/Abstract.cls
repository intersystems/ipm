Class Test.PM.Unit.SemVer.Abstract Extends %UnitTest.TestCase
{

/// Original value of the SemVerPostRelease setting
Property OriginalSemVerPostRelease As %Boolean [ InitialExpression = {##class(%IPM.Repo.UniversalSettings).GetValue("SemVerPostRelease")} ];

/// Before each test, record the original value of the SemVerPostRelease setting and set it to 0 for a clean slate
Method OnBeforeOneTest(testname As %String) As %Status
{
	Set ..OriginalSemVerPostRelease = ##class(%IPM.Repo.UniversalSettings).GetValue("SemVerPostRelease")
	Return ##class(%IPM.Repo.UniversalSettings).SetValue("SemVerPostRelease", 0)
}

/// After each test, restore the original value of the SemVerPostRelease setting
Method OnAfterOneTest(testname As %String) As %Status
{
	Return ##class(%IPM.Repo.UniversalSettings).SetValue("SemVerPostRelease", ..OriginalSemVerPostRelease)
}

}
