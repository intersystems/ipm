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
/// - Running update on a module that has not been installed
/// 
/// 5. Create tests for trying to update the same module at the same time in the same namespace fails
/// 6. Create test for running update AFTER an an update process was killed mid-update is successful
/// 7. Create test that verifies the correct steps have been run after update depending on mirror membership.
/// 8. Update CI pipeline to add another IRIS instance which is mirrored. Initialize the main IRIS container as the primary and the new container as the backup.
/// 9. Update tests above to be mirror-aware.
/// - Check that the correct subset of update steps are run on each mirror member corresponding to its mirror membership types
Parameter ModuleOneVersion As STRING = "1.2.1";

Parameter ModuleTwoVersion As STRING = "2.1.1";

Parameter ModuleThreeVersion As STRING = "3.5.0";

Method OnBeforeAllTests() As %Status
{
  // Setup repo pointing to all modules used for tests in this class
  set tSC = ##class(%IPM.Main).Shell("repo -n integration-tests -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/")
  do $$$AssertStatusOK(tSC,"Created integration-tests repo successfully.")
  return tSC
}

Method OnAfterAllTests() As %Status
{
  // Clean up repo used for tests
  set tSC = ##class(%IPM.Main).Shell("repo -delete -name integration-tests")
  do $$$AssertStatusOK(tSC,"Deleted integration-tests repo successfully.")
  return tSC
}

Method TestModuleNormalUpdateNoMirror()
{
  set updateStepsToSeed = [["Update.Update.V1", "MethodA", 1]]
  set updateStepsToRun = [["Update.Update.V1", "MethodB", 0], ["Update.Update.V1", "MethodC", 1], ["Update.Update.V2", "MethodA", 1], ["Update.Update.V2", "MethodB", 0], ["Update.Update.V2", "MethodC", 1]]

  do ..ModuleNormalUpdateNoMirrorHelper(..#ModuleNoDependencies, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion, 0)
  do ..ModuleNormalUpdateNoMirrorHelper(..#ModuleNoDependencies, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion, 1)
}

Method TestUpdateToOlderVersion()
{
  // Load module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleTwoVersion)

  // Update module
  set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleOneVersion)
  do $$$AssertStatusNotOK(tSC, "Attempt at updating module to older version failed.")
}

Method TestUpdateToInvalidVersion()
{
  // Load module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module
  set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" 1.0.0")
  do $$$AssertStatusNotOK(tSC, "Attempt at updating module to non-existent version failed.")
}

