Include %IPM.Common

/// Integration tests for ORAS repos configured with a Docker Content Trust server (repo -trust-server).
/// Modules are published with the ordinary publish command and signed afterwards with the notary CLI,
/// as an external promotion process would. Needs the oras and notary services of docker-compose.yml
/// and the notary CLI in the IRIS container.
/// <p>
/// Each test publishes to its own registry namespace below one chosen per run, or below auth-test/ for a registry
/// that requires credentials. The notary service keeps trust data for as long as it runs and IPM pins the root key of
/// each repository it has verified. Reusing a repository name across runs would therefore meet the signing keys of an
/// earlier run.
/// <p>
/// Without notary or the trust server the tests are skipped, e.g. on arm64 hosts where the image has no notary.
/// With the environment variable IPM_REQUIRE_CONTENT_TRUST set, as in CI, they fail instead.
Class Test.PM.Integration.OrasContentTrust Extends Test.PM.Integration.Base
{

Parameter OrasURL = "http://oras:5000";

/// Registry host as it appears in OCI references and Docker Content Trust repository names.
Parameter Registry = "oras:5000";

Parameter TrustServerURL = "https://notary:4443";

/// A port on the notary host where nothing listens, standing in for a trust server that is down.
Parameter DownTrustServerURL = "https://notary:4444";

Parameter FixtureRoot = "oras-content-trust";

/// Registry namespace this run publishes under.
Property RunNamespace As %String;

/// Registry namespace of the current test, below RunNamespace. Not named Test..., since %UnitTest
/// would run the property's generated methods as tests.
Property CaseNamespace As %String;

/// Key directory of the external signer.
Property SignerDirectory As %String;

/// Why the tests cannot run here, or "" when they can.
Property Unavailable As %String;

Property SavedNotaryExecutable As %String;

Method OnBeforeAllTests() As %Status
{
    set ..RunNamespace = "content-trust-" _ $translate($zdatetime($horolog, 8), ": ") _ "-" _ $job
    set ..SignerDirectory = ##class(%IPM.Utils.File).CreateTempDirectory()
    set ..SavedNotaryExecutable = ##class(%IPM.Repo.UniversalSettings).GetValue(##class(%IPM.Repo.UniversalSettings).#NotaryExecutable)
    set out = ##class(%Stream.TmpCharacter).%New()
    set sc = ##class(%IPM.Utils.Module).RunCommand(..SignerDirectory, $listbuild(##class(%IPM.Repo.Oras.ContentTrust).NotaryExecutable(), "version"), .out, .out)
    if $$$ISERR(sc) {
        set ..Unavailable = "The notary CLI is not available: " _ $system.Status.GetErrorText(sc)
    } elseif '..TrustServerHealthy() {
        set ..Unavailable = "Trust server " _ ..#TrustServerURL _ " is not reachable"
    }
    return $$$OK
}

Method OnBeforeOneTest(testName As %String) As %Status
{
    set ..CaseNamespace = ..RunNamespace _ "/" _ $zconvert(testName, "L")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"), "Deleted repos")
    do ..ConfigureTrustedRepo(..CaseNamespace)
    return $$$OK
}

/// Removes what the test installed and published. Other ORAS tests search the whole registry,
/// so a package left in this test's namespace would show up in them.
Method OnAfterOneTest(testName As %String) As %Status
{
    do ##class(%IPM.Repo.UniversalSettings).SetValue(##class(%IPM.Repo.UniversalSettings).#NotaryExecutable, ..SavedNotaryExecutable)
    for module = "oras-dep-consumer-name", "default-name", "trust-parent", "trust-child", "trust-app", "trust-alias", "oras-version-with-build", "platform-filter-test", "oras-auth" {
        do ##class(%IPM.Main).Shell("uninstall " _ module)
    }
    if ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists("trusted") {
        for module = "trust-parent", "trust-child", "trust-app", "trust-alias", "oras-version-with-build", "platform-filter-test", "oras-auth", "external-name" {
            if ..PublishedTags(..CaseNamespace _ "/" _ module) '= "" {
                do $$$AssertStatusOK(##class(%IPM.Main).Shell("unpublish trusted/" _ module _ " all -force"), "Unpublished " _ module)
            }
        }
    }
    return $$$OK
}

/// Removes the trust data pinned for this run's repositories and for the stand-in trust servers.
Method OnAfterAllTests() As %Status
{
    do ##class(%IPM.Main).Shell("repo -delete-all")
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(..SignerDirectory)
    for prefix = ..#Registry _ "/" _ ..RunNamespace, ..#Registry _ "/auth-test/" _ ..RunNamespace, "127.0.0.1:18475/" _ ..RunNamespace {
        do ..RemovePinDirectories(##class(%IPM.Repo.Oras.ContentTrust).TrustDirectory(..#TrustServerURL), prefix)
    }
    for server = ..#DownTrustServerURL, "https://127.0.0.1:18472", "https://127.0.0.1:18473" {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(##class(%IPM.Repo.Oras.ContentTrust).TrustDirectory(server))
    }
    return $$$OK
}

// ===== Configuration =====

