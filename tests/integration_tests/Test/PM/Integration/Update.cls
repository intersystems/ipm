Class Test.PM.Integration.Update Extends Test.PM.Integration.Base
{

Parameter ModuleNoDependencies As STRING = "update-simple";

Parameter ModuleWithDependencies As STRING = "update-deps";

Parameter ModuleWithDependenciesAdded As STRING = "update-deps-added";

Parameter ModuleWithDependenciesRemoved As STRING = "update-deps-removed";

Parameter ModuleNoUpdateSteps As STRING = "update-no-steps";

Parameter ModuleStepAddedOlderVersion As STRING = "update-step-added-to-older-version-class";

Parameter ModuleStepAddedCurrVersion As STRING = "update-step-added-curr-version-class";

Parameter ModuleStepErrors As STRING = "update-step-errors";

Parameter ModuleSeededStepErrors As STRING = "update-seeded-step-errors";

Parameter ModuleDepErrors As STRING = "update-dep-errors";

Parameter ModuleInvokeErrors As STRING = "update-invoke-errors";

Parameter ModuleDepInvokeErrors As STRING = "update-dep-invoke-errors";

Parameter ModuleOneVersion As STRING = "1.2.1";

Parameter ModuleOneVersionMinorBump As STRING = "1.3.1";

Parameter ModuleTwoVersion As STRING = "2.1.1";

Parameter ModuleThreeVersion As STRING = "3.5.0";

Parameter UpdateTestRepo As STRING = "update-test-modules";

Method OnBeforeAllTests() As %Status
{
  // Clean up repo used for tests
  set sc = ##class(%IPM.Main).Shell("repo -delete-all")
  set sc = ##class(%IPM.Main).Shell("repo -n "_..#UpdateTestRepo_" -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/update-test/")
  return sc
}

Method TestAllNoErrorModulesNoMirror()
{
  if $system.Mirror.IsMember() {
    return
  }
  // Simple module without dependencies
  set updateStepsToSeed = [["UpdatePackage.V1", "MethodA", 0]]
  set updateStepsToRun = [["UpdatePackage.V1", "MethodB", 1], ["UpdatePackage.V1", "MethodC", 1], ["UpdatePackage.V2", "MethodA", 1], ["UpdatePackage.V2", "MethodC", 1], ["UpdatePackage.V2", "MethodB", 0]]
  do ..NormalUpdateTestSuite(..#ModuleNoDependencies, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion)

  // Module with dependencies
  set updateStepsToSeed = updateStepsToSeed.addAll([["UpdateDeps.UpdatePackage.V1", "MethodA", 0]])
  set updateStepsToRun = updateStepsToRun.addAll([["UpdateDeps.UpdatePackage.V1", "MethodB", 1], ["UpdateDeps.UpdatePackage.V1", "MethodC", 1], ["UpdateDeps.UpdatePackage.V2", "MethodA", 1], ["UpdateDeps.UpdatePackage.V2", "MethodC", 1], ["UpdateDeps.UpdatePackage.V2", "MethodB", 0]])
  do ..NormalUpdateTestSuite(..#ModuleWithDependencies, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion)

  // Module with dependencies added in new version
  set updateStepsToSeed = [["UpdateDepsAdded.UpdatePackage.V1", "MethodA", 1]]
  set updateStepsToRun = updateStepsToRun.addAll([["UpdateDepsAdded.UpdatePackage.V1", "MethodB", 0], ["UpdateDepsAdded.UpdatePackage.V1", "MethodC", 1], ["UpdateDepsAdded.UpdatePackage.V2", "MethodA", 1], ["UpdateDepsAdded.UpdatePackage.V2", "MethodC", 1], ["UpdateDepsAdded.UpdatePackage.V2", "MethodB", 0]])
  do ..SingleNormalUpdateTest(..#ModuleWithDependenciesAdded, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion, 0)
  do ..CleanUpModule(..#ModuleWithDependenciesAdded)

  // Module with dependencies removed in new version
  set updateStepsToSeed = [["UpdateDepsRemoved.UpdatePackage.V1", "MethodA", 1], ["UpdatePackage.V1", "MethodA", 0]]
  set updateStepsToRun = [["UpdateDepsRemoved.UpdatePackage.V1", "MethodB", 0], ["UpdateDepsRemoved.UpdatePackage.V1", "MethodC", 1], ["UpdateDepsRemoved.UpdatePackage.V2", "MethodA", 1], ["UpdateDepsRemoved.UpdatePackage.V2", "MethodC", 1], ["UpdateDepsRemoved.UpdatePackage.V2", "MethodB", 0]]
  do ..SingleNormalUpdateTest(..#ModuleWithDependenciesRemoved, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion, 0)
  do ..CleanUpModule(..#ModuleWithDependenciesRemoved)

  // Module with no update steps
  do ..SingleNormalUpdateTest(..#ModuleNoUpdateSteps, [], [], ..#ModuleOneVersion, ..#ModuleTwoVersion, 0)
  do ..CleanUpModule(..#ModuleNoUpdateSteps)

  // Module with an error in a seeded update step
  set updateStepsToSeed = [["UpdateSeededStepErrors.UpdatePackage.V1", "MethodA", 0]]
  set updateStepsToRun = [["UpdateSeededStepErrors.UpdatePackage.V2", "MethodA", 1]]
  do ..SingleNormalUpdateTest(..#ModuleSeededStepErrors, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion, 0)
  do ..CleanUpModule(..#ModuleSeededStepErrors)
}

Method TestAllErrorModulesNoMirror()
{
  set updateStepsToSeed = [["UpdateStepErrors.UpdatePackage.V1", "MethodA", 1], ["UpdateStepErrors.UpdatePackage.V1", "MethodB", 0], ["UpdateStepErrors.UpdatePackage.V1", "MethodC", 1]]
  do ..SingleFailedUpdateTest(..#ModuleStepErrors, updateStepsToSeed, ..#ModuleOneVersion, ..#ModuleTwoVersion)
  do ..CleanUpModule(..#ModuleStepErrors)

  set updateStepsToSeed = updateStepsToSeed.addAll([["UpdateDepErrors.UpdatePackage.V1", "MethodA", 0]])
  do ..SingleFailedUpdateTest(..#ModuleDepErrors, updateStepsToSeed, ..#ModuleOneVersion, ..#ModuleTwoVersion)
  do ..CleanUpModule(..#ModuleDepErrors)

  set updateStepsToSeed = [["UpdateInvokeErrors.UpdatePackage.V1", "MethodA", 0]]
  do ..SingleFailedUpdateTest(..#ModuleInvokeErrors, updateStepsToSeed, ..#ModuleOneVersion, ..#ModuleTwoVersion)
  do ..CleanUpModule(..#ModuleInvokeErrors)

  set updateStepsToSeed = [["UpdateDepInvokeErrors.UpdatePackage.V1", "MethodA", 0], ["UpdateInvokeErrors.UpdatePackage.V1", "MethodA", 0]]
  do ..SingleFailedUpdateTest(..#ModuleDepInvokeErrors, updateStepsToSeed, ..#ModuleOneVersion, ..#ModuleTwoVersion)
  do ..CleanUpModule(..#ModuleDepInvokeErrors)
}

Method TestUpdateNonMatchingTarballFails()
{
  set moduleToPackage = ..#ModuleWithDependencies
  set moduleToUpdate = ..#ModuleNoDependencies
  set fromVersion = ..#ModuleOneVersion
  set toVersion = ..#ModuleTwoVersion

  // Package moduleToPackage (which is not the same module as moduleToUpdate)
  set exportDir = $system.Util.ManagerDirectory()_moduleToPackage
  do ..AssertModulePackagedCorrectly(moduleToPackage, toVersion, exportDir)

  do ..AssertModuleInstalledCorrectly(moduleToUpdate, fromVersion)

  set sc = ##class(%IPM.Main).Shell("update "_moduleToUpdate_" -path "_exportDir_" -v")
  do $$$AssertStatusNotOK(sc, "Attempting to update module "_moduleToUpdate_" FAILED because the module in the path provided does not match the module to update.")

  do ..CleanUpModule(moduleToUpdate)
  do ..CleanUpDirectory(exportDir)
}

Method TestUpdateAfterInterruptedUpdate()
{
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  if ('$system.Event.Defined("InterruptedUpdate")){
    set isNamedResourceCreated = $system.Event.Create("InterruptedUpdate")
    if 'isNamedResourceCreated {
      $$$ThrowOnError($$$ERROR($$$GeneralError, "Resource InterruptedUpdate not created"))
    }
  }

  job ..InterruptedUpdateJobWrapper(..#ModuleNoDependencies, ..#ModuleTwoVersion, "InterruptedUpdate")

  // Gets child job ID
  set $listbuild(codeOne, updateProcessId) = $system.Event.WaitMsg("InterruptedUpdate")
  set sc = $system.Process.Terminate(updateProcessId)

  // Gets process termination status
  do $$$AssertTrue(sc = 1, "Updating module "_..#ModuleNoDependencies_" from "_..#ModuleOneVersion_" to "_..#ModuleTwoVersion_" was interrupted.")

  // Perform another update
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  do $$$AssertStatusOK(sc, "Update of module "_..#ModuleNoDependencies_" version "_..#ModuleTwoVersion_" after interrupted update succeeded.")

  // Assert it completed
  do ..CleanUpModule(..#ModuleNoDependencies)
}

Method TestModuleUpdateStepAdded()
{
  // Test updating module when update step is added to an older V# class
  set updateStepsToSeed = [["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodA", 1], ["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodB", 0], ["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodC", 1], ["UpdateStepAddedOlderVersion.UpdatePackage.V2", "MethodA", 1], ["UpdateStepAddedOlderVersion.UpdatePackage.V2", "MethodB", 0]]
  set seededUpdateStepsToRun = [["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodA", 1], ["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodB", 0], ["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodC", 1]]
  set seededUpdateStepsToNotRun = [["UpdateStepAddedOlderVersion.UpdatePackage.V2", "MethodA", 1], ["UpdateStepAddedOlderVersion.UpdatePackage.V2", "MethodB", 0]]
  set updateStepsToRun = [["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodD", 0], ["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodB", 0], ["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodA", 1], ["UpdateStepAddedOlderVersion.UpdatePackage.V1", "MethodC", 1], ["UpdateStepAddedOlderVersion.UpdatePackage.V2", "MethodC", 1], ["UpdateStepAddedOlderVersion.UpdatePackage.V3", "MethodA", 1]]

  do ..SingleNormalUpdateNewStepTest(..#ModuleStepAddedOlderVersion, updateStepsToSeed, seededUpdateStepsToRun, seededUpdateStepsToNotRun, updateStepsToRun, ..#ModuleTwoVersion, ..#ModuleThreeVersion)
  do ..CleanUpModule(..#ModuleStepAddedOlderVersion)

  // Test updating module when new update step is added to current V# class which precedes existing update steps in order
  set updateStepsToSeed = [["UpdateStepAddedCurrVersionClass.UpdatePackage.V1", "MethodA", 1], ["UpdateStepAddedCurrVersionClass.UpdatePackage.V1", "MethodB", 0], ["UpdateStepAddedCurrVersionClass.UpdatePackage.V1", "MethodC", 1]]
  set seededUpdateStepsToRun = [["UpdateStepAddedCurrVersionClass.UpdatePackage.V1", "MethodA", 1], ["UpdateStepAddedCurrVersionClass.UpdatePackage.V1", "MethodB", 0], ["UpdateStepAddedCurrVersionClass.UpdatePackage.V1", "MethodC", 1]]
  set updateStepsToRun = [["UpdateStepAddedCurrVersionClass.UpdatePackage.V1", "MethodD", 0]]

  do ..SingleNormalUpdateNewStepTest(..#ModuleStepAddedCurrVersion, updateStepsToSeed, seededUpdateStepsToRun, [], updateStepsToRun, ..#ModuleOneVersion, ..#ModuleOneVersionMinorBump)
  do ..CleanUpModule(..#ModuleStepAddedCurrVersion)
}

Method TestUpdateOfUninstalledModule()
{
  // Make sure the module is not installed
  if (##class(%IPM.Storage.Module).NameExists(..#ModuleNoDependencies)) {
    set sc = ##class(%IPM.Main).Shell("uninstall "_..#ModuleNoDependencies)
    $$$ThrowOnError(sc)
  }

  // Update non-existent module
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleOneVersion)
  do $$$AssertStatusNotOK(sc, "Update of uninstalled module "_..#ModuleNoDependencies_" version "_..#ModuleOneVersion_" failed.")
}

Method TestUpdateToOlderVersion()
{
  // Install module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleTwoVersion)

  // Update module
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleOneVersion)
  do $$$AssertStatusNotOK(sc, "Attempt at updating module to older version failed.")
  do $$$AssertTrue((sc [ "version"), "Error message is descriptive and correctly mentions 'version'")

  do ..CleanUpModule(..#ModuleNoDependencies)
}

Method TestUpdateToInvalidVersion()
{
  // Install module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" 1.0.0")
  do $$$AssertStatusNotOK(sc, "Attempt at updating module to non-existent version failed.")

  do ..CleanUpModule(..#ModuleNoDependencies)
}

Method TestUpdateToNewVersionTwice()
{
  // Install module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module to a 2.x version
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  do $$$AssertStatusOK(sc, "Updated module to "_..#ModuleTwoVersion_" without error")

  // Update module to a 3.x version
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleThreeVersion)
  do $$$AssertStatusOK(sc, "Updated module to "_..#ModuleThreeVersion_" without error")

  do ..CleanUpModule(..#ModuleNoDependencies)
}

Method TestUpdateToSameVersionTwiceNoMirror()
{

  if $system.Mirror.IsMember() {
    return
  }

  // Load module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module to a 2.x version
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  do $$$AssertStatusOK(sc, "Updated module to "_..#ModuleTwoVersion_"without error")

  // Get timestamps of the V2 methods
  set stepTwoA = ..GetUpdateStep("UpdatePackage.V2", "MethodA", 1)
  set stepTwoB = ..GetUpdateStep("UpdatePackage.V2", "MethodB", 0)
  set stepTwoC = ..GetUpdateStep("UpdatePackage.V2", "MethodC", 1)

  set twoAStart = stepTwoA.TimeStampStart
  set twoAEnd = stepTwoA.TimeStampEnd

  set twoBStart = stepTwoB.TimeStampStart
  set twoBEnd = stepTwoB.TimeStampEnd

  set twoCStart = stepTwoC.TimeStampStart
  set twoCEnd = stepTwoC.TimeStampEnd

  // Update module to SAME version
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  do $$$AssertStatusOK(sc, "Updated module to "_..#ModuleTwoVersion_"without error")

  // Reload UpdateStep persistence to get the (hopefully not updated) version
  set stepTwoA = ..GetUpdateStep("UpdatePackage.V2", "MethodA", 1)
  set stepTwoB = ..GetUpdateStep("UpdatePackage.V2", "MethodB", 0)
  set stepTwoC = ..GetUpdateStep("UpdatePackage.V2", "MethodC", 1)

  // Check that second update does not rerun update steps
  // (timestamps on each update step should not have changed)
  do $$$AssertEquals(twoAStart, stepTwoA.TimeStampStart)
  do $$$AssertEquals(twoAEnd, stepTwoA.TimeStampEnd)

  do $$$AssertEquals(twoBStart, stepTwoB.TimeStampStart)
  do $$$AssertEquals(twoBEnd, stepTwoB.TimeStampEnd)

  do $$$AssertEquals(twoCStart, stepTwoC.TimeStampStart)
  do $$$AssertEquals(twoCEnd, stepTwoC.TimeStampEnd)

  do ..CleanUpModule(..#ModuleNoDependencies)
}

/// ///////////////////////////////////////////// HELPER METHODS ////////////////////////////////////////////////
/// Runs through four variations of update for a given module that are each expected to complete successfully:
/// - Install, dev mode
/// - Install, no dev mode
/// - Load, no dev mode
/// - Load, dev mode
Method NormalUpdateTestSuite(
	moduleName As %String,
	updateStepsToSeed As %DynamicArray,
	updateStepsToRun As %DynamicArray,
	fromVersion As %String,
	toVersion As %String)
{
  // No dev mode, install
  do ..SingleNormalUpdateTest(moduleName, updateStepsToSeed, updateStepsToRun, fromVersion, toVersion, 0)
  do ..CleanUpModule(moduleName)

  // Dev mode, install
  do ..SingleNormalUpdateTest(moduleName, updateStepsToSeed, updateStepsToRun, fromVersion, toVersion, 1)
  do ..CleanUpModule(moduleName)

  // Dev mode, load
  set exportDir = $system.Util.ManagerDirectory()_moduleName
  do ..SingleNormalUpdateTest(moduleName, updateStepsToSeed, updateStepsToRun, fromVersion, toVersion, 1, exportDir)
  do ..CleanUpModule(moduleName)
  do ..CleanUpDirectory(exportDir)

  // No dev mode, load
  do ..SingleNormalUpdateTest(moduleName, updateStepsToSeed, updateStepsToRun, fromVersion, toVersion, 0, exportDir)
  do ..CleanUpModule(moduleName)
  do ..CleanUpDirectory(exportDir)
}

Method SingleNormalUpdateNewStepTest(
	moduleName As %String,
	updateStepsToSeed As %DynamicArray,
	seededUpdateStepsToRun As %DynamicArray,
	seededUpdateStepsToNotRun As %DynamicArray,
	updateStepsToRun As %DynamicArray,
	fromVersion As %String,
	toVersion As %String)
{
  // Install module
  do ..AssertModuleInstalledCorrectly(moduleName, fromVersion)

  // Verify that update steps were correctly seeded and capture the TimeStampStart property for comparison
  set timeStampArr = []
  set iter = updateStepsToSeed.%GetIterator()
  while iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    do $$$AssertTrue($isobject(updateStep), "Update step with class="_className_" and method="_methodName_" exists.")
    set timeStampArr(className, methodName, isPrimaryOnly) = updateStep.TimeStampStart
  }

  // Update module
  set sc = ##class(%IPM.Main).Shell("update -v "_moduleName_" "_toVersion)
  do $$$AssertStatusOK(sc, "Updated module "_moduleName_" without error")

  // Check that the seeded update methods within the same version class as the new update step was prepended to were run
  set iter = seededUpdateStepsToRun.%GetIterator()
  while iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    do $$$AssertNotEquals(timeStampArr(className, methodName, isPrimaryOnly), updateStep.TimeStampStart, "Seeded update step with class="_className_" and method="_methodName_" WAS run on update after step order changed.")
  }

  // Check that the rest of the seeded update methods WERE NOT run
  set iter = seededUpdateStepsToNotRun.%GetIterator()
  while iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    do $$$AssertEquals(timeStampArr(className, methodName, isPrimaryOnly), updateStep.TimeStampStart, "Seeded update step with class="_className_" and method="_methodName_" WAS NOT run on update after step order changed.")
  }

  // Check whether correct UpdateStep rows exist in the correct table after update command is run
  do ..AssertUpdateStepsExist(updateStepsToRun)

  // Check module version has been updated
  set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
  do $$$AssertEquals(module.VersionString, toVersion, "Module "_moduleName_" version was successfully updated so that the desired version="_toVersion_" equals current version="_module.VersionString)
}

/// NOTE: For testing simplicity, we will always assume that in the update test, both the module and its dependencies are being updated
/// from and to the same version numbers.
/// Verifies that updating the given moduleName from fromVersion to toVersion FAILS, checking that the given updateStepsToSeed are seeded
/// but that the "update" command throws an error.
/// @argument moduleName          Name of module to install and update
/// @argument updateStepsToSeed   Array of [className, methodName, isPrimaryOnlyStep] update steps that are defined in the module PRE-update
/// @argument updateStepsToRun    Array of [className, methodName, isPrimaryOnlyStep] update steps that exist in the new version of the module POST-update
/// @argument fromVersion         Version of module to install
/// @argument toVersion           Version of module to which to update
Method SingleFailedUpdateTest(
	moduleName As %String,
	updateStepsToSeed As %DynamicArray,
	fromVersion As %String,
	toVersion As %String)
{
  // Install module
  do ..AssertModuleInstalledCorrectly(moduleName, fromVersion)

  // Verify that update steps were correctly seeded and capture the TimeStampStart property for comparison
  set timeStampArr = []
  set iter = updateStepsToSeed.%GetIterator()
  while iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    do $$$AssertTrue($isobject(updateStep), "Update step with class="_className_" and method="_methodName_" exists.")
    set timeStampArr(className, methodName, isPrimaryOnly) = updateStep.TimeStampStart
  }

  // Update module (with appropriate flags)
  set sc = ##class(%IPM.Main).Shell("update -v "_moduleName_" "_toVersion)
  do $$$AssertStatusNotOK(sc, "Attempting to update module "_moduleName_" FAILED.")
}

/// NOTE: For testing simplicity, we will always assume that in the update test, both the module and its dependencies are being updated
/// from and to the same version numbers.
/// Completes an update of given moduleName from fromVersion to toVersion, verifying that the given updateStepsToSeed are seeded
/// and that the given updateStepsToRun are run
/// @argument moduleName          Name of module to install and update
/// @argument updateStepsToSeed   Array of [className, methodName, isPrimaryOnlyStep] update steps that are defined in the module PRE-update
/// @argument updateStepsToRun    Array of [className, methodName, isPrimaryOnlyStep] update steps that exist in the new version of the module POST-update
/// @argument fromVersion         Version of module to install
/// @argument toVersion           Version of module to which to update
/// @argument developerMode       1 if update should be run with -dev flag, 0 otherwise
/// @argument pathToModule        Path to the module tarball to load
Method SingleNormalUpdateTest(
	moduleName As %String,
	updateStepsToSeed As %DynamicArray,
	updateStepsToRun As %DynamicArray,
	fromVersion As %String,
	toVersion As %String,
	developerMode As %Boolean = 0,
	pathToModule As %String = "")
{
  // Package module to update to (if we want to test updating from a tarball)
  if (pathToModule '= "") {
    do ..AssertModulePackagedCorrectly(moduleName, toVersion, pathToModule)
  }

  // Install module
  do ..AssertModuleInstalledCorrectly(moduleName, fromVersion)

  // Verify that update steps were correctly seeded and capture the TimeStampStart property for comparison
  set timeStampArr = []
  set iter = updateStepsToSeed.%GetIterator()
  while iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    do $$$AssertTrue($isobject(updateStep), "Update step with class="_className_" and method="_methodName_" exists.")
    set timeStampArr(className, methodName, isPrimaryOnly) = updateStep.TimeStampStart
  }

  // Update module (with appropriate flags)
  set devFlag = $select(developerMode: "-dev ", 1: "")
  set pathFlag = $select((pathToModule '= ""): "-path "_pathToModule_" ", 1: "")
  set sc = ##class(%IPM.Main).Shell("update -v "_devFlag_pathFlag_moduleName_" "_toVersion)
  do $$$AssertStatusOK(sc, "Updated module "_moduleName_" without error")

  // Check that seeded methods were not re-run
  set iter = updateStepsToSeed.%GetIterator()
  while iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    do $$$AssertTrue($isobject(updateStep), "Update step with class="_className_" and method="_methodName_" exists.")
    do $$$AssertEquals(timeStampArr(className, methodName, isPrimaryOnly), updateStep.TimeStampStart, "Seeded update step with class="_className_" and method="_methodName_" was correctly not rerun on update.")
  }

  // Check whether correct UpdateStep rows exist in the correct table after update command is run
  do ..AssertUpdateStepsExist(updateStepsToRun)

  // NOTE: For testing simplicity, we will always assume that in the update test, both the module and its dependencies are being updated
  // from and to the same version numbers.

  // Check module version has been updated
  set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
  do $$$AssertEquals(module.VersionString, toVersion, "Module "_moduleName_" version was successfully updated so that the desired version="_toVersion_" equals current version="_module.VersionString)

  // Check that dependency version string in the module.xml of the base module matches the version installed
  // dependencyGraph format: dependencyGraph(<module name>) = $ListBuild(<depth>, <server>, <version>)
  set sc = module.BuildDependencyGraph(.dependencyGraph)
  $$$ThrowOnError(sc)
  set moduleName = ""
  for {
    set moduleName = $order(dependencyGraph(moduleName),1,moduleInfo)
    quit:moduleName=""

    set moduleExpectedVersion = $list(moduleInfo, 3) // Taken from the module.xml <Version> tag
    set moduleActualVersion = ##class(%IPM.Storage.Module).NameOpen(moduleName).VersionString // The version of the installed module

    do $$$AssertEquals(moduleExpectedVersion, moduleActualVersion, "Module dependency "_moduleName_" expected version="_moduleExpectedVersion_" equals actual version="_moduleActualVersion)
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
    do $$$AssertTrue($isobject(updateStep), "Update step with class="_className_" and method="_methodName_" exists.")
  }
}

Method AssertModuleInstalledCorrectly(
	moduleName As %String,
	moduleVersion As %String)
{
  set sc = ##class(%IPM.Main).Shell("install -v "_moduleName_" "_moduleVersion)
  do $$$AssertStatusOK(sc,"Installed "_moduleName_" version = "_moduleVersion_" successfully.")
}

Method AssertModulePackagedCorrectly(
	moduleName As %String,
	version As %String,
	packageDir As %String)
{
  // Initial install of module (necessary to be able to package)
  set sc = ##class(%IPM.Main).Shell("install "_moduleName_" "_version)
  do $$$AssertStatusOK(sc,"Installed "_moduleName_" version = "_version_" successfully for packaging.")

  // Package module
  set sc = ##class(%IPM.Main).Shell(moduleName_" package -only -v -DPath="_packageDir)
  do $$$AssertStatusOK(sc, "Successfully packaged module "_moduleName_" to "_packageDir)

  // Uninstall module
  do ..CleanUpModule(moduleName)
}

ClassMethod InterruptedUpdateJobWrapper(
	moduleName,
	toVersion,
	resourceName)
{
  // Send job ID to the named resource
  do $system.Event.Signal(resourceName, $system.SYS.ProcessID())

  set sc = ##class(%IPM.Main).Shell("update "_moduleName_" "_toVersion_" -v")
}

ClassMethod GetUpdateStep(
	className As %String,
	methodName As %String,
	isPrimaryOnly As %Boolean) As %IPM.Storage.UpdateStep.Base
{
  if isPrimaryOnly {
    set step = ##class(%IPM.Storage.UpdateStep.PrimaryOnly).GetUpdateStep(className, methodName)
  } else {
    set step = ##class(%IPM.Storage.UpdateStep.AnyMember).GetUpdateStep(className, methodName)
  }

  if step.%Id() = "" {
    return ""
  }

  return step
}

ClassMethod CleanUpModule(moduleName As %String)
{
  set sc = ##class(%IPM.Main).Shell("uninstall -r "_moduleName)
  $$$ThrowOnError(sc)

  return
}

ClassMethod CleanUpDirectory(dir As %String)
{
  set isRemoved = ##class(%File).RemoveDirectoryTree(dir)
  if 'isRemoved {
    $$$ThrowOnError($$$ERROR($$$GeneralError,$$$FormatText("Unable to remove directory tree for dir = '%1", dir)))
  }
  return
}

}
