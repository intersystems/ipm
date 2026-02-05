Class Test.PM.Integration.LockFile Extends Test.PM.Integration.Base
{

/// Name of the JSON lock file
Parameter LockFileName As String = "module-lock.json";

/// Directory where files for expected lock file contents are located
Parameter ExpectedFilesDir As String = "/home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/lock-test/expected-files/";

/// Module with 0 dependencies
Parameter ModuleA As String = "lock-mod-a-no-deps";

/// Module with 0 dependencies
Parameter ModuleB As String = "lock-mod-b-no-deps";

/// Module with 2 deps w/o transient (A & B)
Parameter ModuleC As String = "lock-mod-c-2-deps-0-transient";

/// Module with 1 dep w/ 2 transient (C)
Parameter ModuleD As String = "lock-mod-d-1-dep-2-transient";

/// Module with 1 dep w/o transient (A)
Parameter ModuleE As String = "lock-mod-e-1-dep-0-transient";

/// Module with 1 dep w/ 1 transient & 1 dep w/o transient (E & B)
Parameter ModuleF As String = "lock-mod-f-2-deps-1-transient";

/// Module with dependencies for all repository types (Module remote, Module oras, Module http, Module filesystem, & Module perforce)
Parameter ModuleG As String = "lock-mod-g-all-repo-types";

/// Module with multiple versions
///     - v2: Base equivalent to Module F
///     - v3: Adds dependency Module A
Parameter ModuleH As String = "lock-mod-h-multiple-versions";

/// Base equivalent to Module F, just deleted the lock file
Parameter ModuleI As String = "lock-mod-i-no-prior-lock-file";

/// Base equivalent to Module D, but different lock file
/// Lock file as A->C->B instead of A->B->C (C is dependent on B)
Parameter ModuleJ As String = "lock-mod-j-deps-misordered";

/// 2 dependencies: C & E, both with same transient dependency: A
Parameter ModuleK As String = "lock-mod-k-common-transient";

/// Module with complex set of nested dependencies
/// Dependencies D, E, & F
///     - D -> C -> A & B
///     - E -> A
///     - F -> E & B
Parameter ModuleL As String = "lock-mod-l-complex-deps";

Method OnBeforeAllTests() As %Status
{
    // Setup repos for LockFile tests
    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc,"Deleted all leftover repos from other tests successfully.")
    set sc = ##class(%IPM.Main).Shell("repo -n lock-file-base -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/lock-test/mods-base-cases/")
    do $$$AssertStatusOK(sc,"Created lock-file-base repo successfully.")
    set sc = ##class(%IPM.Main).Shell("repo -n lock-file-edge -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/lock-test/mods-edge-cases/")
    do $$$AssertStatusOK(sc,"Created lock-file-edge repo successfully.")
    return sc
}

Method OnAfterAllTests() As %Status
{
    // Delete repos for LockFile tests
    set sc = ##class(%IPM.Main).Shell("repo -delete -name lock-file-base")
    do $$$AssertStatusOK(sc,"Removed lock-file-base repo successfully.")
    set sc = ##class(%IPM.Main).Shell("repo -delete -name lock-file-edge")
    do $$$AssertStatusOK(sc,"Removed lock-file-edge repo successfully.")
    return sc
}

Method OnAfterOneTest() As %Status
{
    // Make test environment clean by uninstalling all modules at the end of each test
    set sc = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(sc, "Successfully uninstalled all modules after test")
    return sc
}

