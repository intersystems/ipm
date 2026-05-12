Class Test.PM.Integration.ModuleRoot Extends Test.PM.Integration.Base
{

Method OnAfterOneTest(testname As %String) As %Status
{
    set sc = ##class(%IPM.Repo.UniversalSettings).ResetToDefault("ModuleRoot")
    do $$$AssertStatusOK(sc, "ModuleRoot reset to default after test.")
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

Method TestModuleRootCustomPath()
{
    set sc = $$$OK
    try {
        set defaultRoot = ##class(%File).NormalizeDirectory(##class(%SYSTEM.Util).DataDirectory() _ "ipm/")
        set customPath = ##class(%File).NormalizeDirectory("/tmp/ipm-test-root/")

        // Ensure custom path exists and is writable before configuring it
        do $$$AssertTrue(##class(%File).CreateDirectoryChain(customPath), "Created custom ModuleRoot directory.")

        do $$$AssertStatusOK(##class(%IPM.Repo.UniversalSettings).UpdateOne("ModuleRoot", customPath), "Set ModuleRoot to custom path.")
        do $$$AssertEquals(##class(%IPM.Repo.UniversalSettings).GetModuleRoot(), customPath, "ModuleRoot stored as normalized path.")

        set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
        if $isobject(moduleObj) {
            do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall objectscript-math"), "Uninstalled objectscript-math before relocation test.")
        }

        do $$$AssertStatusOK(##class(%IPM.Main).Shell("install objectscript-math"), "Installed objectscript-math using custom ModuleRoot.")

        set moduleObj = ##class(%IPM.Storage.Module).NameOpen("objectscript-math")
        set moduleRoot = ##class(%File).NormalizeDirectory($piece(moduleObj.Root, "objectscript-math"))
        do $$$AssertTrue(moduleRoot '= defaultRoot, "Module is no longer in default root.")
        do $$$AssertTrue(moduleRoot [ customPath, "Module is installed in custom root: " _ moduleRoot)
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected exception in TestModuleRootCustomPath.")
    }
}

}
