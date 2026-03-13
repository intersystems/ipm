Class Test.PM.Integration.Resources Extends Test.PM.Integration.Base
{

Parameter NEEDSREGISTRY = 0;

Parameter ResourceTestIRISHealthMod = "ResourceTestIRISHealth";

Parameter ResourceTestIRISMod = "ResourceTestIRIS";

Method TestResourceTypesOnIRISForHealth()
{
	new $namespace
	set oldNamespace = $namespace

	if ('$listfind($system.Version.GetISCComponents(), "Health")) {
		do $$$AssertSkipped("This test only runs on IRIS for Health, which has all resource types available.")
		quit $$$OK
	}

	set tSC = $$$OK
	try {
		set tTestRoot = $get(^UnitTestRoot)

		if '$$$AssertStatusOK(..Setup()) {
			quit
		}
		set $namespace = ..#CLIENTNS

		// Uninstall. This might fail; if it does that's fine.
		do ##class(%IPM.Storage.Module).Uninstall(..#ResourceTestIRISHealthMod,1,1)

		set tParams("Verbose") = 1
		set tModuleDirectory = ##class(%File).NormalizeDirectory("_data/resource-tests/resource-test-irishealth", tTestRoot)
		set tSC = ##class(%IPM.Utils.Module).LoadModuleFromDirectory(tModuleDirectory,.tParams)
		do $$$AssertStatusOK(tSC,"Loaded ResourceTest module successfully.")

		for tClass = "ResourceTest.MyClass","ResourceTest.APackage.SomeClass", "ResourceTest.TestIncludeLoads" {
			do $$$AssertTrue($$$defClassDefined(tClass),tClass_" exists.")
		}

		for tClass = "ResourceTest.MyClass","ResourceTest.APackage.SomeClass", "ResourceTest.TestIncludeLoads" {
			do $$$AssertTrue($$$comClassDefined(tClass),tClass_" has been compiled.")
		}

		#; For tUserDoc = "Sample Operational Reports-Auditing Overview.dashboard.DFI","Demo.HL7.MsgRouter.Schema.HL7" {
		#; 	Do $$$AssertTrue(##class(%RoutineMgr).Exists(tUserDoc),tUserDoc_" exists.")
		#; }

		do $$$AssertEquals($get(^ResourceTest),"Hello World","^ResourceTest was imported properly.")

		do $$$AssertEquals($$MyFunction^ResourceTest(),42,"ResourceTest routine exists and was compiled (and, by extension, ResourceTest.inc as well).")

		// Assert that ownership of .INC files is appropriate
		&sql(select ID into :rrID from %IPM_Storage.ResourceReference where ModuleItem->Name = 'ResourceTestIRISHealth' and Name = 'ResourceTest.APackage.PKG')
		$$$ThrowSQLIfError(SQLCODE,%message)
		set rr = ##class(%IPM.Storage.ResourceReference).%OpenId(rrID,,.sc)
		$$$ThrowOnError(sc)
		do $$$AssertStatusOK(rr.ResolveChildren(.res))
		if $$$AssertTrue($data(res("ResourceTest.APackage.IncludeFile.inc"))) {
			do $$$AssertEquals(res("ResourceTest.APackage.IncludeFile.inc","RelativePath"),"cls/ResourceTest/APackage/IncludeFile.inc")
		}
		do $$$AssertNotTrue($data(res("ResourceTest.APackage.AnotherIncludeFile.inc")))
	} catch e {
		do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}

	set $namespace = oldNamespace
	do ..TearDown()
}

Method TestResourceTypesOnIRIS()
{
	new $namespace
	set oldNamespace = $namespace

	set tSC = $$$OK
	try {
		set tTestRoot = $get(^UnitTestRoot)

		if '$$$AssertStatusOK(..Setup()) {
			quit
		}
		set $namespace = ..#CLIENTNS

		// Uninstall. This might fail; if it does that's fine.
		do ##class(%IPM.Storage.Module).Uninstall(..#ResourceTestIRISMod,1,1)

		set tParams("Verbose") = 1
		set tModuleDirectory = ##class(%File).NormalizeDirectory("_data/resource-tests/resource-test-iris", tTestRoot)
		set tSC = ##class(%IPM.Utils.Module).LoadModuleFromDirectory(tModuleDirectory,.tParams)
		do $$$AssertStatusOK(tSC,"Loaded ResourceTest module successfully.")

		for tClass = "ResourceTest.MyClass","ResourceTest.APackage.SomeClass", "ResourceTest.TestIncludeLoads" {
			do $$$AssertTrue($$$defClassDefined(tClass),tClass_" exists.")
		}

		for tClass = "ResourceTest.MyClass","ResourceTest.APackage.SomeClass", "ResourceTest.TestIncludeLoads" {
			do $$$AssertTrue($$$comClassDefined(tClass),tClass_" has been compiled.")
		}

		do $$$AssertEquals($get(^ResourceTest),"Hello World","^ResourceTest was imported properly.")

		do $$$AssertEquals($$MyFunction^ResourceTest(),42,"ResourceTest routine exists and was compiled (and, by extension, ResourceTest.inc as well).")

		// Assert that ownership of .INC files is appropriate
		&sql(select ID into :rrID from %IPM_Storage.ResourceReference where ModuleItem->Name = 'ResourceTestIRIS' and Name = 'ResourceTest.APackage.PKG')
		$$$ThrowSQLIfError(SQLCODE,%message)
		set rr = ##class(%IPM.Storage.ResourceReference).%OpenId(rrID,,.sc)
		$$$ThrowOnError(sc)
		do $$$AssertStatusOK(rr.ResolveChildren(.res))
		if $$$AssertTrue($data(res("ResourceTest.APackage.IncludeFile.inc"))) {
			do $$$AssertEquals(res("ResourceTest.APackage.IncludeFile.inc","RelativePath"),"cls/ResourceTest/APackage/IncludeFile.inc")
		}
		do $$$AssertNotTrue($data(res("ResourceTest.APackage.AnotherIncludeFile.inc")))
	} catch e {
		do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}

	set $namespace = oldNamespace
	do ..TearDown()
}

}
