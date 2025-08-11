Class Test.PM.Integration.Update Extends Test.PM.Integration.Base
{

Parameter ModuleNoDependencies As STRING = "update";

/// Update testing TO-DOs: 
/// 1. Create the following modules:
/// 
/// - (X) Module without dependencies (simplest case)
/// - Module with dependencies
/// - Module with dependencies added as part of an update
/// - Module with dependencies removed as part of an update
/// - Module without any update methods (in either the current or updated module)
/// - Module with update methods but no seeded steps
/// - Module with new update method added to an older major version
/// - Module with changed update method order for the current major version
/// - Module with an update step that throws an error
/// - Module with a dependency whose update step that throws an error
/// - Module with an <Invoke> that throws an error during a lifecycle phase
/// - Module with a dependency with an <Invoke> that throws an error during a lifecycle phase
/// 
/// 2. (X) Create a generic update test to be run on all the modules WITHOUT ERRORS that does the following:
///  Note: Run it once with -dev flag
/// - Rows have been added to the UpdateStep table for each update method in the appropriate range of V# classes for 1) the base module and 2) each of its dependencies
/// - The correct update steps are run (e.g. starting at the correct step within the correct major version)
/// - (SKIPPING FOR NOW) Logging is correctly outputted to the (optionally provided) log file or standard output.
/// - Correct versions of dependency modules are installed
/// 
/// 3. Create a generic update test to be run on all the modules WITH ERRORS:
/// - All update-related logic is rolled back (the old module is still installed and no new UpdateStep objects exist)
/// - Errors are logged appropriately in the (optionally provided) log file or standard output.
/// 
/// 4. Create tests for the following cases (to be run on the simplest module): 
/// - (X) Running update twice on the same module to new version is successful
/// - (X) Running update with an older version throws an error immediately
/// - (X) Running update with a version that doesn't exist in any configured repository throws an error immediately
/// - (X) Running the same update command twice in a row results in a no-op on all update steps the second time
/// 
/// 5. Create tests for trying to update the same module at the same time in the same namespace fails
/// 6. Create test for running update AFTER an an update process was killed mid-update is successful
/// 7. Create test that verifies the correct steps have been run after update depending on mirror membership. 
/// 
Parameter ModuleOneVersion As STRING = "1.2.1";

Parameter ModuleTwoVersion As STRING = "2.1.1";

Parameter ModuleThreeVersion As STRING = "3.5.0";

Method OnBeforeAllTests() As %Status
{
  // Setup repo pointing to all modules used for tests in this class
  Set tSC = ##class(%IPM.Main).Shell("repo -n integration-tests -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/")
  Do $$$AssertStatusOK(tSC,"Created integration-tests repo successfully.")
  Return tSC
}

Method OnAfterAllTests() As %Status
{
  // Clean up repo used for tests
  Set tSC = ##class(%IPM.Main).Shell("repo -delete -name integration-tests")
  Do $$$AssertStatusOK(tSC,"Deleted integration-tests repo successfully.")
  return tSC
}

Method TestModuleNormalUpdateNoMirror()
{
  Set updateStepsBefore = [["Update.Update.V1", "MethodA", 1]]
  Set updateStepsAfter = [["Update.Update.V1", "MethodB", 0], ["Update.Update.V1", "MethodC", 1], ["Update.Update.V2", "MethodA", 1], ["Update.Update.V2", "MethodB", 0], ["Update.Update.V2", "MethodC", 1]]

  Do ..ModuleNormalUpdateNoMirrorHelper(..#ModuleNoDependencies, updateStepsBefore, updateStepsAfter, ..#ModuleOneVersion, ..#ModuleTwoVersion, 0)
  Do ..ModuleNormalUpdateNoMirrorHelper(..#ModuleNoDependencies, updateStepsBefore, updateStepsAfter, ..#ModuleOneVersion, ..#ModuleTwoVersion, 1)
}

Method TestUpdateToOlderVersion()
{
  // Load module
  Do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleTwoVersion)

  // Update module
  Set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleOneVersion)
  Do $$$AssertStatusNotOK(tSC, "Attempt at updating module to older version failed.")
}

Method TestUpdateToInvalidVersion()
{
  // Load module
  Do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module
  Set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_"1.0.0")
  Do $$$AssertStatusNotOK(tSC, "Attempt at updating module to non-existent version failed.")
}

