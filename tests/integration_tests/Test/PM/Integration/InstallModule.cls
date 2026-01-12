Class Test.PM.Integration.InstallModule Extends Test.PM.Integration.Base
{

Parameter DefaultName = "default-name";

Parameter ExternalName = "external-name";

Parameter Folder = "publish-external-name";

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

    // Clean up zot registry - ensure packages are removed even if test failed
    set sc = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/default-name all -force")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/external-name all -force")
    // Also clean from namespaced path
    set sc = ##class(%IPM.Main).Shell("repo -n zot -ns test")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/default-name all -force")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/external-name all -force")
    set sc = ##class(%IPM.Main).Shell("repo -n zot -delete")

    return $$$OK
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

/// Tests that external name and default name can be used interchangeably for installing
Method TestInterchangeableNames()
{
    // Set up repo
    set sc = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
    do $$$AssertStatusOK(sc,"Zot repo configured succesfully")

    // Make sure modules are not already published
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")

    // Load module
    set moduleDir = ..GetModuleDir(..#Folder)
    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir _ "/0.0.1"))
    do $$$AssertStatusOK(sc, "Loaded module")


    // Test 1: Publish with default name and install using external name

    // Publish module
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#DefaultName _ " -verbose -r zot")
    do $$$AssertStatusOK(sc,"Published module successfully with default name")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module with external name")

    // Install using external name
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully installed module with external name")

    // Cleanup by unpublishing and uninstalling
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")
    // Verify cannot install now
    set sc = ##class(%IPM.Main).Shell("install -verbose zot/" _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Test 1: Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Test 1: Correctly failed to install module with external name")


    // Test 2: Publish with external name using -use-ext flag and install using internal name
    // Load and publish module
    set moduleDir = ..GetModuleDir(..#Folder)
    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir _ "/0.0.1"))
    do $$$AssertStatusOK(sc, "Loaded module")
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#DefaultName _ " -verbose -r zot -use-ext")
    do $$$AssertStatusOK(sc,"Published module successfully with default name but -use-ext flag")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module with default name")

    // Install using internal name
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully installed module with default name")

    // Cleanup by unpublishing and uninstalling
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")
    // Verify cannot install now
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Test 2: Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Test 2: Correctly failed to install module with external name")


    // Test 3: Publish with external name without -use-ext flag (will appear in repo under internal name) and install using internal name
    // Load and publish module
    set moduleDir = ..GetModuleDir(..#Folder)
    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir _ "/0.0.1"))
    do $$$AssertStatusOK(sc, "Loaded module")
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#ExternalName _ " -verbose -r zot")
    do $$$AssertStatusOK(sc,"Published module successfully with external name")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module with default name")

    // Install using internal name
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully installed module with default name")

    // Cleanup by unpublishing and uninstalling
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")
    // Verify cannot install now
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Test 3: Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Test 3: Correctly failed to install module with external name")


    // Test 4: Publish with external name without -use-ext flag and install using external name
    // Load and publish module
    set moduleDir = ..GetModuleDir(..#Folder)
    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir _ "/0.0.1"))
    do $$$AssertStatusOK(sc, "Loaded module")
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#ExternalName _ " -verbose -r zot")
    do $$$AssertStatusOK(sc,"Published module successfully with external name")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module with default name")

    // Install using internal name
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully installed module with external name")

    // Cleanup by unpublishing and uninstalling
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")
    // Verify cannot install now
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Test 4: Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Test 4: Correctly failed to install module with external name")


    // Test 5: Test with namespace - publish with -use-ext and install using default name
    // Reconfigure zot repo with namespace
    set sc = ##class(%IPM.Main).Shell("repo -n zot -ns test")
    do $$$AssertStatusOK(sc, "Reconfigured zot repo with namespace 'test'")

    // Load and publish module
    set moduleDir = ..GetModuleDir(..#Folder)
    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir _ "/0.0.1"))
    do $$$AssertStatusOK(sc, "Loaded module")
    // Publish with -use-ext (will be stored as test/external-name)
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#DefaultName _ " -verbose -r zot -use-ext")
    do $$$AssertStatusOK(sc, "Published module with -use-ext in namespaced repo")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")

    // Install using default name (should find test/external-name and match via module.xml)
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully installed module with default name from namespaced repo")

    // Cleanup by unpublishing and uninstalling
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")
    // Verify cannot install now
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Test 5: Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Test 5: Correctly failed to install module with external name")


    // Test 6: Test with namespace - publish without -use-ext and install using external name
    // Publish without -use-ext (will be stored as test/default-name)
    // Load and publish module
    set moduleDir = ..GetModuleDir(..#Folder)
    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir _ "/0.0.1"))
    do $$$AssertStatusOK(sc, "Loaded module")
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#DefaultName _ " -verbose -r zot")
    do $$$AssertStatusOK(sc, "Published module without -use-ext in namespaced repo")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")

    // Install using external name (should find test/default-name and match via module.xml)
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully installed module with external name from namespaced repo")

    // Cleanup by unpublishing and uninstalling
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")
    // Verify cannot install now
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Test 6: Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install zot/" _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Test 6: Correctly failed to install module with external name")


    // Cleanup by removing zot repo
    $$$ThrowOnError(##class(%IPM.Main).Shell("repo -n zot -delete"))
}

}
