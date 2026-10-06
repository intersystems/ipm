Class Test.PM.Integration.CPFMerge Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "cpf-merge";

Method OnAfterOneTest() As %Status
{
    do ..CleanupCPFArtifacts()
    quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    do ..CleanupCPFArtifacts()
    quit $$$OK
}

/// Removes the module and any %SYS artifacts created by the CPF merges, so a failed
/// test does not leak state into the next test or test case. Each step swallows errors
/// since the artifact may not exist on a given run.
Method CleanupCPFArtifacts()
{
    set originalNamespace = $namespace
    try {
        do ##class(%IPM.Main).Shell("uninstall " _ ..#TargetModuleName _ " -force -quiet")
    } catch {}

    new $namespace
    set $namespace = "%SYS"
    set roleName = originalNamespace _ "-MyTestRole"
    for item = $listbuild("Config.MapPackages", "%SYS", "MyPackage"),
            $listbuild("Security.Roles", "MyTestRole"),
            $listbuild("Security.Roles", roleName),
            $listbuild("Security.Resources", "MyTestResource"),
            $listbuild("Security.Applications", "/csp/my-test-webapp"),
            $listbuild("Security.Applications", "/ipm/cpfwebapp") {
        try {
            set cls = $listget(item, 1)
            set arg1 = $listget(item, 2)
            set arg2 = $listget(item, 3)
            if (arg2 '= "") {
                do $classmethod(cls, "Delete", arg1, arg2)
            } else {
                do $classmethod(cls, "Delete", arg1)
            }
        } catch {}
    }
}

Method TestCPFMerge()
{
    set moduleDir = ..GetModuleDir(..#TargetModuleName)

    // During load, only the config-globals.cpf file should be merged
    set cookie = ""
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
}

Method TestCPFPackage()
{
    set moduleDir = ..GetModuleDir(..#TargetModuleName)
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module successfully")

    set pkgDir = ##class(%File).NormalizeDirectory("cpf-merge-pkg", $$$FileTempDir)
    set extractDir = ##class(%File).NormalizeDirectory("cpf-merge-extract", $$$FileTempDir)
    do ##class(%File).RemoveDirectoryTree(pkgDir)
    do ##class(%File).RemoveDirectoryTree(extractDir)
    try {
        set sc = ##class(%IPM.Main).Shell("package " _ ..#TargetModuleName _ " -only -v -path " _ pkgDir)
        do $$$AssertStatusOK(sc, "Packaged module with CPF resources successfully")

        // Verify CPF files land where DoMerge will look for them after install
        set tgz = $extract(pkgDir, 1, *-1) _ ".tgz"
        do $$$AssertTrue(##class(%File).Exists(tgz), "Package tgz was created: " _ tgz)
        do ##class(%File).CreateDirectoryChain(extractDir)
        set sc = ##class(%IPM.General.Archive).Extract(tgz, extractDir)
        do $$$AssertStatusOK(sc, "Extracted packaged tgz")

        set expectedFiles = $listbuild(
            "src/cpf/config-globals.cpf",
            "src/custom-cpf-directory/actions.cpf",
            "src/cpf/package-mapping.cpf",
            "src/cpf/system-expressions.cpf")
        set ptr = 0
        while $listnext(expectedFiles, ptr, relPath) {
            set absPath = ##class(%File).NormalizeFilename(relPath, extractDir)
            do $$$AssertTrue(##class(%File).Exists(absPath), "Archive contains " _ relPath)
        }
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Exception during package verification")
    }
    do ##class(%File).RemoveDirectoryTree(pkgDir)
    do ##class(%File).RemoveDirectoryTree(extractDir)
}

Method TestSystemExpressions()
{
    set moduleDir = ..GetModuleDir(..#TargetModuleName)

    // Load the module first if not already loaded
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module successfully")

    // Run the custom phase that merges the CPF with system expressions
    set cookie = ""
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
}

}
