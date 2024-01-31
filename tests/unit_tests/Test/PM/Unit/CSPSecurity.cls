Class Test.PM.Unit.CSPSecurity Extends %UnitTest.TestCase
{

Method TestCSPURLDefined()
{
	// All classes in the %IPM.PackageManager package that extend %CSP.Page, directly or indirectly,
	// must either define a CSPURL parameter or also extend one of the following classes:
	// %CSP.REST
	// %IPM.PackageManager.Server.AbstractService
	Set tResult = ##class(%Dictionary.ClassDefinition).SubclassOfFunc("%CSP.Page","%IPM.PackageManager")
	If (tResult.%SQLCODE < 0) {
		Set tSC = $$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message)
		Do $$$AssertStatusOK(tSC)
	} Else {
		While tResult.%Next(.tSC) {
			If '$$$ISOK(tSC) {
				Do $$$AssertStatusOK(tSC)
			}
			
			Set tClass = tResult.%Get("Name")
			
			If '(tClass [ "%IPM.PackageManager") {
				// Done.
				Quit
			}
			If $ClassMethod(tClass,"%Extends","%CSP.REST") {
				Continue
			}
			If $ClassMethod(tClass,"%Extends","%IPM.PackageManager.Server.AbstractService") {
				Continue
			}
			
			Set tCSPURL = $Parameter(tClass,"CSPURL")
			Do $$$AssertNotEquals(tCSPURL,"","CSPURL defined for "_tClass)
			
			If '(tCSPURL [ tClass) {
				Do $$$AssertTrue(0,"Bad CSPURL for "_tClass_": "_tCSPURL)
			}
		}
		If '$$$ISOK(tSC) {
			Do $$$AssertStatusOK(tSC)
		}
	}
}

}
