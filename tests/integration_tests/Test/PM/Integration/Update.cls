Class Test.PM.Integration.Update Extends Test.PM.Integration.Base
{

Parameter ModuleNoDependencies As STRING = "update-simple";

Parameter ModuleOneVersion As STRING = "1.2.1";

Parameter ModuleTwoVersion As STRING = "2.1.1";

Parameter ModuleThreeVersion As STRING = "3.5.0";

Parameter UpdateTestRepo As STRING = "update-test-modules";

Method OnBeforeOneTest() As %Status
{
  // Setup repo pointing to all modules used for tests in this class
  set sc = ##class(%IPM.Main).Shell("repo -n "_..#UpdateTestRepo_"-fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/update-test/")
  do $$$AssertStatusOK(sc,"Created "_..#UpdateTestRepo_" repo successfully.")
  return sc
}

Method OnAfterOneTest() As %Status
{
  // Clean up repo used for tests
  set sc = ##class(%IPM.Main).Shell("repo -delete -name "_..#UpdateTestRepo)
  do $$$AssertStatusOK(sc,"Deleted "_..#UpdateTestRepo_" repo successfully.")
  return sc
}

Method TestModuleNormalUpdateNoMirror()
{
  set updateStepsToSeed = [["UpdatePackage.V1", "MethodA", 1]]
  set updateStepsToRun = [["UpdatePackage.V1", "MethodB", 0], ["UpdatePackage.V1", "MethodC", 1], ["UpdatePackage.V2", "MethodA", 1], ["UpdatePackage.V2", "MethodC", 1], ["UpdatePackage.V2", "MethodB", 0]]

  // No dev mode, install
  do ..ModuleNormalUpdateNoMirrorHelper(..#ModuleNoDependencies, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion, 0)

  // Dev mode, install
  do ..ModuleNormalUpdateNoMirrorHelper(..#ModuleNoDependencies, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion, 1)

  // No dev mode, load
  set exportDir = $system.Util.ManagerDirectory()
  do ..ModuleNormalUpdateNoMirrorHelper(..#ModuleNoDependencies, updateStepsToSeed, updateStepsToRun, ..#ModuleOneVersion, ..#ModuleTwoVersion, 1, exportDir)
}

Method TestUpdateToOlderVersion()
{
  // Load module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleTwoVersion)

  // Update module
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleOneVersion)
  do $$$AssertStatusNotOK(sc, "Attempt at updating module to older version failed.")
  do $$$AssertTrue((sc [ "version"), "Error message is descriptive and correctly mentions 'version'")
}

Method TestUpdateToInvalidVersion()
{
  // Load module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" 1.0.0")
  do $$$AssertStatusNotOK(sc, "Attempt at updating module to non-existent version failed.")
}

Method TestUpdateToNewVersionTwice()
{
  // Load module
  do ..AssertModuleInstalledCorrectly(..#ModuleNoDependencies, ..#ModuleOneVersion)

  // Update module to a 2.x version
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleTwoVersion)
  do $$$AssertStatusOK(sc, "Updated module to "_..#ModuleTwoVersion_" without error")

  // Update module to a 3.x version
  set sc = ##class(%IPM.Main).Shell("update -v "_..#ModuleNoDependencies_" "_..#ModuleThreeVersion)
  do $$$AssertStatusOK(sc, "Updated module to "_..#ModuleThreeVersion_" without error")
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
}

/// ///////////////////////////////////////////// HELPER METHODS ////////////////////////////////////////////////
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
Method ModuleNormalUpdateNoMirrorHelper(
	moduleName As %String,
	updateStepsToSeed As %DynamicArray,
	updateStepsToRun As %DynamicArray,
	fromVersion As %String,
	toVersion As %String,
	developerMode As %Boolean = 0,
	pathToModule As %String = "")
{
  if $system.Mirror.IsMember() {
    return
  }

  // Package module to update to (if we want to test updating from a tarball)
  if pathToModule {
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
    do $$$AssertTrue(%IsObject(updateStep), "Update step with class="_className_" and method="_methodName_" exists.")
    set timeStampArr(className, methodName, isPrimaryOnly) = updateStep.TimeStampStart
  }

  // Update module (with appropriate flags)
  set devFlag = $select(developerMode: " -dev ", 1: "")
  set pathFlag = $select(pathToModule: " -path="_pathToModule, 1: "")
  set sc = ##class(%IPM.Main).Shell("update -v"_devFlag_pathFlag_moduleName_" "_toVersion)
  do $$$AssertStatusOK(sc, "Updated module "_moduleName_" without error")

  // Check that seeded methods were not re-run
  set iter = updateStepsToSeed.%GetIterator()
  while iter.%GetNext(.key, .value) {
    set className = value.%Get(0)
    set methodName = value.%Get(1)
    set isPrimaryOnly = value.%Get(2)

    set updateStep = ..GetUpdateStep(className, methodName, isPrimaryOnly)
    do $$$AssertTrue(%IsObject(updateStep), "Update step with class="_className_" and method="_methodName_" exists.")
    do $$$AssertEquals(timeStampArr(className, methodName, isPrimaryOnly), updateStep.TimeStampStart, "Seeded update step with class="_className_" and method="_methodName_" was correctly not rerun on update.")
  }

  // Check whether correct UpdateStep rows exist in the correct table after update command is run
  do ..AssertUpdateStepsExist(updateStepsToRun)

  // NOTE: For testing simplicity, we will always assume that in the update test, both the module and its dependencies are being updated
  // from and to the same version numbers.

  // Check module version has been updated
  set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
  do $$$AssertEquals(module.VersionString, toVersion)

  // Check that dependency versions have been updated
  // dependencyGraph format: dependencyGraph(<module name>) = $ListBuild(<depth>, <server>, <version>)
  set sc = module.BuildDependencyGraph(.dependencyGraph)
  $$$ThrowOnError(sc)
  set moduleName = ""
  for {
    set moduleName = $order(dependencyGraph(moduleName),1,moduleInfo)
    quit:moduleName=""

    set moduleVersion = $list(moduleInfo, 2)

    do $$$AssertEquals(moduleVersion, toVersion)
  }
}

ClassMethod AssertModulePackagedCorrectly(
	moduleName As %String,
	version As %String,
	packageDir As %String)
{
  // Initial install of module (necessary to be able to package)
  set sc = ##class(%IPM.Main).Shell("install "_moduleName_" "_version)
  do $$$AssertStatusOK(sc,"Installed "_moduleName_" version = "_version_" successfully.")

  // Package module
  set sc = ##class(%IPM.Main).Shell(_moduleName_" package -only -v -DPath="_packageDir)
  do $$$AssertStatusOK(sc, "Successfully packaged module to "_packageDir)

  // Uninstall module
  set sc = ##class(%IPM.Main).Shell("uninstall "_moduleName_" "_version)
  do $$$AssertStatusOK(sc,"Uninstalled "_moduleName_" version = "_version_" successfully after packaging.")
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
    do $$$AssertTrue(%IsObject(updateStep), "Update step with class="_className_" and method="_methodName_" exists.")
  }
}

Method AssertModuleInstalledCorrectly(
	moduleName As %String,
	moduleVersion As %String)
{
  set sc = ##class(%IPM.Main).Shell("install -v "_moduleName_" "_moduleVersion)
  do $$$AssertStatusOK(sc, "Loaded module successfully")
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

  return step
}

}
