/// Integration tests against the local ORAS (zot) registry.
/// zot requires Basic authentication for auth-test/** and auth-private/** and allows anonymous access elsewhere.
Class Test.PM.Integration.Oras Extends Test.PM.Integration.Base
{

/// Oras registry URL. Uses the docker-compose service name by default.
Parameter OrasURL = "http://oras:5000";

/// Some tests point the repo at a namespace, so every test starts from a fresh repo definition.
Method OnBeforeOneTest(testName As %String) As %Status
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"), "Deleted repos successfully")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name oras -url " _ ..#OrasURL _ " -publish 1"), "Set up oras repo successfully")
    return $$$OK
}

Method OnAfterOneTest(testName As %String) As %Status
{
    if (testName = "TestLookupFailureWarnsAndContinues") || (testName = "TestLookupSystemErrorFails") {
        // The repo's class goes with the module, so the repo has to go first
        do ##class(%IPM.Main).Shell("repo -delete -name throwing")
        do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall oras-throwing-repo"), "Uninstalled oras-throwing-repo")
    }
    return $$$OK
}

Method OnAfterAllTests() As %Status
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"), "Deleted repos successfully")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -reset-defaults"), "Reset repos to default successfully")
    return $$$OK
}

// ===== Anonymous publish and install =====

Method TestOrasTagConversion()
{
    set moduleDir = ..GetModuleDir("oras-tag")

    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module successfully")

    set sc = ##class(%IPM.Main).Shell("publish oras-tag -r oras -verbose")
    do $$$AssertStatusOK(sc, "Published module successfully")

    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc, "Uninstalled module successfully")

    set sc = ##class(%IPM.Main).Shell("install oras-tag")
    do $$$AssertStatusOK(sc, "Installed module from ORAS registry successfully")

    set sc = ##class(%IPM.Main).Shell("unpublish oras/oras-tag all -force")
    do $$$AssertStatusOK(sc, "Unpublished module successfully")
}

Method TestOrasNamespace()
{
    set moduleDir = ..GetModuleDir("oras-tag")

    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module successfully")

    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns testnamespace")
    do $$$AssertStatusOK(sc, "Set up oras repo with namespace successfully")

    // Publish module (should be stored as testnamespace/oras-tag)
    set sc = ##class(%IPM.Main).Shell("publish oras-tag -r oras -verbose")
    do $$$AssertStatusOK(sc, "Published module successfully to namespaced repo")

    // Uninstall and reinstall
    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc, "Uninstalled module successfully")

    set sc = ##class(%IPM.Main).Shell("install oras-tag")
    do $$$AssertStatusOK(sc, "Installed module from namespaced ORAS registry successfully")

    // Verify searching only shows modules in the namespace
    set sc = ##class(%IPM.Main).Shell("repo -list-modules -n oras")
    do $$$AssertStatusOK(sc, "Listed modules in namespaced repo successfully")

    // Reconfigure to no namespace to verify isolation
    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns """"")
    do $$$AssertStatusOK(sc, "Reconfigured oras repo without namespace")

    // Publish to the non-namespaced repo (should be stored as oras-tag)
    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc, "Uninstalled module before republishing")

    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc, "Reloaded module successfully")

    set sc = ##class(%IPM.Main).Shell("publish oras-tag -r oras -verbose")
    do $$$AssertStatusOK(sc, "Published module to non-namespaced repo")

    // Reconfigure back to namespace
    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns testnamespace")
    do $$$AssertStatusOK(sc, "Reconfigured oras repo with namespace again")

    // Verify we can install from the namespaced repo (should find testnamespace/oras-tag)
    set sc = ##class(%IPM.Main).Shell("install oras/oras-tag")
    do $$$AssertStatusOK(sc, "Installed module from namespaced repo using oras/oras-tag syntax")

    // Reconfigure to no namespace
    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns """"")
    do $$$AssertStatusOK(sc, "Reconfigured oras repo without namespace again")

    // Verify we can also install from the non-namespaced repo
    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc, "Uninstalled module successfully")

    set sc = ##class(%IPM.Main).Shell("install oras/oras-tag")
    do $$$AssertStatusOK(sc, "Installed module from non-namespaced repo using oras/oras-tag syntax")

    // Cleanup - unpublish from both namespaced and non-namespaced
    set sc = ##class(%IPM.Main).Shell("unpublish oras/oras-tag all -force")
    do $$$AssertStatusOK(sc, "Unpublished module from non-namespaced repo")

    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns testnamespace")
    do $$$AssertStatusOK(sc, "Reconfigured oras repo with namespace for cleanup")

    set sc = ##class(%IPM.Main).Shell("unpublish oras/oras-tag all -force")
    do $$$AssertStatusOK(sc, "Unpublished module from namespaced repo")

    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc, "Uninstalled module successfully")
}

