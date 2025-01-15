Class Test.PM.Integration.CPFMerge Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "cpf-merge";

Method TestCPFMerge()
{
    Set tModuleDir = ..GetModuleDir(..#TargetModuleName)

    Set tSC = ##class(%IPM.Main).Shell("load -v "_tModuleDir)
    Do $$$AssertStatusOK(tSC, "Loaded module successfully")

    // Config.* classes are only available in %SYS
    New $Namespace
    Set $Namespace = "%SYS"

    // Test config globals
    Do $$$AssertStatusOK(##class(Config.config).Get(.props))
    Do $$$AssertEquals(props("globals8kb"), 150000)

    // Test package mapping
    Set packageMap = ##class(Config.MapPackages).Open("%SYS", "MyPackage")
    Do $$$AssertEquals(packageMap.Database, "USER")

    // Test role
    Do $$$AssertTrue(##class(Security.Roles).Exists("MyTestRole"))

    // Test Resource
    Do $$$AssertTrue(##class(Security.Resources).Exists("MyTestResource"))

    // Test Web Application
    Do $$$AssertTrue(##class(Security.Applications).Exists("/csp/my-test-webapp"))
}

}
