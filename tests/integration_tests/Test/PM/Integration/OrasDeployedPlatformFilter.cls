/// Integration tests for deployed module platform filtering against a real ORAS (zot) registry.
Class Test.PM.Integration.OrasDeployedPlatformFilter Extends Test.PM.Integration.Base
{

/// Fixture directory under _data holding every module these tests use. The folder
/// parameters below are relative to it.
Parameter FixtureRoot = "platform-filter";

Parameter ModuleFolder = "test/v1";

/// Same module name as ModuleFolder, but version 2.0.0.
Parameter ModuleFolderV2 = "test/v2";

Parameter ModuleName = "platform-filter-test";

/// Depends on ModuleName at ">=1.0.0", which both published versions satisfy.
Parameter ConsumerFolder = "consumer/range";

Parameter ConsumerName = "platform-filter-consumer";

/// Depends on ModuleName at "^2.0.0", which only the incompatible version satisfies.
Parameter PinnedConsumerFolder = "consumer/pinned";

Parameter PinnedConsumerName = "platform-filter-consumer-pinned";

/// Platform guaranteed not to match any real IRIS instance.
Parameter IncompatiblePlatform = "9999.1";

/// Oras registry URL. Uses the docker-compose service name by default.
Parameter OrasURL = "http://oras:5000";

/// Point the namespace at the local zot registry once. Every test publishes to it and
/// unpublishes in OnAfterOneTest, so no test needs its own registry setup.
Method OnBeforeAllTests() As %Status
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"), "Cleared repos")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -name oras -o -url " _ ..#OrasURL _ " -publish 1"), "Configured ORAS registry")
    return $$$OK
}

Method OnAfterAllTests() As %Status
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"), "Cleared repos")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -reset-defaults"), "Reset repos to defaults")
    return $$$OK
}