/// Dependencies of a module installed from a namespaced repo are resolved within that namespace.
Method TestOrasNamespaceDependencies()
{
    set parent = "simplest-module"
    set child = "simplest-module-dep"
    set moduleDir = ..GetModuleDir(parent, "3.0.0")

    // The dependency is loaded from the fixture's .modules directory
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module with dependency successfully")

    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns test")
    do $$$AssertStatusOK(sc, "Set up oras repo with namespace successfully")

    set sc = ##class(%IPM.Main).Shell("publish " _ child _ " -r oras -verbose -only")
    do $$$AssertStatusOK(sc, "Published dependency to namespaced repo")

    set sc = ##class(%IPM.Main).Shell("publish " _ parent _ " -r oras -verbose -only")
    do $$$AssertStatusOK(sc, "Published parent to namespaced repo")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ parent), "Uninstalled parent")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ child), "Uninstalled dependency")

    set sc = ##class(%IPM.Main).Shell("install oras/" _ parent _ " 3.0.0")
    do $$$AssertStatusOK(sc, "Installed parent and dependency from namespaced repo")
    do ..AssertVersion(parent, "3.0.0")
    do ..AssertVersion(child, "1.0.0")

    // Cleanup
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("unpublish oras/" _ parent _ " all -force"), "Unpublished parent")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("unpublish oras/" _ child _ " all -force"), "Unpublished dependency")
    do ##class(%IPM.Main).Shell("uninstall " _ parent)
    do ##class(%IPM.Main).Shell("uninstall " _ child)
}

Method TestOrasVersionAnnotations()
{
    set module = "oras-version-annotations"
    set originalVersion = "1.0.0-prerelease+build"
    set updatedVersion = "1.0.0"
    set folder = ..GetModuleDir(module)

    set sc = ##class(%IPM.Main).Shell("load " _ folder)
    do $$$AssertStatusOK(sc, "Successfully loaded module at " _ folder)

    do ..AssertVersion(module, originalVersion)

    set sc = ##class(%IPM.Main).Shell("publish " _ module _ " -r oras -verbose")
    do $$$AssertStatusOK(sc, "Published module successfully")

    do ..AssertVersion(module, originalVersion)

    set sc = ##class(%IPM.Main).Shell("modver " _ module _ " " _ updatedVersion _ " -force")
    do $$$AssertStatusOK(sc, "Updated module version to " _ updatedVersion)

    do ..AssertVersion(module, updatedVersion)

    set sc = ##class(%IPM.Main).Shell("publish " _ module _ " -r oras -verbose -only")
    do $$$AssertStatusOK(sc, "Published module successfully")

    do ..AssertVersion(module, updatedVersion)

    set sc = ##class(%IPM.Main).Shell("uninstall " _ module)
    do $$$AssertStatusOK(sc, "Uninstalled module successfully")

    set sc = ##class(%IPM.Main).Shell("install " _ module)
    do $$$AssertStatusOK(sc, "Installed module from ORAS registry successfully")

    do ..AssertVersion(module, updatedVersion)
}