/// The trust server is stored, read back, passed to the package service, kept by the lock file and by the deep clone
/// repo -copy-from makes, and can be cleared. Records saved before the setting existed read as unprotected.
Method TestRepoConfiguration()
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -trust-server HTTPS://Notary:4443/"), "Set the trust server in another form")
    set repo = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted")
    do $$$AssertEquals(repo.TrustServer, ..#TrustServerURL, "The trust server is stored canonically")
    do $$$AssertEquals(repo.GetPackageService().TrustServer, ..#TrustServerURL, "The package service uses the trust server")
    do $$$AssertEquals(repo.%ConstructClone(1).TrustServer, ..#TrustServerURL, "repo -copy-from's deep clone keeps the trust server")
    do $$$AssertStatusOK(repo.%JSONExportToString(.lockEntry, "LockFileMapping"))
    do $$$AssertTrue(lockEntry [ """trustServer"":""https://notary:4443""", "Lock file entry has the trust server: " _ lockEntry)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -publish 1"), "Reconfigured without -trust-server")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").TrustServer, ..#TrustServerURL, "Other options keep the trust server")

    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    do ##class(%IPM.Main).Shell("repo -list")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .lines)
    do $$$AssertTrue(..FindStringInMultiDimArray("Trust server:", .lines), "repo -list shows the trust server")

    for refused = "http://notary:4443", "ftp://notary:4443" {
        set sc = ##class(%IPM.Main).Shell("repo -o -name trusted -trust-server " _ refused)
        do $$$AssertStatusNotOK(sc, "A trust server that is not https is refused: " _ refused)
        do $$$AssertTrue($system.Status.GetErrorText(sc) [ "must be an https:// URL", $system.Status.GetErrorText(sc))
        do $$$AssertEquals(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").TrustServer, ..#TrustServerURL, "The refused value was not saved")
    }

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -trust-server """""), "Cleared the trust server")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").TrustServer, "", "The trust server is cleared")

    // Other repository types do not check signatures, so they refuse the setting rather than ignore it
    set sc = ##class(%IPM.Main).Shell("repo -fs -name untrusted-fs -path " _ ..FixtureDir("trust-app-1.0.0") _ " -trust-server " _ ..#TrustServerURL)
    do $$$AssertStatusNotOK(sc, "A filesystem repo refuses -trust-server")
    do $$$AssertNotTrue(##class(%IPM.Repo.Definition).ServerDefinitionKeyExists("untrusted-fs"), "The refused repo was not created")

    // config delete restores finding notary on the PATH, not the first path ever set
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("config set NotaryExecutable /nonexistent/notary"))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("config delete NotaryExecutable"))
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).NotaryExecutable(), "notary", "config delete resets the verifier path")

    // A definition saved by an earlier version has no slot for the trust server
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -trust-server " _ ..#TrustServerURL))
    kill repo
    set id = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").%Id()
    set node = $name(^IPM.Repo.DefinitionD(id, "OrasRepoDefinition"))
    do $$$AssertEquals($listget(@node, 7), ..#TrustServerURL, "The trust server is stored in the seventh slot")
    set @node = $list(@node, 1, 6)
    set old = ##class(%IPM.Repo.Oras.Definition).%OpenId(id, 0)
    do $$$AssertStatusOK(old.%Reload(), "Reread the definition from storage")
    do $$$AssertEquals(old.TrustServer, "", "An earlier record reads with no trust server")
    do $$$AssertEquals(old.GetPackageService().TrustServer, "", "An earlier record gives an unprotected package service")
}

// ===== Signed and unsigned packages =====

/// A package published with the ordinary publish command is refused until it is signed outside IPM, then installs.
Method TestSignedInstall()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Publish("trust-app-2.0.0", "trust-app")

    set sc = ..Run("install trusted/trust-app 1.0.0", .lines)
    do ..AssertRefused(sc, .lines, "no signature for them: 1.0.0")
    do ..AssertNotInstalled("trust-app")
    set reference = ##class(%IPM.Storage.ModuleInfo).%New()
    set reference.Name = "trust-app"
    set reference.VersionString = "1.0.0"
    do $$$AssertNotTrue(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").GetPackageService().HasModule(reference), "HasModule ignores the unsigned version")

    // The same manifest signed for another repository does not count for this one
    set manifest = {}.%FromJSON(..ReadManifest(..#Registry, ..CaseNamespace _ "/trust-app", "1.0.0"))
    set otherGUN = ..GUN("trust-app-mirror")
    do ..InitTrust(otherGUN)
    do ..Notary(..SignerDirectory, ["addhash", (otherGUN), "1.0.0", (manifest.size), "--sha256", ($piece(manifest.digest, ":", 2)), "-p"])
    set sc = ..Run("install trusted/trust-app 1.0.0", .lines)
    do ..AssertRefused(sc, .lines, "no signature for them: 1.0.0")
    do ..AssertNotInstalled("trust-app")

    do ..Sign("trust-app", "1.0.0")
    do $$$AssertTrue(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").GetPackageService().HasModule(reference), "HasModule finds the signed version")
    do $$$AssertStatusOK(..Run("install trusted/trust-app", .lines), "Installed the newest signed version")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")
    do ..AssertLatestHistory("install", "trust-app", 1)

    // A value stored without NormalizeTrustServer, e.g. through the object API, fails every check
    set repo = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted")
    set repo.TrustServer = "http://notary:4443"
    do $$$AssertStatusOK(repo.%Save(), "Stored an http trust server")
    set sc = ..Run("install trusted/trust-app 1.0.0 -force", .lines)
    do ..AssertRefused(sc, .lines, "must be an https:// URL")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -trust-server " _ ..#TrustServerURL), "Restored the https trust server")

    // Without the setting, the same repo installs unsigned packages again
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -trust-server """""), "Turned verification off")
    do $$$AssertStatusOK(..Run("install trusted/trust-app 2.0.0", .lines), "Installed the unsigned package")
    do ..AssertRevision("2.0.0", "2.0.0")
}

/// As docker pull does, a signature in targets/releases takes priority over one in targets,
/// and a signature only in another delegation is not trusted.
Method TestTrustedRoles()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    do ..Publish("trust-app-1.0.0-rev2", "trust-app")
    do ..AddDelegation("trust-app", "targets/releases")
    do ..Sign("trust-app", "1.0.0", "targets/releases")
    do ..Publish("trust-app-2.0.0", "trust-app")
    do ..AddDelegation("trust-app", "targets/other")
    do ..Sign("trust-app", "2.0.0", "targets/other")

    do $$$AssertStatusOK(..Run("install trusted/trust-app", .lines), "Installed the newest trusted version")
    do ..AssertRevision("1.0.0", "1.0.0 revision 2")
    set sc = ..Run("update trust-app 2.0.0", .lines)
    do ..AssertRefused(sc, .lines, "no signature for them: 2.0.0")
    do ..AssertRevision("1.0.0", "1.0.0 revision 2")
}

Method TestUnrelatedDelegatedTargetWithSpace()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    do ..AddDelegation("trust-app", "targets/releases")
    set notes = "Release notes"
    set hash = $zconvert(##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHAHash(256, notes)), "L")
    do ..Notary(..SignerDirectory, ["addhash", (..GUN("trust-app")), "release notes", ($length(notes)), "--sha256", (hash), "-r", "targets/releases", "-p"])

    do $$$AssertStatusOK(..Run("install trusted/trust-app", .lines), "Installed the signed package with an unrelated delegated target")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")
    set repository = ..GUN("trust-app")
    set pins = ##class(%IPM.Repo.Oras.ContentTrust).PinDirectory(..#TrustServerURL, repository)
    do $$$AssertTrue(##class(%File).Exists(pins _ "tuf/" _ repository _ "/metadata/targets/releases.json"), "The verifier cached the delegation")
}

/// The signed manifest is what installs, even after the tag moves to another manifest.
/// When the registry no longer has the signed manifest, the install is refused.
Method TestSignedArtifactIsTheOneInstalled()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    set signed = ..Sign("trust-app", "1.0.0")
    do ..Publish("trust-app-1.0.0-rev2", "trust-app")
    do $$$AssertNotEquals(..ManifestDigest("trust-app", "1.0.0"), signed, "The tag now names an unsigned manifest")

    do $$$AssertStatusOK(..Run("install trusted/trust-app 1.0.0", .lines), "Installed 1.0.0")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")

    // A version whose signed manifest is gone is not offered, rather than installing what the tag names now
    do ..DeleteManifest("trust-app", signed)
    set sc = ..Run("install trusted/trust-app 1.0.0 -force", .lines)
    do ..AssertRefused(sc, .lines, "trust-app 1.0.0 not found")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")
    do ..AssertLatestHistory("install", "trust-app", 0)
}

/// Within one shell command the signed listing is read once. A tag signed again between dependency planning
/// and download does not change the package the command loads. The next command sees the new signature.
Method TestSnapshotWithinCommand()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    set first = ..Sign("trust-app", "1.0.0")
    do ..Publish("trust-app-1.0.0-rev2", "trust-app")
    set reference = ##class(%IPM.Storage.ModuleInfo).%New()
    set reference.Name = "trust-app"
    set reference.VersionString = "1.0.0"

    // The lookup state a shell command starts with
    new $$$RepoLookupState
    set $$$RepoLookupState = ""
    set service = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").GetPackageService()
    do $$$AssertTrue($isobject(service.GetModuleManifest(reference)), "Read the manifest for dependency planning")
    set second = ..Sign("trust-app", "1.0.0")
    do $$$AssertNotEquals(second, first, "The tag is now signed for the second revision")
    do $$$AssertEquals(..StreamDigest(service.GetModule(reference)), ..PackageDigest("trust-app", first), "The command downloads the package it planned with")

    kill $$$RepoLookupState
    set $$$RepoLookupState = ""
    do $$$AssertEquals(..StreamDigest(service.GetModule(reference)), ..PackageDigest("trust-app", second), "The next command downloads the newly signed package")
}

/// Bytes that do not match what was signed are refused before anything is unpacked.
Method TestMismatchedContentRefused()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")

    // The signature names the right digest with the wrong size
    do ..Sign("trust-app", "1.0.0", , , 1)
    set sc = ..Run("install trusted/trust-app 1.0.0", .lines)
    do ..AssertRefused(sc, .lines, "does not match its signed digest and size")
    do ..AssertNotInstalled("trust-app")

    // A signed manifest whose package layer is one byte longer than the package
    do ..PushModifiedManifest("trust-app", "1.0.0", "1.0.1", "size")
    do ..Sign("trust-app", "1.0.1")
    set sc = ..Run("install trusted/trust-app 1.0.1", .lines)
    do ..AssertRefused(sc, .lines, "does not match its signed digest and size")
    do ..AssertNotInstalled("trust-app")
    do ..AssertLatestHistory("install", "trust-app", 0)

    // A signed manifest with two package layers does not identify one package
    do ..PushModifiedManifest("trust-app", "1.0.0", "1.0.2", "duplicate")
    do ..Sign("trust-app", "1.0.2")
    set sc = ..Run("install trusted/trust-app 1.0.2", .lines)
    do ..AssertRefused(sc, .lines, "more than one package layer")
    do ..AssertNotInstalled("trust-app")

    // A signed manifest whose package layer is a valid blob that is not an archive reaches extraction and fails there
    do ..PushModifiedManifest("trust-app", "1.0.0", "1.0.4", "config")
    do ..Sign("trust-app", "1.0.4")
    set sc = ..Run("install trusted/trust-app 1.0.4", .lines)
    do $$$AssertStatusNotOK(sc, "A signed package that is not an archive does not install")
    do $$$AssertNotTrue($system.Status.GetErrorText(sc) [ "does not match", "It passed the size and digest check: " _ $system.Status.GetErrorText(sc))
    do ..AssertNotInstalled("trust-app")
    do ..AssertLatestHistory("install", "trust-app", 0)
}

