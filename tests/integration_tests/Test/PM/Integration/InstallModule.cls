Class Test.PM.Integration.InstallModule Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
{
    // Using update-test modules for the test of making sure update steps are used correctly with zpm "install"
    set sc = ##class(%IPM.Main).Shell("repo -n update-test-modules -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/update-test/")
    do $$$AssertStatusOK(sc,"Created update-test-modules repo successfully.")
    return sc
}

Method OnAfterAllTests() As %Status
{
    // Remove test repository after tests have been run
    set sc = ##class(%IPM.Main).Shell("repo -delete -name update-test-modules")
    do $$$AssertStatusOK(sc,"Deleted update-test-modules repo successfully.")
    return sc
}

Method TestSimpleApp()
{
  set tSC = $$$OK
  try {
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))

    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-module/")
    set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully.")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

/// Verify that the UpdateStep table is properly seeded at install/load,
/// regardless of whether the module is provided in a tarball or local directory
Method TestUpdateStepsSeededOnInstall()
{
    // Install module via zpm "install"
    set sc = ##class(%IPM.Main).Shell("install -v update-simple 3.5.0")
    do $$$AssertStatusOK(sc,"Installed update-simple")

    // Confirm that table is properly seeded for all update steps with that module
    set updateStepsToSeed = [["UpdatePackage.V1", "MethodB", 0], ["UpdatePackage.V1", "MethodA", 1], ["UpdatePackage.V1", "MethodC", 1],
                             ["UpdatePackage.V2", "MethodB", 0], ["UpdatePackage.V2", "MethodA", 1], ["UpdatePackage.V2", "MethodC", 1],
                             ["UpdatePackage.V3", "MethodA", 1]]
    do ..ConfirmUpdateStepsAreSeeded(updateStepsToSeed)

    // Defining paths for module tarball
    set tempDir = $$$FileTempDir
    set exportPath = ##class(%File).NormalizeFilename("update-simple", tempDir)
    set tarballPath = ##class(%File).NormalizeFilename("update-simple.tgz", tempDir)

    // Package module into a tarball
    set sc = ##class(%IPM.Main).Shell("update-simple package -only -v -DPath="_exportPath)
    do $$$AssertStatusOK(sc, "Successfully packaged module update-simple to "_tarballPath)

    // Clean up the module prior to trying via tarball
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall update-simple"))


    // Install module via tarball
    set sc = ##class(%IPM.Main).Shell("load -v " _ tarballPath)
    do $$$AssertStatusOK(sc, "Successfully loaded update-simple from tarball")

    // Confirm that table is properly seeded for all update steps with that module
    do ..ConfirmUpdateStepsAreSeeded(updateStepsToSeed)

    // Clean up the module after test is completed
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall update-simple"))
}

/// Verify that attempting to run install/load without the force flag fails if a module is already installed
Method TestInstallForceFlag()
{
    set sc = ##class(%IPM.Main).Shell("install -v update-simple 2.1.1")
    do $$$AssertStatusOK(sc,"Installed update-simple")

    set sc = ##class(%IPM.Main).Shell("install -v update-simple 1.2.1")
    do $$$AssertStatusNotOK(sc,"Trying to install older version of already existing update-simple without -force flag fails")

    set sc = ##class(%IPM.Main).Shell("install -v update-simple 3.5.0")
    do $$$AssertStatusNotOK(sc,"Trying to install newer version of already existing update-simple without -force flag fails")

    set sc = ##class(%IPM.Main).Shell("install -v -force update-simple 1.2.1")
    do $$$AssertStatusNotOK(sc,"Trying to install older version of already existing update-simple with -force flag fails")

    set sc = ##class(%IPM.Main).Shell("install -v -force update-simple 3.5.0")
    do $$$AssertStatusOK(sc,"Trying to install newer version of already existing update-simple with -force flag succeeds")

    // Clean up the module after test is completed
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall update-simple"))
}

