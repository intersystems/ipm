Class Test.PM.Integration.DeployedItems Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "deployable-test";

Parameter ModuleName = "deployable-test";

Method OnAfterOneTest(testname As %String) As %Status
{
    Quit ##class(%IPM.Main).Shell("unmap -ns %SYS")
}

Method OnBeforeOneTest(testname As %String) As %Status
{
    Quit ##class(%IPM.Main).Shell("enable -map -ns %SYS")
}

Method TestPackageDeployedItems()
{
    Set folder = ..GetModuleDir(..#ModuleFolder)
    Set sc = ##class(%IPM.Main).Shell("load -v "_folder)
    Do $$$AssertStatusOK(sc, "Successfully loaded module at "_folder)

    Set sc = ##class(%IPM.Main).Shell(..#ModuleName _ " makedeployed -v")
    Do $$$AssertStatusOK(sc, "Successfully ran MakeDeployed")

    Set tmpDir = $$$FileTempDir _ "package"
    Set sc = ##class(%IPM.Main).Shell("package " _..#ModuleName _ " -v -path " _ tmpDir)
    Do $$$AssertStatusOK(sc, "Successfully packaged module to "_tmpDir)

    New $Namespace
    Set $Namespace = "%SYS"
    Set sc = ##class(%IPM.Main).Shell("load -v "_tmpDir)
    Do $$$AssertStatusOK(sc, "Successfully loaded module with deployed items at "_tmpDir)

    Try {
        Do ##class(DeployableTest.Main).Hello()
        Do $$$AssertSuccess("Successfully ran method from deployed item")
    } Catch ex {
        Do $$$AssertFailure("Failed to run method from deployed item: "_ex.AsStatus())
    }
}

}
