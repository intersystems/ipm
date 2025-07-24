Class Test.PM.Integration.Update Extends Test.PM.Integration.Base
{

Parameter ModuleNoDependencies As STRING = "update";
Parameter ModuleWithDependencies As STRING = "update-with-deps";
Parameter ModuleNoUpdateSteps As STRING = "update-no-update-steps";
Parameter ModuleDependenciesAdded As STRING = "update-deps-added";
Parameter OldModuleVersion As STRING = "1.2.0";
Parameter NewModuleVersion As STRING = "3.2.1";

Method OnBeforeAllTests() As %Status
{
  // Setup repo pointing to all modules used for tests in this class
  Set tSC = ##class(%IPM.Main).Shell("repo -n integration-tests -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/")
  Do $$$AssertStatusOK(tSC,"Created integration-tests repo successfully.")
  Return tSC
}

Method OnAfterAllTests() As %Status
{
  // Delete repo for FileCopy tests
  Set tSC = ##class(%IPM.Main).Shell("repo -delete -name integration-tests")
  Do $$$AssertStatusOK(tSC,"Deleted integration-tests repo successfully.")
  return tSC
}

Method TestModuleUpdateNoDependencies() 
{
  // straight up update from update 1.2.0 to update 3.2.1
}

Method TestModuleUpdateWithDependencies() 
{
  // straight up update from update-with-deps 1.2.0 to update-with-deps 3.2.1
}

Method TestModuleNoSeededUpdateSteps() 
{
  // No UpdateStep table records exist, or there is a gap
}

Method TestModuleNoUpdateClasses() 
{
  // No V#.cls classes exist
}

Method TestModuleUpdateNoInstall()
{
  // Update is called but the module was not already installed
}

Method TestModuleUpdateError()
{
  // Test that transaction is properly rolled back
}

Method TestUpdateFailsOnPrimary()
{
  // If running update on a primary mirror member, throw an error
}

Method TestDataUpdates()
{
  // Test that data updates are correctly applied
}

}