/// The registry's bytes must have the signed digest, not just the signed size. zot cannot serve wrong bytes for a
/// digest, so a stand-in server does.
Method TestWrongBytesRefused()
{
    if '..Available() {
        return
    }
    set port = 18471
    do ..StartStub("serve", port, 60)
    set registry = "http://127.0.0.1:" _ port
    set repository = "127.0.0.1:" _ port _ "/tampered/module"
    // The stand-in serves 64 bytes of "x". The signature is for 64 bytes of "y".
    set signed = "sha256:" _ $zconvert(##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHAHash(256, $translate($justify("", 64), " ", "y"))), "L")
    try {
        do ##class(%IPM.Repo.Oras.PackageService).DownloadVerified("manifest", registry, repository, signed, 64, "", "", "", "", "apiKey")
        do $$$AssertFailure("Accepted a manifest with the wrong digest")
    } catch e {
        set text = $system.Status.GetErrorText(##class(%IPM.Repo.Oras.PackageService).MismatchAsError(e).AsStatus())
        do $$$AssertTrue(text [ ("manifest 127.0.0.1:" _ port _ "/tampered/module@" _ signed _ " from the registry does not match its signed digest and size of 64 bytes"), text)
    }
    set file = ##class(%IPM.Utils.File).CreateTempDirectory() _ "package.tgz"
    try {
        do ##class(%IPM.Repo.Oras.PackageService).DownloadVerified("blob", registry, repository, signed, 64, file, "", "", "", "apiKey")
        do $$$AssertFailure("Accepted a package with the wrong digest")
    } catch e {
        set text = $system.Status.GetErrorText(##class(%IPM.Repo.Oras.PackageService).MismatchAsError(e).AsStatus())
        do $$$AssertTrue(text [ ("blob 127.0.0.1:" _ port _ "/tampered/module@" _ signed _ " from the registry does not match its signed digest and size of 64 bytes"), text)
    }
    do $$$AssertNotTrue(##class(%File).Exists(file), "The refused download was deleted")
}

/// A trust server that answers notary's first request and then stalls fails the check instead of hanging it.
Method TestStalledTrustServerRefused()
{
    if '..Available() {
        return
    }
    if ($system.Version.GetOS() '= "UNIX") {
        do $$$AssertSkipped("The deadline uses the Unix timeout program")
        return
    }
    set port = 18472
    do ..StartStub("stall", port, 60)
    set start = $zhorolog
    try {
        do ##class(%IPM.Repo.Oras.ContentTrust).LookUpSignedTargets("https://127.0.0.1:" _ port, "oras:5000/stalled/module", 3)
        do $$$AssertFailure("A stalled trust server answered")
    } catch e {
        set text = $system.Status.GetErrorText(e.AsStatus())
        do $$$AssertTrue(text [ "did not finish within 3 seconds", text)
    }
    do $$$AssertTrue(($zhorolog - start) < 30, "Gave up after " _ ($zhorolog - start) _ "s")

    // Within one command, the next repository on the stalled server fails without waiting again
    new $$$RepoLookupState
    set $$$RepoLookupState = ""
    set server = "https://127.0.0.1:" _ port
    try {
        do ##class(%IPM.Repo.Oras.ContentTrust).SignedTargets(server, "oras:5000/stalled/first", "stalled-repo", 3)
        do $$$AssertFailure("A stalled trust server answered for the first repository")
    } catch e {
        do $$$AssertTrue($system.Status.GetErrorText(e.AsStatus()) [ "did not finish within 3 seconds")
    }
    set start = $zhorolog
    try {
        do ##class(%IPM.Repo.Oras.ContentTrust).SignedTargets(server, "oras:5000/stalled/second", "stalled-repo", 3)
        do $$$AssertFailure("A stalled trust server answered for the second repository")
    } catch e {
        set text = $system.Status.GetErrorText(e.AsStatus())
        do $$$AssertTrue(text [ ("was not attempted because trust server " _ server _ " did not answer within 3 seconds"), text)
    }
    do $$$AssertTrue(($zhorolog - start) < 2, "The second repository failed after " _ ($zhorolog - start) _ "s")
}

/// A protected repo only downloads and checks the package archive. The ORAS pull of an unprotected repo
/// unpacks a directory layer before IPM checks the package, which shows the check below can see unpacking.
Method TestNothingUnpackedBeforeVerification()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    set marker = "content-trust-marker-" _ $job _ "-" _ $translate($ztimestamp, ",.")
    do $$$AssertEquals(..PushManifestWithDirectoryLayer(..#Registry, ..CaseNamespace _ "/trust-app", "1.0.0", "1.0.3", marker), 201, "Pushed a manifest with a directory layer")
    do ..Sign("trust-app", "1.0.3")

    set sc = ..Run("install trusted/trust-app 1.0.3", .lines)
    do ..AssertRefused(sc, .lines, "does not match its signed digest and size")
    set tempRoot = ##class(%File).ParentDirectoryName(##class(%IPM.Utils.File).CreateTempDirectory())
    do $$$AssertEquals(..FindDirectory(tempRoot, marker), "", "The protected repo unpacked no layer")
    set extracted = ##class(%File).NormalizeDirectory("trust-app/1.0.3", ##class(%IPM.Repo.UniversalSettings).GetModuleRoot())
    do $$$AssertNotTrue(##class(%File).DirectoryExists(extracted), "IPM did not extract the package into " _ extracted)
    do $$$AssertEquals(..FindFile(tempRoot, "trust-app/1.0.3/package.tgz"), "", "The refused package was deleted")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -trust-server """""), "Turned verification off")
    set sc = ..Run("install trusted/trust-app 1.0.3", .lines)
    do $$$AssertStatusNotOK(sc, "The unprotected repo also refuses the package size")
    do $$$AssertNotEquals(..FindDirectory(tempRoot, marker), "", "but only after ORAS unpacked the directory layer")
    do ..AssertNotInstalled("trust-app")
}

/// After IPM has pinned a repository's root key, trust data under another root key is refused, including by
/// reinstall with -force and by a developer-mode install. The installed code stays.
Method TestReplacedRootRefused()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    do $$$AssertStatusOK(..Run("install trusted/trust-app 1.0.0", .lines), "Installed 1.0.0")

    // Someone without the original keys replaces the repository's trust data
    do ..Notary(..SignerDirectory, ["delete", (..GUN("trust-app")), "--remote"])
    do ..Sign("trust-app", "1.0.0", , ..SignerDirectory _ "other-root/")

    set sc = ..Run("install trusted/trust-app 1.0.0 -force", .lines)
    do ..AssertRefused(sc, .lines, "could not rotate trust to a new trusted root")
    set sc = ..Run("install trusted/trust-app 1.0.0 -force -dev", .lines)
    do ..AssertRefused(sc, .lines, "could not rotate trust to a new trusted root")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")
}

/// A trust server that cannot be reached, or a verifier that cannot be run, refuses the install,
/// even when the pinned trust data is valid and a current timestamp lies next to it.
Method TestVerifierUnavailableRefused()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    do $$$AssertStatusOK(..Run("install trusted/trust-app 1.0.0", .lines), "Installed 1.0.0")

    set gunPath = "tuf/" _ ..GUN("trust-app") _ "/"
    set pinned = ##class(%File).NormalizeDirectory(gunPath, ##class(%IPM.Repo.Oras.ContentTrust).PinDirectory(..#TrustServerURL, ..GUN("trust-app")))
    do $$$AssertTrue(##class(%File).Exists(pinned _ "metadata/root.json"), "The check pinned the root")
    do $$$AssertNotTrue(##class(%File).Exists(pinned _ "metadata/timestamp.json"), "The pins have no timestamp")

    // Give the server that is down those pins and a timestamp another check has just downloaded
    set copy = ##class(%File).NormalizeDirectory(gunPath, ##class(%IPM.Repo.Oras.ContentTrust).PinDirectory(..#DownTrustServerURL, ..GUN("trust-app")))
    do $$$AssertTrue(##class(%File).CreateDirectoryChain(copy), "Created " _ copy)
    do $$$AssertTrue(##class(%File).CopyDir(pinned, copy, 1), "Copied the pins to " _ copy)
    set scratch = ##class(%IPM.Utils.File).CreateTempDirectory()
    do ..Notary(scratch, ["list", (..GUN("trust-app"))])
    set fresh = ##class(%File).NormalizeFilename(gunPath _ "metadata/timestamp.json", scratch)
    do $$$AssertTrue(##class(%File).CopyFile(fresh, copy _ "metadata/timestamp.json"), "Placed a current timestamp with the pins")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -trust-server " _ ..#DownTrustServerURL))
    set sc = ..Run("install trusted/trust-app 1.0.0 -force", .lines)
    do ..AssertRefused(sc, .lines, "client is offline")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name trusted -trust-server " _ ..#TrustServerURL))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("config set NotaryExecutable /nonexistent/notary"), "Set the verifier path")
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    do ##class(%IPM.Main).Shell("config list")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .lines)
    do $$$AssertTrue(..FindStringInMultiDimArray("NotaryExecutable: /nonexistent/notary", .lines), "config list shows the verifier path")
    set sc = ..Run("install trusted/trust-app 1.0.0 -force", .lines)
    do ..AssertRefused(sc, .lines, "Unable to run the Docker Content Trust verifier '/nonexistent/notary'")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")
}

/// While a check runs, a current timestamp can appear with the pins, written by another check or any other process.
/// The first check below is held after notary starts, a current timestamp is placed with the pins, and then the check
/// loses the trust server. It refuses rather than use that timestamp. A second check of the same repository waits for
/// the first, then reaches the trust server. The pins keep no timestamp. A notary wrapper holds the first check
/// and takes the trust server away from it through a proxy that refuses connections.
Method TestConcurrentCheckUsesOwnTimestamp()
{
    if '..Available() {
        return
    }
    if ($system.Version.GetOS() '= "UNIX") {
        do $$$AssertSkipped("The notary wrapper is a shell script")
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    set repository = ..GUN("trust-app")
    // Pins the root, as an earlier install would
    do ##class(%IPM.Repo.Oras.ContentTrust).LookUpSignedTargets(..#TrustServerURL, repository)
    set pinned = ##class(%File).NormalizeDirectory("tuf/" _ repository _ "/metadata", ##class(%IPM.Repo.Oras.ContentTrust).PinDirectory(..#TrustServerURL, repository))
    do $$$AssertTrue(##class(%File).Exists(pinned _ "root.json"), "The root is pinned")
    // A current timestamp, as another check would download
    set scratch = ##class(%IPM.Utils.File).CreateTempDirectory()
    do ..Notary(scratch, ["list", (repository)])
    set fresh = ##class(%File).NormalizeFilename("tuf/" _ repository _ "/metadata/timestamp.json", scratch)

    set dir = ##class(%IPM.Utils.File).CreateTempDirectory()
    do ..WriteNotaryWrapper(dir, ##class(%IPM.Repo.Oras.ContentTrust).NotaryExecutable())
    do ##class(%IPM.Repo.UniversalSettings).SetValue(##class(%IPM.Repo.UniversalSettings).#NotaryExecutable, dir _ "notary.sh")
    set key = $job
    kill ^IPM.Test.ContentTrust(key)
    try {
        job ##class(Test.PM.Integration.OrasContentTrust).CheckInBackground(..#TrustServerURL, repository, key)
        for i = 1:1:150 {
            quit:##class(%File).DirectoryExists(dir _ "first")
            hang 0.2
        }
        do $$$AssertTrue(##class(%File).DirectoryExists(dir _ "first"), "The first check's notary is waiting")
        do $$$AssertTrue(##class(%File).CopyFile(fresh, pinned _ "timestamp.json"), "Placed a current timestamp with the pins")
        job ##class(Test.PM.Integration.OrasContentTrust).RemoveLater(dir _ "hold", 3)
        set start = $zhorolog
        set second = ##class(%IPM.Repo.Oras.ContentTrust).LookUpSignedTargets(..#TrustServerURL, repository)
        set waited = $zhorolog - start
        do $$$AssertTrue(second.%IsDefined("1.0.0"), "The second check reached the trust server: " _ second.%ToJSON())
        do $$$AssertTrue(waited >= 2, "The second check waited for the first, " _ waited _ "s")
        for i = 1:1:300 {
            quit:$data(^IPM.Test.ContentTrust(key))
            hang 0.2
        }
        set first = $get(^IPM.Test.ContentTrust(key))
        do $$$AssertTrue($piece(first, " ") = "refused", "The first check refused: " _ first)
        do $$$AssertTrue(first [ "client is offline", "It could not reach the trust server: " _ first)
        do $$$AssertNotTrue(##class(%File).Exists(pinned _ "timestamp.json"), "The pins have no timestamp")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(), "Concurrent checks")
    }
    kill ^IPM.Test.ContentTrust(key)
}

/// An install looks up its dependencies inside a transaction. A check made there must not hold back another process's
/// check of the same repository until the transaction ends.
Method TestCheckInTransactionReleasesRepository()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    set repository = ..GUN("trust-app")
    set key = $job
    kill ^IPM.Test.ContentTrust(key)
    set level = $tlevel
    tstart
    try {
        set mine = ##class(%IPM.Repo.Oras.ContentTrust).LookUpSignedTargets(..#TrustServerURL, repository)
        do $$$AssertTrue(mine.%IsDefined("1.0.0"), "The check in the transaction verified: " _ mine.%ToJSON())
        job ##class(Test.PM.Integration.OrasContentTrust).CheckInBackground(..#TrustServerURL, repository, key)
        // Well below the 150 seconds another check would wait for the lock
        for i = 1:1:300 {
            quit:$data(^IPM.Test.ContentTrust(key))
            hang 0.2
        }
        set other = $get(^IPM.Test.ContentTrust(key))
        do $$$AssertTrue($piece(other, " ") = "accepted", "Another process's check finished while the transaction was open: " _ other)
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(), "Check in a transaction")
    }
    while ($tlevel > level) {
        trollback 1
    }
    kill ^IPM.Test.ContentTrust(key)
}

// ===== Every retrieval through the repo =====

/// A dependency fetched from a protected repo must be signed too, including for a local developer load.
Method TestProtectedDependency()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-child", "trust-child", 1)
    do ..Publish("trust-parent", "trust-parent")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall trust-child"), "Uninstalled the dependency")
    do ..Publish("trust-child-2.0.0", "trust-child")
    do ..Sign("trust-parent", "1.0.0")
    // Signed but outside the parent's ^1.0.0 range
    do ..Sign("trust-child", "2.0.0")

    set sc = ..Run("install trusted/trust-parent 1.0.0", .lines)
    do ..AssertRefused(sc, .lines, "Could not find satisfactory version of trust-child", "no signature for them: 1.0.0")
    do ..AssertNotInstalled("trust-parent")
    do ..AssertNotInstalled("trust-child")

    set sc = ..Run("load " _ ..FixtureDir("trust-parent") _ " -dev", .lines)
    do ..AssertRefused(sc, .lines, "Could not find satisfactory version of trust-child")
    do ..AssertNotInstalled("trust-child")
    do ##class(%IPM.Main).Shell("uninstall trust-parent")

    do ..Sign("trust-child", "1.0.0")
    do $$$AssertStatusOK(..Run("install trusted/trust-parent 1.0.0", .lines), "Installed the parent and its signed dependency")
    do $$$AssertEquals(..InstalledVersion("trust-child"), "1.0.0")
    do $$$AssertEquals($classmethod("TrustParent.Hello", "Hello"), "child via parent")

    // Local code is not checked, so a developer load of the unsigned parent works once its dependency is signed
    do ##class(%IPM.Main).Shell("uninstall trust-parent")
    do ##class(%IPM.Main).Shell("uninstall trust-child")
    do $$$AssertStatusOK(..Run("load " _ ..FixtureDir("trust-parent") _ " -dev", .lines), "Loaded the local parent in developer mode")
    do $$$AssertEquals(..InstalledVersion("trust-child"), "1.0.0")
    do $$$AssertEquals($classmethod("TrustParent.Hello", "Hello"), "child via parent")
}

/// Reusing a locally installed dependency fetches no package from the protected repository.
Method TestInstalledDependency()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-child", "trust-child", 1)
    do ..Publish("trust-parent", "trust-parent")
    do ..Sign("trust-parent", "1.0.0")
    do $$$AssertStatusOK(..Run("install trusted/trust-parent", .lines))
    do $$$AssertEquals(..InstalledVersion("trust-child"), "1.0.0")
    do $$$AssertEquals($classmethod("TrustParent.Hello", "Hello"), "child via parent")
}

/// Update offers only signed versions. Reinstall checks the signature again.
Method TestUpdateAndReinstall()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Publish("trust-app-2.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    do $$$AssertStatusOK(..Run("install trusted/trust-app 1.0.0", .lines), "Installed 1.0.0")

    set sc = ..Run("update trust-app 2.0.0", .lines)
    do ..AssertRefused(sc, .lines, "no signature for them: 2.0.0")
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")

    do ..Sign("trust-app", "2.0.0")
    do $$$AssertStatusOK(..Run("update trust-app", .lines), "Updated to the signed 2.0.0")
    do ..AssertRevision("2.0.0", "2.0.0")
    do ..AssertLatestHistory("update", "trust-app", 1)

    do $$$AssertStatusOK(..Run("install trusted/trust-app 2.0.0 -force", .lines), "Reinstalled the signed 2.0.0")
    do ..AssertRevision("2.0.0", "2.0.0")

    do $$$AssertStatusOK(..Run("reinstall trust-app", .lines), "reinstall fetched the signed 2.0.0 again")
    do ..AssertRevision("2.0.0", "2.0.0")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("config set NotaryExecutable /nonexistent/notary"))
    set sc = ..Run("reinstall trust-app", .lines)
    do ..AssertRefused(sc, .lines, "Unable to run the Docker Content Trust verifier")
    do ..AssertRevision("2.0.0", "2.0.0")
}

// ===== Existing selection, naming and credentials =====

/// A named install also works on registries that publish their catalog only under the namespace.
Method TestNamespacedCatalog()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    set service = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").GetPackageService()
    do $$$AssertEquals(..Offered(service, ""), 1, "The signed module appears in the global catalog")

    set registry = "127.0.0.1:18475"
    do ..StartStub("scoped", 18475, 120, ..CaseNamespace)
    set command = "repo -o -name scoped -url http://" _ registry _ " -namespace " _ ..CaseNamespace
    do $$$AssertStatusOK(..Run(command, .lines))
    set service = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("scoped").GetPackageService()
    set unsignedCount = ..Offered(service, "")

    set gun = registry _ "/" _ ..CaseNamespace _ "/trust-app"
    set descriptor = {}.%FromJSON(..ReadManifest(..#Registry, ..CaseNamespace _ "/trust-app", "1.0.0"))
    do ..InitTrust(gun)
    do ..Notary(..SignerDirectory, ["addhash", (gun), "1.0.0", (descriptor.size), "--sha256", ($piece(descriptor.digest, ":", 2)), "-p"])
    do $$$AssertStatusOK(..Run("repo -o -name scoped -trust-server " _ ..#TrustServerURL, .lines))
    set service = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("scoped").GetPackageService()
    do $$$AssertEquals(..Offered(service, ""), unsignedCount, "Signed and unsigned enumeration agree in the scoped catalog")
    do $$$AssertStatusOK(..Run("install scoped/trust-app 1.0.0", .lines))
    do ..AssertRevision("1.0.0", "1.0.0 revision 1")
}

/// A trust requirement preserves ORAS version selection for prereleases and snapshots which are all signed.
Method TestPrereleaseAndSnapshotSelection()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app", 1)
    do ..Sign("trust-app", "1.0.0")
    for version = "2.0.0-beta.1", "3.0.0+snapshot" {
        do $$$AssertStatusOK(..Run("modver trust-app " _ version _ " -force", .lines))
        do $$$AssertStatusOK(..Run("publish trust-app -r trusted -only", .lines))
        do ..Sign("trust-app", $$$Semver2Tag(version))
        do $$$AssertStatusOK(..Run("uninstall trust-app", .lines))
        do $$$AssertStatusOK(..Run("repo -o -name trusted -prereleases 0 -snapshots 0 -trust-server """"", .lines))
        do $$$AssertStatusOK(..Run("install trusted/trust-app", .lines))
        set selected = ..InstalledVersion("trust-app")
        do $$$AssertStatusOK(..Run("uninstall trust-app", .lines))
        do $$$AssertStatusOK(..Run("repo -o -name trusted -trust-server " _ ..#TrustServerURL, .lines))
        do $$$AssertStatusOK(..Run("install trusted/trust-app", .lines))
        do $$$AssertEquals(..InstalledVersion("trust-app"), selected, "Protected lookup selects the same version as ordinary ORAS with " _ version)
    }
}

/// An explicit build must itself be signed, a request without a build selects among signed versions as usual,
/// and a platform-specific artifact for another platform stays unavailable even when it is signed.
Method TestBuildAndPlatformSelection()
{
    if '..Available() {
        return
    }
    set module = "oras-version-with-build"
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..GetModuleDir(module)), "Loaded " _ module)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish " _ module _ " -r trusted -only"), "Published the build")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("modver " _ module _ " 1.0.0-prerelease -force"))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish " _ module _ " -r trusted -only"), "Published the version without a build")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ module))
    do ..Sign(module, "1.0.0-prerelease")

    set sc = ..Run("install trusted/" _ module _ " 1.0.0-prerelease+build", .lines)
    do ..AssertRefused(sc, .lines, "no signature for them: 1.0.0-prerelease+build")
    do ..AssertNotInstalled(module)
    do $$$AssertStatusOK(..Run("install trusted/" _ module _ " 1.0.0-prerelease", .lines), "Installed the signed version")
    do $$$AssertEquals(..InstalledVersion(module), "1.0.0-prerelease")

    // platform-filter-test 1.0.0 for this platform and 2.0.0 for another, both signed
    set platformModule = "platform-filter-test"
    set platformDir = ..GetModuleDir("platform-filter", "test", "v1")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -nodev " _ platformDir), "Loaded " _ platformModule)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("package " _ platformModule _ " -only -path " _ ##class(%IPM.Utils.File).CreateTempDirectory() _ platformModule), "Packaged for this platform")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish " _ platformModule _ " -r trusted -only"), "Published for this platform")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ platformModule))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -nodev " _ ..GetModuleDir("platform-filter", "test", "v2")))
    do $$$AssertStatusOK(..PublishForPlatform(platformModule, "9999.1"), "Published 2.0.0 for another platform")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ platformModule))
    do ..Sign(platformModule, "1.0.0" _ $$$OrasTagPlatformSeparator _ $$$CurrentPlatformVersion)
    do ..Sign(platformModule, "2.0.0" _ $$$OrasTagPlatformSeparator _ "9999.1")

    do $$$AssertStatusOK(..Run("install trusted/" _ platformModule, .lines), "Installed the version for this platform")
    do $$$AssertEquals(..InstalledVersion(platformModule), "1.0.0")
    do $$$AssertEquals($classmethod("PlatformFilterTest.Public", "Version"), "1.0.0")
    set sc = ..Run("update " _ platformModule _ " 2.0.0", .lines)
    do ..AssertRefused(sc, .lines, "is not available for platform version", "9999.1")
    do $$$AssertEquals(..InstalledVersion(platformModule), "1.0.0")
}

