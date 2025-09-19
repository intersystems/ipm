Class Test.PM.Unit.Oras Extends %UnitTest.TestCase
{

Method TestOras()
{
    set Registry = "http://oras:5000"
    set Name = "objectscript-math"

    // Target package
    set moduleRef = ##class(%IPM.Storage.ModuleInfo).%New()
    set moduleRef.Name = Name

    // Cleanup
    do ..RunCommand("repo -delete-all")
    do ..RunCommand("repo -reset-defaults")

    // Set up ORAS repo
    do ..AssertNoException("repo -o -name oci -url " _ Registry)
	do ..RunCommand("repo -list")
	do ..RunCommand("repo -list-modules")

    &sql(SELECT id INTO :ociId FROM %IPM_Repo_Oras.definition WHERE name='oci')
    do $$$AssertEquals(SQLCODE, 0)
    set oci = ##class(%IPM.Repo.Oras.Definition).%OpenId(ociId,0)
    set packageService = oci.GetPackageService()
    set publishService = oci.GetPublishService()

    if 'packageService.IsAvailable() {
        do $$$AssertSkipped("ORAS registry unavailable, skipping")
    }

    // make sure package is not in the registry first
    set version = packageService.GetLatestTagPy(Registry, Name, "", "", "", "", 0)
    if version '= "" {
        do publishService.DeleteModule(Registry, Name, "", "", "", "", 0)
    }
    do $$$AssertNotTrue(packageService.HasModule(moduleRef))

    // Install package from the default registry
    do ..RunCommand("install registry/" _ Name)

    // Push to OCI registry
    do ..AssertNoException("publish " _ Name _ " -r oci")
    do $$$AssertTrue(packageService.HasModule(moduleRef))

    // Pull from OCI registry
    do ..RunCommand("uninstall " _ Name)
    do ..AssertNoException("install oci/" _ Name)

    // Delete from OCI registry
    do publishService.DeleteModule(Registry, Name, "", "", "", "", 0)

    // Set as default registry
    do ..RunCommand("repo -publish 1 -n oci")

    // Install from default
    do ..AssertNoException("install " _ Name)

    // Clean up
    do ..RunCommand("repo -delete-all")
    do ..RunCommand("repo -reset-defaults")
}

Method RunCommand(pCommand As %String)
{
	do ##class(%IPM.Main).Shell(pCommand)
	do $$$LogMessage("Run command: "_pCommand)
}

Method AssertNoException(pCommand As %String)
{
	do ##class(%IPM.Main).ShellInternal(pCommand,.tException)
	if '$$$AssertEquals(tException,"","No exceptions occurred running command: "_pCommand) {
		do $$$LogMessage(tException.DisplayString())
	}
}

}
