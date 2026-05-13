Class Test.PM.Integration.ModuleRoot Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
{
    set sc = ##class(%IPM.Main).Shell("repo -remote -n registry -url https://pm.community.intersystems.com/ -user """" -pass """"")
    do $$$AssertStatusOK(sc, "Community registry configured.")
    return sc
}

Method OnAfterAllTests() As %Status
{
    set sc = ##class(%IPM.Main).Shell("uninstall objectscript-math -force")
    set sc = ##class(%IPM.Main).Shell("repo -delete -n registry")
    do $$$AssertStatusOK(sc, "Community registry removed.")
    return sc
}

Method OnAfterOneTest(testname As %String) As %Status
{
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

Method TestModuleRootDefault()
{
    set sc = $$$OK
    try {
        set defaultRoot = ##class(%File).NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")

        set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
        if $isobject(moduleObj) {
            do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall objectscript-math"), "Uninstalled objectscript-math before test.")
        }

        do $$$AssertStatusOK(##class(%IPM.Main).Shell("install objectscript-math"), "Installed objectscript-math using default ModuleRoot.")

        set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
        set moduleRoot = ##class(%File).NormalizeDirectory($piece(moduleObj.Root, "objectscript-math"))
        do $$$AssertEquals(moduleRoot, defaultRoot, "Module installed into default root.")
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected exception in TestModuleRootDefault.")
    }
}

Method TestModuleRootCustomPathExists()
{
    set sc = $$$OK
    try {
        set defaultRoot = ##class(%File).NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")
        set customPath = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "ipm-test-root-exists/")

        do $$$AssertTrue(##class(%File).CreateDirectoryChain(customPath), "Created custom ModuleRoot directory.")

        do $$$AssertStatusOK(##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", customPath), "Set ModuleRoot to existing custom path.")
        do $$$AssertEquals(##class(%IPM.Repo.UniversalSettings).GetModuleRoot(), customPath, "ModuleRoot stored as normalized path.")

        set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
        if $isobject(moduleObj) {
            do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall objectscript-math"), "Uninstalled objectscript-math before relocation test.")
        }

        do $$$AssertStatusOK(##class(%IPM.Main).Shell("install objectscript-math"), "Installed objectscript-math using existing custom ModuleRoot.")

        set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
        set moduleRoot = ##class(%File).NormalizeDirectory($piece(moduleObj.Root, "objectscript-math"))
        do $$$AssertTrue(moduleRoot '= defaultRoot, "Module is no longer in default root.")
        do $$$AssertTrue(moduleRoot [ customPath, "Module is installed in custom root: " _ moduleRoot)
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected exception in TestModuleRootCustomPathExists.")
    }
}

Method TestModuleRootCustomPathCreated()
{
    set sc = $$$OK
    try {
        set defaultRoot = ##class(%File).NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")
        set customPath = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "ipm-test-root-new/")

        // Remove the directory if it exists from a prior run
        if ##class(%File).DirectoryExists(customPath) {
            do ##class(%File).RemoveDirectoryTree(customPath)
        }
        do $$$AssertTrue('##class(%File).DirectoryExists(customPath), "Custom path does not exist before config set.")

        do $$$AssertStatusOK(##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", customPath), "Set ModuleRoot to nonexistent path — should create it.")
        do $$$AssertTrue(##class(%File).DirectoryExists(customPath), "Directory was created by config set.")

        set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
        if $isobject(moduleObj) {
            do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall objectscript-math"), "Uninstalled objectscript-math before relocation test.")
        }

        do $$$AssertStatusOK(##class(%IPM.Main).Shell("install objectscript-math"), "Installed objectscript-math into auto-created custom ModuleRoot.")

        set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
        set moduleRoot = ##class(%File).NormalizeDirectory($piece(moduleObj.Root, "objectscript-math"))
        do $$$AssertTrue(moduleRoot '= defaultRoot, "Module is no longer in default root.")
        do $$$AssertTrue(moduleRoot [ customPath, "Module is installed in auto-created root: " _ moduleRoot)
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected exception in TestModuleRootCustomPathCreated.")
    }
}

}
