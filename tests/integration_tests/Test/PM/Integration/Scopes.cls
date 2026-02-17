/// This is an integration test because it creates data.
Class Test.PM.Integration.Scopes Extends Test.PM.Integration.Base
{

Method TestEverything()
{
	#dim tModule As %IPM.Storage.Module

	new $namespace
	set tOrigNS = $namespace
	try {
		if '$$$AssertStatusOK(..Setup()) {
			quit
		}

		// In client namespace:
		set $namespace = ..#CLIENTNS

		// Create modules
		for i=1:1:4 {
			kill tModule
			quit:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,"ServerModule"_i,.tModule),"Loaded module from XData block ServerModule"_i)
			set tModules(i) = tModule
		}

		kill tGraph
		for i=2:1:4 {
			for tEndPhase = "Activate","Test","Package","Verify" {
				set tModule = tModules(i)
				kill tGraph
				set tSC = tModule.BuildDependencyGraph(.tGraph,,,,tModule.Lifecycle.GetCompletePhases($listbuild(tEndPhase)))
				do $$$AssertStatusOK(tSC,"Built dependency graph for module "_tModule.Name_" "_tModule.VersionString_" phase "_tEndPhase)

				// Cases where there should be an HS.JSON dependency reported
				if (i = 2) ||
					((i = 3) && (tEndPhase = "Test")) ||
					((i = 4) && (tEndPhase = "Verify")) {
					do $$$AssertTrue($data(tGraph("hs.unittest1")))
				} else {
					do $$$AssertNotTrue($data(tGraph("hs.unittest1")))
				}
			}
		}
	} catch e {
		do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}

	// Cleanup
	set $namespace = tOrigNS
	do $$$AssertStatusOK(..TearDown())
}

/// Validates that modules with scoped classes and packages can be installed
/// Validates that scoped classes and packages do not compile on normal install
Method TestScopedResourceInstall()
{
    set sc = $$$OK
    try {
        set moduleDir = ..GetModuleDir("scope-test/scope-class")
        set status = ##class(%IPM.Main).Shell("load -verbose "_moduleDir)
        do $$$AssertStatusOK(status, "Module ScopeClass successfully installed.")

        // Normal install: Scoped class should not exist
        do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("HS.ScopedClass"), "Scoped class should NOT exist after normal install")

        set moduleDir = ..GetModuleDir("scope-test/scope-package")
        set status = ##class(%IPM.Main).Shell("load -verbose "_moduleDir)
        do $$$AssertStatusOK(status, "Module ScopePackage successfully installed.")

        // Normal install: Class within a scoped package should not exist
        do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("HS.Class"), "Class within scoped package should NOT exist after normal install")
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected failure in TestScopedResourceInstall")
    }
}

/// Validates that test-scoped dependencies are loaded when running tests
Method TestScopedDependencyLoadingTest()
{
    set sc = $$$OK
    try {
        // Setup filesystem repository
        set repoDir = ..GetModuleDir("scope-test/scope-test")
        set sc = ##class(%IPM.Main).Shell("repo -fs -name scopetest -path " _ repoDir)
        do $$$AssertStatusOK(sc, "Set up filesystem repository")

        // Uninstall any existing modules first
        set sc = ##class(%IPM.Main).Shell("uninstall scope-test-dep")
        set sc = ##class(%IPM.Main).Shell("uninstall scope-test")

        // Install parent module from filesystem repo (should NOT install scoped dependency yet)
        set sc = ##class(%IPM.Main).Shell("install scopetest/scope-test -verbose")
        do $$$AssertStatusOK(sc, "Installed scope-test from filesystem repo")

        // Verify scoped dependency class does not exist yet
        do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Test.Scope.ScopedClass"), "Test.Scope.ScopedClass should NOT exist before running tests")

        // Run tests (should load scoped dependency)
        set sc = ##class(%IPM.Main).Shell("scope-test test -only -verbose")
        do $$$AssertStatusOK(sc, "Running tests should load test-scoped dependency and pass")

        // Verify scoped dependency was installed and class exists
        do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Test.Scope.ScopedClass"), "Test.Scope.ScopedClass should exist after running tests")

        // Cleanup: uninstall modules
        set sc = ##class(%IPM.Main).Shell("uninstall scope-test-dep")
        set sc = ##class(%IPM.Main).Shell("uninstall scope-test")

        // Cleanup: delete repository
        set sc = ##class(%IPM.Main).Shell("repo -delete -name scopetest")
        do $$$AssertStatusOK(sc, "Deleted filesystem repo")

    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected failure in TestScopedDependencyLoadingTest")
    }
}

/// Validates that verify-scoped dependencies are loaded when running verify
Method TestScopedDependencyLoadingVerify()
{
    set sc = $$$OK
    try {
        // Setup filesystem repository
        set repoDir = ..GetModuleDir("scope-test/scope-test")
        set sc = ##class(%IPM.Main).Shell("repo -fs -name scopetest -path " _ repoDir)
        do $$$AssertStatusOK(sc, "Set up filesystem repository")

        // Uninstall any existing modules first
        set sc = ##class(%IPM.Main).Shell("uninstall scope-test-dep-verify")
        set sc = ##class(%IPM.Main).Shell("uninstall scope-test")

        // Install parent module from filesystem repo (should NOT install scoped dependency yet)
        set sc = ##class(%IPM.Main).Shell("install scopetest/scope-test -verbose")
        do $$$AssertStatusOK(sc, "Installed scope-test from filesystem repo")

        // Verify scoped dependency class does not exist yet
        do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Test.Scope.VerifyScopedClass"), "Test.Scope.VerifyScopedClass should NOT exist before running verify")

        // Run verify (should load scoped dependency)
        set sc = ##class(%IPM.Main).Shell("scope-test verify -only -verbose")
        do $$$AssertStatusOK(sc, "Running verify should load verify-scoped dependency and pass")

        // Cleanup: uninstall modules
        set sc = ##class(%IPM.Main).Shell("uninstall scope-test-dep-verify")
        set sc = ##class(%IPM.Main).Shell("uninstall scope-test")

        // Cleanup: delete repository
        set sc = ##class(%IPM.Main).Shell("repo -delete -name scopetest")
        do $$$AssertStatusOK(sc, "Deleted filesystem repo")

    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected failure in TestScopedDependencyLoadingVerify")
    }
}

XData ServerModule1 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.UNITTEST1</Name>
  <Version>0.0.1</Version>
</Module>
}

XData ServerModule2 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.UNITTEST2</Name>
  <Version>0.0.1</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.UNITTEST1</Name>
  <Version>0.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule3 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.UNITTEST3</Name>
  <Version>0.0.1</Version>
  <Dependencies>
  <ModuleReference Scope="test">
  <Name>HS.UNITTEST1</Name>
  <Version>0.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule4 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.UNITTEST4</Name>
  <Version>0.0.1</Version>
  <Dependencies>
  <ModuleReference Scope="verify">
  <Name>HS.UNITTEST1</Name>
  <Version>0.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

}
