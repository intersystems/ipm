Class Test.PM.Integration.Resources Extends %UnitTest.TestCase
{

Method TestResourceTypes()
{
  If ('##class(%EnsembleMgr).IsHealthShareInstalled()) {
    Quit $$$OK
  }

	Set tSC = $$$OK
	Try {
		Set tTestRoot = $Get(^UnitTestRoot)
		
		// Uninstall. This might fail; if it does that's fine.
		Do ##class(%ZPM.Storage.Module).Uninstall("ResourceTest",1,1)
		
		Set tParams("Verbose") = 1
		Set tModuleDirectory = ##class(%File).NormalizeDirectory("_data/resource-test", tTestRoot)
		Set tSC = ##class(%ZPM.Utils.Module).LoadModuleFromDirectory(tModuleDirectory,.tParams)
		Do $$$AssertStatusOK(tSC,"Loaded ResourceTest module successfully.")
		
		For tClass = "ResourceTest.MyClass","ResourceTest.APackage.SomeClass" {
			Do $$$AssertTrue($$$defClassDefined(tClass),tClass_" exists.")
		}
		
		For tClass = "ResourceTest.MyClass","ResourceTest.APackage.SomeClass" {
			Do $$$AssertTrue($$$comClassDefined(tClass),tClass_" has been compiled.")
		}
		
		#; For tUserDoc = "Sample Operational Reports-Auditing Overview.dashboard.DFI","Demo.HL7.MsgRouter.Schema.HL7" {
		#; 	Do $$$AssertTrue(##class(%RoutineMgr).Exists(tUserDoc),tUserDoc_" exists.")
		#; }
		
		Do $$$AssertEquals($Get(^ResourceTest),"Hello World","^ResourceTest was imported properly.")
		
		Do $$$AssertEquals($$MyFunction^ResourceTest(),42,"ResourceTest routine exists and was compiled (and, by extension, ResourceTest.inc as well).")
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
}

}
