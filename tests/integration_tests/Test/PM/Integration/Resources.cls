Class Test.PM.Integration.Resources Extends Test.PM.Integration.Base
{

Parameter NEEDSREGISTRY = 0;

Method TestResourceTypes()
{
	New $Namespace
	Set oldNamespace = $Namespace

	If ('$ListFind($system.Version.GetISCComponents(), "Health")) {
		Do $$$AssertSkipped("This test only runs on IRIS for Health, which has all resource types available.")
		Quit $$$OK
	}

	Set tSC = $$$OK
	Try {
		Set tTestRoot = $Get(^UnitTestRoot)

		If '$$$AssertStatusOK(..Setup()) {
			Quit
		}
		Set $Namespace = ..#CLIENTNS
		
		// Uninstall. This might fail; if it does that's fine.
		Do ##class(%IPM.Storage.Module).Uninstall("ResourceTest",1,1)
		
		Set tParams("Verbose") = 1
		Set tModuleDirectory = ##class(%File).NormalizeDirectory("_data/resource-test", tTestRoot)
		Set tSC = ##class(%IPM.Utils.Module).LoadModuleFromDirectory(tModuleDirectory,.tParams)
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

		// Assert that ownership of .INC files is appropriate
		&sql(select ID into :rrID from %IPM_Storage.ResourceReference where ModuleItem->Name = 'ResourceTest' and Name = 'ResourceTest.APackage.PKG')
		$$$ThrowSQLIfError(SQLCODE,%message)
		Set rr = ##class(%IPM.Storage.ResourceReference).%OpenId(rrID,,.sc)
		$$$ThrowOnError(sc)
		Do $$$AssertStatusOK(rr.ResolveChildren(.res))
		If $$$AssertTrue($Data(res("ResourceTest.APackage.IncludeFile.inc"))) {
			Do $$$AssertEquals(res("ResourceTest.APackage.IncludeFile.inc","RelativePath"),"cls/ResourceTest/APackage/IncludeFile.inc")
		}
		Do $$$AssertNotTrue($Data(res("ResourceTest.APackage.AnotherIncludeFile.inc")))
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}

	Set $Namespace = oldNamespace
	Do ..TearDown()
}

}