/// A dependency published under its external name is verified under that registry name and installs under its own name.
Method TestExternalNameDependency()
{
    if '..Available() {
        return
    }
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..GetModuleDir("publish-external-name", "0.0.1")), "Loaded the dependency")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish default-name -r trusted -only -use-external-name"), "Published it under its external name")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall default-name"))

    set consumer = ..GetModuleDir("oras-dep-name", "consumer-name")
    set sc = ..Run("load " _ consumer, .lines)
    do ..AssertRefused(sc, .lines, "Could not find satisfactory version of default-name")
    do ..AssertNotInstalled("default-name")
    do ##class(%IPM.Main).Shell("uninstall oras-dep-consumer-name")

    do ..Sign("external-name", "0.0.1")
    do $$$AssertStatusOK(..Run("load " _ consumer, .lines), "Loaded the consumer with its signed dependency")
    do $$$AssertEquals(..InstalledVersion("default-name"), "0.0.1")
}

/// trust-alias 1.0.0 has two signed artifacts with different external names: one for platform 1000.1, which the
/// listing names first, and one for this platform. The repo offers the version under this platform's external name
/// and installs this platform's artifact by it, and does not offer it under the other platform's external name.
Method TestExternalNameOfInstalledPlatform()
{
    if '..Available() {
        return
    }
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..FixtureDir("trust-alias-older")), "Loaded the other platform's variant")
    do $$$AssertStatusOK(..PublishForPlatform("trust-alias", "1000.1"), "Published it for platform 1000.1")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall trust-alias"))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..FixtureDir("trust-alias-current")), "Loaded this platform's variant")
    do $$$AssertStatusOK(..PublishForPlatform("trust-alias", $$$CurrentPlatformVersion), "Published it for this platform")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall trust-alias"))
    do ..Sign("trust-alias", "1.0.0" _ $$$OrasTagPlatformSeparator _ "1000.1")
    do ..Sign("trust-alias", "1.0.0" _ $$$OrasTagPlatformSeparator _ $$$CurrentPlatformVersion)

    set signedTags = ##class(%IPM.Repo.Oras.ContentTrust).LookUpSignedTargets(..#TrustServerURL, ..GUN("trust-alias"))
    do $$$AssertEquals($piece(##class(%IPM.Repo.Oras.PackageService).SortTags(signedTags.%ToJSON()), ", "), "1.0.0" _ $$$OrasTagPlatformSeparator _ "1000.1", "The other platform's artifact is listed first")

    set service = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").GetPackageService()
    do $$$AssertEquals(..Offered(service, "trust-alias"), 1, "Offered under its name")
    do $$$AssertEquals(..Offered(service, "trust-alias-current"), 1, "Offered under this platform's external name")
    do $$$AssertEquals(..Offered(service, "trust-alias-older"), 0, "Not offered under the other platform's external name")

    do $$$AssertStatusOK(..Run("install trusted/trust-alias-current", .lines), "Installed by this platform's external name")
    do $$$AssertEquals(..InstalledVersion("trust-alias"), "1.0.0")
    do $$$AssertEquals($classmethod("TrustAlias.Hello", "Variant"), "current", "This platform's artifact is installed")

    // 1.0.1: this platform's signed artifact says it is not deployed, so install would look for an untagged artifact
    do ..PushModifiedManifest("trust-alias", "1.0.0" _ $$$OrasTagPlatformSeparator _ "1000.1", "1.0.1" _ $$$OrasTagPlatformSeparator _ "1000.1", "copy")
    do ..PushModifiedManifest("trust-alias", "1.0.0" _ $$$OrasTagPlatformSeparator _ $$$CurrentPlatformVersion, "1.0.1" _ $$$OrasTagPlatformSeparator _ $$$CurrentPlatformVersion, "undeploy")
    do ..Sign("trust-alias", "1.0.1" _ $$$OrasTagPlatformSeparator _ "1000.1")
    do ..Sign("trust-alias", "1.0.1" _ $$$OrasTagPlatformSeparator _ $$$CurrentPlatformVersion)
    set sc = ..Run("install trusted/trust-alias 1.0.1", .lines)
    do ..AssertRefused(sc, .lines, "No trust data for '" _ ..GUN("trust-alias") _ ":1.0.1'")
    do $$$AssertEquals(..InstalledVersion("trust-alias"), "1.0.0", "1.0.0 stays installed")
}

/// When the newest signed version fails its checks, the repo does not fall back to an older signed version, so the
/// registry cannot steer an install to it by altering or withholding the newer one.
Method TestNewerSignedVersionNotBypassed()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Publish("trust-app-2.0.0", "trust-app")
    do ..Sign("trust-app", "1.0.0")
    // The signature for 2.0.0 names a size the registry's manifest does not have
    set signed = ..Sign("trust-app", "2.0.0", , , 1)
    set sc = ..Run("install trusted/trust-app", .lines)
    do ..AssertRefused(sc, .lines, "does not match its signed digest and size")
    do ..AssertNotInstalled("trust-app")

    // Signed correctly, then withheld by the registry
    do ..Sign("trust-app", "2.0.0")
    do ..DeleteManifest("trust-app", signed)
    set sc = ..Run("install trusted/trust-app", .lines)
    do ..AssertRefused(sc, .lines, "does not have the manifest signed for tag 2.0.0")
    do ..AssertNotInstalled("trust-app")

    // The signature left for the withheld manifest does not affect the repo's other packages
    do ..Publish("trust-child", "trust-child")
    do ..Sign("trust-child", "1.0.0")
    do $$$AssertStatusOK(..Run("install trusted/trust-child", .lines), "Installed another package of the repo")
    do $$$AssertEquals(..InstalledVersion("trust-child"), "1.0.0")
}

