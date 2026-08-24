/// Unit tests for %IPM.Storage.ModuleInfo.IsCompatibleWithPlatform.
/// Constructs ModuleInfo objects directly — no running IRIS registry or ORAS service needed.
Class Test.PM.Unit.DeployedModuleFilter Extends %UnitTest.TestCase
{

/// Deployed module whose PlatformVersions includes the current platform should pass the filter.
Method TestDeployedCompatiblePlatformIncluded()
{
    set mod = ..BuildDeployedMod("2024.1", "2025.1")
    do $$$AssertTrue(mod.IsCompatibleWithPlatform("2024.1"), "Compatible platform is included")
    do $$$AssertTrue(mod.IsCompatibleWithPlatform("2025.1"), "Second compatible platform is included")
}

/// Deployed module whose PlatformVersions does not include the current platform should return false.
Method TestDeployedIncompatiblePlatformExcluded()
{
    set mod = ..BuildDeployedMod("2024.1", "2025.1")
    do $$$AssertNotTrue(mod.IsCompatibleWithPlatform("2025.2"), "Incompatible platform is excluded")
    do $$$AssertNotTrue(mod.IsCompatibleWithPlatform("9999.9"), "Unknown platform is excluded")
}

/// Non-deployed modules always return true regardless of platform.
Method TestNonDeployedAlwaysCompatible()
{
    set mod = ##class(%IPM.Storage.ModuleInfo).%New()
    set mod.Name = "mymodule"
    set mod.VersionString = "1.0.0"
    set mod.Deployed = 0
    do mod.PlatformVersions.Insert("2024.1")

    do $$$AssertTrue(mod.IsCompatibleWithPlatform("9999.9"), "Non-deployed is always compatible")
}

/// Deployed module with empty PlatformVersions (e.g. filesystem repos) always returns true.
Method TestDeployedNoPlatformVersionsAlwaysCompatible()
{
    set mod = ##class(%IPM.Storage.ModuleInfo).%New()
    set mod.Name = "mymodule"
    set mod.VersionString = "1.0.0"
    set mod.Deployed = 1

    do $$$AssertTrue(mod.IsCompatibleWithPlatform("9999.9"), "Deployed with no PlatformVersions is always compatible")
}


/// FormatPlatformVersions returns comma-separated list.
Method TestFormatPlatformVersions()
{
    set mod = ..BuildDeployedMod("2024.1", "2025.1")
    do $$$AssertEquals(mod.FormatPlatformVersions(), "2024.1, 2025.1", "Two platforms formatted correctly")
}

/// FormatPlatformVersions returns empty string for empty list.
Method TestFormatPlatformVersionsEmpty()
{
    set mod = ##class(%IPM.Storage.ModuleInfo).%New()
    set mod.Name = "mymodule"
    set mod.VersionString = "1.0.0"
    do $$$AssertEquals(mod.FormatPlatformVersions(), "", "Empty list returns empty string")
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a deployed ModuleInfo with the given platform version strings.
ClassMethod BuildDeployedMod(platforms...) As %IPM.Storage.ModuleInfo
{
    set mod = ##class(%IPM.Storage.ModuleInfo).%New()
    set mod.Name = "mymodule"
    set mod.VersionString = "1.0.0"
    set mod.Deployed = 1
    for i=1:1:$get(platforms) {
        do mod.PlatformVersions.Insert(platforms(i))
    }
    return mod
}

}