Method OnAfterOneTest(testName As %String) As %Status
{
    do ##class(%IPM.Main).Shell("uninstall " _ ..#ConsumerName)
    do ##class(%IPM.Main).Shell("uninstall " _ ..#PinnedConsumerName)
    do ##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName)
    do ##class(%IPM.Main).Shell("unpublish oras/" _ ..#ModuleName _ " all -force")
    do ..DeleteTgz(..TgzPath(..#ModuleFolder))
    do ..DeleteTgz(..TgzPath(..#ModuleFolderV2))
    return $$$OK
}

/// A module published for the current platform is both visible and installable.
Method TestCompatiblePlatformVisibleAndInstallable()
{
    do ..LoadAndPackage()
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish " _ ..#ModuleName _ " -v -only"), "Published for current platform")

    do $$$AssertTrue(..ModuleVisibleInList(..#ModuleName), "Compatible module is visible in list-modules")

    // Uninstall the locally loaded copy first, so the install really comes from the registry
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName), "Uninstalled before reinstall")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("install " _ ..#ModuleName), "Install from compatible platform tag succeeded")
    do $$$AssertEquals(..InstalledVersion(..#ModuleName), "1.0.0", "Installed 1.0.0 from the registry")
}

/// A module available only for an incompatible platform is filtered out of repository listings.
Method TestIncompatiblePlatformHiddenFromList()
{
    set tgzPath = ..LoadAndPackage()
    do $$$AssertStatusOK(..PublishWithPlatform(tgzPath, ..#IncompatiblePlatform), "Published for incompatible platform")

    do $$$AssertNotTrue(..ModuleVisibleInList(..#ModuleName), "Incompatible module is hidden from list-modules")
}

/// Installing a module available only for an incompatible platform reports the platforms it
/// is actually available for, rather than a bare "not found".
Method TestIncompatiblePlatformInstallError()
{
    set currentPlatform = $system.Version.GetMajor() _ "." _ $system.Version.GetMinor()

    set tgzPath = ..LoadAndPackage()
    do $$$AssertStatusOK(..PublishWithPlatform(tgzPath, ..#IncompatiblePlatform), "Published for incompatible platform")

    set installSC = ##class(%IPM.Main).Shell("install " _ ..#ModuleName)
    do $$$AssertStatusNotOK(installSC, "Install of incompatible-platform module fails")

    set errText = $system.Status.GetErrorText(installSC)
    do $$$AssertTrue(errText [ ..#IncompatiblePlatform, "Error names the available platform ("_..#IncompatiblePlatform_")")
    do $$$AssertTrue(errText [ currentPlatform, "Error mentions the current platform ("_currentPlatform_")")
}

/// With 1.0.0 available for the current platform and 2.0.0 only for an incompatible one,
/// an install with no version constraint must resolve 1.0.0.
Method TestPlatformFilterPicksLowerCompatibleVersion()
{
    do ..PublishBothVersions()

    // Repository results are sorted highest-version-first and Install takes the first
    // match, so 2.0.0 would win here if the platform filter did not exclude it.
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("install " _ ..#ModuleName), "Installed with no version constraint")
    do $$$AssertEquals(..InstalledVersion(..#ModuleName), "1.0.0", "Resolved compatible 1.0.0 rather than incompatible 2.0.0")
}

/// A dependent whose range (">=1.0.0") is satisfied by both published versions must get the
/// one that is compatible with this platform. Exercises the dependency resolution path in
/// %IPM.Storage.Module rather than the install path in %IPM.Main.
Method TestDependencyResolvesToCompatibleVersion()
{
    do ..PublishBothVersions()

    set consumerDir = ..FixtureDir(..#ConsumerFolder)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v -nodev " _ consumerDir), "Loaded consumer from " _ consumerDir)
    do $$$AssertEquals(..InstalledVersion(..#ModuleName), "1.0.0", "Dependency resolved to compatible 1.0.0")
}

/// A dependent pinned to "^2.0.0" can only be satisfied by the incompatible version,
/// so resolution must fail rather than silently falling back to 1.0.0.
Method TestDependencyPinnedToIncompatibleVersionFails()
{
    do ..PublishBothVersions()

    set consumerDir = ..FixtureDir(..#PinnedConsumerFolder)
    set loadSC = ##class(%IPM.Main).Shell("load -v -nodev " _ consumerDir)
    do $$$AssertStatusNotOK(loadSC, "Load fails when the only satisfying version is platform-incompatible")
    // Check the specific message, not just that something failed. An unrelated error
    // would otherwise let this test pass without resolution ever being exercised
    set errText = $system.Status.GetErrorText(loadSC)
    do $$$AssertTrue(errText [ "Could not find satisfactory version", "Failed for lack of a satisfying version")
    do $$$AssertTrue(errText [ ..#ModuleName, "Error names the unresolvable dependency")
    do $$$AssertEquals(..InstalledVersion(..#ModuleName), "", "Incompatible 2.0.0 was not installed as a fallback")
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Absolute path to a fixture directory, given its path relative to FixtureRoot.
/// The relative path is split on "/" so each segment becomes its own path component.
ClassMethod FixtureDir(relativePath As %String) As %String
{
    set segmentCount = $length(relativePath, "/")
    set subfolders = 1 + segmentCount
    set subfolders(1) = ..#FixtureRoot
    for i = 1:1:segmentCount {
        set subfolders(i + 1) = $piece(relativePath, "/", i)
    }
    return ..GetModuleDir(subfolders...)
}

/// Path a fixture is packaged to, without the .tgz extension. The fixture's relative
/// path is flattened into the filename so every version gets its own tarball directly
/// under the temp directory, and teardown can find it from the folder parameter alone.
ClassMethod TgzPath(moduleFolder As %String) As %String
{
    return $$$FileTempDir _ ..#FixtureRoot _ "-" _ $translate(moduleFolder, "/", "-")
}

/// Load a module fixture from _data, package it, and return the path to the .tgz without
/// the extension.
Method LoadAndPackage(moduleFolder As %String = "") As %String
{
    if (moduleFolder = "") {
        set moduleFolder = ..#ModuleFolder
    }
    // -nodev is required: the deploy branch of the Reload phase is skipped in developer mode
    set folder = ..FixtureDir(moduleFolder)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v -nodev " _ folder), "Loaded module from " _ folder)

    set tgzPath = ..TgzPath(moduleFolder)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("package " _ ..#ModuleName _ " -only -v -path " _ tgzPath), "Packaged module to " _ tgzPath)
    return tgzPath
}

/// Publish platform-filter-test twice: 1.0.0 for the current platform and 2.0.0 for an
/// incompatible one.
Method PublishBothVersions()
{
    // 1.0.0 for the current platform, via the real publish command. The MakeDeployed phase
    // stamps SystemRequirements with this IRIS version during packaging; publish tags with it.
    do ..LoadAndPackage(..#ModuleFolder)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish " _ ..#ModuleName _ " -v -only"), "Published 1.0.0 for current platform")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName), "Uninstalled 1.0.0 before loading 2.0.0")

    // 2.0.0 for an incompatible platform. The publish command can only ever stamp the
    // current platform, so this tag has to be pushed directly.
    set v2Tgz = ..LoadAndPackage(..#ModuleFolderV2)
    do $$$AssertStatusOK(..PublishWithPlatform(v2Tgz, ..#IncompatiblePlatform), "Published 2.0.0 for incompatible platform")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName), "Uninstalled 2.0.0 after publishing")
}

/// Publish the packaged module with an explicit platform version tag by calling
/// PublishModule directly, bypassing the normal publish shell command which would
/// tag with the current IRIS platform version.
///
/// The version and manifest come from the module object currently loaded in this
/// namespace, so they match whichever fixture LoadAndPackage was given.
Method PublishWithPlatform(
    tgzPath As %String,
    platformVersion As %String) As %Status
{
    set sc = $$$OK
    try {
        set module = ##class(%IPM.Storage.Module).NameOpen(..#ModuleName,, .sc)
        $$$ThrowOnError(sc)

        set orasDef = ##class(%IPM.Repo.Oras.Definition).%New()
        set orasDef.URL = ..#OrasURL
        set publishSvc = orasDef.GetPublishService()

        set modInfo = ##class(%IPM.Repo.Remote.ModuleInfo).%New()
        set modInfo.Name = ..#ModuleName
        set modInfo.VersionString = module.VersionString
        set modInfo.Deployed = 1
        set modInfo.PlatformVersion = platformVersion

        set payloadStream = ##class(%Stream.FileBinary).%New()
        set payloadStream.Filename = tgzPath _ ".tgz"
        do modInfo.Payload.CopyFrom(payloadStream)

        // Export the real manifest, exactly as the publish command does, so it carries
        // the Deployed flag and SystemRequirements that MakeDeployed stamped
        set manifestStream = ##class(%Stream.GlobalCharacter).%New()
        $$$ThrowOnError(module.XMLExportToStream(manifestStream))
        set modInfo.Manifest = manifestStream

        set sc = publishSvc.PublishModule(modInfo)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Returns true if the named module appears in repo -list-modules for oras.
/// Queries the search criteria API directly rather than parsing terminal output.
ClassMethod ModuleVisibleInList(moduleName As %String) As %Boolean
{
    set criteria = ##class(%IPM.Repo.SearchCriteria).%New()
    set criteria.Name = $$$lcase(moduleName)
    set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(criteria, .results)
    if $$$ISERR(sc) || '$isobject(results) {
        return 0
    }
    return results.Count() > 0
}

/// Version of the named module as currently installed, or "" if it is not installed.
ClassMethod InstalledVersion(moduleName As %String) As %String
{
    set module = ##class(%IPM.Storage.Module).NameOpen(moduleName,, .sc)
    if $$$ISERR(sc) || '$isobject(module) {
        return ""
    }
    return module.VersionString
}

ClassMethod DeleteTgz(tgzPath As %String)
{
    if ##class(%File).Exists(tgzPath _ ".tgz") {
        do ##class(%File).Delete(tgzPath _ ".tgz")
    }
}

}
