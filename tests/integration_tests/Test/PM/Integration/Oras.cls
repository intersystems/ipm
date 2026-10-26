/// Integration tests against the local ORAS (zot) registry.
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

Method OnAfterAllTests() As %Status
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"), "Deleted repos successfully")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -reset-defaults"), "Reset repos to default successfully")
    return $$$OK
}

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

}
