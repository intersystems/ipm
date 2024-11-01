Class Test.PM.Unit.Oras Extends %UnitTest.TestCase
{

Method TestOras()
{
    Set Registry = "http://oras:5001"
    Set Name = "objectscript-math"

    // Target package
    Set moduleRef = ##class(%IPM.Storage.ModuleInfo).%New()
    Set moduleRef.Name = Name

    // Cleanup
    Do ..RunCommand("repo -delete-all")
    Do ..RunCommand("repo -reset-defaults")

    // Set up ORAS repo
    Do ..AssertNoException("repo -o -name oci -url " _ Registry)
	Do ..RunCommand("repo -list")
    
    &sql(SELECT id INTO :ociId FROM %IPM_Repo_Oras.definition WHERE name='oci')
    Do $$$AssertEquals(SQLCODE, 0)
    Set oci = ##class(%IPM.Repo.Oras.Definition).%OpenId(ociId)
    Set packageService = oci.GetPackageService()
    Set publishService = oci.GetPublishService()

    If 'packageService.IsAvailable() {
        Do $$$AssertSkipped("ORAS registry unavailable, skipping")
    }

    // make sure package is not in the registry first
    Set version = packageService.GetLatestTagPy(Registry, Name, "", "", "", "")
    If version '= "" {
        Do publishService.DeleteModule(Registry, Name, "", "", "", "")
    }
    Do $$$AssertNotTrue(packageService.HasModule(moduleRef))

    // Install package from the default registry
    Do ..RunCommand("install registry/" _ Name)

    // Push to OCI registry
    Do ..AssertNoException("publish " _ Name _ " -r oci")
    Do $$$AssertTrue(packageService.HasModule(moduleRef))

    // Pull from OCI registry
    Do ..RunCommand("uninstall " _ Name)
    Do ..AssertNoException("install oci/" _ Name)

    // Delete from OCI registry
    Do publishService.DeleteModule(Registry, Name, "", "", "", "")

    // Set as default registry
    Do ..RunCommand("repo -publish 1 -n oci")

    // Install from default
    Do ..AssertNoException("install " _ Name)
}

Method RunCommand(pCommand As %String)
{
	Do ##class(%IPM.Main).Shell(pCommand)
	Do $$$LogMessage("Run command: "_pCommand)
}

Method AssertNoException(pCommand As %String)
{
	Do ##class(%IPM.Main).ShellInternal(pCommand,.tException)
	If '$$$AssertEquals(tException,"","No exceptions occurred running command: "_pCommand) {
		Do $$$LogMessage(tException.DisplayString())
	}
}

}