/// Verify that rows in the UpdateStep table are properly removed when the module is uninstalled
Method TestUninstallRemovesUpdateSteps()
{
    // Install module via zpm "install"
    set sc = ##class(%IPM.Main).Shell("install -v update-simple 3.5.0")
    do $$$AssertStatusOK(sc,"Installed update-simple")

    // Confirm that table is properly seeded for all update steps with that module
    set updateStepsToSeed = [["UpdatePackage.V1", "MethodB", 0], ["UpdatePackage.V1", "MethodA", 1], ["UpdatePackage.V1", "MethodC", 1],
                             ["UpdatePackage.V2", "MethodB", 0], ["UpdatePackage.V2", "MethodA", 1], ["UpdatePackage.V2", "MethodC", 1],
                             ["UpdatePackage.V3", "MethodA", 1]]
    do ..ConfirmUpdateStepsExist(updateStepsToSeed, 1)

    // Uninstall the module
    set sc = ##class(%IPM.Main).Shell("uninstall update-simple")
    do $$$AssertStatusOK(sc, "Uninstalled update-simple")

    // Confirm that steps don't exist anymore
    do ..ConfirmUpdateStepsExist(updateStepsToSeed, 0)
}

/// Verify that, if trying to uninstall a dependency module it errors out and no update metadata is removed
Method TestUninstallDependencyDoesError()
{
    do $$$AssertSkipped("The functionality for preventing an uninstall of a dependency module does not yet exist.")
    quit
    // First, install base module and dependency
    set sc = ##class(%IPM.Main).Shell("install -v update-deps 2.1.1")
    do $$$AssertStatusOK(sc, "Installed update-deps and dependencies")

    // Confirm pre-uninstall that update steps exist
    set updateStepsToSeed = [["UpdateDeps.UpdatePackage.V1", "MethodA", 0], ["UpdateDeps.UpdatePackage.V1", "MethodB", 1], ["UpdateDeps.UpdatePackage.V1", "MethodC", 1],
                             ["UpdateDeps.UpdatePackage.V2", "MethodB", 0], ["UpdateDeps.UpdatePackage.V2", "MethodA", 1], ["UpdateDeps.UpdatePackage.V2", "MethodC", 1],
                             ["UpdatePackage.V1", "MethodA", 0], ["UpdatePackage.V1", "MethodB", 1], ["UpdatePackage.V1", "MethodC", 1],
                             ["UpdatePackage.V2", "MethodB", 0], ["UpdatePackage.V2", "MethodA", 1], ["UpdatePackage.V2", "MethodC", 1]]

    // Confirm that table is properly seeded for all update steps with that module
    do ..ConfirmUpdateStepsAreSeeded(updateStepsToSeed)

    // Attempt to uninstall dependency module first. Should fail
    set sc = ##class(%IPM.Main).Shell("uninstall update-simple")
    do $$$AssertStatusNotOK(sc, "Can't uninstall a module that is a dependency of another installed module")

    // Make sure update steps are still present since no module was actually removed
    do ..ConfirmUpdateStepsExist(updateStepsToSeed, 1)

    // Clean up the module after test is completed
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall -r update-deps"))
}

/// Verify that running install/load when a module is already installed (no matter the version)
/// succeeds in dev mode and fails otherwise
Method TestDevMode()
{
    set sc = ##class(%IPM.Main).Shell("install -v update-simple 2.1.1")
    do $$$AssertStatusOK(sc,"Installed update-simple")

    set sc = ##class(%IPM.Main).Shell("install -v update-simple 1.2.1")
    do $$$AssertStatusNotOK(sc,"Trying to install older version of already existing update-simple without -dev flag fails")

    set sc = ##class(%IPM.Main).Shell("install -v update-simple 3.5.0")
    do $$$AssertStatusNotOK(sc,"Trying to install newer version of already existing update-simple without -dev flag fails")

    set sc = ##class(%IPM.Main).Shell("install -v -dev update-simple 1.2.1")
    do $$$AssertStatusNotOK(sc,"Trying to install older version of already existing update-simple with -dev flag fails")

    set sc = ##class(%IPM.Main).Shell("install -v -dev update-simple 3.5.0")
    do $$$AssertStatusOK(sc,"Trying to install newer version of already existing update-simple with -dev flag succeeds")

    // Clean up the module after test is completed
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall update-simple"))
}

