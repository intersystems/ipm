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
    // Somehow the role cannot be created. Something's wrong with create-roles.cpf
    Do $$$AssertTrue(##class(Security.Roles).Exists("MyTestRole", .role))
}

}
