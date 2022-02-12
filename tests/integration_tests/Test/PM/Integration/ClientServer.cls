Class Test.PM.Integration.ClientServer Extends Test.PM.Integration.Base
{

Method TestEverything()
{
	#dim tModule As %IPM.Storage.Module
	
	New $Namespace
	Set tOrigNS = $Namespace
	Try {
		If '$$$AssertStatusOK(..Setup()) {
			Quit
		}

		// Create a module
		Quit:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,"ServerModule",.tModule))
		
		// Register that module
		Do $$$AssertStatusOK(tModule.Lifecycle.Publish())

		// In client namespace:
		Set $Namespace = ..#CLIENTNS
		
		// Create a module referring to the module in the remote repository
		Quit:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,"LocalModule",.tModule))
		
		// Compile that module
		Do $$$AssertStatusOK(tModule.%Compile("d"))
		
		// Clean that module
		Do $$$AssertStatusOK(tModule.Lifecycle.Clean())
		
		// Validate that module
		Do $$$AssertStatusOK(tModule.Lifecycle.Validate())
		
		// Clean that module
		Do $$$AssertStatusOK(tModule.Lifecycle.Clean())
		
		// Compile that module
		Do $$$AssertStatusOK(tModule.%Compile("d"))
		
		// Compile that module
		Do $$$AssertStatusOK(tModule.%Compile("d"))
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
	
	// Cleanup
	Set $Namespace = tOrigNS
	Do $$$AssertStatusOK(..TearDown())
}

XData ServerModule [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>0.0.1+snapshot</Version>
</Module>
}

XData LocalModule [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.2+snapshot</Version>
  <Dependencies>
    <ModuleReference>
      <Name>HS.JSON</Name>
      <Version>0.0.1</Version>
    </ModuleReference>
  </Dependencies>
</Module>
}

}