/// Verify that attempting to install/load the same version fails with informational message
/// unless -force flag is used, and that reinstall command always works
Method TestSameVersionInstallPrevention()
{
    set sc = ##class(%IPM.Main).Shell("install -v update-simple 2.1.1")
    do $$$AssertStatusOK(sc,"Installed update-simple 2.1.1")

    // Test install command with same version - should fail with informational message
    set sc = ##class(%IPM.Main).Shell("install -v update-simple 2.1.1")
    do $$$AssertStatusNotOK(sc,"Trying to install same version of update-simple without -force flag fails")
    do $$$AssertTrue($system.Status.GetOneErrorText(sc) [ "update-simple version 2.1.1 is already installed.", "Error message indicates version is already installed")

    // Test install command with same version and -force flag - should succeed
    set sc = ##class(%IPM.Main).Shell("install -v -force update-simple 2.1.1")
    do $$$AssertStatusOK(sc,"Trying to install same version of update-simple with -force flag succeeds")

    // Test reinstall command - should always work
    set sc = ##class(%IPM.Main).Shell("reinstall update-simple")
    do $$$AssertStatusOK(sc,"Reinstalling update-simple with reinstall command succeeds")

    // Clean up the module after test is completed
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall update-simple"))
}

/// Verify that load command also prevents same-version installation with a message
Method TestSameVersionLoadPrevention()
{
    // Get test root and prepare module directory
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-module/")

    // First load
    set sc = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusOK(sc,"Loaded SimpleModule from directory")

    // Try to load same version again - should fail with informational message
    set sc = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusNotOK(sc,"Trying to load same version without -force flag fails")
    do $$$AssertTrue($system.Status.GetOneErrorText(sc) [ "simplemodule version 0.0.1+snapshot is already installed.", "Error message indicates version is already installed")

    // Try to load with -force flag - should succeed
    set sc = ##class(%IPM.Main).Shell("load -force "_tModuleDir)
    do $$$AssertStatusOK(sc,"Trying to load same version with -force flag succeeds")

    // Clean up the module after test is completed
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall SimpleModule"))
}

/// Verify that PermitReinstall parameter allows same-version installation without -force flag
Method TestPermitReinstallParameter()
{
    // Get test root and prepare module directory
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/permit-reinstall/")

    // First load
    set sc = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusOK(sc,"Loaded PermitReinstall module")

    // Try to load same version again - should succeed because PermitReinstall=1 in module.xml
    set sc = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusOK(sc,"Loading same version with PermitReinstall=1 parameter succeeds")

    // Clean up the module after test is completed
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall PermitReinstall"))
}

Method ConfirmUpdateStepsExist(
	updateStepsToSeed As %DynamicArray,
	doesExist As %Boolean)
{
    set iter = updateStepsToSeed.%GetIterator()
    while iter.%GetNext(.key, .value) {
        set className = value.%Get(0)
        set methodName = value.%Get(1)
        set isPrimaryOnly = value.%Get(2)

        set stepExists = $isobject(##class(Test.PM.Integration.Update).GetUpdateStep(className, methodName, isPrimaryOnly))
        if doesExist {
            do $$$AssertTrue(stepExists, "Update step with class="_className_" and method="_methodName_" exists")
        }
        else {
            do $$$AssertNotTrue(stepExists, "Update step with class="_className_" and method="_methodName_" does not exist")
        }
    }
}

Method ConfirmUpdateStepsAreSeeded(updateStepsToSeed As %DynamicArray)
{
    set iter = updateStepsToSeed.%GetIterator()
    while iter.%GetNext(.key, .value) {
        set className = value.%Get(0)
        set methodName = value.%Get(1)
        set isPrimaryOnly = value.%Get(2)

        set updateStep = ##class(Test.PM.Integration.Update).GetUpdateStep(className, methodName, isPrimaryOnly)
        set stepIsSeeded = (updateStep.TimeStampEnd '= "") && (updateStep.TimeStampStart = "")
        do $$$AssertTrue(stepIsSeeded, "Update step with class="_className_" and method="_methodName_" is seeded")
    }
}

}
