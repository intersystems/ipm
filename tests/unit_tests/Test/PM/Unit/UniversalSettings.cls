Class Test.PM.Unit.UniversalSettings Extends %UnitTest.TestCase
{

Parameter TestIndx As STRING = "TestIndx";

Method TestSetValueOverwrite()
{
    do ##class(%IPM.Repo.UniversalSettings).SetValue(..#TestIndx, "new value a", )
    set value = ##class(%IPM.Repo.UniversalSettings).GetValue(..#TestIndx)
    do $$$AssertEquals(value, "new value a")

    do ##class(%IPM.Repo.UniversalSettings).SetValue(..#TestIndx, "new value b", 1)
    set value = ##class(%IPM.Repo.UniversalSettings).GetValue(..#TestIndx)
    do $$$AssertEquals(value, "new value b")
}

Method TestSetValueNoOverwrite()
{
    do ##class(%IPM.Repo.UniversalSettings).SetValue(..#TestIndx, "new value c", 0)
    set value = ##class(%IPM.Repo.UniversalSettings).GetValue(..#TestIndx)
    do $$$AssertEquals(value, "default value")
}

/// Run by <B>RunTest</B> immediately after each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required.
/// </dl>
Method OnAfterOneTest(testname As %String) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    kill ^IPM.settings(..#TestIndx)
    quit $$$OK
}

/// Run by <B>RunTest</B> immediately before each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required.
/// </dl>
Method OnBeforeOneTest(testname As %String) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set ^IPM.settings(..#TestIndx) = "default value"
    quit $$$OK
}

Method TestModuleRootValidationRejectsNonexistentDir()
{
    set sc = $$$OK
    set exceptionThrown = 0
    try {
        do ##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", "/nonexistent_ipm_test_dir_xyz/")
    } catch ex {
        set exceptionThrown = 1
    }
    do $$$AssertTrue(exceptionThrown, "Setting ModuleRoot to a nonexistent directory throws an exception.")
}

Method TestModuleRootResetToDefault()
{
    set sc = $$$OK
    try {
        set expectedDefault = ##class(%File).NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")
        set customPath = ##class(%File).NormalizeDirectory("/tmp/ipm-test-root/")
        do $$$AssertTrue(##class(%File).CreateDirectoryChain(customPath), "Created custom ModuleRoot directory.")

        do $$$AssertStatusOK(##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", customPath), "Set ModuleRoot to custom path.")

        do $$$AssertStatusOK(##class(%IPM.Repo.UniversalSettings).ResetToDefault("ModuleRoot"), "Reset ModuleRoot to default.")
        set resetValue = ##class(%IPM.Repo.UniversalSettings).GetModuleRoot()
        do $$$AssertEquals(resetValue, expectedDefault, "ModuleRoot reset value matches expected default.")
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected exception in TestModuleRootResetToDefault.")
    }
}

}
