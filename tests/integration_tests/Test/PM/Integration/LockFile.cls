Class Test.PM.Integration.LockFile Extends Test.PM.Integration.Base
{

/// Name of the JSON lock file
Parameter LockFileName As String = "module-lock.json";

/// Directory where files for expected lock file contents are located
Parameter ExpectedFilesDir As String = "/home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/lock-test/expected-files/";

/// Module with 0 dependencies
Parameter ModuleA As String = "lock-mod-a";

/// Module with 0 dependencies
Parameter ModuleB As String = "lock-mod-b";

/// Module with 2 deps w/o transient (A & B)
Parameter ModuleC As String = "lock-mod-c";

/// Module with 1 dep w/ 2 transient (C)
Parameter ModuleD As String = "lock-mod-d";

/// Module with 1 dep w/o transient (A)
Parameter ModuleE As String = "lock-mod-e";

/// Module with 1 dep w/ 1 transient & 1 dep w/o transient (E & B)
Parameter ModuleF As String = "lock-mod-f";

/// Module with dependencies for all repository types (Module remote, Module oras, Module http, Module filesystem, & Module perforce)
Parameter ModuleG As String = "lock-mod-g";

/// Module with multiple versions
///     - v2: Base equivalent to Module F
///     - v3: Adds dependency Module A
Parameter ModuleH As String = "lock-mod-h";

/// Base equivalent to Module F, just deleted the lock file
Parameter ModuleI As String = "lock-mod-i";

/// Base equivalent to Module D, but different lock file
/// Lock file as A->C->B instead of A->B->C (C is dependent on B)
Parameter ModuleJ As String = "lock-mod-j";

/// 2 dependencies: C & E, both with same transient dependency: A
Parameter ModuleK As String = "lock-mod-k";

/// TODO: Question: Should the modules have lock files for them by default?
///         If yes - Will be like how other modules are defined but base install will be the "update a lock file" case
///         If no  - Modules won't start in their final form but every install will be a "create a lock file" by default
///       Decision: Yes
///         Doesn't matter which we choose since "create" & "update" should be identical, just make sure to add a sanity test for the other case
Method OnBeforeAllTests() As %Status
{
    // TODO: Have this in so that dev changes get picked up in testing ns, delete later
    set sc = $system.OBJ.Load("/home/irisowner/zpm/src/cls/IPM/Main.cls", "ck")
    do $$$AssertStatusOK(sc, "Successfully imported dev %IPM.Main class")
    // Setup repo for LockFile tests
    set sc = ##class(%IPM.Main).Shell("repo -n lock-file -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/lock-test/")
    do $$$AssertStatusOK(sc,"Created lock-file repo successfully.")
    return sc
}

/// Module with 0 dependencies
/// Uses Module A
Method TestModule0Dependencies()
{
    set tSC = $$$OK
    try {
        set moduleName = ..#ModuleA
        // Do an initial install of the module and create a lock file for it
        set sc = ##class(%IPM.Main).Shell("install -create-lockfile "_moduleName)
        do $$$AssertStatusOK(sc, "Able to install "_moduleName_" and create lock file for it")

        // Compare the generated lock file with the expected one
        set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
        set lockFilePath = module.Root_..#LockFileName
        set areLockFilesEqual = ..AreLockFilesEqual(lockFilePath, ..#ExpectedFilesDir_moduleName_".json")
        do $$$AssertTrue(areLockFilesEqual, "Lock file contents for "_moduleName_" match expected values")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Module0Dependencies.")
    }
}

/// Module with 2 direct dependencies (they themselves don't have deps)
/// Uses Module C
Method TestModule2Dependencies0Transient()
{
    set tSC = $$$OK
    try {
        set moduleName = ..#ModuleC
        do ..AssertInstallCreatesLockFileAsExpected(moduleName)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Module2Dependencies0Transient.")
    }
}

/// Module with dependency that has transient dependencies
/// Uses Module D
Method TestModule1Dependency2Transient()
{
    set tSC = $$$OK
    try {
        set moduleName = ..#ModuleD
        do ..AssertInstallCreatesLockFileAsExpected(moduleName)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Module1Dependency2Transient.")
    }
}

/// Module with 1 dep (with transient), 1 dep (without transient)
/// Uses Module F
Method TestModule2Dependencies1Transient()
{
    set tSC = $$$OK
    try {
        set moduleName = ..#ModuleF
        do ..AssertInstallCreatesLockFileAsExpected(moduleName)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Module2Dependencies1Transient.")
    }
}

/// Edge cases below:
/// All repository types
/// Uses Module G
Method TestModuleDependenciesAllRepositoryTypes()
{
}

/// Module with multiple versions: Can both specify a version and defaults to latest (highest #) version
/// Uses Module H
Method TestModuleMultipleVersions()
{
}

/// zpm "ci" on a module with no lock file as well as creating a lock file for a module that didn't already have one
/// Uses Module I
Method TestModuleNoLockFile()
{
}

/// Try install on a lock file that lists dependencies out of order
/// Uses Module J
Method TestModuleDependenciesOutOfOrder()
{
}

/// / 2 dependencies for a module have the same transient to add to the lock file
/// Uses Module K
Method TestModule2DependenciesSameTransient()
{
    set tSC = $$$OK
    try {
        set moduleName = ..#ModuleK
        do ..AssertInstallCreatesLockFileAsExpected(moduleName)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in Module2DependenciesSameTransient.")
    }
}

/// Base cases of creating and installing from a lock file
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
    set actualLockFileContents = ##class(%DynamicAbstractObject).%FromJSONFile(actualLockFilePath)
    set expectedLockFileContents = ##class(%DynamicAbstractObject).%FromJSONFile(expectedLockFilePath)
    return actualLockFileContents.%ToJSON() = expectedLockFileContents.%ToJSON()
}

}