Method TestUpdateToNewVersionTwice()
{
  // Load module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module to a 2.x version
  set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  do $$$AssertStatusOK(tSC, "Updated module to "_..#ModuleTwoVersion_" without error")

  // Update module to a 3.x version
  set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleThreeVersion)
  do $$$AssertStatusOK(tSC, "Updated module to "_..#ModuleThreeVersion_" without error")
}

Method TestUpdateToSameVersionTwiceNoMirror()
{
  // Load module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module to a 2.x version
  set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  do $$$AssertStatusOK(tSC, "Updated module to "_..#ModuleTwoVersion_"without error")

  // Get timestamps of the V2 methods
  set stepTwoA = ..GetUpdateStep("Update.Update.V2", "MethodA", 1)
  set stepTwoB = ..GetUpdateStep("Update.Update.V2", "MethodB", 0)
  set stepTwoC = ..GetUpdateStep("Update.Update.V2", "MethodC", 1)

  set twoAStart = stepTwoA.TimeStampStart
  set twoAEnd = stepTwoA.TimeStampEnd

  set twoBStart = stepTwoB.TimeStampStart
  set twoBEnd = stepTwoB.TimeStampEnd

  set twoCStart = stepTwoC.TimeStampStart
  set twoCEnd = stepTwoC.TimeStampEnd

  // Update module to SAME version
  set tSC = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  do $$$AssertStatusOK(tSC, "Updated module to "_..#ModuleTwoVersion_"without error")

  // Check that second update does not rerun update steps
  // (timestamps on each update step should not have changed)
  do $$$AssertEquals(twoAStart, stepTwoA.TimeStampStart)
  do $$$AssertEquals(twoAEnd, stepTwoA.TimeStampEnd)

  do $$$AssertEquals(twoBStart, stepTwoB.TimeStampStart)
  do $$$AssertEquals(twoBEnd, stepTwoB.TimeStampEnd)

  do $$$AssertEquals(twoCStart, stepTwoC.TimeStampStart)
  do $$$AssertEquals(twoCEnd, stepTwoC.TimeStampEnd)
}

/// ///////////////////////////////////////////// HELPER METHODS ////////////////////////////////////////////////
/// NOTE: For testing simplicity, we will always assume that in the update test, both the module and its dependencies are being updated
/// from and to the same version numbers.
/// Completes an update of given moduleName from fromVersion to toVersion, verifying that the given updateStepsToSeed are seeded
/// and that the given updateStepsToRun are run
/// @params moduleName          Name of module to install and update
/// @params updateStepsToSeed   Array of [className, methodName, isPrimaryOnlyStep] update steps that are defined in the module PRE-update
/// @params updateStepsToRun    Array of [className, methodName, isPrimaryOnlyStep] update steps that exist in the new version of the module POST-update
/// @params fromVersion         Version of module to install
/// @params toVersion           Version of module to which to update
/// @params developerMode       1 if update should be run with -dev flag, 0 otherwise
Method ModuleNormalUpdateNoMirrorHelper(
	moduleName As %String,
	updateStepsToSeed As %DynamicArray,
	updateStepsToRun As %DynamicArray,
	fromVersion As %String,
	toVersion As %String,
	developerMode As %Boolean = 0)
{
  if '$system.Mirror.IsMember() {
    // Load module
    do ..AssertModuleInstalledCorrectly(moduleName, fromVersion)

    // Verify that update steps were correctly seeded and capture the TimeStampEnd property for comparison
    set timeStampArr = []
    set iter = updateStepsToSeed.%GetIterator()
    while iter.%GetNext(.key, .value) {
      set className = value.%Get(0)
      set methodName = value.%Get(1)
      set isPrimaryOnly = value.%Get(2)

      set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
      do $$$AssertNotEquals("", updateStep, "Update step with class="_className_" and method="_methodName_" exists.")
      set timeStampArr(updateStep.UpdateStepClassMethodIdx) = updateStep.TimeStampStart
    }

    // Update module
    set devFlag = $select(developerMode: "-dev", 1: "")
    set tSC = ##class(%IPM.Main).Shell("update -v "_devFlag_" "_moduleName_" "_toVersion)
    do $$$AssertStatusOK(tSC, "Updated module "_moduleName_" without error")

    // Check that seeded methods were not re-run
    set iter = updateStepsToSeed.%GetIterator()
    while iter.%GetNext(.key, .value) {
      set className = value.%Get(0)
      set methodName = value.%Get(1)
      set isPrimaryOnly = value.%Get(2)

      set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
      do $$$AssertEquals(timeStampArr(updateStep.UpdateStepClassMethodIdx), updateStep.TimeStampStart, "Seeded update step with class="_className_" and method="_methodName_" was correctly not rerun on update.")
    }

    // Check whether correct UpdateStep rows exist in the correct table after update command is run
    do ..AssertUpdateStepsExist(updateStepsToRun)

    // NOTE: For testing simplicity, we will always assume that in the update test, both the module and its dependencies are being updated
    // from and to the same version numbers.

    // Check module version has been updated
    set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
    do $$$AssertEquals(module.VersionString, toVersion)

    // Check that dependency versions have been updated
    set iter = module.Dependencies.%GetIterator()
    while iter.%GetNext(.key, .value) {
      do $$$AssertEquals(value.VersionString, toVersion)
    }
  }
}

/// Asserts that each update method in the given array has a corresponding UpdateStep object of the correct subclass
/// @params updateStepsList  Array of arrays, where each element is [className, methodName, isPrimaryOnly]
Method AssertUpdateStepsExist(updateStepsList As %DynamicArray)
{
  set iter = updateStepsList.%GetIterator()
  while iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    do $$$AssertNotEquals("", updateStep, "Update step with class="_className_" and method="_methodName_" exists.")
  }
}

Method AssertModuleInstalledCorrectly(
	moduleName As %String,
	moduleVersion As %String)
{
  set tSC = ##class(%IPM.Main).Shell("install -v "_moduleName_" "_moduleVersion)
  do $$$AssertStatusOK(tSC, "Loaded module successfully")
}

ClassMethod GetUpdateStep(
	className As %String,
	methodName As %String,
	isPrimaryOnly As %Boolean) As %IPM.Storage.UpdateStep
{
  if isPrimaryOnly {
    set step = ##class(%IPM.Storage.UpdateStep.PrimaryOnly).GetUpdateStep(className, methodName)
  } else {
    set step = ##class(%IPM.Storage.UpdateStep.AnyMember).GetUpdateStep(className, methodName)
  }

  return step
}

}