Method TestInstallSpecificBuildVersion()
{
    set module = "oras-version-with-build"
    set buildVersion = "1.0.0-prerelease+build"
    set cleanVersion = "1.0.0-prerelease"

    // Load the module with build metadata
    set folder = ..GetModuleDir(module)
    set sc = ##class(%IPM.Main).Shell("load " _ folder)
    do $$$AssertStatusOK(sc, "Loaded module with build metadata")

    // Publish the build version
    do ..AssertVersion(module, buildVersion)
    set sc = ##class(%IPM.Main).Shell("publish " _ module _ " -r oras -verbose")
    do $$$AssertStatusOK(sc, "Published build metadata version")

    // Modify the module version to clean version (same base, no build)
    set sc = ##class(%IPM.Main).Shell("modver " _ module _ " " _ cleanVersion _ " -force")
    do $$$AssertStatusOK(sc, "Changed version to clean prerelease")

    // Publish the clean version
    do ..AssertVersion(module, cleanVersion)
    set sc = ##class(%IPM.Main).Shell("publish " _ module _ " -r oras -verbose -only")
    do $$$AssertStatusOK(sc, "Published clean prerelease version")

    // Uninstall all local copies
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ module))

    // Install the version with build explicitly
    set sc = ##class(%IPM.Main).Shell("install oras/" _ module _ " " _ buildVersion)
    do $$$AssertStatusOK(sc, "Installed build version explicitly")
    do ..AssertVersion(module, buildVersion)

    // Install without build specified
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ module))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("install oras/" _ module _ " " _ cleanVersion))
    do ..AssertVersion(module, cleanVersion)

    // Publish 3 builds of the same base version: build1, build2, build3
    for i = 1:1:3 {
        set buildVer = "1.0.0-prerelease+build" _ i
        do $$$AssertStatusOK(##class(%IPM.Main).Shell("modver " _ module _ " " _ buildVer _ " -force"))
        do ..AssertVersion(module, buildVer)
        do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish " _ module _ " -r oras -verbose -only"))
    }

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ module))

    // Install a specific older build (build2)
    set specificBuild = "1.0.0-prerelease+build2"
    set sc = ##class(%IPM.Main).Shell("install oras/" _ module _ " " _ specificBuild)
    do $$$AssertStatusOK(sc, "Installed older build version explicitly")
    do ..AssertVersion(module, specificBuild)
}

/// Asserts that moduleName is installed at version ver.
Method AssertVersion(
    moduleName As %String,
    ver As %String) As %Boolean
{
    set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
    if '$$$AssertTrue($isobject(module), "Module " _ moduleName _ " is installed") {
        return 0
    }
    return $$$AssertEquals(module.VersionString, ver) && $$$AssertEquals(module.Version.ToString(), ver)
}

// ===== Basic authentication =====

/// Loads the oras-auth fixture and recreates repo name rather than modifying it,
/// so no credentials carry over from an earlier configuration.
Method ConfigureRepo(
	name As %String,
	namespace As %String,
	username As %String = "",
	password As %String = "")
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..GetModuleDir("oras-auth")), "Loaded oras-auth successfully")
    // Repo URLs must be unique, so the oras repo from OnBeforeOneTest goes. The repo being configured may not exist yet.
    do ##class(%IPM.Main).Shell("repo -delete -name oras")
    do ##class(%IPM.Main).Shell("repo -delete -name " _ name)
    set command = "repo -o -name " _ name _ " -url " _ ..#OrasURL _ " -namespace " _ namespace _ " -publish 1"
    if username '= "" {
        set command = command _ " -username " _ username _ " -password " _ password
    }
    do $$$AssertStatusOK(##class(%IPM.Main).Shell(command), "Configured repo " _ name)
}