/// Module with 0 dependencies
/// Uses Module A
Method Test01Module0Dependencies()
{
    try {
        do ..ExecuteGenericLockFileTest(..#ModuleA)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test01Module0Dependencies.")
    }
}

/// Module with 2 direct dependencies (they themselves don't have deps)
/// Uses Module C
Method Test02Module2Dependencies0Transient()
{
    try {
        do ..ExecuteGenericLockFileTest(..#ModuleC)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test02Module2Dependencies0Transient.")
    }
}

/// Module with dependency that has transient dependencies
/// Uses Module D
Method Test03Module1Dependency2Transient()
{
    try {
        do ..ExecuteGenericLockFileTest(..#ModuleD)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test03Module1Dependency2Transient.")
    }
}

/// Module with 1 dep (with transient), 1 dep (without transient)
/// Uses Module F
Method Test04Module2Dependencies1Transient()
{
    try {
        do ..ExecuteGenericLockFileTest(..#ModuleF)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test04Module2Dependencies1Transient.")
    }
}

/// Edge cases below:
/// All repository types
/// Uses Module G
Method Test05AllRepositoryTypes()
{
    set sc = $$$OK
    try {
        // The first step is to publish the modules to their specified repo types. Need to add a repo for the initial module files first though
        set sc = ##class(%IPM.Main).Shell("repo -n lock-file-other-repos -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/lock-test/mods-other-repos/")
        do $$$AssertStatusOK(sc,"Created lock-file-other-repos repo successfully.")

        // Publish a module to a remote repository
        set remoteRepo = "lock-file-remote"
        set remoteMod = "lock-mod-remote"
        do ##class(%IPM.Main).Shell("install "_remoteMod)
        // Add remote repo for this test stack and push the module there
        set sc = ##class(%IPM.Main).Shell("repo -r -name "_remoteRepo_" -url http://registry:52773/registry -username admin -password SYS")
        do $$$AssertStatusOK(sc, "Successfully set up remote repo")
        set sc = ##class(%IPM.Main).Shell("publish "_remoteMod_" -r "_remoteRepo_" -v -export-deps 1")
        do $$$AssertStatusOK(sc, "Successfully published module to remote repo")
        // Uninstall mod and to then be installed from remote repo
        do ##class(%IPM.Main).Shell("uninstall -r "_remoteMod)

        // Publish a module to an ORAS repository
        set orasRepo = "lock-file-oras"
        set orasMod = "lock-mod-oras"
        do ##class(%IPM.Main).Shell("install "_orasMod)
        // Add oras repo for this test stack and push the module there
        set sc = ##class(%IPM.Main).Shell("repo -o -name "_orasRepo_" -url http://oras:5000 -publish 1")
        do $$$AssertStatusOK(sc, "Successfully set up ORAS repo")
        set sc = ##class(%IPM.Main).Shell("publish "_orasMod_" -r "_orasRepo_" -v -export-deps 1")
        do $$$AssertStatusOK(sc, "Successfully published module to ORAS repo")
        // Uninstall mod and to then be installed from ORAS repo
        do ##class(%IPM.Main).Shell("uninstall -r "_orasMod)

        // Remove repo for files to other repo types so we don't pull the filesystem module by accident
        set sc = ##class(%IPM.Main).Shell("repo -delete -name lock-file-other-repos")
        do $$$AssertStatusOK(sc,"Removed lock-file-other-repos repo successfully.")

        // Now that modules and repositories are set up, do the actual test
        do ..ExecuteGenericLockFileTest(remoteMod, "LockModRemote.Class1")
        do ..ExecuteGenericLockFileTest(orasMod, "LockModORAS.Class1")

        do ##class(%IPM.Main).Shell("repo -delete -name "_remoteRepo)
        do $$$AssertStatusOK(sc, "Removed "_remoteRepo_" at the end of the test")
        do ##class(%IPM.Main).Shell("repo -delete -name "_orasRepo)
        do $$$AssertStatusOK(sc, "Removed "_orasRepo_" at the end of the test")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test05ModuleDependenciesAllRepositoryTypes.")
    }
}

/// Module with multiple versions: Can both specify a version and defaults to latest (highest #) version
/// Uses Module H
Method Test06ModuleMultipleVersions()
{
    try {
        set moduleName = ..#ModuleH

        // First test with the latest version of the module
        set latestVersion = "3.0.0"
        set latestLockFileName = "lock-mod-h-multiple-versions-v3.json"

        // Do an initial install of the latest version of the module and create a lock file for it
        set sc = ##class(%IPM.Main).Shell("install -create-lockfile "_moduleName)
        do $$$AssertStatusOK(sc, "Able to install "_moduleName_" v"_latestVersion_" and create lock file for it")

        // Compare the generated lock file with the expected one
        set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
        set lockFilePath = module.Root_..#LockFileName
        set areLockFilesEqual = ..AreLockFilesEqual(lockFilePath, ..#ExpectedFilesDir_latestLockFileName)
        do $$$AssertTrue(areLockFilesEqual, "Lock file contents for "_moduleName_" v"_latestVersion_" match expected values")

        // Uninstall module to prepare for install from lock file
        set sc = ##class(%IPM.Main).Shell("uninstall -r "_moduleName)
        do $$$AssertStatusOK(sc, "Uninstalled "_moduleName)

        // Install module from lock file
        set sc = ##class(%IPM.Main).Shell("ci "_moduleName)
        do $$$AssertStatusOK(sc, "Able to install "_moduleName_" v"_latestVersion_" from the lock file")

        // Confirm classes and dependencies get installed as well
        do $classmethod("LockModH.Class1", "MethodB")

        // Uninstall module before testing with other version
        set sc = ##class(%IPM.Main).Shell("uninstall -r "_moduleName)
        do $$$AssertStatusOK(sc, "Uninstalled "_moduleName)



        // Now test with an older version of the same module
        set olderLockFileName =  "lock-mod-h-multiple-versions-v2.json"
        set olderVersion = "2.0.0"

        // Do an initial install of the module and create a lock file for it
        set sc = ##class(%IPM.Main).Shell("install -create-lockfile "_moduleName_" "_olderVersion)
        do $$$AssertStatusOK(sc, "Able to install "_moduleName_" v"_olderVersion_" and create lock file for it")

        // Compare the generated lock file with the expected one
        set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
        set lockFilePath = module.Root_..#LockFileName
        set areLockFilesEqual = ..AreLockFilesEqual(lockFilePath, ..#ExpectedFilesDir_olderLockFileName)
        do $$$AssertTrue(areLockFilesEqual, "Lock file contents for "_moduleName_" v"_olderVersion_" match expected values")

        // Go back to the initial state by uninstalling the module and dependencies at the end of the test
        set sc = ##class(%IPM.Main).Shell("uninstall -r "_moduleName)
        do $$$AssertStatusOK(sc, "Uninstalled "_moduleName)

        // Install module from lock file
        set sc = ##class(%IPM.Main).Shell("ci "_moduleName_" "_olderVersion)
        do $$$AssertStatusOK(sc, "Able to install "_moduleName_" v"_olderVersion_" from the lock file")

        // Confirm classes and dependencies get installed as well
        do $classmethod("LockModH.Class1", "MethodA")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test06ModuleMultipleVersions.")
    }
}

/// Module with no pre-existing lock file
///     - Test creation of a lock file, for a module that did not already have one.
///         - Differs from other tests which overwrite pre-existing lock files
///         - Both cases SHOULD be functionally equivalent
///     - zpm "ci" should fail due to not being able to locate the lock file
/// Uses Module I
Method Test07ModuleNoLockFile()
{
    try {
        set moduleName = ..#ModuleI

        // Install and create lock file for module
        do ..AssertInstallCreatesLockFileAsExpected(moduleName)

        // Go back to the initial state by deleting lock file for this module at the end of the test
        set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
        set lockFilePath = module.Root_..#LockFileName
        if '##class(%File).Delete(lockFilePath) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Failed to delete lock file located at: %1", lockFilePath)))
        }

        // Uninstall module to prepare to install from lock file
        set sc = ##class(%IPM.Main).Shell("uninstall -r "_moduleName)
        do $$$AssertStatusOK(sc, "Uninstalled "_moduleName)

        // This should fail due to no lock file
        set sc = ##class(%IPM.Main).Shell("ci "_moduleName)
        do $$$AssertStatusNotOK(sc, "zpm ""ci"" fails on module "_moduleName_"due to not having a lock file")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test07ModuleNoLockFile.")
    }
}

/// TODO: This succeeds, compiling modules doesn't see dependency issues and by the time
///       we call LockModJ.Class1::MethodA() all dependencies are loaded so no issues there.
///           - Is that okay?
///               - I'm inclined to say yes. Dependencies out of order isn't too realistic a use case
///                 anyways so maybe delete this case altogether?
/// Try install on a lock file that lists dependencies out of order
/// Uses Module J
Method Test08ModuleDependenciesOutOfOrder()
{
    set moduleName = ..#ModuleJ

    zpm "install -lock "_moduleName

    //set sc = ##class(%IPM.Main).Shell("ci "_moduleName)
    //do $$$AssertStatusNotOK(sc, "Installing from lock file with dependencies listed out of order fails")
}

/// 2 dependencies for a module have the same transient to add to the lock file
/// Uses Module K
Method Test09Module2DependenciesSameTransient()
{
    try {
        do ..ExecuteGenericLockFileTest(..#ModuleK)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test09Module2DependenciesSameTransient.")
    }
}

/// Tests writing and installing from a lock file for a module with a more complex nested dependencies setup
/// Uses Module L
Method Test10ComplexNestedDependencies()
{
    try {
        do ..ExecuteGenericLockFileTest(..#ModuleL)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Test10ComplexNestedDependencies.")
    }
}

/// Generic lock file test are steps that are shared across many cases above. The steps are:
/// 1. Install and create lock file for module
/// 2. Check that the lock file generated matches expected values
/// 3. Uninstall the module (and dependencies)
/// 4. Install from lock file via zpm "ci"
/// 5. Call method in installed module (which in turn calls dependency methods) to confirm "ci" loads all modules correctly
Method ExecuteGenericLockFileTest(
	moduleName As %String,
	className As %String = "")
{
    // Install and create lock file for module
    do ..AssertInstallCreatesLockFileAsExpected(moduleName)

    // Uninstall module to prepare to install from lock file
    set sc = ##class(%IPM.Main).Shell("uninstall -r "_moduleName)
    do $$$AssertStatusOK(sc, "Uninstalled "_moduleName)

    // Install module from lock file
    do ..AssertInstallFromLockFileAsExpected(moduleName, className)
}

/// Base cases of creating a lock file upon install of a module
Method AssertInstallCreatesLockFileAsExpected(moduleName As %String)
{
    // Do an initial install of the module and create a lock file for it
    set sc = ##class(%IPM.Main).Shell("install -create-lockfile "_moduleName)
    do $$$AssertStatusOK(sc, "Able to install "_moduleName_" and create lock file for it")

    // Compare the generated lock file with the expected one
    set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
    set lockFilePath = module.Root_..#LockFileName
    set areLockFilesEqual = ..AreLockFilesEqual(lockFilePath, ..#ExpectedFilesDir_moduleName_".json")
    do $$$AssertTrue(areLockFilesEqual, "Lock file contents for "_moduleName_" match expected values")
}

/// Takes in the path to two lock files and compares their values
/// Comparison is done as a string so if the keys are in a different order the comparison will fail, even if data is equivalent
/// This is intended as the keys being in a different order should alert us to further investigate
/// Especially for the dependencies list where order is explicitly required (for zpm "ci" to install in correct order)
/// 
/// Returns: 1 - if lock files have equivalent contents
///          0 - if lock files are different
ClassMethod AreLockFilesEqual(
	actualLockFilePath As %String,
	expectedLockFilePath As %String) As %Boolean
{
    try {
        set actualLockFileContents = ##class(%DynamicAbstractObject).%FromJSONFile(actualLockFilePath)
        set expectedLockFileContents = ##class(%DynamicAbstractObject).%FromJSONFile(expectedLockFilePath)
        return actualLockFileContents.%ToJSON() = expectedLockFileContents.%ToJSON()
    } catch (ex) {
        // Should error if we fail to open either the actual or expected file
        return ex.AsStatus()
    }
}

/// Base case of installing a module from a lock file and confirming everything gets loaded as expected
Method AssertInstallFromLockFileAsExpected(
	moduleName As %String,
	className As %String = "")
{
    set sc = ##class(%IPM.Main).Shell("ci "_moduleName)
    do $$$AssertStatusOK(sc, "Installed "_moduleName_" via the lock file successfully")

    set sc = $$$OK
    try {
        if (className = "") {
            // Letter of the module is in the 10th place: "lock-mod-x-..."
            set packageLetter = $zconvert($extract(moduleName, 10), "u")
            set className = "LockMod"_packageLetter_".Class1"
        }
        do $classmethod(className, "MethodA")
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    do $$$AssertStatusOK(sc, "Called MethodA() to confirm "_moduleName_" and dependency classes loaded correctly")
}

}
