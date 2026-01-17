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
        do $$$AssertNotTrue($classmethod("%Dictionary.ClassDefinition", "%ExistsId", "HS.ScopedClass"), "Scoped class should NOT exist after normal install")

        set moduleDir = ..GetModuleDir("scope-test/scope-package")
        set status = ##class(%IPM.Main).Shell("load -verbose "_moduleDir)
        do $$$AssertStatusOK(status, "Module ScopePackage successfully installed.")

        // Normal install: Class within a scoped package should not exist
        do $$$AssertNotTrue($classmethod("%Dictionary.ClassDefinition", "%ExistsId", "HS.Class"), "Class within scoped package should NOT exist after normal install")
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Unexpected failure in TestScopedResourceInstall")
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