/// trust-alias 1.0.0 is built for this platform and for platform 1000.1, which the listing names first. The build for
/// 1000.1 does not match its signature, but this platform's build still installs. 2.0.0, built only for 1000.1 and
/// also broken, does not hide 1.0.0, since this platform could not install it anyway.
Method TestOtherPlatformBuildDoesNotHideThisPlatform()
{
    if '..Available() {
        return
    }
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..FixtureDir("trust-alias-current")), "Loaded the module")
    do $$$AssertStatusOK(..PublishForPlatform("trust-alias", $$$CurrentPlatformVersion), "Published 1.0.0 for this platform")
    do $$$AssertStatusOK(..PublishForPlatform("trust-alias", "1000.1"), "Published 1.0.0 for platform 1000.1")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("modver trust-alias 2.0.0 -force"))
    do $$$AssertStatusOK(..PublishForPlatform("trust-alias", "1000.1"), "Published 2.0.0 for platform 1000.1")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall trust-alias"))
    do ..Sign("trust-alias", "1.0.0" _ $$$OrasTagPlatformSeparator _ $$$CurrentPlatformVersion)
    // The other platform's signatures name a size their manifests do not have
    do ..Sign("trust-alias", "1.0.0" _ $$$OrasTagPlatformSeparator _ "1000.1", , , 1)
    do ..Sign("trust-alias", "2.0.0" _ $$$OrasTagPlatformSeparator _ "1000.1", , , 1)

    do $$$AssertStatusOK(..Run("install trusted/trust-alias", .lines), "Installed this platform's build")
    do $$$AssertEquals(..InstalledVersion("trust-alias"), "1.0.0")
    do $$$AssertEquals($classmethod("TrustAlias.Hello", "Variant"), "current")
}

