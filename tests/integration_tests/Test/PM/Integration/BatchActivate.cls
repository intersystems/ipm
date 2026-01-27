/// Test class for batch activation of CPF merge after all namespaces are processed during unmap and enable commands
Class Test.PM.Integration.BatchActivate Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "cpf-merge";

/// Test that unmapping from a single namespace still works correctly after batch activation change
Method TestBatchActivationUnmapSingleNamespace()
{
    set sc = ##class(%IPM.Main).Shell("load -v " _ ..GetModuleDir(..#TargetModuleName))
    do $$$AssertStatusOK(sc, "Loaded cpf-merge module successfully")

    set ns = "TEST_UNMAP_NS"

    // Create test namespace using utility
    set sc = ##class(%IPM.Test.Utils).CreateNamespace(ns)
    do $$$AssertStatusOK(sc, "Created test namespace")

    // Add a test package mapping
    set sc = ##class(%IPM.Utils.Module).AddPackageMapping(ns, "TestPackage", "USER")
    do $$$AssertStatusOK(sc, "Added test package mapping")

    // Verify mapping exists before unmap
    set originalNs = $namespace
    new $namespace
    set $namespace = "%SYS"
    set exists = ##class(Config.MapPackages).Exists(ns, "TestPackage")
    do $$$AssertTrue(exists, "Test package mapping exists before unmap")

    // Test unmap via CLI (uses batch activation internally)
    set $namespace = originalNs
    set sc = ##class(%IPM.Main).Shell("unmap -ns " _ ns _ " -q")
    do $$$AssertStatusOK(sc, "Unmap command executed successfully")

    // Verify mappings are removed
    set $namespace = "%SYS"
    set pkgExists = ##class(Config.MapPackages).Exists(ns, "%IPM")
    do $$$AssertNotTrue(pkgExists, "%IPM package mapping removed")

    set rtnExists = ##class(Config.MapRoutines).Exists(ns, "%IPM.*")
    do $$$AssertNotTrue(rtnExists, "%IPM routine mapping removed")

    // Cleanup: Remove test namespace
    set $namespace = originalNs
    set sc = ##class(%IPM.Test.Utils).DeleteNamespace(ns)
    do $$$AssertStatusOK(sc, "Cleaned up test namespace")
}

/// Test batch activation when unmapping from multiple namespaces
Method TestBatchActivationUnmapMultipleNamespaces()
{
    set sc = ##class(%IPM.Main).Shell("load -v " _ ..GetModuleDir(..#TargetModuleName))
    do $$$AssertStatusOK(sc, "Loaded cpf-merge module successfully")

    // Create multiple test namespaces
    set ns1 = "TEST_BATCH_NS1"
    set ns2 = "TEST_BATCH_NS2"
    set ns3 = "TEST_BATCH_NS3"
    set namespaces = $listbuild(ns1, ns2, ns3)

    for i=1:1:$listlength(namespaces) {
        set ns = $listget(namespaces, i)
        set sc = ##class(%IPM.Test.Utils).CreateNamespace(ns)
        do $$$AssertStatusOK(sc, "Created namespace: " _ ns)

        // Add test mappings to each namespace
        set sc = ##class(%IPM.Utils.Module).AddPackageMapping(ns, "TestPackage", "USER")
        do $$$AssertStatusOK(sc, "Added package mapping to " _ ns)
    }

    // Verify all mappings exist
    set originalNs = $namespace
    new $namespace
    set $namespace = "%SYS"
    for i=1:1:$listlength(namespaces) {
        set ns = $listget(namespaces, i)
        set exists = ##class(Config.MapPackages).Exists(ns, "TestPackage")
        do $$$AssertTrue(exists, "Package mapping exists in " _ ns)
    }

    // Unmap from all namespaces at once (uses batch activation)
    set $namespace = originalNs
    set sc = ##class(%IPM.Main).Shell("unmap -ns " _ $listtostring(namespaces, ",") _ " -q")
    do $$$AssertStatusOK(sc, "Unmap from multiple namespaces executed successfully")

    // Verify all mappings are removed
    set $namespace = "%SYS"
    for i=1:1:$listlength(namespaces) {
        set ns = $listget(namespaces, i)
        set pkgExists = ##class(Config.MapPackages).Exists(ns, "%IPM")
        do $$$AssertNotTrue(pkgExists, "%IPM package mapping removed from " _ ns)
    }

    // Cleanup: Remove test namespaces
    set $namespace = originalNs
    for i=1:1:$listlength(namespaces) {
        set ns = $listget(namespaces, i)
        set sc = ##class(%IPM.Test.Utils).DeleteNamespace(ns)
        do $$$AssertStatusOK(sc, "Cleaned up namespace: " _ ns)
    }
}

