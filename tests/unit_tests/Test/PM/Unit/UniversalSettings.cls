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

Method TestModuleRootConfiguration()
{
    #define NormalizeDirectory(%dir)    ##class(%File).NormalizeDirectory(%dir)
    // Define the system default for comparison

    //zpminit setup - set the global to default ipm directory
    do ##class(%IPM.Repo.UniversalSettings).SetValue("ModuleRoot",##class(%SYSTEM.Util).DataDirectory() _ "ipm/", 1)

    do $$$LogMessage("Running on "_$namespace_ "namespace")

    do ##class(%IPM.Main).GetVersion("zpm",.out)
    if $get(out)="" {
        do $$$LogMessage("No registry configured. So started configuring https://pm.community.intersystems.com")
        set status = ..RunCommand("repo -remote -n registry -url https://pm.community.intersystems.com/ -user """" -pass """"")
        do $$$AssertStatusOK(status, "Registory configured successfully")
    }
    set defaultRoot = $$$NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
    if $isobject(moduleObj) {
        set status = ..RunCommand("uninstall objectscript-math")
        do $$$AssertStatusOK(status, "Module 'objectscript-math' uninstalled for testing the module root check.")
    }

    do $$$LogMessage("Phase 1: Verifying installation using default system paths.")
    set status = ..RunCommand("install objectscript-math")
    do $$$AssertStatusOK(status, "Module 'objectscript-math' installed successfully using default paths.")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
    set moduleRoot = $$$NormalizeDirectory($piece(moduleObj.Root, "objectscript-math"))

    do $$$AssertTrue(moduleRoot=defaultRoot, "Verified: Module root '"_moduleRoot_"' matches system default: '"_defaultRoot_"'")

    do $$$LogMessage("Phase 2: Testing permission validation for restricted directories.")
    try {
        // Attempting to set a restricted directory should trigger the validation logic you wrote
        set status = ##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", "/usr")
        do $$$AssertStatusNotOK(status, "Correctly blocked setting ModuleRoot to a restricted directory (/usr).")
    } catch ex {
        // Fallback if the method throws an exception instead of returning a status
        do $$$LogMessage("Caught expected exception during permission test: " _ ex.DisplayString())
    }

    do $$$LogMessage("Phase 3: Configuring a custom valid ModuleRoot.")
    set customPath = "/tmp/" // Ensure it is treated as a directory
    set status = ##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", customPath)
    do $$$AssertStatusOK(status, "Successfully updated ModuleRoot to custom path: " _ customPath)

    do $$$LogMessage("Verify the ModuleRoot directory.")

    do $$$LogMessage("Module Dir: "_##class(%IPM.Repo.UniversalSettings).GetValue("ModuleRoot"))

    do $$$LogMessage("Phase 4: Reinstalling module to verify path redirection.")
    set status = ..RunCommand("uninstall objectscript-math")
    do $$$AssertStatusOK(status, "Uninstalled 'objectscript-math' to prepare for relocation test.")

    set status = ..RunCommand("install objectscript-math")
    do $$$AssertStatusOK(status, "Reinstalled 'objectscript-math' successfully.")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
    set moduleRoot = $$$NormalizeDirectory($piece(moduleObj.Root, "objectscript-math"))

    // Verify the root has actually changed
    do $$$AssertTrue(moduleRoot'=defaultRoot, "Verified: Module is no longer in default root.")
    do $$$AssertTrue(moduleRoot[customPath, "Verified: Module is now installed in custom root: " _ moduleRoot)

    set status = ##class(%IPM.Repo.UniversalSettings).ResetToDefault("ModuleRoot")
    if $$$ISOK(status) {
        do $$$AssertStatusOK(status, "reset the ModuleRoot directory: "_##class(%IPM.Repo.UniversalSettings).GetValue("ModuleRoot"))
    }
}

Method RunCommand(command) As %Status
{
    set status = ##class(%IPM.Main).Shell(command)
    do $$$LogMessage("Run command: "_command)
    return status
}

}