/// 2.0.1 has an untagged artifact signed as deployed and this platform's artifact signed as not deployed. Its signed
/// artifacts disagree, which ends the list, so the older signed 1.0.0 is not installed in its place.
Method TestDeployedDisagreementEndsList()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-app-1.0.0", "trust-app")
    do ..Publish("trust-app-2.0.0", "trust-app")
    do ..PushModifiedManifest("trust-app", "2.0.0", "2.0.1", "deploy")
    do ..PushModifiedManifest("trust-app", "2.0.0", "2.0.1" _ $$$OrasTagPlatformSeparator _ $$$CurrentPlatformVersion, "undeploy")
    do ..Sign("trust-app", "1.0.0")
    do ..Sign("trust-app", "2.0.1")
    do ..Sign("trust-app", "2.0.1" _ $$$OrasTagPlatformSeparator _ $$$CurrentPlatformVersion)
    set sc = ..Run("install trusted/trust-app", .lines)
    do ..AssertRefused(sc, .lines, "disagree on whether it is deployed")
    do ..AssertNotInstalled("trust-app")
}

/// A dependency is planned with the signed manifest of the version selected for it. Its download requests the
/// version that manifest's module.xml gives. A promotion process that signed the 1.0.0 artifact again as 1.0.1 would
/// make the two differ, so planning refuses it rather than install an artifact other than the one planned with.
Method TestDependencyPlannedArtifactIsInstalled()
{
    if '..Available() {
        return
    }
    do ..Publish("trust-child", "trust-child", 1)
    do ..Publish("trust-parent", "trust-parent")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall trust-child"), "Uninstalled the dependency")
    do ..PushModifiedManifest("trust-child", "1.0.0", "1.0.1", "copy")
    do ..Sign("trust-child", "1.0.0")
    do ..Sign("trust-child", "1.0.1")
    do ..Sign("trust-parent", "1.0.0")

    set sc = ..Run("install trusted/trust-parent 1.0.0", .lines)
    do ..AssertRefused(sc, .lines, "gives version 1.0.0 rather than 1.0.1")
    do ..AssertNotInstalled("trust-child")
    do ..AssertNotInstalled("trust-parent")
}

/// A trust server whose certificate the system does not trust is refused, so the first check of a repository cannot
/// pin a root presented by a server that is not authenticated.
Method TestUntrustedTrustServerRefused()
{
    if '..Available() {
        return
    }
    if ($system.Version.GetOS() '= "UNIX") {
        do $$$AssertSkipped("The stand-in certificate is made with openssl")
        return
    }
    set certs = ##class(%IPM.Utils.File).CreateTempDirectory()
    set out = ##class(%Stream.TmpCharacter).%New()
    set command = $listbuild("openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes", "-days", "1", "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1", "-keyout", certs _ "notary-server.key", "-out", certs _ "notary-server.crt")
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).RunCommand(certs, command, .out, .out), "Made a certificate the system does not trust")
    set port = 18473
    do ..StartStub("stall", port, 60, certs)
    set server = "https://127.0.0.1:" _ port
    try {
        do ##class(%IPM.Repo.Oras.ContentTrust).LookUpSignedTargets(server, "oras:5000/untrusted/module", 10)
        do $$$AssertFailure("A trust server with an untrusted certificate answered")
    } catch e {
        set text = $system.Status.GetErrorText(e.AsStatus())
        do $$$AssertTrue(text [ "failed", "The check failed: " _ text)
        do $$$AssertNotTrue(text [ "did not finish", "It failed on the certificate, not by waiting: " _ text)
    }
    set pinned = ##class(%File).NormalizeDirectory("tuf/oras:5000/untrusted/module/metadata", ##class(%IPM.Repo.Oras.ContentTrust).PinDirectory(server, "oras:5000/untrusted/module"))
    do $$$AssertNotTrue(##class(%File).Exists(pinned _ "root.json"), "No root was pinned")
}

/// The verified manifest and package reads send the repo's configured credentials, as oras-py does for blobs:
/// a username and password, a bearer token, an API key and a Basic token.
Method TestCredentialsOnVerifiedReads()
{
    set port = 18474
    do ..StartStub("auth", port, 60)
    set registry = "http://127.0.0.1:" _ port
    set repository = "127.0.0.1:" _ port _ "/keyed/module"
    set signed = "sha256:" _ $zconvert(##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHAHash(256, $translate($justify("", 64), " ", "y"))), "L")
    set modes = $listbuild($listbuild("stub-user", "stub-pass", "", ""), $listbuild("", "", "stub-token", "bearer"), $listbuild("", "", "stub-key", "apiKey"), $listbuild("", "", "stub-basic-token", "basic"))
    set pointer = 0
    while $listnext(modes, pointer, mode) {
        set $listbuild(username, password, token, method) = mode
        set label = $select(method = "": "username and password", 1: method)
        set text = ##class(%IPM.Repo.Oras.PackageService).DownloadVerified("manifest", registry, repository, signed, 64, "", username, password, token, method)
        do $$$AssertEquals($length(text), 64, "Read the manifest with " _ label)
        set file = ##class(%IPM.Utils.File).CreateTempDirectory() _ "package.tgz"
        do ##class(%IPM.Repo.Oras.PackageService).DownloadVerified("blob", registry, repository, signed, 64, file, username, password, token, method)
        do $$$AssertEquals(##class(%File).GetFileSize(file), 64, "Downloaded the package with " _ label)
    }
    try {
        do ##class(%IPM.Repo.Oras.PackageService).DownloadVerified("manifest", registry, repository, signed, 64, "", "", "", "", "apiKey")
        do $$$AssertFailure("Read the manifest without credentials")
    } catch e {
        set failure = ##class(%IPM.Repo.Oras.HttpException).FromException(e)
        do $$$AssertTrue($isobject(failure) && (failure.StatusCode = 401), "Without credentials the registry answers 401: " _ $system.Status.GetErrorText(e.AsStatus()))
    }
}

/// A refused -trust-server changes no repo, including the one that -publish 1 would take the default deployment flag from.
Method TestRefusedTrustServerChangesNothing()
{
    do $$$AssertEquals(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").DeploymentEnabled, 1, "trusted is the default deployment repo")
    set sc = ##class(%IPM.Main).Shell("repo -o -name other -url " _ ..#OrasURL _ " -namespace " _ ..CaseNamespace _ "/other -publish 1 -trust-server http://notary:4443")
    do $$$AssertStatusNotOK(sc, "An http trust server is refused")
    do $$$AssertNotTrue(##class(%IPM.Repo.Definition).ServerDefinitionKeyExists("other"), "The refused repo was not created")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").DeploymentEnabled, 1, "trusted is still the default deployment repo")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name other -url " _ ..#OrasURL _ " -namespace " _ ..CaseNamespace _ "/other"), "Created another repo")
    set sc = ##class(%IPM.Main).Shell("repo -o -name other -publish 1 -trust-server http://notary:4443")
    do $$$AssertStatusNotOK(sc, "An http trust server is refused for an existing repo")
    do $$$AssertNotEquals(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("other").DeploymentEnabled, 1, "The existing repo did not become the default deployment repo")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted").DeploymentEnabled, 1, "trusted is still the default deployment repo")
}

/// Verification reads the registry with the repo's credentials. Errors do not show them.
Method TestBasicAuthentication()
{
    if '..Available() {
        return
    }
    set ..CaseNamespace = "auth-test/" _ ..RunNamespace
    do ##class(%IPM.Main).Shell("repo -delete -name trusted")
    do ..ConfigureTrustedRepo(..CaseNamespace, "-username writer -password writerpass")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..GetModuleDir("oras-auth")), "Loaded oras-auth")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish oras-auth -r trusted -only"), "Published with credentials")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall oras-auth"))

    set sc = ..Run("install trusted/oras-auth 1.0.0", .lines)
    do ..AssertRefused(sc, .lines, "no signature for them: 1.0.0")
    do $$$AssertNotTrue(..FindStringInMultiDimArray("writerpass", .lines), "The output does not show the password")
    do $$$AssertNotTrue($system.Status.GetErrorText(sc) [ "writerpass", "The error does not show the password")

    do ..Sign("oras-auth", "1.0.0", , , , "writer", "writerpass")
    do $$$AssertStatusOK(..Run("install trusted/oras-auth 1.0.0", .lines), "Installed with credentials")
    do $$$AssertEquals(##class(OrasAuth.Hello).Hello(), "hello")
}

// ===== Helpers =====

/// Returns whether the tests can run here, recording a skip if not.
Method Available() As %Boolean
{
    if (..Unavailable = "") {
        return 1
    }
    if ($system.Util.GetEnviron("IPM_REQUIRE_CONTENT_TRUST") '= "") {
        do $$$AssertFailure(..Unavailable)
    } else {
        do $$$AssertSkipped(..Unavailable)
    }
    return 0
}

/// Configures repo "trusted" on registry namespace with the trust server, plus any extra repo modifiers.
Method ConfigureTrustedRepo(
	namespace As %String,
	extra As %String = "")
{
    set command = "repo -o -name trusted -url " _ ..#OrasURL _ " -namespace " _ namespace _ " -publish 1 -trust-server " _ ..#TrustServerURL _ " " _ extra
    do $$$AssertStatusOK(##class(%IPM.Main).Shell(command), "Configured protected repo on " _ namespace)
}

ClassMethod FixtureDir(folder As %String) As %String
{
    return ..GetModuleDir(..#FixtureRoot, folder)
}

/// Loads fixture folder, publishes module to the protected repo with the ordinary publish command and,
/// unless keepInstalled is set, uninstalls it again.
Method Publish(
	folder As %String,
	module As %String,
	keepInstalled As %Boolean = 0)
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..FixtureDir(folder)), "Loaded " _ folder)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish " _ module _ " -r trusted -only"), "Published " _ folder)
    if 'keepInstalled {
        do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ module), "Uninstalled " _ module)
    }
}

