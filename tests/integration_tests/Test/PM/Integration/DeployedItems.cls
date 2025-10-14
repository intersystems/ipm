Class Test.PM.Integration.DeployedItems Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "deployable-test";

Parameter ModuleName = "deployable-test";

Method OnBeforeAllTests() As %Status
{
    // Enable interoperability to satisfy SystemRequirements
    set sc = $$$OK
    do $$$AssertStatusOK(##class(%EnsembleMgr).EnableNamespace($namespace))
    return sc
}

Method OnAfterAllTests() As %Status
{
    // Disable interoperability
    set sc = $$$OK
    do $$$AssertStatusOK(##class(%EnsembleMgr).DisableNamespace($namespace))
    return sc
}

Method TestDeployedItems()
{
    do ..SetupModule()

    set tmpDir = $$$FileTempDir _ "package"
    set sc = ##class(%IPM.Main).Shell("package " _..#ModuleName _ " -only -v -path " _ tmpDir)
    do $$$AssertStatusOK(sc, "Successfully packaged module to "_tmpDir)
    do ..SetupOrasRegistry()
    set sc = ##class(%IPM.Main).Shell("publish "_..#ModuleName_" -v -only")
    do $$$AssertStatusOK(sc, "Successfully published module")
    do ..UninstallModule()

    set sc = ##class(%IPM.Main).Shell("load -v "_tmpDir_".tgz")
    do $$$AssertStatusOK(sc, "Successfully loaded module with deployed items at "_tmpDir)
    do ..RunDeployedCode()
    do ..UninstallModule()

    set sc = ##class(%IPM.Main).Shell("install "_..#ModuleName)
    do $$$AssertStatusOK(sc, "Successfully installed module")

    do ..RunDeployedCode()
    do ..UninstallModule()
    do ..RestoreDefaultReigstry()
}

Method SetupModule()
{
    set folder = ..GetModuleDir(..#ModuleFolder)
    set sc = ##class(%IPM.Main).Shell("load -v "_folder)
    do $$$AssertStatusOK(sc, "Successfully loaded module at "_folder)
}

Method UninstallModule()
{
    set sc = ##class(%IPM.Main).Shell("uninstall "_..#ModuleName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module")
    try {
        do ##class(DeployableTest.Main).Hello()
        do $$$AssertFailure("Should not be able to run method after uninstall")
    } catch ex {
        do $$$AssertSuccess("Run method after uninstall failed as expected")
    }
}

Method RunDeployedCode()
{
    try {
        do ##class(DeployableTest.Main).Hello()
        do $$$AssertSuccess("Successfully ran method from deployed item")
    } catch ex {
        do $$$AssertFailure("Failed to run method from deployed item: "_ex.AsStatus())
    }
}

Method SetupOrasRegistry()
{
    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc, "Successfully deleted modules")

    set sc = ##class(%IPM.Main).Shell("repo -name oras -o -url http://oras:5000 -publish 1")
    do $$$AssertStatusOK(sc, "Successfully setup oras registry")
}

Method RestoreDefaultReigstry()
{
    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc, "Successfully deleted modules")

    set sc = ##class(%IPM.Main).Shell("repo -reset-defaults")
    do $$$AssertStatusOK(sc, "Successfully reset repo to defaults")
}

}
