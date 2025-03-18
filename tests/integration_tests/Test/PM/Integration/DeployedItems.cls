Class Test.PM.Integration.DeployedItems Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "deployable-test";

Parameter ModuleName = "deployable-test";

Method TestDeployedItems()
{
    Do ..SetupModule()

    Set tmpDir = $$$FileTempDir _ "package"
    Set sc = ##class(%IPM.Main).Shell("package " _..#ModuleName _ " -v -path " _ tmpDir)
    Do $$$AssertStatusOK(sc, "Successfully packaged module to "_tmpDir)
    Do ..SetupOrasReigstry()
    Set sc = ##class(%IPM.Main).Shell("publish "_..#ModuleName)
    Do $$$AssertStatusOK(sc, "Successfully published module")
    Do ..UninstallModule()

    Set sc = ##class(%IPM.Main).Shell("load -v "_tmpDir)
    Do $$$AssertStatusOK(sc, "Successfully loaded module with deployed items at "_tmpDir)
    Do ..RunDeployedCode()
    Do ..UninstallModule()

    Set sc = ##class(%IPM.Main).Shell("install "_..#ModuleName)
    Do $$$AssertStatusOK(sc, "Successfully installed module")

    Do ..RunDeployedCode()
    Do ..UninstallModule()
    Do ..RestoreDefaultReigstry()
}

Method SetupModule()
{
    Set folder = ..GetModuleDir(..#ModuleFolder)
    Set sc = ##class(%IPM.Main).Shell("load -v "_folder)
    Do $$$AssertStatusOK(sc, "Successfully loaded module at "_folder)

    Set sc = ##class(%IPM.Main).Shell(..#ModuleName _ " makedeployed -v")
    Do $$$AssertStatusOK(sc, "Successfully ran MakeDeployed")
}

Method UninstallModule()
{
    Set sc = ##class(%IPM.Main).Shell("uninstall "_..#ModuleName)
    Do $$$AssertStatusOK(sc, "Successfully uninstalled module")
    Try {
        Do ##class(DeployableTest.Main).Hello()
        Do $$$AssertFailure("Should not be able to run method after uninstall")
    } Catch ex {
        Do $$$AssertSuccess("Run method after uninstall failed as expected")
    }
}

Method RunDeployedCode()
{
    Try {
        Do ##class(DeployableTest.Main).Hello()
        Do $$$AssertSuccess("Successfully ran method from deployed item")
    } Catch ex {
        Do $$$AssertFailure("Failed to run method from deployed item: "_ex.AsStatus())
    }
}

Method SetupOrasReigstry()
{
    Set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(sc, "Successfully deleted modules")

    Set sc = ##class(%IPM.Main).Shell("repo -name oras -o -url http://oras:5000 -publish 1")
    Do $$$AssertStatusOK(sc, "Successfully setup oras registry")
}

Method RestoreDefaultReigstry()
{
    Set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(sc, "Successfully deleted modules")

    Set sc = ##class(%IPM.Main).Shell("repo -reset-defaults")
    Do $$$AssertStatusOK(sc, "Successfully reset repo to defaults")
}

}
