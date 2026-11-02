Class Test.PM.Integration.ModuleRoot Extends Test.PM.Integration.Base
{

Parameter ModuleName = "simplest-module";

Parameter ModuleVersion = "1.0.0";

/// Filesystem repos load modules in place, so the module comes from the local ORAS registry to exercise ModuleRoot.
/// It is published once for all tests because every test installs the same unchanged package.
Method OnBeforeAllTests() As %Status
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"), "Deleted repos.")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name oras -url http://oras:5000 -publish 1"), "Configured ORAS repo.")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..GetModuleDir(..#ModuleName, ..#ModuleVersion)), "Loaded test module.")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish " _ ..#ModuleName _ " -r oras"), "Published test module.")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName), "Uninstalled test module.")
    return $$$OK
}

Method OnAfterAllTests() As %Status
{
    do ##class(%IPM.Main).Shell("unpublish oras/" _ ..#ModuleName _ " " _ ..#ModuleVersion _ " -force")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"), "Deleted repos.")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -reset-defaults"), "Reset repos to defaults.")
    return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
    if ##class(%IPM.Storage.Module).NameExists(..#ModuleName) {
        do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName), "Uninstalled test module.")
    }
    set sc = ##class(%IPM.Repo.UniversalSettings).ResetToDefault(##class(%IPM.Repo.UniversalSettings).#ModuleRoot)
    do $$$AssertStatusOK(sc, "ModuleRoot reset to default after test.")
    for dir = "ipm-test-root-exists/","ipm-test-root-new/" {
        set fullPath = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ dir)
        if ##class(%File).DirectoryExists(fullPath) {
            do ##class(%File).RemoveDirectoryTree(fullPath)
        }
    }
    return sc
}

/// Installs the test module and returns the directory it was installed under, minus the module's own subfolder.
Method InstallAndGetRoot() As %String
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("install " _ ..#ModuleName _ " " _ ..#ModuleVersion), "Installed test module.")
    set moduleObj = ##class(%IPM.Storage.Module).NameOpen(..#ModuleName)
    return ##class(%File).NormalizeDirectory($piece(moduleObj.Root, ..#ModuleName))
}

Method TestModuleRootDefault()
{
    try {
        set defaultRoot = ##class(%File).NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")

        set moduleRoot = ..InstallAndGetRoot()
        do $$$AssertEquals(moduleRoot, defaultRoot, "Module installed into default root.")
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected exception in TestModuleRootDefault.")
    }
}

Method TestModuleRootCustomPathExists()
{
    try {
        set defaultRoot = ##class(%File).NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")
        set customPath = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "ipm-test-root-exists/")

        do $$$AssertTrue(##class(%File).CreateDirectoryChain(customPath), "Created custom ModuleRoot directory.")

        do $$$AssertStatusOK(##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", customPath), "Set ModuleRoot to existing custom path.")
        do $$$AssertEquals(##class(%IPM.Repo.UniversalSettings).GetModuleRoot(), customPath, "ModuleRoot stored as normalized path.")

        set moduleRoot = ..InstallAndGetRoot()
        do $$$AssertTrue(moduleRoot '= defaultRoot, "Module is no longer in default root.")
        do $$$AssertTrue(moduleRoot [ customPath, "Module is installed in custom root: " _ moduleRoot)
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected exception in TestModuleRootCustomPathExists.")
    }
}

Method TestModuleRootCustomPathCreated()
{
    try {
        set defaultRoot = ##class(%File).NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")
        set customPath = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "ipm-test-root-new/")

        // Remove the directory if it exists from a prior run
        if ##class(%File).DirectoryExists(customPath) {
            do ##class(%File).RemoveDirectoryTree(customPath)
        }
        do $$$AssertTrue('##class(%File).DirectoryExists(customPath), "Custom path does not exist before config set.")

        do $$$AssertStatusOK(##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", customPath), "Set ModuleRoot to nonexistent path, which should create it.")
        do $$$AssertTrue(##class(%File).DirectoryExists(customPath), "Directory was created by config set.")

        set moduleRoot = ..InstallAndGetRoot()
        do $$$AssertTrue(moduleRoot '= defaultRoot, "Module is no longer in default root.")
        do $$$AssertTrue(moduleRoot [ customPath, "Module is installed in auto-created root: " _ moduleRoot)
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected exception in TestModuleRootCustomPathCreated.")
    }
}

}
