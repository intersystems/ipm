/// This is an integration test because it creates data.
Class Test.PM.Integration.Scopes Extends Test.PM.Integration.Base
{

Method TestEverything()
{
	#dim tModule As %ZPM.Storage.Module
	
	New $Namespace
	Set tOrigNS = $Namespace
	Try {
		If '$$$AssertStatusOK(..Setup()) {
			Quit
		}
		
		// In client namespace:
		Set $Namespace = ..#CLIENTNS
		
		// Create modules
		For i=1:1:4 {
			Kill tModule
			Quit:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,"ServerModule"_i,.tModule),"Loaded module from XData block ServerModule"_i)
			Set tModules(i) = tModule
		}
		
		Kill tGraph
		For i=2:1:4 {
			For tEndPhase = "Activate","Test","Package","Verify" {
				Set tModule = tModules(i)
				Kill tGraph
				Set tSC = tModule.BuildDependencyGraph(.tGraph,,,,tModule.Lifecycle.GetCompletePhases($ListBuild(tEndPhase)))
				Do $$$AssertStatusOK(tSC,"Built dependency graph for module "_tModule.Name_" "_tModule.VersionString_" phase "_tEndPhase)
				
				// Cases where there should be an HS.JSON dependency reported
				If (i = 2) ||
					((i = 3) && (tEndPhase = "Test")) ||
					((i = 4) && (tEndPhase = "Verify")) {
					Do $$$AssertTrue($Data(tGraph("hs.unittest1")))
				} Else {
					Do $$$AssertNotTrue($Data(tGraph("hs.unittest1")))
				}
			}
		}
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
	
	// Cleanup
	Set $Namespace = tOrigNS
	Do $$$AssertStatusOK(..TearDown())
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