/// Publishes the loaded module for platformVersion, which the publish command cannot choose.
Method PublishForPlatform(
	module As %String,
	platformVersion As %String) As %Status
{
    set sc = $$$OK
    try {
        set tgz = ##class(%IPM.Utils.File).CreateTempDirectory() _ module
        $$$ThrowOnError(##class(%IPM.Main).Shell("package " _ module _ " -only -path " _ tgz))
        set loaded = ##class(%IPM.Storage.Module).NameOpen(module, , .sc)
        $$$ThrowOnError(sc)
        set repo = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted")
        set info = ##class(%IPM.Repo.Remote.ModuleInfo).%New()
        set info.Name = module
        set info.VersionString = loaded.VersionString
        set info.Deployed = 1
        set info.PlatformVersion = platformVersion
        set payload = ##class(%Stream.FileBinary).%New()
        set payload.Filename = tgz _ ".tgz"
        $$$ThrowOnError(info.Payload.CopyFrom(payload))
        set manifest = ##class(%Stream.GlobalCharacter).%New()
        $$$ThrowOnError(loaded.XMLExportToStream(manifest))
        set info.Manifest = manifest
        set sc = repo.GetPublishService().PublishModule(info)
    } catch e {
        set sc = e.AsStatus()
    }
    return sc
}

/// Docker Content Trust repository name of module in this test's registry namespace.
Method GUN(module As %String) As %String
{
    return ..#Registry _ "/" _ ..CaseNamespace _ "/" _ module
}

/// Signs tag of module as an external promotion process would: reads the manifest's digest and size from the
/// registry and signs them on the trust server with notary, in role if given. sizeOffset adds to the signed size.
/// Returns the digest of the manifest read.
Method Sign(
	module As %String,
	tag As %String,
	role As %String = "",
	signerDirectory As %String = {..SignerDirectory},
	sizeOffset As %Integer = 0,
	username As %String = "",
	password As %String = "") As %String
{
    set manifest = {}.%FromJSON(..ReadManifest(..#Registry, ..CaseNamespace _ "/" _ module, tag, username, password))
    set gun = ..GUN(module)
    do ..InitTrust(gun, signerDirectory)
    set args = ["addhash", (gun), (tag), (manifest.size + sizeOffset), "--sha256", ($piece(manifest.digest, ":", 2)), "-p"]
    if (role '= "") {
        do args.%Push("-r").%Push(role)
    }
    do ..Notary(signerDirectory, args)
    return manifest.digest
}

/// Creates trust data for repository gun on the trust server, with keys in signerDirectory, unless it has some.
Method InitTrust(
	gun As %String,
	signerDirectory As %String = {..SignerDirectory})
{
    if '..Notary(signerDirectory, ["list", (gun)], 1) {
        do ..Notary(signerDirectory, ["init", (gun)])
        do ..Notary(signerDirectory, ["key", "rotate", (gun), "snapshot", "-r"])
        do ..Notary(signerDirectory, ["publish", (gun)])
    }
}

/// Adds delegation role for module's repository with a new key that the signer holds.
Method AddDelegation(
	module As %String,
	role As %String)
{
    set name = $piece(role, "/", *)
    set key = ..SignerDirectory _ name _ "-key.pem"
    set cert = ..SignerDirectory _ name _ ".pem"
    set out = ##class(%Stream.TmpCharacter).%New()
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).RunCommand(..SignerDirectory, $listbuild("openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", key), .out, .out), "Generated a key for " _ role)
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).RunCommand(..SignerDirectory, $listbuild("openssl", "req", "-new", "-x509", "-key", key, "-out", cert, "-days", "3650", "-subj", "/CN=" _ name), .out, .out), "Generated a certificate for " _ role)
    do ..Notary(..SignerDirectory, ["delegation", "add", (..GUN(module)), (role), (cert), "--all-paths", "-p"])
    do ..Notary(..SignerDirectory, ["key", "import", (key), "--role", (role)])
}