Method TestBasicLoginPublishAndInstall()
{
    do ..ConfigureRepo("authrepo", "auth-test", "writer", "writerpass")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish oras-auth -r authrepo"))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall oras-auth"))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("install authrepo/oras-auth"))
    do $$$AssertEquals(##class(OrasAuth.Hello).Hello(), "hello")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("unpublish authrepo/oras-auth all -force"))
}

Method TestBadPasswordFailsFast()
{
    do ..ConfigureRepo("authrepo", "auth-test", "writer", "wrong")
    set start = $zhorolog
    set sc = ##class(%IPM.Main).Shell("publish oras-auth -r authrepo")
    do $$$AssertStatusNotOK(sc)
    set elapsed = $zhorolog - start
    do $$$AssertTrue(elapsed < 30, "Failed in " _ elapsed _ "s")
}

// ===== Error messages =====

/// Asserts that sc is an error whose text contains each of the substrings.
Method AssertErrorContains(
	sc As %Status,
	substrings... As %String)
{
    do $$$AssertStatusNotOK(sc)
    set text = $system.Status.GetErrorText(sc)
    for i = 1:1:$get(substrings) {
        do $$$AssertTrue(text [ substrings(i), "Error contains: " _ substrings(i) _ $char(13,10) _ "Error was: " _ text)
    }
}

Method TestBadPasswordPublishMessage()
{
    do ..ConfigureRepo("authrepo", "auth-test", "writer", "wrong")
    set sc = ##class(%IPM.Main).Shell("publish oras-auth -r authrepo")
    do ..AssertErrorContains(sc, "Registry 'authrepo' (http://oras:5000) rejected the credentials: 401 Unauthorized", "Update the credentials configured for repo 'authrepo'.")
}

Method TestReaderPublishDenied()
{
    // The repository must exist for the reader's refusal to be about permission
    do ..ConfigureRepo("authrepo", "auth-test", "writer", "writerpass")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish oras-auth -r authrepo"))

    do ..ConfigureRepo("authrepo", "auth-test", "reader", "readerpass")
    set sc = ##class(%IPM.Main).Shell("publish oras-auth -r authrepo")
    do ..AssertErrorContains(sc, "denied access to 'oras-auth': 403 Forbidden", "lack permission for this repository")

    do ..ConfigureRepo("authrepo", "auth-test", "writer", "writerpass")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("unpublish authrepo/oras-auth all -force"))
}

Method TestNoCredentialsPublish()
{
    do ..ConfigureRepo("authrepo", "auth-test")
    set sc = ##class(%IPM.Main).Shell("publish oras-auth -r authrepo")
    do ..AssertErrorContains(sc, "requires authentication: 401 Unauthorized", "Configure credentials for repo 'authrepo'.")
}

Method TestUnpublishMissingVersion()
{
    do ..ConfigureRepo("authrepo", "auth-test", "writer", "writerpass")
    set sc = ##class(%IPM.Main).Shell("unpublish authrepo/oras-auth 9.9.9 -force")
    do ..AssertErrorContains(sc, "'oras-auth' 9.9.9 not found in repo 'authrepo'.")
}

Method TestUnpublishMissingModule()
{
    do ..ConfigureRepo("authrepo", "auth-test", "writer", "writerpass")
    set sc = ##class(%IPM.Main).Shell("unpublish authrepo/no-such-module all -force")
    do ..AssertErrorContains(sc, "'no-such-module' not found in repo 'authrepo'.")
}

// ===== Lookups across repos =====

/// Number of lines containing text.
ClassMethod CountOccurrences(
	ByRef lines,
	text As %String) As %Integer
{
    set count = 0
    for i = 1:1:$get(lines) {
        if $get(lines(i)) [ text {
            set count = count + 1
        }
    }
    return count
}

/// Sets the order in which lookups search repo name.
Method SetSortOrder(
	name As %String,
	order As %Integer)
{
    set repo = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(name, , .sc)
    if '$$$AssertStatusOK(sc, "Opened repo " _ name) {
        return
    }
    set repo.OverriddenSortOrder = order
    do $$$AssertStatusOK(repo.%Save(), "Saved sort order for repo " _ name)
}