Method TestUpdateToNewVersionTwice()
{
  // Load module
  Do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module to a 2.x version
  Set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  Do $$$AssertStatusOK(tSC, "Updated module to "_..#ModuleTwoVersion_"without error")

  // Update module to a 3.x version
  Set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleThreeVersion)
  Do $$$AssertStatusOK(tSC, "Updated module to "_..#ModuleThreeVersion_"without error")
}

Method TestUpdateToSameVersionTwiceNoMirror()
{
  // Load module
  Do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module to a 2.x version
  Set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  Do $$$AssertStatusOK(tSC, "Updated module to "_..#ModuleTwoVersion_"without error")

  // Get timestamps of the V2 methods
  Set stepTwoA = ..GetUpdateStep("Update.Update.V2", "MethodA", 1)
  Set stepTwoB = ..GetUpdateStep("Update.Update.V2", "MethodB", 0)
  Set stepTwoC = ..GetUpdateStep("Update.Update.V2", "MethodC", 1)
  
  Set twoAStart = stepTwoA.TimeStampStart
  Set twoAEnd = stepTwoA.TimeStampEnd

  Set twoBStart = stepTwoB.TimeStampStart
  Set twoBEnd = stepTwoB.TimeStampEnd
  
  Set twoCStart = stepTwoC.TimeStampStart
  Set twoCEnd = stepTwoC.TimeStampEnd

  // Update module to SAME version
  Set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  Do $$$AssertStatusOK(tSC, "Updated module to "_..#ModuleTwoVersion_"without error")

  // Check that second update does not rerun update steps
  // (timestamps on each update step should not have changed) 
  Do $$$AssertEquals(twoAStart, stepTwoA.TimeStampStart)
  Do $$$AssertEquals(twoAEnd, stepTwoA.TimeStampEnd)
  
  Do $$$AssertEquals(twoBStart, stepTwoB.TimeStampStart)
  Do $$$AssertEquals(twoBEnd, stepTwoB.TimeStampEnd)
  
  Do $$$AssertEquals(twoCStart, stepTwoC.TimeStampStart)
  Do $$$AssertEquals(twoCEnd, stepTwoC.TimeStampEnd)
}

/// ///////////////////////////////////////////// HELPER METHODS ////////////////////////////////////////////////
/// For testing simplicity, we will always assume that in the update test, both the module and its dependencies are being updated
/// from and to the same version numbers.
Method ModuleNormalUpdateNoMirrorHelper(moduleName As %String, updateStepsBefore As %DynamicArray, updateStepsAfter As %DynamicArray, fromVersion As %String, toVersion As %String, DeveloperMode As %Boolean = 0)
{
  if '$system.Mirror.IsMember() {
    // Load module
    Do ..AssertModuleInstalledCorrectly(moduleName, ..#ModuleOneVersion)

    // Verify that update steps were correctly seeded and capture the TimeStampEnd property for comparison
    Set timeStampArr = []
    Set iter = updateStepsBefore.%GetIterator()
    While iter.%GetNext(.key, .value) {
      set className = value.%Get(0)
      set methodName = value.%Get(1)
      set isPrimaryOnly = value.%Get(2)

      Set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
      Do $$$AssertNotEquals("", updateStep, "Update step with class="_className_" and method="_methodName_" exists.")
      Set timeStampArr(updateStep.UpdateStepClassMethodIdx) = updateStep.TimeStampEnd
    }

    // Update module
    Set devFlag = $select(DeveloperMode: "-dev", 1: "")
    Set tSC = ##class(%IPM.Main).Shell("update -v "_devFlag_moduleName_" "_..#ModuleTwoVersion)
    Do $$$AssertStatusOK(tSC, "Updated module without error") 

    // Check that seeded methods were not re-run
    Set iter = updateStepsBefore.%GetIterator()
    While iter.%GetNext(.key, .value) {
      set className = value.%Get(0)
      set methodName = value.%Get(1)
      set isPrimaryOnly = value.%Get(2)

      Set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
      Do $$$AssertEquals(timeStampArr(updateStep.UpdateStepClassMethodIdx), updateStep.TimeStampEnd, "Seeded update step with class="_className_" and method="_methodName_" was correctly not rerun on update.")
    }

    // Check whether correct UpdateStep rows exist in the correct table after update command is run
    Set updateSteps = ..AssertUpdateStepsExist(updateStepsAfter)

    // NOTE: For testing simplicity, we will always assume that in the update test, both the module and its dependencies are being updated
    // from and to the same version numbers.

    // Check module version has been updated
    Set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
    Do $$$AssertEquals(module.VersionString, ..#ModuleTwoVersion)

    // Check that dependency versions have been updated
    Set iter = module.Dependencies.%GetIterator()
    While iter.%GetNext(.key, .value) {
      Do $$$AssertEquals(value.VersionString, ..#ModuleTwoVersion)
    }
  }
}

/// @params updateStepsList  Array of arrays, where each element is [className, methodName, isPrimaryOnly]
Method AssertUpdateStepsExist(updateStepsList As %DynamicArray) As %DynamicArray
{
  Set updateStepList = []
  Set iter = updateStepsList.%GetIterator()
  While iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    Set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    Do $$$AssertNotEquals("", updateStep, "Update step with class="_className_" and method="_methodName_" exists.")
    Do updateStepList.%Push(updateStep)
  }

  Return updateStepList
}

Method AssertModuleInstalledCorrectly(moduleName As %String, moduleVersion As %String)
{
  Set tSC = ##class(%IPM.Main).Shell("install -v "_moduleName_" "_moduleVersion)
  Do $$$AssertStatusOK(tSC, "Loaded module successfully")
}

ClassMethod GetUpdateStep(className As %String, methodName As %String, isPrimaryOnly As %Boolean) As %IPM.Storage.UpdateStep
{
  If isPrimaryOnly {
    set step = ##class(%IPM.Storage.UpdateStep.PrimaryOnly).GetUpdateStep(className, methodName)
  } Else {
    set step = ##class(%IPM.Storage.UpdateStep.AnyMember).GetUpdateStep(className, methodName)
  }

  Return step
}

}