/// Runs notary as the signer, with keys in signerDirectory. Returns whether it succeeded if
/// mayFail is set. Otherwise asserts that it did.
Method Notary(
	signerDirectory As %String,
	args As %DynamicArray,
	mayFail As %Boolean = 0) As %Boolean
{
    set result = {}.%FromJSON(..RunSigner(##class(%IPM.Repo.Oras.ContentTrust).NotaryExecutable(), signerDirectory, ..#TrustServerURL, args.%ToJSON()))
    if mayFail {
        return result.ok
    }
    do $$$AssertTrue(result.ok, "notary " _ args.%Get(0) _ ": " _ result.output)
    return result.ok
}

/// Runs notary for the signer with its passphrases, returning {"ok": &lt;succeeded&gt;, "output": &lt;stdout and stderr&gt;}.
ClassMethod RunSigner(
	notary As %String,
	signerDirectory As %String,
	trustServer As %String,
	argsJSON As %String) As %String [ Language = python ]
{
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update({
        "NOTARY_ROOT_PASSPHRASE": "ipm-test-root",
        "NOTARY_TARGETS_PASSPHRASE": "ipm-test-targets",
        "NOTARY_SNAPSHOT_PASSPHRASE": "ipm-test-snapshot",
        "NOTARY_DELEGATION_PASSPHRASE": "ipm-test-delegation",
    })
    command = [notary, "-d", signerDirectory, "-s", trustServer] + [str(arg) for arg in json.loads(argsJSON)]
    process = subprocess.run(command, env=env, capture_output=True, text=True, timeout=120)
    return json.dumps({"ok": process.returncode == 0, "output": process.stdout + process.stderr})
}

/// Returns {"digest": "sha256:...", "size": n} of the manifest that tag names in repository path.
ClassMethod ReadManifest(
	registry As %String,
	path As %String,
	tag As %String,
	username As %String = "",
	password As %String = "") As %String [ Language = python ]
{
    import hashlib
    import json
    import requests

    url = f"http://{registry}/v2/{path}/manifests/{tag}"
    auth = (username, password) if username else None
    response = requests.get(url, headers={"Accept": "application/vnd.oci.image.manifest.v1+json"}, auth=auth, timeout=30)
    response.raise_for_status()
    return json.dumps({"digest": "sha256:" + hashlib.sha256(response.content).hexdigest(), "size": len(response.content)})
}

/// Returns the digest of the manifest tag names in module's repository in this test's namespace.
Method ManifestDigest(
	module As %String,
	tag As %String) As %String
{
    return {}.%FromJSON(..ReadManifest(..#Registry, ..CaseNamespace _ "/" _ module, tag)).digest
}

/// Returns the digest of the package layer in the manifest with manifestDigest in module's repository in this test's namespace.
Method PackageDigest(
	module As %String,
	manifestDigest As %String) As %String
{
    set request = ##class(%Net.HttpRequest).%New()
    do ##class(%Net.URLParser).Decompose(..#OrasURL, .parts)
    set request.Server = parts("host")
    set request.Port = parts("port")
    do request.SetHeader("Accept", "application/vnd.oci.image.manifest.v1+json")
    $$$ThrowOnError(request.Get("/v2/" _ ..CaseNamespace _ "/" _ module _ "/manifests/" _ manifestDigest))
    return {}.%FromJSON(request.HttpResponse.Data).layers.%Get(0).digest
}

/// Returns "sha256:" and the hex SHA-256 of stream.
ClassMethod StreamDigest(stream As %Stream.Object) As %String
{
    do stream.Rewind()
    return "sha256:" _ $zconvert(##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHAHashStream(256, stream)), "L")
}

/// Deletes the manifest with digest from module's repository in this test's namespace.
Method DeleteManifest(
	module As %String,
	digest As %String)
{
    do $$$AssertEquals(..RegistryRequest(..#Registry, "DELETE", ..CaseNamespace _ "/" _ module, digest), 202, "Deleted manifest " _ digest)
}

/// Pushes as newTag a copy of the manifest tag names in module's repository, with the same content ("copy") or changed
/// so that its package layer is one byte longer than the package ("size"), appears twice ("duplicate") or names the
/// config blob ("config"), or so that it is deployed ("deploy") or not ("undeploy").
Method PushModifiedManifest(
	module As %String,
	tag As %String,
	newTag As %String,
	change As %String)
{
    do $$$AssertEquals(..RegistryRequest(..#Registry, "PUT", ..CaseNamespace _ "/" _ module, newTag, tag, change), 201, "Pushed modified manifest " _ newTag)
}

/// Sends method to the manifest of reference in repository path and returns the status code.
/// For PUT, sends the manifest that sourceTag names, changed as PushModifiedManifest describes.
ClassMethod RegistryRequest(
	registry As %String,
	method As %String,
	path As %String,
	reference As %String,
	sourceTag As %String = "",
	change As %String = "") As %Integer [ Language = python ]
{
    import json
    import requests

    base = f"http://{registry}/v2/{path}/manifests/"
    mediaType = "application/vnd.oci.image.manifest.v1+json"
    if method != "PUT":
        return requests.request(method, base + reference, timeout=30).status_code
    manifest = requests.get(base + sourceTag, headers={"Accept": mediaType}, timeout=30).json()
    layer = manifest["layers"][0]
    if change == "size":
        layer["size"] += 1
    elif change == "config":
        layer["digest"] = manifest["config"]["digest"]
        layer["size"] = manifest["config"]["size"]
    elif change == "undeploy":
        manifest.setdefault("annotations", {})["com.intersystems.ipm.deployed"] = "0"
    elif change == "deploy":
        manifest.setdefault("annotations", {})["com.intersystems.ipm.deployed"] = "1"
    elif change == "duplicate":
        manifest["layers"].append(dict(layer))
    # A copy is indented, so its digest differs and unpublish does not delete one manifest twice
    body = json.dumps(manifest, indent=2) if change == "copy" else json.dumps(manifest)
    return requests.put(base + reference, data=body, headers={"Content-Type": mediaType}, timeout=30).status_code
}

/// Pushes as newTag a copy of the manifest sourceTag names in repository path, with its package layer one byte
/// longer than the package and an extra directory layer that ORAS unpacks into a directory named marker.
ClassMethod PushManifestWithDirectoryLayer(
	registry As %String,
	path As %String,
	sourceTag As %String,
	newTag As %String,
	marker As %String) As %Integer [ Language = python ]
{
    import hashlib
    import io
    import json
    import requests
    import tarfile

    base = f"http://{registry}/v2/{path}"
    mediaType = "application/vnd.oci.image.manifest.v1+json"
    manifest = requests.get(f"{base}/manifests/{sourceTag}", headers={"Accept": mediaType}, timeout=30).json()
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
        content = b"unpacked by the registry client\n"
        entry = tarfile.TarInfo(f"{marker}/marker.txt")
        entry.size = len(content)
        archive.addfile(entry, io.BytesIO(content))
    blob = buffer.getvalue()
    digest = "sha256:" + hashlib.sha256(blob).hexdigest()
    location = requests.post(f"{base}/blobs/uploads/", timeout=30).headers["Location"]
    if location.startswith("/"):
        location = f"http://{registry}{location}"
    separator = "&" if "?" in location else "?"
    requests.put(f"{location}{separator}digest={digest}", data=blob, headers={"Content-Type": "application/octet-stream"}, timeout=30).raise_for_status()
    manifest["layers"][0]["size"] += 1
    manifest["layers"].insert(0, {
        "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
        "digest": digest,
        "size": len(blob),
        "annotations": {"org.opencontainers.image.title": marker, "io.deis.oras.content.unpack": "true"},
    })
    return requests.put(f"{base}/manifests/{newTag}", data=json.dumps(manifest), headers={"Content-Type": mediaType}, timeout=30).status_code
}

/// Returns the path of a directory named name at most four levels below root, or "" if there is none.
ClassMethod FindDirectory(
	root As %String,
	name As %String) As %String [ Language = python ]
{
    import os

    depth = root.rstrip(os.sep).count(os.sep)
    for current, directories, files in os.walk(root):
        if name in directories:
            return os.path.join(current, name)
        if current.count(os.sep) - depth >= 4:
            directories[:] = []
    return ""
}

/// Returns the tags in repository path as a comma separated string, or "" if it has none.
/// Uses the credentials of repo "trusted", since the auth-test namespace requires them.
Method PublishedTags(path As %String) As %String
{
    set repo = ##class(%IPM.Repo.Oras.Definition).ServerDefinitionKeyOpen("trusted")
    set client = ##class(%IPM.Repo.Oras.PackageService).GetClient(..#OrasURL, repo.Username, repo.Password, repo.Token, repo.TokenAuthMethod)
    return ##class(%IPM.Repo.Oras.PackageService).GetAllTags(..#OrasURL, path, "", client)
}

/// Starts the stand-in server in mode on port for seconds, with arguments for the mode, and waits until it answers.
/// See stub/server.py for the modes.
Method StartStub(
	mode As %String,
	port As %Integer,
	seconds As %Integer,
	arguments... As %String)
{
    set script = ..FixtureDir("stub") _ "server.py"
    set null = ##class(%Library.Device).GetNullDevice()
    do $zf(-100, "/ASYNC /STDOUT=""" _ null _ """ /STDERR=""" _ null _ """", "python3", script, mode, port, seconds, arguments...)
    set url = $select(mode = "stall": "https", 1: "http") _ "://127.0.0.1:" _ port _ "/v2/"
    for i = 1:1:50 {
        if ..Answers(url, $get(arguments) = 0) {
            return
        }
        hang 0.2
    }
    do $$$AssertFailure("The stand-in server on port " _ port _ " did not start")
}

/// Returns whether url answers a GET with status 200, checking an https server's certificate against the system store
/// if verify is set.
ClassMethod Answers(
	url As %String,
	verify As %Boolean = 1) As %Boolean [ Language = python ]
{
    import ssl
    import urllib.request

    context = ssl.create_default_context() if verify else ssl._create_unverified_context()
    try:
        with urllib.request.urlopen(url, timeout=5, context=context) as response:
            return response.status == 200
    except Exception:
        return False
}

/// Returns the path of a file whose path ends in relative at most six levels below root, or "" if there is none.
ClassMethod FindFile(
	root As %String,
	relative As %String) As %String [ Language = python ]
{
    import os

    depth = root.rstrip(os.sep).count(os.sep)
    for current, directories, files in os.walk(root):
        for name in files:
            path = os.path.join(current, name)
            if path.endswith(os.sep + relative):
                return path
        if current.count(os.sep) - depth >= 6:
            directories[:] = []
    return ""
}

/// Runs a shell command, returning its status and its output in lines.
Method Run(
	command As %String,
	Output lines) As %Status
{
    kill lines
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell(command)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .lines)
    return sc
}

/// Asserts that sc failed and that its error text or the command's output contains each substring.
Method AssertRefused(
	sc As %Status,
	ByRef lines,
	substrings... As %String)
{
    do $$$AssertStatusNotOK(sc, "The command was refused")
    set text = $system.Status.GetErrorText(sc)
    for i = 1:1:$get(lines) {
        set text = text _ $char(10) _ $get(lines(i))
    }
    for i = 1:1:$get(substrings) {
        do $$$AssertTrue(text [ substrings(i), "Refusal mentions: " _ substrings(i) _ $char(10) _ "Output was: " _ text)
    }
}

/// Asserts that trust-app is installed at version and its code reports revision.
Method AssertRevision(
	version As %String,
	revision As %String)
{
    do $$$AssertEquals(..InstalledVersion("trust-app"), version, "trust-app " _ version _ " is installed")
    do $$$AssertEquals($classmethod("TrustApp.Hello", "Revision"), revision, "The installed code is " _ revision)
}

Method AssertNotInstalled(module As %String)
{
    do $$$AssertEquals(..InstalledVersion(module), "", module _ " is not installed")
}

/// Asserts that the newest history entry is action on module, successful or not.
Method AssertLatestHistory(
	action As %String,
	module As %String,
	success As %Boolean)
{
    set rs = ##class(%IPM.General.History).GetHistory(, 0, 1)
    if '$$$AssertTrue(rs.%Next(), "There is a history entry") {
        return
    }
    do $$$AssertEquals(rs.%Get("Action"), action, "The newest history entry is " _ action)
    do $$$AssertEquals(rs.%Get("Package"), module, "The newest history entry is for " _ module)
    do $$$AssertEquals(''$$$ISOK(rs.%Get("Success")), success, "The newest history entry's success")
}

/// Version of the named module as installed, or "" if it is not installed.
ClassMethod InstalledVersion(module As %String) As %String
{
    set loaded = ##class(%IPM.Storage.Module).NameOpen(module, , .sc)
    return $select($$$ISERR(sc) || '$isobject(loaded): "", 1: loaded.VersionString)
}

/// Removes the pin directories in trustDirectory of the repositories whose names start with prefix.
ClassMethod RemovePinDirectories(
	trustDirectory As %String,
	prefix As %String) [ Language = python ]
{
    import os
    import re
    import shutil

    # PinDirectory keeps 40 characters of a repository's name before its hash
    folder = re.sub(r"[^A-Za-z0-9]", "_", prefix)[:40]
    for name in os.listdir(trustDirectory):
        if name.startswith(folder):
            shutil.rmtree(os.path.join(trustDirectory, name), ignore_errors=True)
}

/// Returns how many entries service lists for module name.
ClassMethod Offered(
	service As %IPM.Repo.Oras.PackageService,
	name As %String) As %Integer
{
    set criteria = ##class(%IPM.Repo.SearchCriteria).%New()
    set criteria.Name = name
    return service.ListModules(criteria).Count()
}

/// Writes directory/notary.sh, which runs notary. The first run waits while directory/hold exists, which this
/// creates, and then runs with every connection to the trust server refused by a proxy on a closed port.
ClassMethod WriteNotaryWrapper(
	directory As %String,
	notary As %String) [ Language = python ]
{
    import os
    import shlex

    first, hold = shlex.quote(directory + "first"), shlex.quote(directory + "hold")
    script = "\n".join([
        "#!/bin/sh",
        f"if mkdir {first} 2>/dev/null; then",
        f"    while [ -e {hold} ]; do sleep 0.2; done",
        f"    exec env HTTPS_PROXY=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 NO_PROXY= no_proxy= {shlex.quote(notary)} \"$@\"",
        "fi",
        f"exec {shlex.quote(notary)} \"$@\"",
        "",
    ])
    path = directory + "notary.sh"
    with open(path, "w") as f:
        f.write(script)
    os.chmod(path, 0o755)
    open(directory + "hold", "w").close()
}

/// Run by JOB: checks repository on server and records "accepted ..." or "refused ..." in ^IPM.Test.ContentTrust(key).
ClassMethod CheckInBackground(
	server As %String,
	repository As %String,
	key As %String)
{
    try {
        set ^IPM.Test.ContentTrust(key) = "accepted " _ ##class(%IPM.Repo.Oras.ContentTrust).LookUpSignedTargets(server, repository).%ToJSON()
    } catch e {
        set ^IPM.Test.ContentTrust(key) = "refused " _ $system.Status.GetErrorText(e.AsStatus())
    }
}

/// Run by JOB: deletes file after seconds.
ClassMethod RemoveLater(
	file As %String,
	seconds As %Integer)
{
    hang seconds
    do ##class(%File).Delete(file)
}

/// Returns whether the trust server answers its health check over https with a certificate the system trusts.
ClassMethod TrustServerHealthy() As %Boolean
{
    return ..Answers(..#TrustServerURL _ "/_notary_server/health")
}

}
