Include %occErrors

Class Test.PM.Unit.ResourceReference Extends %UnitTest.TestCase
{

Method TestDatabaseResources()
{
	Do ..AssertResourceNameValid("My.Class.CLS")
	Do ..AssertResourceNameValid("My.Package.PKG")
	Do ..AssertResourceNameValid("Include.INC")
	#; Do ..AssertResourceNameInvalid("abc")
}

Method TestDirectoryResources()
{
	Do ..AssertResourceNameValid("/ui")
	Do ..AssertResourceNameValid("/ui/")
	Do ..AssertResourceNameValid("/localize/MyErrorMessages.xml")
	#; Do ..AssertResourceNameInvalid("\badslash")
}

Method AssertResourceNameValid(pResourceName As %String)
{
	Set tSC = ##class(%IPM.Storage.ResourceReference).NameIsValid(pResourceName)
	Do $$$AssertStatusOK(tSC,"Resource name "_pResourceName_" is valid.")
}

Method AssertResourceNameInvalid(pResourceName As %String)
{
	Set tSC = ##class(%IPM.Storage.ResourceReference).NameIsValid(pResourceName)
	Do $$$AssertEquals($System.Status.GetErrorCodes(tSC),$$$DTPattern,"Resource name "_pResourceName_" is invalid.")
}

}