/// Test that activation is skipped when there are no actual changes
Method TestBatchActivationSkipsWhenNoChanges()
{
    set sc = ##class(%IPM.Main).Shell("load -v " _ ..GetModuleDir(..#TargetModuleName))
    do $$$AssertStatusOK(sc, "Loaded cpf-merge module successfully")

    set ns = "TEST_NO_CHANGE_NS"
    set sc = ##class(%IPM.Test.Utils).CreateNamespace(ns)
    do $$$AssertStatusOK(sc, "Created test namespace")

    // First, add a test mapping so we have something to unmap
    set sc = ##class(%IPM.Utils.Module).AddPackageMapping(ns, "TestPackage", "USER")
    do $$$AssertStatusOK(sc, "Added test package mapping")

    // Unmap from the namespace (this will activate)
    set sc = ##class(%IPM.Main).Shell("unmap -ns " _ ns _ " -q")
    do $$$AssertStatusOK(sc, "First unmap executed successfully")

    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    // Try to unmap again from the same namespace
    // Since there are no more IPM mappings, this should skip
    set sc = ##class(%IPM.Main).Shell("unmap -ns " _ ns)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    // Should report "No mapping found" and skip (no activation)
    do $$$AssertTrue(..FindStringInMultiDimArray("No mapping found", .output), "Correctly skipped namespace with no mappings")

    // Cleanup
    set sc = ##class(%IPM.Test.Utils).DeleteNamespace(ns)
    do $$$AssertStatusOK(sc, "Cleaned up test namespace")
}

/// Verify enable -map uses batch activation when mapping into a single namespace
Method TestEnableMapSingleNamespace()
{
    set targetNs = "TEST_ENABLE_MAP_NS1"

    // Ensure target namespace exists
    set sc = ##class(%IPM.Test.Utils).CreateNamespace(targetNs)
    do $$$AssertStatusOK(sc, "Created target namespace")

    // Map IPM from current namespace into target namespace (quiet mode)
    set sc = ##class(%IPM.Main).Shell("enable -map -ns " _ targetNs _ " -q")
    do $$$AssertStatusOK(sc, "enable -map executed successfully")

    // Verify mappings were created
    set originalNs = $namespace
    new $namespace
    set $namespace = "%SYS"
    do $$$AssertTrue(##class(Config.MapPackages).Exists(targetNs, "%IPM"), "%IPM package mapped")
    do $$$AssertTrue(##class(Config.MapRoutines).Exists(targetNs, "%IPM.*"), "%IPM routines mapped")

    // Cleanup
    set $namespace = originalNs
    set sc = ##class(%IPM.Test.Utils).DeleteNamespace(targetNs)
    do $$$AssertStatusOK(sc, "Cleaned up target namespace")
}

/// Verify enable -map -repos batches activation across multiple namespaces
Method TestEnableMapMultipleNamespacesWithRepos()
{
    set sc = ##class(%IPM.Main).Shell("load -v " _ ..GetModuleDir(..#TargetModuleName))
    do $$$AssertStatusOK(sc, "Loaded cpf-merge module successfully")

    set ns1 = "TEST_ENABLE_MAP_NS2"
    set ns2 = "TEST_ENABLE_MAP_NS3"

    // Create target namespaces
    set sc = ##class(%IPM.Test.Utils).CreateNamespace(ns1)
    do $$$AssertStatusOK(sc, "Created namespace " _ ns1)
    set sc = ##class(%IPM.Test.Utils).CreateNamespace(ns2)
    do $$$AssertStatusOK(sc, "Created namespace " _ ns2)

    // Map IPM and repos from current namespace into both targets
    set sc = ##class(%IPM.Main).Shell("enable -map -repos -ns " _ ns1 _ "," _ ns2 _ " -q")
    do $$$AssertStatusOK(sc, "enable -map -repos executed successfully")

    // Verify package/routine and repo globals mapped
    set originalNs = $namespace
    new $namespace
    set $namespace = "%SYS"
    for ns=ns1,ns2 {
        do $$$AssertTrue(##class(Config.MapPackages).Exists(ns, "%IPM"), "%IPM package mapped in " _ ns)
        do $$$AssertTrue(##class(Config.MapRoutines).Exists(ns, "%IPM.*"), "%IPM routines mapped in " _ ns)
        for suffix="D","S","I" {
            do $$$AssertTrue(##class(Config.MapGlobals).Exists(ns, "IPM.Repo.Definition"_suffix), "Repo global mapped in " _ ns _ " ("_suffix_")")
        }
    }

    // Cleanup
    set $namespace = originalNs
    for ns=ns1,ns2 {
        set sc = ##class(%IPM.Test.Utils).DeleteNamespace(ns)
        do $$$AssertStatusOK(sc, "Cleaned up namespace " _ ns)
    }
}

}
