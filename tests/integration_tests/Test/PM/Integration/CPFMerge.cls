Class Test.PM.Integration.CPFMerge Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "cpf-merge";

Method TestCPFMerge()
{
    Set tModuleDir = ..GetModuleDir(..#TargetModuleName)

    // During load, only the config-globals.cpf file should be merged
    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    Set tSC = ##class(%IPM.Main).Shell("load -v "_tModuleDir)
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .pLoadOutput)
    Do $$$AssertStatusOK(tSC, "Loaded module successfully")
    Do $$$AssertTrue(..FindStringInMultiDimArray("config-globals.cpf", .pLoadOutput))
    Do $$$AssertNotTrue(..FindStringInMultiDimArray("actions.cpf", .pLoadOutput))
    Do $$$AssertNotTrue(..FindStringInMultiDimArray("package-mapping.cpf", .pLoadOutput))

    // During MakeDeployed, only the actions.cpf file should be merged
    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    Set tSC = ##class(%IPM.Main).Shell("cpf-merge makedeployed -v -only")
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .pMakeDeployedOutput)
    Do $$$AssertStatusOK(tSC, "MakeDeployed executed successfully")
    Do $$$AssertNotTrue(..FindStringInMultiDimArray("config-globals.cpf", .pMakeDeployedOutput))
    Do $$$AssertTrue(..FindStringInMultiDimArray("actions.cpf", .pMakeDeployedOutput))
    Do $$$AssertNotTrue(..FindStringInMultiDimArray("package-mapping.cpf", .pMakeDeployedOutput))

    // During custom phase "MyPhase", only the package-mapping.cpf file should be merged. Also, the SayHello Invoke should be executed.
    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    Set tSC = ##class(%IPM.Main).Shell("cpf-merge myphase -v -only")
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .pMyPhaseOutput)
    Do $$$AssertStatusOK(tSC, "MyPhase executed successfully")
    Do $$$AssertNotTrue(..FindStringInMultiDimArray("config-globals.cpf", .pMyPhaseOutput))
    Do $$$AssertNotTrue(..FindStringInMultiDimArray("actions.cpf", .pMyPhaseOutput))
    Do $$$AssertTrue(..FindStringInMultiDimArray("package-mapping.cpf", .pMyPhaseOutput))
    Do $$$AssertTrue(..FindStringInMultiDimArray("Hello, World!", .pMyPhaseOutput))

    // Verify the CPF files are merged correctly
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
