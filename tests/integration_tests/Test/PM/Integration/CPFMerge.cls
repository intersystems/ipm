Class Test.PM.Integration.CPFMerge Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "cpf-merge";

Method TestCPFMerge()
{
    set moduleDir = ..GetModuleDir(..#TargetModuleName)

    // During load, only the config-globals.cpf file should be merged
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .pLoadOutput)
    do $$$AssertStatusOK(sc, "Loaded module successfully")
    do $$$AssertTrue(..FindStringInMultiDimArray("config-globals.cpf", .pLoadOutput))
    do $$$AssertNotTrue(..FindStringInMultiDimArray("actions.cpf", .pLoadOutput))
    do $$$AssertNotTrue(..FindStringInMultiDimArray("package-mapping.cpf", .pLoadOutput))

    // During MakeDeployed, only the actions.cpf file should be merged
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("cpf-merge makedeployed -v -only")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .pMakeDeployedOutput)
    do $$$AssertStatusOK(sc, "MakeDeployed executed successfully")
    do $$$AssertNotTrue(..FindStringInMultiDimArray("config-globals.cpf", .pMakeDeployedOutput))
    do $$$AssertTrue(..FindStringInMultiDimArray("actions.cpf", .pMakeDeployedOutput))
    do $$$AssertNotTrue(..FindStringInMultiDimArray("package-mapping.cpf", .pMakeDeployedOutput))

    // During custom phase "MyPhase", only the package-mapping.cpf file should be merged. Also, the SayHello Invoke should be executed.
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("cpf-merge myphase -v -only")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .pMyPhaseOutput)
    do $$$AssertStatusOK(sc, "MyPhase executed successfully")
    do $$$AssertNotTrue(..FindStringInMultiDimArray("config-globals.cpf", .pMyPhaseOutput))
    do $$$AssertNotTrue(..FindStringInMultiDimArray("actions.cpf", .pMyPhaseOutput))
    do $$$AssertTrue(..FindStringInMultiDimArray("package-mapping.cpf", .pMyPhaseOutput))
    do $$$AssertTrue(..FindStringInMultiDimArray("Hello, World!", .pMyPhaseOutput))

    // Verify the CPF files are merged correctly
    new $namespace
    set $namespace = "%SYS"

    // Test config globals
    do $$$AssertStatusOK(##class(Config.config).Get(.props))
    do $$$AssertEquals(props("globals8kb"), 150000)

    // Test package mapping
    set packageMap = ##class(Config.MapPackages).Open("%SYS", "MyPackage")
    do $$$AssertEquals(packageMap.Database, "USER")

    // Test role
    do $$$AssertTrue(##class(Security.Roles).Exists("MyTestRole"))

    // Test Resource
    do $$$AssertTrue(##class(Security.Resources).Exists("MyTestResource"))

    // Test Web Application
    do $$$AssertTrue(##class(Security.Applications).Exists("/csp/my-test-webapp"))

    // Cleanup: Remove resources created by the test
    set sc = ##class(Config.MapPackages).Delete("%SYS", "MyPackage")
    do $$$AssertStatusOK(sc, "Cleaned up package mapping: MyPackage")

    set sc = ##class(Security.Roles).Delete("MyTestRole")
    do $$$AssertStatusOK(sc, "Cleaned up role: MyTestRole")

    set sc = ##class(Security.Resources).Delete("MyTestResource")
    do $$$AssertStatusOK(sc, "Cleaned up resource: MyTestResource")

    set sc = ##class(Security.Applications).Delete("/csp/my-test-webapp")
    do $$$AssertStatusOK(sc, "Cleaned up web application: /csp/my-test-webapp")
}

Method TestSystemExpressions()
{
    set moduleDir = ..GetModuleDir(..#TargetModuleName)

    // Load the module first if not already loaded
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module successfully")

    // Run the custom phase that merges the CPF with system expressions
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("cpf-merge testsystemexpressions -v -only")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .pOutput)
    do $$$AssertStatusOK(sc, "TestSystemExpressions phase executed successfully")
    do $$$AssertTrue(..FindStringInMultiDimArray("system-expressions.cpf", .pOutput))

    // Verify that system expressions were evaluated correctly
    new $namespace
    set originalNamespace = $namespace
    set $namespace = "%SYS"

    // Test role created with {$namespace} expression
    set roleName = originalNamespace _ "-MyTestRole"
    do $$$AssertTrue(##class(Security.Roles).Exists(roleName), "Role created with evaluated {$namespace} expression: "_roleName)

    // Test Web Application created with {$ns} expression
    set webAppName = "/ipm/cpfwebapp"
    do $$$AssertTrue(##class(Security.Applications).Exists(webAppName), "Web application exists: "_webAppName)

    // Verify web application properties
    set sc = ##class(Security.Applications).Get(webAppName, .webAppProps)
    do $$$AssertStatusOK(sc, "Retrieved web application properties successfully")
    do $$$AssertEquals(webAppProps("NameSpace"), originalNamespace, "Web app namespace set correctly using {$ns} expression")
    do $$$AssertEquals(webAppProps("AutheEnabled"), $$$AutheUnauthenticated, "Web app authentication set correctly using $$$AutheUnauthenticated macro")

    // Cleanup: Remove the web application and role created by the test
    set sc = ##class(Security.Applications).Delete(webAppName)
    do $$$AssertStatusOK(sc, "Cleaned up web application: "_webAppName)

    set sc = ##class(Security.Roles).Delete(roleName)
    do $$$AssertStatusOK(sc, "Cleaned up role: "_roleName)
}

}
