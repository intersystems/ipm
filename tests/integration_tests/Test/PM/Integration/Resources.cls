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
	do ..DeleteLocalizationExport($get(tModuleDirectory))
	do ..TearDown()
}

/// Activate exports the module's .LOC messages into its root, which is the fixture directory
ClassMethod DeleteLocalizationExport(moduleDirectory As %String)
{
	if moduleDirectory = "" {
		return
	}
	do ##class(%File).Delete(##class(%File).NormalizeFilename("localize/HTTPStatuses.xml", moduleDirectory))
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
	do ..DeleteLocalizationExport($get(tModuleDirectory))
	do ..TearDown()
}

/// Loading skips files IRIS cannot import, such as the .DS_Store files macOS Finder creates. The
/// fixture has them in a package directory and in the preload directory. The preload class processes
/// a resource and records each phase it runs in, so it runs in Reload only if preload compiled it.
Method TestLoadSkipsUnsupportedFiles()
{
    kill ^IPMTest("UnsupportedFiles")
    set moduleDir = ..GetModuleDir("unsupported-files")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ moduleDir), "Loaded module with unsupported files")
    do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("Test.Unsupported.MyClass"), "Class in package directory was compiled")
    do $$$AssertTrue($get(^IPMTest("UnsupportedFiles", "Reload")), "Class in preload directory was compiled before Reload")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall unsupported-files"), "Uninstalled module")
    kill ^IPMTest("UnsupportedFiles")
}

/// Export writes the item under the resource name, so a file holding a different class would package empty.
Method TestLoadFailsOnMismatchedClassName()
{
    set moduleDir = ..GetModuleDir("mismatched-names", "class")
    set sc = ##class(%IPM.Main).Shell("load " _ moduleDir)
    do $$$AssertStatusNotOK(sc, "Load failed")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "MismatchTest.Bar", "Error names the class in the file: " _ $system.Status.GetErrorText(sc))
    do ##class(%IPM.Storage.Module).Uninstall("mismatched-class", 1, 1)
    do $system.OBJ.Delete("MismatchTest.Bar.cls", "-d")
}

/// The document name inside an XML export, not its file name, decides what gets imported.
Method TestLoadFailsOnMismatchedDocumentName()
{
    set moduleDir = ..GetModuleDir("mismatched-names", "document")
    set sc = ##class(%IPM.Main).Shell("load " _ moduleDir)
    do $$$AssertStatusNotOK(sc, "Load failed")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "MismatchTest.Other.LOC", "Error names the document in the file: " _ $system.Status.GetErrorText(sc))
    do ##class(%IPM.Storage.Module).Uninstall("mismatched-document", 1, 1)
    do ##class(%RoutineMgr).Delete("MismatchTest.Other.LOC")
}

/// Load reports the names it imported as one comma-separated string, so a name containing a comma must still match.
Method TestLoadAcceptsCommaInDocumentName()
{
    set moduleDir = ..GetModuleDir("comma-document-name")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ moduleDir), "Loaded module")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall comma-document-name"), "Uninstalled module")
}

}
