/// Unit tests for the platform filtering of deployed modules: the compatibility check on
/// %IPM.Storage.ModuleInfo and the version reordering in %IPM.Repo.Oras.PackageService.
/// Everything is built in memory — no registry or ORAS service needed.
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

/// The compatible version must be promoted ahead of the newer incompatible one, so a caller
/// taking the first entry installs something that works on this platform.
Method TestPreferCompatibleVersionsPromotesCompatible()
{
    set platforms("2.0.0") = $listbuild("9999.1")
    set platforms("1.0.0") = $listbuild("2024.1")
    set reordered = ##class(%IPM.Repo.Oras.PackageService).PreferCompatibleVersions($listbuild("2.0.0", "1.0.0"), .platforms, "2024.1")
    do $$$AssertEquals($listtostring(reordered), "1.0.0,2.0.0", "Compatible 1.0.0 promoted ahead of incompatible 2.0.0")
}

/// Within each group the newest-first order the versions arrived in must be preserved.
Method TestPreferCompatibleVersionsKeepsOrderWithinGroups()
{
    set platforms("3.0.0") = $listbuild("2024.1")
    set platforms("2.0.0") = $listbuild("9999.1")
    set platforms("1.0.0") = $listbuild("2024.1")
    set reordered = ##class(%IPM.Repo.Oras.PackageService).PreferCompatibleVersions($listbuild("3.0.0", "2.0.0", "1.0.0"), .platforms, "2024.1")
    do $$$AssertEquals($listtostring(reordered), "3.0.0,1.0.0,2.0.0", "Newest-first order kept within each group")
}

/// A version with no platform suffix is not platform-specific, so it counts as compatible.
Method TestPreferCompatibleVersionsTreatsEmptyPlatformAsCompatible()
{
    set platforms("2.0.0") = $listbuild("9999.1")
    set platforms("1.0.0") = $listbuild("")
    set reordered = ##class(%IPM.Repo.Oras.PackageService).PreferCompatibleVersions($listbuild("2.0.0", "1.0.0"), .platforms, "2024.1")
    do $$$AssertEquals($listtostring(reordered), "1.0.0,2.0.0", "Version without a platform counts as compatible")
}

/// With nothing compatible the order is unchanged, so the caller still reports the newest
/// version and the platform filter downstream produces the error message.
Method TestPreferCompatibleVersionsAllIncompatible()
{
    set platforms("2.0.0") = $listbuild("9999.1")
    set platforms("1.0.0") = $listbuild("9999.2")
    set reordered = ##class(%IPM.Repo.Oras.PackageService).PreferCompatibleVersions($listbuild("2.0.0", "1.0.0"), .platforms, "2024.1")
    do $$$AssertEquals($listtostring(reordered), "2.0.0,1.0.0", "Order unchanged when nothing is compatible")
}

/// An empty version list must not error.
Method TestPreferCompatibleVersionsEmptyList()
{
    set reordered = ##class(%IPM.Repo.Oras.PackageService).PreferCompatibleVersions("", .platforms, "2024.1")
    do $$$AssertEquals(reordered, "", "Empty list returns empty list")
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