/// Installs simplest-module 3.0.0, which has a dependency, with failingRepo searched before a filesystem repo holding both.
/// Returns the install's status, and its output in lines.
Method InstallWithFailingRepo(
	failingRepo As %String,
	Output lines) As %Status
{
    do ##class(%IPM.Main).Shell("repo -delete -name oras")
    do ##class(%IPM.Main).Shell("repo -delete -name local")
    // The dependency is in the fixture's .modules directory
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -fs -name local -path " _ ..GetModuleDir("simplest-module", "3.0.0")), "Configured filesystem repo")
    do ..SetSortOrder(failingRepo, 1)
    do ..SetSortOrder("local", 2)

    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("install simplest-module 3.0.0")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .lines)

    do ##class(%IPM.Main).Shell("uninstall simplest-module")
    do ##class(%IPM.Main).Shell("uninstall simplest-module-dep")
    do ##class(%IPM.Main).Shell("repo -delete -name local")
    return sc
}

Method TestRejectingRepoWarnsOnce()
{
    do ..ConfigureRepo("badauth", "auth-test", "writer", "wrong")
    set sc = ..InstallWithFailingRepo("badauth", .lines)
    do $$$AssertStatusOK(sc, "Installed from the filesystem repo")
    do $$$AssertEquals(..CountOccurrences(.lines, "rejected the credentials"), 1)
}

Method TestRefusalAfterLoginSilent()
{
    do ..ConfigureRepo("private", "auth-private", "reader", "readerpass")
    set sc = ..InstallWithFailingRepo("private", .lines)
    do $$$AssertStatusOK(sc, "Installed from the filesystem repo")
    do $$$AssertEquals(..CountOccurrences(.lines, "denied access"), 0)
    do $$$AssertEquals(..CountOccurrences(.lines, "WARNING"), 0)
}

/// Adds repo "throwing" from the oras-throwing-repo fixture. The URL is never contacted.
Method AddThrowingRepo(url As %String)
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..GetModuleDir("oras-throwing-repo")), "Loaded oras-throwing-repo")
    set repo = $classmethod("OrasThrowingRepo.Definition", "%New")
    set repo.Name = "throwing"
    set repo.URL = url
    set repo.Enabled = 1
    do $$$AssertStatusOK(repo.%Save(), "Saved throwing repo")
}

Method TestLookupFailureWarnsAndContinues()
{
    do ..AddThrowingRepo("http://throwing.invalid")
    set sc = ..InstallWithFailingRepo("throwing", .lines)
    do $$$AssertStatusOK(sc, "Installed from the filesystem repo")
    do $$$AssertEquals(..CountOccurrences(.lines, "Simulated registry failure [x:y]"), 1)
}

Method TestLookupSystemErrorFails()
{
    do ..AddThrowingRepo("http://system-error.invalid")
    set sc = ..InstallWithFailingRepo("throwing", .lines)
    do ..AssertErrorContains(sc, "<DIVIDE>")
}

/// Skipping a repo whose credentials were rejected lasts only for the shell command.
Method TestRejectedRepoSearchedAfterCommand()
{
    do ..ConfigureRepo("badauth", "auth-test", "writer", "wrong")
    // Must be the last shell command before the search, and fails since badauth is the only repo
    do $$$AssertStatusNotOK(##class(%IPM.Main).Shell("install simplest-module 3.0.0"), "Install found nothing")

    set criteria = ##class(%IPM.Repo.SearchCriteria).%New()
    set criteria.Name = "simplest-module"
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(criteria, .results)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .lines)
    do $$$AssertStatusOK(sc, "Searched repos")
    do $$$AssertEquals(..CountOccurrences(.lines, "rejected the credentials"), 1)
}

}
