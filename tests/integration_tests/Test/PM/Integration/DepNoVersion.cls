Class Test.PM.Integration.DepNoVersion Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "dep-no-version";

/// Verify that a dependency declared without a Version attribute loads successfully
/// and is treated as matching any version (*).
Method TestLoadDependencyWithNoVersion() As %Status
{
    set moduleDir = ..GetModuleDir(..#ModuleFolder)
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Load module with version-less dependency")

    set module = ##class(%IPM.Storage.Module).NameOpen("dep-no-version", sc)
    do $$$AssertStatusOK(sc, "Opened module")
    if '$$$AssertTrue($isobject(module), "Module object valid") {
        quit $$$OK
    }

    set dep = module.Dependencies.GetAt(1)
    do $$$AssertEquals(dep.VersionString, "*", "Missing version defaults to *")
    do $$$AssertTrue(dep.Version.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("1.0.0")), "* satisfies 1.0.0")
    do $$$AssertTrue(dep.Version.IsSatisfiedBy(##class(%IPM.General.SemanticVersion).FromString("99.99.99")), "* satisfies any version")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall dep-no-version-dep"), "Uninstalled dep-no-version-dep")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall dep-no-version"), "Uninstalled dep-no-version")

    quit $$$OK
}

}
