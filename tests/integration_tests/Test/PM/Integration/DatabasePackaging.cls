/// Test class for database packaging functionality
Class Test.PM.Integration.DatabasePackaging Extends Test.PM.Integration.Base
{

/// Namespaces created during the current test — cleaned up in OnAfterOneTest.
Property CreatedNamespaces As %List;

/// Namespace active when the test class was invoked — restored after each test.
Property OriginalNamespace As %String;

/// Directory where .tgz packages are written during tests — wiped and recreated in OnBeforeOneTest.
Property PackageOutputDir As %String;

/// Globals databases created per-test — cleaned up in OnAfterOneTest.
/// Separate from the routines DB so dismounting during package-database doesn't lose IPM metadata.
Property CreatedGlobalsDatabases As %List;

/// Packaging namespaces are shared across tests to avoid the ~10s overhead of creating and
/// tearing down a namespace + globals DB for every test. Each shared NS is lazily initialized
/// on first use and cleaned up in OnAfterAllTests. Tests still create their own install
/// namespaces via CreateTestNamespace — those are per-test and cleaned up in OnAfterOneTest.
///
/// Sharing is safe because package-database does not modify namespace state — it creates a
/// temp DB elsewhere, compiles into it, and discards it. The loaded classes, globals, and
/// module registry in the shared NS are untouched. Any on-disk side effects (e.g. wheels
/// downloaded by ExportPythonDependencies) are the responsibility of the individual tests.
///
/// Shared NS for the majority of tests — generally along compiled-resource lines.
/// Lazily created by GetOrCreateSharedNS1; cleaned up in OnAfterAllTests.
Property SharedNS1 As %String;

/// Shared NS for Python/resource-heavy tests — generally along non-compiled-resource lines.
/// Lazily created by GetOrCreateSharedNS2; cleaned up in OnAfterAllTests.
/// Note: Each module loaded here must use a distinct PythonWheel filename — IPM disallows
/// two modules in the same namespace from claiming the same wheel. If adding a module with a
/// PythonWheel or requirements.txt, ensure it uses a wheel not already claimed by another
/// module in this namespace (e.g. lune, colorama, pycparser, packaging are already taken).
Property SharedNS2 As %String;

/// Globals databases for shared namespaces — tracked separately since they outlive individual tests.
/// Cleaned up in OnAfterAllTests.
Property SharedGlobalsDatabases As %List;

/// Defensive cleanup of leftover shared namespaces from interrupted previous runs.
Method OnBeforeAllTests() As %Status
{
    set ..OriginalNamespace = $namespace
    set ..SharedNS1 = ""
    set ..SharedNS2 = ""
    set ..SharedGlobalsDatabases = ""

    for i=1:1:2 {
        set ns = "TESTDBPKGNS" _ i
        set globalsDB = ns _ "G"
        do ##class(%IPM.Test.Utils).DeleteNamespace(ns)
        set dbPath = ##class(%IPM.Lifecycle.Database).GetDatabaseDirectory(globalsDB)
        try {
            new $namespace
            set $namespace = "%SYS"
            do ##class(SYS.Database).DismountDatabase(dbPath)
            if ##class(Config.Databases).Exists(globalsDB) {
                do ##class(Config.Databases).Delete(globalsDB)
            }
            do ##class(SYS.Database).DeleteDatabase(dbPath)
            set $namespace = ..OriginalNamespace
            if ##class(%Library.File).DirectoryExists(dbPath) {
                do ##class(%IPM.Utils.File).RemoveDirectoryTree(dbPath)
            }
        } catch ex {
            // Best-effort — may not exist from a previous clean run
        }
    }
    quit $$$OK
}

/// Resets test state: clears namespace/DB tracking lists, records original namespace,
/// and creates a clean package output directory (wiping any leftover from previous runs).
Method OnBeforeOneTest() As %Status
{
    set ..CreatedNamespaces = ""
    set ..CreatedGlobalsDatabases = ""
    set ..OriginalNamespace = $namespace
    set ..PackageOutputDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "pkg-test-output")
    if ##class(%Library.File).DirectoryExists(..PackageOutputDir) {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(..PackageOutputDir)
    }
    do ##class(%File).CreateDirectory(..PackageOutputDir)
    return $$$OK
}

/// Tears down all test namespaces and their dedicated globals databases created during the test.
/// Always restores $namespace to the original namespace first.
Method OnAfterOneTest() As %Status
{
    set sc = $$$OK
    set $namespace = ..OriginalNamespace

    // Clean up all created namespaces (and their main routines databases)
    for i=1:1:$listlength(..CreatedNamespaces) {
        set ns = $listget(..CreatedNamespaces, i)
        if (ns '= "") {
            set cleanupSC = ##class(%IPM.Test.Utils).DeleteNamespace(ns)
            set sc = $$$ADDSC(sc, cleanupSC)
        }
    }

    // Clean up the separate globals databases
    for i=1:1:$listlength(..CreatedGlobalsDatabases) {
        set dbName = $listget(..CreatedGlobalsDatabases, i)
        if dbName '= "" {
            set cleanupSC = $$$OK
            try {
                new $namespace
                set $namespace = "%SYS"
                set dbPath = ##class(%Library.File).NormalizeDirectory(
                    ##class(%Library.File).ManagerDirectory() _ dbName)
                // Best-effort dismount — may already be dismounted
                do ##class(SYS.Database).DismountDatabase(dbPath)
                $$$ThrowOnError(##class(Config.Databases).Delete(dbName))
                $$$ThrowOnError(##class(SYS.Database).DeleteDatabase(dbPath))
                set $namespace = ..OriginalNamespace
                if ##class(%Library.File).DirectoryExists(dbPath) {
                    do ##class(%IPM.Utils.File).RemoveDirectoryTree(dbPath)
                }
            } catch ex {
                set cleanupSC = ex.AsStatus()
            }
            set sc = $$$ADDSC(sc, cleanupSC)
        }
    }

    return sc
}

/// Tears down shared namespaces (TESTDBPKGNS1, TESTDBPKGNS2) and their globals databases.
/// Per-test namespaces and DBs are handled by OnAfterOneTest.
Method OnAfterAllTests() As %Status
{
    set sc = $$$OK
    set $namespace = ..OriginalNamespace

    // Clean up shared packaging namespaces (routines DBs)
    if ..SharedNS1 '= "" {
        set sc = $$$ADDSC(sc, ##class(%IPM.Test.Utils).DeleteNamespace(..SharedNS1))
    }
    if ..SharedNS2 '= "" {
        set sc = $$$ADDSC(sc, ##class(%IPM.Test.Utils).DeleteNamespace(..SharedNS2))
    }

    // Clean up shared globals databases
    for i=1:1:$listlength(..SharedGlobalsDatabases) {
        set dbName = $listget(..SharedGlobalsDatabases, i)
        if dbName '= "" {
            set dbPath = ##class(%IPM.Lifecycle.Database).GetDatabaseDirectory(dbName)
            try {
                new $namespace
                set $namespace = "%SYS"
                do ##class(SYS.Database).DismountDatabase(dbPath)
                if ##class(Config.Databases).Exists(dbName) {
                    $$$ThrowOnError(##class(Config.Databases).Delete(dbName))
                }
                $$$ThrowOnError(##class(SYS.Database).DeleteDatabase(dbPath))
                set $namespace = ..OriginalNamespace
                if ##class(%Library.File).DirectoryExists(dbPath) {
                    do ##class(%IPM.Utils.File).RemoveDirectoryTree(dbPath)
                }
            } catch ex {
                set sc = $$$ADDSC(sc, ex.AsStatus())
            }
        }
    }

    return sc
}

/// Creates a test namespace with a separate globals database.
/// The routines database (pNamespace) can be safely dismounted during
/// package-database or database swap without losing IPM metadata globals.
Method CreateTestNamespace(pNamespace As %String) As %Status
{
    // Create the standard namespace (initially Globals=pNamespace, Routines=pNamespace)
    set sc = ##class(%IPM.Test.Utils).CreateNamespace(pNamespace)
    if $$$ISERR(sc) {
        return sc
    }
    set ..CreatedNamespaces = ..CreatedNamespaces _ $listbuild(pNamespace)

    // Create a dedicated globals database so dismounting the routines DB
    // during packaging or swap doesn't lose IPM metadata (^IPM.Storage.*)
    set globalsDBName = pNamespace _ "G"
    set sc = $$$OK
    try {
        new $namespace
        set $namespace = "%SYS"

        set globalsPath = ##class(%Library.File).NormalizeDirectory(
            ##class(%Library.File).ManagerDirectory() _ globalsDBName)

        // Clean up any leftover state from a previous test run
        // Check both directory existence and DB registration independently
        if ##class(%Library.File).DirectoryExists(globalsPath) {
            do ##class(SYS.Database).DismountDatabase(globalsPath)
            do ##class(SYS.Database).DeleteDatabase(globalsPath)
            if ##class(%Library.File).DirectoryExists(globalsPath) {
                set $namespace = ..OriginalNamespace
                do ##class(%IPM.Utils.File).RemoveDirectoryTree(globalsPath)
                set $namespace = "%SYS"
            }
        }
        if ##class(Config.Databases).Exists(globalsDBName) {
            do ##class(Config.Databases).Delete(globalsDBName)
        }

        if '##class(%Library.File).CreateDirectory(globalsPath, .result) {
            set tMsg = "Failed to create globals DB directory: " _ result
            $$$ThrowStatus($$$ERROR($$$GeneralError, tMsg))
        }

        $$$ThrowOnError(##class(SYS.Database).CreateDatabase(globalsPath))

        set dbProps("Directory") = globalsPath
        set dbProps("MountRequired") = 1
        $$$ThrowOnError(##class(Config.Databases).Create(globalsDBName, .dbProps))

        set mountSC = ##class(SYS.Database).MountDatabase(globalsPath)
        if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
            $$$ThrowOnError(mountSC)
        }

        $$$ThrowOnError(##class(Config.Namespaces).Get(pNamespace, .nsProps))
        set nsProps("Globals") = globalsDBName
        $$$ThrowOnError(##class(Config.Namespaces).Modify(pNamespace, .nsProps))

        set ..CreatedGlobalsDatabases = ..CreatedGlobalsDatabases _ $listbuild(globalsDBName)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Returns the shared packaging namespace for core modules (generally compiled-resource tests).
/// Creates TESTDBPKGNS1 on first call and loads all relevant modules; reuses on subsequent calls.
/// GetModuleDir calls are made before any namespace switch since ^UnitTestRoot is only in origNS.
Method GetOrCreateSharedNS1() As %String
{
    if ..SharedNS1 '= "" {
        quit ..SharedNS1
    }

    set ns = "TESTDBPKGNS1"

    // Resolve all module dirs before switching namespace (^UnitTestRoot only in original NS)
    set depModuleDir = ..GetModuleDir("db-packaging", "dependency-module")
    set simpleDir = ..GetModuleDir("db-packaging", "simple-module")
    set withDepsDir = ..GetModuleDir("db-packaging", "module-with-deps")
    set testsDir = ..GetModuleDir("db-packaging", "module-with-tests")
    set invokesDir = ..GetModuleDir("db-packaging", "module-with-invokes")

    $$$ThrowOnError(..CreateTestNamespace(ns))
    // Move the shared NS from per-test tracking to shared tracking so OnAfterOneTest
    // doesn't clean it up prematurely
    set lastIdx = $listlength(..CreatedNamespaces)
    set ..CreatedNamespaces = $list(..CreatedNamespaces, 1, lastIdx - 1)
    set lastIdx = $listlength(..CreatedGlobalsDatabases)
    set lastDB = $list(..CreatedGlobalsDatabases, lastIdx)
    set ..CreatedGlobalsDatabases = $list(..CreatedGlobalsDatabases, 1, lastIdx - 1)
    set ..SharedGlobalsDatabases = ..SharedGlobalsDatabases _ $listbuild(lastDB)

    new $namespace
    set $namespace = ns
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ depModuleDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ simpleDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ withDepsDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ testsDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ invokesDir))
    // Configure the local zot ORAS registry once for ORAS-related tests
    $$$ThrowOnError(##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000"))

    set ..SharedNS1 = ns
    quit ns
}

/// Returns the shared packaging namespace for Python/resource-heavy modules (generally non-compiled-resource tests).
/// Creates TESTDBPKGNS2 on first call and loads all relevant modules; reuses on subsequent calls.
Method GetOrCreateSharedNS2() As %String
{
    if ..SharedNS2 '= "" {
        quit ..SharedNS2
    }

    set ns = "TESTDBPKGNS2"

    // Resolve all module dirs before switching namespace (^UnitTestRoot only in original NS)
    set allResDir = ..GetModuleDir("db-packaging", "module-with-all-resources")
    set reqsDir = ..GetModuleDir("db-packaging", "module-with-requirements")
    set mixPyDir = ..GetModuleDir("db-packaging", "module-with-mixed-python")
    set nonCmpDir = ..GetModuleDir("db-packaging", "module-with-non-compiled-resources")

    $$$ThrowOnError(..CreateTestNamespace(ns))
    // Move the shared NS from per-test tracking to shared tracking
    set lastIdx = $listlength(..CreatedNamespaces)
    set ..CreatedNamespaces = $list(..CreatedNamespaces, 1, lastIdx - 1)
    set lastIdx = $listlength(..CreatedGlobalsDatabases)
    set lastDB = $list(..CreatedGlobalsDatabases, lastIdx)
    set ..CreatedGlobalsDatabases = $list(..CreatedGlobalsDatabases, 1, lastIdx - 1)
    set ..SharedGlobalsDatabases = ..SharedGlobalsDatabases _ $listbuild(lastDB)

    new $namespace
    set $namespace = ns
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ allResDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ reqsDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ mixPyDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ nonCmpDir))

    set ..SharedNS2 = ns
    quit ns
}

/// Test simple package and install with database packaging
Method TestSimplePackageAndInstall()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (simple-db-module and dep-module are pre-loaded)
    new $namespace
    set $namespace = packagingNS

    // Package as database package
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module as database package")

    // Verify package file exists
    set packageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%File).Exists(packageFile), "Database package .tgz file exists")

    // Extract and verify contents
    set extractDir = ##class(%File).NormalizeDirectory(..PackageOutputDir _ "extract")
    do ##class(%File).CreateDirectory(extractDir)
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, extractDir)
    do $$$AssertStatusOK(sc, "Extracted package contents for verification")

    // Verify IRIS.DAT exists in extracted package
    set irisDataFile = ##class(%File).NormalizeDirectory(extractDir) _ "IRIS.DAT"
    do $$$AssertTrue(##class(%File).Exists(irisDataFile), "IRIS.DAT file exists in package")
    do $$$AssertTrue(##class(%File).GetFileSize(irisDataFile) > 0, "IRIS.DAT is not zero-sized")

    // Verify module.xml exists and contains database packaging metadata
    set moduleXMLFile = ##class(%File).NormalizeDirectory(extractDir) _ "module.xml"
    do $$$AssertTrue(##class(%File).Exists(moduleXMLFile), "module.xml exists in package")

    // Read and verify module.xml content
    set stream = ##class(%Stream.FileCharacter).%New()
    set sc = stream.LinkToFile(moduleXMLFile)
    do $$$AssertStatusOK(sc, "Linked to module.xml file")

    set xmlContent = stream.Read()
    do $$$AssertTrue(xmlContent [ "<Packaging>database</Packaging>", "module.xml contains <Packaging>database</Packaging>")
    do $$$AssertTrue(xmlContent [ "<Checksum Algorithm=""SHA-256"">", "module.xml contains SHA-256 checksum")

    // SystemRequirements Version should be auto-populated with the current IRIS version
    set currentIrisVersion = $system.Version.GetMajor() _ "." _ $system.Version.GetMinor()
    do $$$AssertTrue(xmlContent [ "Version=""" _ currentIrisVersion _ """", "module.xml SystemRequirements Version matches current IRIS version")

    // Verify deps/ directory exists
    set extractedDepsDir = ##class(%File).NormalizeDirectory(extractDir) _ "deps/"
    do $$$AssertTrue(##class(%File).DirectoryExists(extractedDepsDir), "deps/ directory exists in package")

    // Create a new test namespace for installation
    set installNS = "TESTDBINST1"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation test namespace")

    set $namespace = installNS

    // Install database package with -swap-db flag
    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package successfully")

    // Verify classes are accessible
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "SimpleModule.Main class exists")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Utils"), "SimpleModule.Utils class exists")

    // Verify classes work correctly
    set result = ##class(SimpleModule.Main).GetMessage()
    do $$$AssertEquals(result, "Hello from Simple DB Module", "SimpleModule.Main.GetMessage() works")

    set addResult = ##class(SimpleModule.Main).Add(5, 3)
    do $$$AssertEquals(addResult, 8, "SimpleModule.Main.Add() works")

    // Verify module appears in zpm list
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("list")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    do $$$AssertStatusOK(sc, "List command executed")
    do $$$AssertTrue(..FindStringInMultiDimArray("simple-db-module", .output), "Module appears in zpm list")

    // Verify installation is recorded in history
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("history")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .historyOutput)
    do $$$AssertStatusOK(sc, "History command executed")
    do $$$AssertTrue(..FindStringInMultiDimArray("simple-db-module", .historyOutput), "Installation recorded in history")
}

/// Test packaging and installing modules with dependencies
/// Tests dependency packaging behaviour: both default flow and -use-current-db must
/// produce a self-contained IRIS.DAT that includes transitive dependency code.
///
/// Isolation check: packaging dep-module alone must NOT include MainModule.App
/// (main-with-deps is installed in the packaging NS but never compiled into dep-module's DB).
Method TestPackageAndInstallWithDependencies()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    new $namespace
    set $namespace = packagingNS

    // --- Part 1: dep-module (no deps) — isolation check ---
    // main-with-deps depends on dep-module, but must not appear in dep-module's IRIS.DAT.
    set sc = ##class(%IPM.Main).Shell("package-database dep-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged dep-module")

    set depPkg = ..PackageOutputDir _ "dep-module-1.0.0-database.tgz"

    set installNS1 = "TESTDBDEPINST1"
    set sc = ..CreateTestNamespace(installNS1)
    do $$$AssertStatusOK(sc, "Created install NS for dep-module")
    set $namespace = installNS1

    set sc = ##class(%IPM.Main).Shell("load " _ depPkg _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed dep-module database package")

    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepModule.Core"), "DepModule.Core present after dep-module install")
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("MainModule.App"), "MainModule.App absent — unpackaged parent not compiled into dep-module's IRIS.DAT")
    set result = ##class(DepModule.Core).GetVersion()
    do $$$AssertEquals(result, "1.0.0", "DepModule.Core.GetVersion() works")

    // --- Part 2: main-with-deps default flow — deps must be included ---
    // The IRIS.DAT must be self-contained: dep code compiled in, UseDependency() callable.
    set $namespace = packagingNS
    set sc = ##class(%IPM.Main).Shell("package-database main-with-deps -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged main-with-deps (default flow)")

    set mainPkg = ..PackageOutputDir _ "main-with-deps-1.0.0-database.tgz"

    set installNS2 = "TESTDBDEPINST2"
    set sc = ..CreateTestNamespace(installNS2)
    do $$$AssertStatusOK(sc, "Created install NS for main-with-deps")
    set $namespace = installNS2

    set sc = ##class(%IPM.Main).Shell("load " _ mainPkg _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed main-with-deps")

    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("MainModule.App"), "MainModule.App present after install")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepModule.Core"), "DepModule.Core present — transitive dep compiled into IRIS.DAT")
    set depResult = ##class(MainModule.App).UseDependency()
    do $$$AssertTrue(depResult [ "1.0.0", "UseDependency() works — dep code is callable")

    // dep-module metadata also registered via deps/ manifest
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("list")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .listOutput)
    do $$$AssertTrue(..FindStringInMultiDimArray("dep-module", .listOutput), "dep-module appears in list (metadata from deps/)")
}

/// Smoke test: a module using every compiled resource type (class, include, generated class,
/// WebApplication) packages and installs correctly as a database package.
/// Asserts on the compiled outputs — class existence, runtime behavior, WebApp creation.
///
/// Distinct from TestNonCompiledResourcesAppliedDuringInstall: this test does not attempt to
/// prove that non-compiled processor hooks fire during install. It uses module-with-all-resources
/// (FileCopy, PythonWheel, WebApp present) because real modules mix resource types; the goal
/// is to confirm nothing breaks, not to assert on each non-compiled resource individually.
Method TestPackageAndInstallAllResourceTypes()
{
    set packagingNS = ..GetOrCreateSharedNS2()

    // Switch to shared packaging namespace (all-resources-module is pre-loaded)
    new $namespace
    set $namespace = packagingNS

    // Package as database
    set sc = ##class(%IPM.Main).Shell("package-database all-resources-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module with all resources")

    set packageFile = ..PackageOutputDir _ "all-resources-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBRESINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install the package
    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed module with all resources")

    // Verify classes exist
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("AllResources.Main"), "AllResources.Main class exists")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("AllResources.Generated"), "Generated resource class exists")

    // Verify class can use include file
    set result = ##class(AllResources.Main).Process()
    do $$$AssertTrue(result [ "TestValue", "Include file constant is accessible")

    // Verify generated resource works
    set genResult = ##class(AllResources.Generated).GetGeneratedValue()
    do $$$AssertEquals(genResult, "Generated resource value", "Generated resource class works")

    // Verify WebApplication was created
    new $namespace
    set $namespace = "%SYS"
    set webAppExists = ##class(Security.Applications).Exists("/allresources")
    set $namespace = installNS
    do $$$AssertTrue(webAppExists, "WebApplication /allresources created")

}

/// Test packaging with and without test resources
Method TestPackageAndInstallWithTestResources()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (module-with-tests is pre-loaded)
    new $namespace
    set $namespace = packagingNS

    // Package WITH test resources
    set sc = ##class(%IPM.Main).Shell("package-database module-with-tests -dev -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged with test resources")

    // Install and verify test resources are present
    set packageFileWithTests = ..PackageOutputDir _ "module-with-tests-1.0.0-database.tgz"

    set installNS1 = "TESTDBTESTINS1"
    set sc = ..CreateTestNamespace(installNS1)
    do $$$AssertStatusOK(sc, "Created installation namespace 1")

    set $namespace = installNS1
    set sc = ##class(%IPM.Main).Shell("load " _ packageFileWithTests _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed with test resources")

    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.Test"), "Test class (Type B UnitTest) exists when included")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.TestHelper"), "TestHelper class (Type A Scope=test) exists when included")

    // Package WITHOUT test resources (default)
    set $namespace = packagingNS
    set sc = ##class(%IPM.Main).Shell("package-database module-with-tests -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged without test resources")

    set packageFileNoTests = ..PackageOutputDir _ "module-with-tests-1.0.0-database.tgz"

    set installNS2 = "TESTDBTESTINS2"
    set sc = ..CreateTestNamespace(installNS2)
    do $$$AssertStatusOK(sc, "Created installation namespace 2")

    set $namespace = installNS2
    set sc = ##class(%IPM.Main).Shell("load " _ packageFileNoTests _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed without test resources")

    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.Test"), "Test class excluded by default")
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.TestHelper"), "TestHelper class excluded by default")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.Main"), "Main class exists")
}

/// Test packaging and install validation (errors and edge cases)
Method TestPackagingAndInstallValidation()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (simple-db-module is pre-loaded)
    new $namespace
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module")

    set packageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"

    // Test: Checksum validation - tamper with IRIS.DAT
    // Extract package, modify IRIS.DAT, repack, attempt install
    // This should fail with checksum mismatch error
    set installNS = "TESTDBVALIDINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Valid package installs successfully")

    // Test: Tampered IRIS.DAT fails checksum validation
    set tamperDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "tamper-extract")
    do ##class(%Library.File).CreateDirectory(tamperDir)
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, tamperDir)
    do $$$AssertStatusOK(sc, "Extracted package for tampering test")

    set tamperedIRISDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", tamperDir)
    do ##class(%Library.File).Delete(tamperedIRISDAT)
    set tamperTmp = ##class(%Library.File).TempFilename("dat")
    set tamperedStream = ##class(%Stream.FileBinary).%New()
    $$$ThrowOnError(tamperedStream.LinkToFile(tamperTmp))
    do tamperedStream.Write("NOT_A_REAL_IRIS_DATABASE_FILE")
    $$$ThrowOnError(tamperedStream.%Save())
    if '##class(%Library.File).Rename(tamperTmp, tamperedIRISDAT) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot rename tamper file to IRIS.DAT"))
    }

    set tamperedPackage = ..PackageOutputDir _ "simple-db-module-tampered.tgz"
    set sc = ##class(%IPM.General.Archive).Create(tamperDir, tamperedPackage)
    do $$$AssertStatusOK(sc, "Repacked tampered archive")

    set installNS2 = "TESTDBVALIDINS2"
    set sc = ..CreateTestNamespace(installNS2)
    do $$$AssertStatusOK(sc, "Created namespace for tampered install test")
    set $namespace = installNS2

    set sc = ##class(%IPM.Main).Shell("load " _ tamperedPackage _ " -swap-db")
    do $$$AssertStatusNotOK(sc, "Tampered IRIS.DAT rejected by checksum validation")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "SHA-256", "Error mentions SHA-256 checksum mismatch")

    // Test: Missing deps/ directory fails validation
    set missingDepsDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "missing-deps-extract")
    do ##class(%Library.File).CreateDirectory(missingDepsDir)
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, missingDepsDir)
    do $$$AssertStatusOK(sc, "Extracted package for missing deps/ test")

    set missingDepsSubDir = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).NormalizeFilename("deps", missingDepsDir))
    do ##class(%Library.File).RemoveDirectoryTree(missingDepsSubDir)

    set missingDepsPackage = ..PackageOutputDir _ "simple-db-module-missing-deps.tgz"
    set sc = ##class(%IPM.General.Archive).Create(missingDepsDir, missingDepsPackage)
    do $$$AssertStatusOK(sc, "Repacked archive without deps/ directory")

    set installNS3 = "TESTDBVALIDINS3"
    set sc = ..CreateTestNamespace(installNS3)
    do $$$AssertStatusOK(sc, "Created namespace for missing-deps test")
    set $namespace = installNS3

    set sc = ##class(%IPM.Main).Shell("load " _ missingDepsPackage _ " -swap-db")
    do $$$AssertStatusNotOK(sc, "Missing deps/ directory rejected by validation")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "deps/", "Error mentions missing deps/ directory")
}

/// Test upgrading from source package to database package
Method TestUpgradeSourceToDatabase()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (simple-db-module is pre-loaded)
    new $namespace
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package simple-db-module -path " _ ..PackageOutputDir _ "simple-db-module-1.0.0/")
    do $$$AssertStatusOK(sc, "Packaged as source")

    set sourcePackage = ..PackageOutputDir _ "simple-db-module-1.0.0.tgz"

    // Create installation namespace
    set installNS = "TESTDBUPGSRCINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install source package
    set sc = ##class(%IPM.Main).Shell("load " _ sourcePackage)
    do $$$AssertStatusOK(sc, "Installed source package")

    // Verify source installed
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Source package installed")

    // Now package as database and upgrade
    set $namespace = packagingNS
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged as database")

    set dbPackage = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"

    set $namespace = installNS

    // Upgrade from source to database package
    set sc = ##class(%IPM.Main).Shell("update simple-db-module -path " _ dbPackage _ " -swap-db")
    do $$$AssertStatusOK(sc, "Upgraded from source to database package")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Module still installed after upgrade")

    // Verify module metadata was migrated: packaging type must now be 'database'
    set module = ##class(%IPM.Storage.Module).NameOpen("simple-db-module")
    do $$$AssertEquals(module.Packaging, "database", "Module packaging changed to 'database' after source-to-database upgrade")

    // Verify a DB swap occurred (at least one backup was created)
    do $$$AssertTrue(..CountBackupFiles(installNS) > 0, "DB swap occurred during source-to-database upgrade")
}

/// Test uninstalling database package
Method TestUninstallDatabasePackage()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (simple-db-module is pre-loaded)
    new $namespace
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module")

    set packageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBUNINSNS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install database package
    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package")

    // Verify installation
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Module installed")

    // Uninstall the module
    set sc = ##class(%IPM.Main).Shell("uninstall simple-db-module")
    do $$$AssertStatusOK(sc, "Uninstalled database package")

    // Verify module is removed
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("list")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertNotTrue(..FindStringInMultiDimArray("simple-db-module", .output), "Module no longer in list")

    // Verify backup file is preserved after uninstall (user manages cleanup)
    do $$$AssertTrue(..CountBackupFiles(installNS) > 0, "Backup file preserved after uninstall")

    // Verify compiled classes are removed from the routines DB (spec: uninstall deletes compiled resources)
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Classes removed from namespace after uninstall")
}

/// Test mixed packaging scenarios
Method TestMixedPackaging()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (simple-db-module and dep-module are pre-loaded)
    new $namespace
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged as database")

    set dbPackageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBMIXEDINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install database package
    set sc = ##class(%IPM.Main).Shell("load " _ dbPackageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package")

    // Test: Install source package in same namespace should work
    // dep-module is pre-loaded in shared NS1; package it as source first
    set $namespace = packagingNS
    set sc = ##class(%IPM.Main).Shell("package dep-module -path " _ ..PackageOutputDir _ "dep-module-1.0.0/")
    do $$$AssertStatusOK(sc, "Packaged as source")

    set sourcePackageFile = ..PackageOutputDir _ "dep-module-1.0.0.tgz"

    set $namespace = installNS

    // Install source package in namespace with database package
    set sc = ##class(%IPM.Main).Shell("load " _ sourcePackageFile)
    do $$$AssertStatusOK(sc, "Installed source package alongside database package")

    // Verify both packages exist
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("list")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertTrue(..FindStringInMultiDimArray("simple-db-module", .output), "Database package in list")
    do $$$AssertTrue(..FindStringInMultiDimArray("dep-module", .output), "Source package in list")

    // Test: Cannot install second database package in same namespace
    // dep-module is pre-loaded in shared NS1 — just package it as database
    set $namespace = packagingNS
    set sc = ##class(%IPM.Main).Shell("package-database dep-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged dep-module as database")

    set dbPackage2 = ..PackageOutputDir _ "dep-module-1.0.0-database.tgz"

    set $namespace = installNS

    // Attempt to install second database package should fail
    set sc = ##class(%IPM.Main).Shell("load " _ dbPackage2 _ " -swap-db")
    do $$$AssertStatusNotOK(sc, "Cannot install second database package in same namespace")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "Only one database package", "Error mentions one-package-per-namespace constraint")
}

/// A database install replaces the namespace's routines DB wholesale, so any module whose code
/// lives in that DB would lose its classes while its metadata (in the globals DB) survived.
/// Verifies that install is rejected in that case, and that uninstalling the module clears the way.
///
/// Also verifies the two exemptions: the package's own transitive dependencies (their code is in
/// the incoming IRIS.DAT) and modules with no routines-DB code do not trigger the rejection.
Method TestInstallRejectedWhenModulesWouldBeOrphaned()
{
    set depModuleDir = ..GetModuleDir("db-packaging", "dependency-module")
    set noCodeDir = ..GetModuleDir("db-packaging", "module-without-code")

    set packagingNS = ..GetOrCreateSharedNS1()
    new $namespace
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged simple-db-module as database")
    set dbPackage = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"

    // main-with-deps depends on dep-module, so dep-module's code ships inside this IRIS.DAT
    set sc = ##class(%IPM.Main).Shell("package-database main-with-deps -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged main-with-deps as database")
    set withDepsPackage = ..PackageOutputDir _ "main-with-deps-1.0.0-database.tgz"

    // --- Rejection: a source module with classes in the routines DB blocks the install ---
    set installNS = "TESTDBORPHANINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created install namespace")
    set $namespace = installNS

    set sc = ##class(%IPM.Main).Shell("load -v " _ depModuleDir)
    do $$$AssertStatusOK(sc, "Loaded dep-module from source into install namespace")

    set sc = ##class(%IPM.Main).Shell("load " _ dbPackage _ " -swap-db")
    do $$$AssertStatusNotOK(sc, "Install rejected — dep-module's code would be destroyed by the swap")
    set errorText = $system.Status.GetErrorText(sc)
    do $$$AssertTrue(errorText [ "dep-module", "Error names the module that would be orphaned")
    do $$$AssertTrue(errorText [ "uninstall", "Error tells the user to uninstall first")

    // The rejection happens before any swap, so the original DB must be untouched
    do $$$AssertEquals(..CountBackupFiles(installNS), 0, "No DB swap occurred — rejection is pre-swap")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepModule.Core"), "dep-module's classes still present after rejection")

    // --- Uninstalling the blocking module clears the way ---
    set sc = ##class(%IPM.Main).Shell("uninstall dep-module")
    do $$$AssertStatusOK(sc, "Uninstalled dep-module")

    set sc = ##class(%IPM.Main).Shell("load " _ dbPackage _ " -swap-db")
    do $$$AssertStatusOK(sc, "Install succeeds once the blocking module is uninstalled")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Database package installed")

    // --- Exemption: a module with no routines-DB code does not block ---
    // module-without-code has only a FileCopy resource, which lives on the filesystem rather
    // than in the routines DB, so the swap cannot orphan it.
    set installNS2 = "TESTDBORPHANINS2"
    set sc = ..CreateTestNamespace(installNS2)
    do $$$AssertStatusOK(sc, "Created second install namespace")
    set $namespace = installNS2

    set sc = ##class(%IPM.Main).Shell("load -v " _ noCodeDir)
    do $$$AssertStatusOK(sc, "Loaded module-without-code from source")

    set sc = ##class(%IPM.Main).Shell("load " _ dbPackage _ " -swap-db")
    do $$$AssertStatusOK(sc, "Module with no routines-DB code does not block the install")

    // --- Exemption: the package's own transitive dependencies do not block ---
    // dep-module is installed as source here, but main-with-deps carries its code and metadata,
    // so the swap replaces rather than orphans it.
    set installNS3 = "TESTDBORPHANINS3"
    set sc = ..CreateTestNamespace(installNS3)
    do $$$AssertStatusOK(sc, "Created third install namespace")
    set $namespace = installNS3

    set sc = ##class(%IPM.Main).Shell("load -v " _ depModuleDir)
    do $$$AssertStatusOK(sc, "Loaded dep-module from source into third namespace")

    set sc = ##class(%IPM.Main).Shell("load " _ withDepsPackage _ " -swap-db")
    do $$$AssertStatusOK(sc, "Packaged dependency does not block the install")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepModule.Core"), "dep-module's code came from the packaged IRIS.DAT")
}

/// Upgrading a database package whose dependency tree changed shape must not be blocked by the
/// orphan check, and dependencies that no longer ship in the new IRIS.DAT must have their stale
/// IPM metadata removed rather than left behind pointing at code that is gone.
///
/// deptree-parent v1 -> v2 exercises all four kinds of change at once. The comparison is between
/// flattened dependency sets, so re-parenting is invisible to it:
///
///   v1: deptree-dropped -> deptree-leaf     v2: deptree-added  -> deptree-leaf
///       deptree-stable 1.0.0                    deptree-stable 2.0.0 -> deptree-extra
///
///   deptree-dropped  in v1 only  -> dropped dependency, metadata must be cleaned up
///   deptree-added    in v2 only  -> new direct dependency
///   deptree-leaf     in both     -> re-parented transitive dependency, must survive untouched
///   deptree-extra    in v2 only  -> new transitive dependency under an unchanged carrier
///
/// deptree-leaf and deptree-extra are deliberately reached through different parents than the
/// added/dropped pair so that each feature is isolated: a bug that keys off direct dependencies
/// rather than the flattened set fails on deptree-leaf, and one that ignores transitive additions
/// fails on deptree-extra.
Method TestUpdateWithChangedDependencyTree()
{
    // Resolve all module dirs before any namespace switch (^UnitTestRoot only in the original NS)
    set leafDir = ..GetModuleDir("db-packaging", "deptree-leaf")
    set extraDir = ..GetModuleDir("db-packaging", "deptree-extra")
    set droppedDir = ..GetModuleDir("db-packaging", "deptree-dropped")
    set addedDir = ..GetModuleDir("db-packaging", "deptree-added")
    set stableV1Dir = ..GetModuleDir("db-packaging", "deptree-stable-v1")
    set stableV2Dir = ..GetModuleDir("db-packaging", "deptree-stable-v2")
    set parentV1Dir = ..GetModuleDir("db-packaging", "deptree-parent-v1")
    set parentV2Dir = ..GetModuleDir("db-packaging", "deptree-parent-v2")

    // A dedicated packaging NS rather than a shared one: this test loads two different versions
    // of deptree-parent and deptree-stable, which would corrupt the shared namespaces' registries.
    set packagingNS = "TESTDBDEPTREEPKG"
    do $$$AssertStatusOK(..CreateTestNamespace(packagingNS), "Created packaging namespace")

    new $namespace
    set $namespace = packagingNS

    // --- Package v1: deptree-dropped (-> deptree-leaf) and deptree-stable 1.0.0 ---
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ leafDir), "Loaded deptree-leaf")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ droppedDir), "Loaded deptree-dropped")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ stableV1Dir), "Loaded deptree-stable 1.0.0")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ parentV1Dir), "Loaded deptree-parent 1.0.0")

    set sc = ##class(%IPM.Main).Shell("package-database deptree-parent -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged deptree-parent 1.0.0 as database")
    set v1Package = ..PackageOutputDir _ "deptree-parent-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%Library.File).Exists(v1Package), "v1 database package exists")

    // --- Reshape the tree in the packaging NS, then package v2 ---
    // deptree-added and deptree-extra are new; deptree-stable gains the deptree-extra edge at 2.0.0.
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ extraDir), "Loaded deptree-extra")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ addedDir), "Loaded deptree-added")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("update deptree-stable -path " _ stableV2Dir), "Updated deptree-stable to 2.0.0")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("update deptree-parent -path " _ parentV2Dir), "Updated deptree-parent to 2.0.0")

    set sc = ##class(%IPM.Main).Shell("package-database deptree-parent -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged deptree-parent 2.0.0 as database")
    set v2Package = ..PackageOutputDir _ "deptree-parent-2.0.0-database.tgz"
    do $$$AssertTrue(##class(%Library.File).Exists(v2Package), "v2 database package exists")

    // --- Install v1 into a clean namespace ---
    set installNS = "TESTDBDEPTREEINST"
    do $$$AssertStatusOK(..CreateTestNamespace(installNS), "Created install namespace")
    set $namespace = installNS

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ v1Package _ " -swap-db"), "Installed deptree-parent 1.0.0")

    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Parent"), "Parent class present after v1 install")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Dropped"), "deptree-dropped code in v1 IRIS.DAT")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Leaf"), "deptree-leaf code in v1 IRIS.DAT")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-dropped"), "deptree-dropped metadata registered from v1 deps/")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-leaf"), "deptree-leaf metadata registered from v1 deps/")
    do $$$AssertNotTrue(##class(%IPM.Storage.Module).NameExists("deptree-added"), "deptree-added absent before upgrade")
    do $$$AssertNotTrue(##class(%IPM.Storage.Module).NameExists("deptree-extra"), "deptree-extra absent before upgrade")

    // --- Upgrade to v2 ---
    // Every module installed here arrived inside v1's IRIS.DAT, so none of them may trigger the
    // orphan rejection — including deptree-dropped, which v2 no longer carries.
    set sc = ##class(%IPM.Main).Shell("update deptree-parent -path " _ v2Package _ " -swap-db")
    do $$$AssertStatusOK(sc, "Upgrade not blocked by the orphan check despite the reshaped tree")

    // Dropped dependency: code is gone from the new IRIS.DAT, so its metadata must go too
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Dropped"), "deptree-dropped code absent from v2 IRIS.DAT")
    do $$$AssertNotTrue(##class(%IPM.Storage.Module).NameExists("deptree-dropped"), "deptree-dropped metadata cleaned up — no record pointing at missing code")

    // New direct dependency
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Added"), "deptree-added code in v2 IRIS.DAT")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-added"), "deptree-added metadata registered from v2 deps/")

    // Re-parented transitive dependency: moved from deptree-dropped to deptree-added, must survive
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Leaf"), "deptree-leaf code still present after re-parenting")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-leaf"), "deptree-leaf metadata retained — re-parenting is not a drop")

    // New transitive dependency under the unchanged carrier
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Extra"), "deptree-extra code in v2 IRIS.DAT")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-extra"), "deptree-extra metadata registered from v2 deps/")

    // The unchanged carrier itself
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Stable"), "deptree-stable code present after upgrade")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-stable"), "deptree-stable metadata retained")

    do $$$AssertTrue(..CountBackupFiles(installNS) > 1, "Second backup created — the DB was swapped again during the upgrade")
}

/// Tests all Python dependency packaging behaviour in one pass:
/// - module-with-mixed-python (explicit PythonWheel + requirements.txt): both wheels present
///   by default; both absent with -export-python-deps 0; lune installs correctly at runtime
/// - module-with-requirements (requirements.txt only): wheel present by default; absent with flag
/// Combining these avoids packaging module-with-mixed-python twice across separate test methods.
Method TestPythonDependencyPackaging()
{
    // Capture module dirs before NS switch — GetModuleDir uses ^UnitTestRoot which is only set here
    set mixedModuleDir = ..GetModuleDir("db-packaging", "module-with-mixed-python")
    set reqModuleDir = ..GetModuleDir("db-packaging", "module-with-requirements")

    set packagingNS = ..GetOrCreateSharedNS2()
    new $namespace
    set $namespace = packagingNS

    // module-with-mixed-python: default (export-python-deps)
    // Packages both an explicit <PythonWheel> (lune) and a requirements.txt dep (pycparser)
    set sc = ##class(%IPM.Main).Shell("package-database module-with-mixed-python -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module-with-mixed-python with default settings")

    set defaultPkg = ..PackageOutputDir _ "module-with-mixed-python-1.0.0-database.tgz"
    set extractDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-mixpy")
    do ##class(%Library.File).CreateDirectory(extractDir)
    set sc = ##class(%IPM.General.Archive).Extract(defaultPkg, extractDir)
    do $$$AssertStatusOK(sc, "Extracted module-with-mixed-python default package")

    set luneWheel = ##class(%Library.File).NormalizeFilename("wheels/lune-1.6.2-py3-none-any.whl", extractDir)
    do $$$AssertTrue(##class(%Library.File).Exists(luneWheel), "Explicit PythonWheel (lune) included in default package")

    set wheelsDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).NormalizeFilename("wheels", extractDir))
    set pycparserFound = 0
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %Library.File_FileSet(?, ?, ?, ?)", wheelsDir, "pycparser*.whl", "", 0)
    while rs.%Next() { set pycparserFound = 1 }
    do $$$AssertTrue(pycparserFound, "requirements.txt wheel (pycparser) included in default package")

    // module-with-mixed-python: -export-python-deps 0
    set noExportDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "noexport")
    do ##class(%Library.File).CreateDirectory(noExportDir)
    set sc = ##class(%IPM.Main).Shell("package-database module-with-mixed-python -export-python-deps 0 -path " _ noExportDir)
    do $$$AssertStatusOK(sc, "Packaged module-with-mixed-python with -export-python-deps 0")

    set noExportPkg = noExportDir _ "module-with-mixed-python-1.0.0-database.tgz"
    set extractDir2 = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-nowheel")
    do ##class(%Library.File).CreateDirectory(extractDir2)
    set sc = ##class(%IPM.General.Archive).Extract(noExportPkg, extractDir2)
    do $$$AssertStatusOK(sc, "Extracted no-export package")

    set wheelInNoExport = ##class(%Library.File).NormalizeFilename("wheels/lune-1.6.2-py3-none-any.whl", extractDir2)
    do $$$AssertNotTrue(##class(%Library.File).Exists(wheelInNoExport), "Wheel excluded when -export-python-deps 0 is set")

    // Runtime install: PythonWheel.OnPhase("Initialize") fires (no Database.cls override)
    set installNS = "TESTDBPYWHLINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created install namespace")
    set $namespace = installNS

    do ..PurgePythonPackage("lune")

    set sc = ##class(%IPM.Main).Shell("load " _ defaultPkg _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package with Python wheel")

    try {
        set lunePackage = ##class(%SYS.Python).Import("lune")
        do $$$AssertSuccess("lune importable after database install")
        set wheelVer = ..GetPythonVersion("lune")
        do $$$AssertEquals(wheelVer, "1.6.2", "lune version is 1.6.2 as packaged")
    } catch ex {
        do $$$AssertFailure("Failed to import lune after database install: " _ ex.AsStatus())
    }

    // module-with-requirements: default (requirements.txt → wheel)
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package-database module-with-requirements -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module-with-requirements with default settings")

    set reqPkg = ..PackageOutputDir _ "module-with-requirements-1.0.0-database.tgz"
    set extractDir3 = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-reqtxt")
    do ##class(%Library.File).CreateDirectory(extractDir3)
    set sc = ##class(%IPM.General.Archive).Extract(reqPkg, extractDir3)
    do $$$AssertStatusOK(sc, "Extracted module-with-requirements default package")

    set wheelPath = ##class(%Library.File).NormalizeFilename("wheels/packaging-25.0-py3-none-any.whl", extractDir3)
    do $$$AssertTrue(##class(%Library.File).Exists(wheelPath), "Wheel from requirements.txt included in package")

    // module-with-requirements: -export-python-deps 0
    set noExportReqDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "noexport-reqtxt")
    do ##class(%Library.File).CreateDirectory(noExportReqDir)
    set sc = ##class(%IPM.Main).Shell("package-database module-with-requirements -export-python-deps 0 -path " _ noExportReqDir)
    do $$$AssertStatusOK(sc, "Packaged module-with-requirements with -export-python-deps 0")

    set noExportReqPkg = noExportReqDir _ "module-with-requirements-1.0.0-database.tgz"
    set extractDir4 = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-noreqtxt")
    do ##class(%Library.File).CreateDirectory(extractDir4)
    set sc = ##class(%IPM.General.Archive).Extract(noExportReqPkg, extractDir4)
    do $$$AssertStatusOK(sc, "Extracted no-export requirements package")

    set wheelPath2 = ##class(%Library.File).NormalizeFilename("wheels/packaging-25.0-py3-none-any.whl", extractDir4)
    do $$$AssertNotTrue(##class(%Library.File).Exists(wheelPath2), "Wheel excluded from requirements package when -export-python-deps 0 is set")

    // Cleanup: wheels downloaded by ExportPythonDependencies during packaging
    do ..DeletePattern(mixedModuleDir _ "wheels/", "pycparser*.whl")
    do ..DeletePath(reqModuleDir _ "wheels")
}

/// Test invoke firing behavior during database package install.
/// The DB swap happens inside %Reload, so all invokes from Reload.After onward run
/// with the DB mounted. Both Compile.After and Activate.After should fire.
/// Each invoke sets a global marker so we can verify whether it executed.
Method TestInvokeBehaviorDuringDatabaseInstall()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (module-with-invokes is pre-loaded)
    // Both invokes fired when the module was loaded during NS1 init — clear lingering markers.
    new $namespace
    set $namespace = packagingNS
    kill ^InvokeTest

    // Package as database
    set sc = ##class(%IPM.Main).Shell("package-database module-with-invokes -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module with invokes")

    set packageFile = ..PackageOutputDir _ "module-with-invokes-1.0.0-database.tgz"

    // Install in a fresh namespace
    set installNS = "TESTDBINVKINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created install namespace")
    set $namespace = installNS

    // Confirm markers don't exist before install
    do $$$AssertEquals($get(^InvokeTest("compile"), 0), 0, "No compile marker before install")
    do $$$AssertEquals($get(^InvokeTest("activate"), 0), 0, "No activate marker before install")

    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package with invokes")

    // Both Compile.After and Activate.After run — DB is mounted after %Reload completes
    do $$$AssertEquals($get(^InvokeTest("compile")), 1, "Compile invoke ran during database install")
    do $$$AssertEquals($get(^InvokeTest("activate")), 1, "Activate invoke ran during database install")

    // Verify module classes are accessible (DB was mounted)
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("InvokeModule.Main"), "InvokeModule.Main class exists")

    // Cleanup
    kill ^InvokeTest
}

/// Proves that non-compiled resource processor hooks (CPF, FileCopy) actually fire during
/// a database package install, not just during the original source load.
/// Uses a delete-then-verify pattern for FileCopy: the file is deleted after the initial load,
/// then install is run — if FileCopy fires, the file reappears. CPF staging is verified by
/// extracting the package and confirming the CPF file is present.
///
/// Distinct from TestPackageAndInstallAllResourceTypes: that test checks compiled outputs
/// (classes, include, WebApp) on a full-featured module. This test uses a minimal module
/// (class + CPF + FileCopy only) to isolate and prove the processor hook firing mechanism,
/// with explicit before/after assertions rather than a passive smoke test.
Method TestNonCompiledResourcesAppliedDuringInstall()
{
    set packagingNS = ..GetOrCreateSharedNS2()

    // Switch to shared packaging namespace (module-with-non-compiled-resources is pre-loaded;
    // FileCopy already ran during NS2 init so the target file exists)
    new $namespace
    set $namespace = packagingNS

    // Package as database
    set sc = ##class(%IPM.Main).Shell("package-database module-with-non-compiled-resources -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module as database")

    set packageFile = ..PackageOutputDir _ "module-with-non-compiled-resources-1.0.0-database.tgz"

    // Verify CPF file is staged in the package
    set cpfExtractDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "cpf-staging-check")
    do ##class(%Library.File).CreateDirectory(cpfExtractDir)
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, cpfExtractDir)
    do $$$AssertStatusOK(sc, "Extracted package for CPF staging check")
    set stagedCPF = ##class(%Library.File).NormalizeFilename("src/cpf/config.cpf", cpfExtractDir)
    do $$$AssertTrue(##class(%Library.File).Exists(stagedCPF), "CPF file is staged in database package")

    // Compute FileCopy target: ${mgrdir}../non-compiled-data.txt
    // ParentDirectoryName handles the .. reliably across platforms
    set mgrDir = ##class(%Library.File).ManagerDirectory()
    set parentDir = ##class(%Library.File).ParentDirectoryName(mgrDir)
    set fileCopyTarget = ##class(%Library.File).NormalizeFilename("non-compiled-data.txt", parentDir)

    // Confirm FileCopy created the file during load, then delete it
    do $$$AssertTrue(##class(%Library.File).Exists(fileCopyTarget), "FileCopy target exists after load (pre-condition)")
    set deleteOK = ##class(%Library.File).Delete(fileCopyTarget)
    do $$$AssertTrue(deleteOK, "FileCopy target successfully deleted before install (setup check)")
    do $$$AssertNotTrue(##class(%Library.File).Exists(fileCopyTarget), "FileCopy target absent before install (setup verified)")

    // Create install namespace
    set installNS = "TESTDBNONCMPINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created install namespace")
    set $namespace = installNS

    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package (CPF applied during Initialize, FileCopy during Activate)")

    // CPF.OnBeforePhase("Initialize") and FileCopy.OnBeforePhase("Activate") are both invoked
    // by Module.RunPhase independently of the lifecycle method — resource processor hooks are
    // siblings, not children. CPF staging is verified above; FileCopy is verified here.
    do $$$AssertTrue(##class(%Library.File).Exists(fileCopyTarget), "FileCopy target created during database install")
}

/// Test that update steps are seeded (not run) on a fresh database package install, and that
/// new steps introduced in a later version run exactly once during a database package upgrade.
///
/// Flow:
/// 1. Load v1 from source in a dedicated packaging NS; package-database v1.
/// 2. Upgrade to v2 from source in the same NS; package-database v2.
/// 3. In a fresh install NS: install v1 database package — Step001 must be seeded, not run.
/// 4. Upgrade to v2 database package — Step001 must still not have run; Step002 must run once.
///
/// Uses a dedicated per-test packaging NS (not SharedNS1/2) because it is mutated by the
/// v1→v2 source upgrade. The packaging NS's update step side effects (Step002 executes there
/// during the source upgrade) do not affect the install NS — ^DBPkgUpdateSteps is a global and
/// lives in each namespace's own globals DB.
Method TestUpdateStepsWithDatabasePackaging()
{
    set v1Dir = ..GetModuleDir("db-packaging", "module-with-update-steps-v1")
    set v2Dir = ..GetModuleDir("db-packaging", "module-with-update-steps-v2")

    // --- Packaging phase: load both versions from source and database-package each ---
    set packagingNS = "TESTDBUPDPKGNS"
    set sc = ..CreateTestNamespace(packagingNS)
    do $$$AssertStatusOK(sc, "Created packaging namespace")

    new $namespace
    set $namespace = packagingNS

    // Fresh install of v1 from source: Module.cls:%Activate seeds Step001 in packaging NS globals
    set sc = ##class(%IPM.Main).Shell("load -v " _ v1Dir)
    do $$$AssertStatusOK(sc, "Loaded v1 from source in packaging NS")

    set sc = ##class(%IPM.Main).Shell("package-database update-steps-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged update-steps-module v1 as database")
    set v1Package = ..PackageOutputDir _ "update-steps-module-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%Library.File).Exists(v1Package), "v1 database package .tgz exists")

    // Source upgrade to v2: Step001 already seeded so it is skipped; Step002 runs in packaging NS
    set sc = ##class(%IPM.Main).Shell("update update-steps-module -path " _ v2Dir)
    do $$$AssertStatusOK(sc, "Upgraded to v2 from source in packaging NS")

    set sc = ##class(%IPM.Main).Shell("package-database update-steps-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged update-steps-module v2 as database")
    set v2Package = ..PackageOutputDir _ "update-steps-module-2.0.0-database.tgz"
    do $$$AssertTrue(##class(%Library.File).Exists(v2Package), "v2 database package .tgz exists")

    // --- Install phase: fresh namespace, verify seeding and selective step execution ---
    set installNS = "TESTDBUPDINSTNS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created install namespace")

    set $namespace = installNS

    // Install v1 database package.
    // Database.cls:%Reload swaps the DB then seeds all update steps — Step001 must be
    // seeded (not executed) because its work is already baked into the IRIS.DAT.
    set sc = ##class(%IPM.Main).Shell("load " _ v1Package _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed v1 database package")

    do $$$AssertEquals($get(^DBPkgUpdateSteps("step001"), 0), 0, "Step001 not run after v1 database install (seeded only)")
    do $$$AssertEquals($get(^DBPkgUpdateSteps("step002"), 0), 0, "Step002 absent in v1 — counter is 0")

    // Upgrade to v2 database package.
    // Database.cls:%Reload swaps the DB (skips seeding — update path);
    // %ApplyUpdateSteps then runs HandleAllUpdateSteps: Step001 is already seeded so it is
    // skipped; Step002 is new and must run exactly once.
    set sc = ##class(%IPM.Main).Shell("update update-steps-module -path " _ v2Package _ " -swap-db")
    do $$$AssertStatusOK(sc, "Upgraded to v2 database package")

    do $$$AssertEquals($get(^DBPkgUpdateSteps("step001"), 0), 0, "Step001 still not run after v2 upgrade (seeded at v1 install)")
    do $$$AssertEquals($get(^DBPkgUpdateSteps("step002"), 0), 1, "Step002 ran exactly once during v2 database upgrade")
    do $$$AssertTrue(..CountBackupFiles(installNS) > 1, "Second backup created during v2 upgrade (DB was swapped again)")

    kill ^DBPkgUpdateSteps
}

/// Verifies packaging-type-aware registry filtering via zot (http://oras:5000).
/// Publishes dep-module as both source and database, and main-with-deps as source only.
/// Then verifies: source install (no -swap-db), database install (-swap-db), dependency
/// resolution always picks source, and a helpful error is returned when only a database
/// package is available and -swap-db is not specified.
Method TestPublishDatabaseWithORAS()
{
    // dep-module and main-with-deps are pre-loaded in NS1; zot is configured there at NS init time.
    // This test focuses on registry-specific packaging-type filtering behavior.
    set packagingNS = ..GetOrCreateSharedNS1()

    // Create a fresh install namespace for all install steps
    set installNS = "TESTDBORASINSTNS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created ORAS install namespace")

    new $namespace
    set $namespace = installNS
    set sc = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
    do $$$AssertStatusOK(sc, "Configured zot registry in install NS")

    // --- Pre-test cleanup: purge any stale versions from a prior run ---
    set $namespace = packagingNS
    do ##class(%IPM.Main).Shell("unpublish zot/dep-module all -f")
    do ##class(%IPM.Main).Shell("unpublish zot/main-with-deps all -f")

    // --- Publish phase (all publishes first, then installs) ---

    // Step 1: publish dep-module as source to zot
    set sc = ##class(%IPM.Main).Shell("publish dep-module -r zot")
    do $$$AssertStatusOK(sc, "Published dep-module as source to zot")

    // Step 2: publish dep-module as database to zot
    set sc = ##class(%IPM.Main).Shell("publish-database dep-module -r zot")
    do $$$AssertStatusOK(sc, "Published dep-module as database to zot")

    // Step 3: publish main-with-deps as source to zot (exercises dependency filtering path)
    set sc = ##class(%IPM.Main).Shell("publish main-with-deps -r zot")
    do $$$AssertStatusOK(sc, "Published main-with-deps as source to zot")

    // --- Install phase ---
    set $namespace = installNS

    // Step 4: install without -swap-db → should install source package
    set sc = ##class(%IPM.Main).Shell("install dep-module")
    do $$$AssertStatusOK(sc, "Installed dep-module (source) without -swap-db")
    set mod = ##class(%IPM.Storage.Module).NameOpen("dep-module", , .modSC)
    do $$$AssertStatusOK(modSC, "dep-module record accessible after source install")
    do $$$AssertEquals(mod.Packaging, "module", "dep-module packaging is module (source) after non-swap-db install")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepModule.Core"), "DepModule.Core class exists after source install")
    set sc = ##class(%IPM.Main).Shell("uninstall dep-module -f")
    do $$$AssertStatusOK(sc, "Uninstalled dep-module before next step")

    // Step 5: install with -swap-db → should install database package
    set sc = ##class(%IPM.Main).Shell("install dep-module -swap-db")
    do $$$AssertStatusOK(sc, "Installed dep-module with -swap-db")
    set mod = ##class(%IPM.Storage.Module).NameOpen("dep-module", , .modSC)
    do $$$AssertStatusOK(modSC, "dep-module record accessible after database install")
    do $$$AssertEquals(mod.Packaging, "database", "dep-module packaging is database after -swap-db install")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepModule.Core"), "DepModule.Core class exists after database install")
    set sc = ##class(%IPM.Main).Shell("uninstall dep-module -f")
    do $$$AssertStatusOK(sc, "Uninstalled dep-module (database) before next step")

    // Step 6: install main-with-deps → dep-module should resolve as source
    set sc = ##class(%IPM.Main).Shell("install main-with-deps")
    do $$$AssertStatusOK(sc, "Installed main-with-deps (source)")
    set depMod = ##class(%IPM.Storage.Module).NameOpen("dep-module", , .depModSC)
    do $$$AssertStatusOK(depModSC, "dep-module record accessible after main-with-deps install")
    do $$$AssertEquals(depMod.Packaging, "module", "dep-module resolved as source when installing main-with-deps")
    set sc = ##class(%IPM.Main).Shell("uninstall main-with-deps -f")
    do $$$AssertStatusOK(sc, "Uninstalled main-with-deps")
    set sc = ##class(%IPM.Main).Shell("uninstall dep-module -f")
    do $$$AssertStatusOK(sc, "Uninstalled dep-module after main-with-deps test")

    // Step 7: unpublish only the source version of dep-module, leaving database tag intact
    set $namespace = packagingNS
    set sc = ##class(%IPM.Main).Shell("unpublish zot/dep-module 1.0.0 -f")
    do $$$AssertStatusOK(sc, "Unpublished source version of dep-module from zot")

    // Step 8: install without -swap-db → should fail with helpful error pointing to -swap-db
    set $namespace = installNS
    set sc = ##class(%IPM.Main).Shell("install dep-module")
    do $$$AssertTrue($$$ISERR(sc), "Install dep-module without -swap-db fails when only database package available")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "-swap-db", "Error message references -swap-db flag")

    // --- Cleanup ---
    // Unpublish all remaining versions of dep-module and main-with-deps from zot
    set $namespace = packagingNS
    set sc = ##class(%IPM.Main).Shell("unpublish zot/dep-module all -f")
    // Ignore error — database tag may already be gone if step 7 deleted all
    set sc = ##class(%IPM.Main).Shell("unpublish zot/main-with-deps all -f")
    // Ignore error — already cleaned up above
}

/// Verifies that package-database overwrites an existing SystemRequirements Version
/// with the current IRIS version and emits a warning when the versions differ.
Method TestSystemRequirementsOverwrite()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Build a previous-major IRIS version string dynamically to avoid hardcoding invalid values
    set prevIrisVersion = ($system.Version.GetMajor() - 1) _ "." _ $system.Version.GetMinor()
    set currentIrisVersion = $system.Version.GetMajor() _ "." _ $system.Version.GetMinor()

    // Read XData template before switching namespaces — %Dictionary.CompiledXData looks up
    // class metadata in the current namespace, and the test class is not compiled in packagingNS.
    set xData = ##class(%Dictionary.CompiledXData).IDKEYOpen($classname(), "SimpleModuleWithSysReqTemplate", , .sc)
    $$$ThrowOnError(sc)
    set rawXML = ""
    while 'xData.Data.AtEnd {
        set rawXML = rawXML _ xData.Data.Read()
    }
    set rawXML = $replace(rawXML, "REPLACEPREVIRISVERSION", prevIrisVersion)

    new $namespace
    set $namespace = packagingNS

    // simple-db-module is already loaded in NS1. Temporarily overwrite its on-disk module.xml
    // with one that declares the previous IRIS version in SystemRequirements, package it,
    // then restore the original. This avoids re-loading (which would enforce SystemRequirements).
    set mod = ##class(%IPM.Storage.Module).NameOpen("simple-db-module", , .sc)
    $$$ThrowOnError(sc)
    set moduleXMLPath = ##class(%Library.File).NormalizeFilename("module.xml", mod.Root)

    // Read and preserve the original module.xml
    set origStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(origStream.LinkToFile(moduleXMLPath))
    set origXML = origStream.Read(, .sc)
    $$$ThrowOnError(sc)

    // Mutate module.xml then run packaging inside a try/catch so that a write failure
    // still reaches the restore block below — the file may be partially written.
    set sc = $$$OK
    try {
        set writeStream = ##class(%Stream.FileCharacter).%New()
        $$$ThrowOnError(writeStream.LinkToFile(moduleXMLPath))
        $$$ThrowOnError(writeStream.Clear())
        $$$ThrowOnError(writeStream.Write(rawXML))
        $$$ThrowOnError(writeStream.%Save())

        // Package as database — should overwrite SystemRequirements Version with current IRIS version
        set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    } catch ex {
        set sc = ex.AsStatus()
    }

    // Restore original module.xml unconditionally — writing origXML over an untouched file
    // (if the mutation write never completed) is harmless. Protects SharedNS1 in all paths.
    try {
        set restoreStream = ##class(%Stream.FileCharacter).%New()
        $$$ThrowOnError(restoreStream.LinkToFile(moduleXMLPath))
        $$$ThrowOnError(restoreStream.Clear())
        $$$ThrowOnError(restoreStream.Write(origXML))
        $$$ThrowOnError(restoreStream.%Save())
    } catch restoreEx {
        set sc = $$$ADDSC(sc, restoreEx.AsStatus())
    }

    do $$$AssertStatusOK(sc, "Packaged simple-db-module with overwrite of SystemRequirements Version")

    // Extract and read the packaged module.xml
    set packageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"
    set extractDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-sysreq")
    if '##class(%Library.File).CreateDirectory(extractDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to create extract dir: " _ extractDir))
    }
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, extractDir)
    do $$$AssertStatusOK(sc, "Extracted package for SystemRequirements verification")

    set readStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(readStream.LinkToFile(extractDir _ "module.xml"))
    set pkgXML = readStream.Read()

    set tHasCurrentVersion = (pkgXML [ ("Version=""" _ currentIrisVersion _ """"))
    set tLacksPrevVersion = '(pkgXML [ ("Version=""" _ prevIrisVersion _ """"))
    do $$$AssertTrue(tHasCurrentVersion, "Packaged module.xml has current IRIS version in SystemRequirements")
    do $$$AssertTrue(tLacksPrevVersion, "Packaged module.xml does not contain previous IRIS version")

    // Cleanup
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(extractDir)
}

/// A module declaring Packaging="database" with no explicit LifecycleClass must resolve to
/// %IPM.Lifecycle.Database, not the generic %IPM.Lifecycle.Module.
Method TestPackagingDerivesLifecycleClass()
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = "derive-lifecycle-check"
    set module.VersionString = "1.0.0"
    set module.Packaging = "database"
    // Leave LifecycleClass empty so the derivation path runs.

    set sc = module.%ValidateObject()
    do $$$AssertStatusOK(sc, "Module with Packaging=database validates")
    do $$$AssertEquals(module.LifecycleClass, "%IPM.Lifecycle.Database", "LifecycleClass derived from database packaging")
}

/// Get the installed version of a Python package.
ClassMethod GetPythonVersion(name As %String) As %String
{
    try {
        set importlib = ##class(%SYS.Python).Import("importlib")
        set metadata = importlib."import_module"("importlib.metadata")
        set ver = metadata."version"(name)
        return ver
    } catch ex {
        set packageResources = ##class(%SYS.Python).Import("pkg_resources")
        set dist = packageResources."get_distribution"(name)
        return dist."version"
    }
}

/// Remove a file or directory if it exists.
ClassMethod DeletePath(path As %String)
{
    if ##class(%Library.File).DirectoryExists(path) {
        set removeSuccess = ##class(%Library.File).RemoveDirectoryTree(path)
        if 'removeSuccess {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to remove directory: " _ path))
        }
    } elseif ##class(%Library.File).Exists(path) {
        set removeSuccess = ##class(%Library.File).Delete(path)
        if 'removeSuccess {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to remove file: " _ path))
        }
    }
}

/// Remove all files under folder matching a glob pattern.
ClassMethod DeletePattern(
	folder As %String,
	pattern As %String)
{
    set file = $zsearch(folder _ pattern)
    while file '= "" {
        do ..DeletePath(file)
        set file = $zsearch("")
    }
}

/// Counts IRIS_<dbname>_*.DAT backup files in the routines DB directory for a namespace.
/// The last FileSet argument must be 0: with directories included they are returned regardless
/// of the wildcard, so the DB directory's own subdirectories (e.g. stream) would be counted.
Method CountBackupFiles(ns As %String) As %Integer
{
    set routinesDBName = ##class(%IPM.Lifecycle.Database).GetRoutinesDBName(ns)
    set dbDir = ##class(%IPM.Lifecycle.Database).GetDatabaseDirectory(routinesDBName)
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS fileCount FROM %Library.File_FileSet(?, ?, ?, ?)",
        dbDir, "IRIS_" _ routinesDBName _ "_*.DAT", "", 0)
    if rs.%SQLCODE < 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error counting backup files: " _ rs.%Message))
    }
    do rs.%Next()
    quit rs.%Get("fileCount")
}

/// Removes all installed files of a Python package from the shared pip target directory.
/// Deletes both the package directory and its .dist-info metadata directory.
/// Uses direct file deletion rather than pip uninstall to avoid pip dependency resolution
/// and ensure a clean slate regardless of pip state.
ClassMethod PurgePythonPackage(name As %String)
{
    set target = ##class(%Library.File).NormalizeDirectory("python", ##class(%Library.File).ManagerDirectory())
    do ..DeletePath(target _ name)
    do ..DeletePattern(target, name _ "-*" _ ".dist-info")
}

/// Simulates a swap that failed before the original IRIS.DAT was renamed to a backup:
/// the routines DB directory still holds the original IRIS.DAT and no backup file exists.
/// RollbackDatabaseSwap must not delete the original when there is no backup to restore.
Method TestRollbackPreservesOriginalWhenNoBackup()
{
    // Create a throwaway namespace so we have a real, mounted routines DB directory to act on.
    set installNS = "TESTDBROLLBACKNS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    // Resolve the routines DB directory for the namespace.
    set dbDir = ##class(%IPM.Lifecycle.Database).GetDatabaseDirectory(##class(%IPM.Lifecycle.Database).GetRoutinesDBName(installNS))
    set irisDAT = dbDir _ "IRIS.DAT"
    do $$$AssertTrue(##class(%Library.File).Exists(irisDAT), "Original IRIS.DAT exists before rollback")

    // Invoke rollback with a backupPath that does not exist.
    set bogusBackup = dbDir _ "IRIS_nonexistent_backup.DAT"
    do $$$AssertNotTrue(##class(%Library.File).Exists(bogusBackup), "Backup file intentionally absent")
    set lifecycle = ##class(%IPM.Lifecycle.Database).%New(##class(%IPM.Storage.Module).%New())
    do lifecycle.RollbackDatabaseSwap(dbDir, bogusBackup)

    // The original must survive.
    do $$$AssertTrue(##class(%Library.File).Exists(irisDAT), "Original IRIS.DAT preserved when no backup exists")
}

/// Template module.xml for TestSystemRequirementsOverwrite.
/// REPLACEPREVIRISVERSION is substituted at runtime with a dynamically computed previous IRIS version.
XData SimpleModuleWithSysReqTemplate
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
  <Document name="simple-db-module.ZPM">
    <Module>
      <Name>simple-db-module</Name>
      <Version>1.0.0</Version>
      <Packaging>module</Packaging>
      <SourcesRoot>src</SourcesRoot>
      <SystemRequirements Version="REPLACEPREVIRISVERSION"/>
      <Resource Name="SimpleModule.Main.CLS" />
      <Resource Name="SimpleModule.Utils.CLS" />
    </Module>
  </Document>
</Export>
}

/// The checksum embedded in a packaged module.xml must equal the hash of the IRIS.DAT that
/// actually ships in the .tgz — verified for the -use-current-db copy flow.
Method TestChecksumMatchesShippedDat()
{
    set packagingNS = ..GetOrCreateSharedNS1()
    new $namespace
    set $namespace = packagingNS
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -use-current-db -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module with -use-current-db")
    set packageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%Library.File).Exists(packageFile), "Package file exists")

    // Extract into a temp dir.
    set extractDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-checksum")
    do ##class(%Library.File).CreateDirectory(extractDir)
    do $$$AssertStatusOK(##class(%IPM.General.Archive).Extract(packageFile, extractDir), "Extracted package")

    // Read the embedded checksum from module.xml (string match, matching this class's other tests).
    set stream = ##class(%Stream.FileCharacter).%New()
    do $$$AssertStatusOK(stream.LinkToFile(extractDir _ "module.xml"), "Linked module.xml")
    set xmlContent = stream.Read()
    // Extract the value between <Checksum Algorithm="SHA-256"> and </Checksum>.
    set marker = "<Checksum Algorithm=""SHA-256"">"
    set afterOpen = $piece(xmlContent, marker, 2)
    set embedded = $piece(afterOpen, "</Checksum>", 1)
    do $$$AssertTrue(embedded '= "", "Embedded checksum found in module.xml")

    // Hash the shipped IRIS.DAT and compare.
    set actual = ##class(%IPM.Lifecycle.Database).ComputeSHA256Hex(extractDir _ "IRIS.DAT")
    do $$$AssertEquals($zconvert(actual, "L"), $zconvert(embedded, "L"), "Embedded checksum matches shipped IRIS.DAT")

    do ##class(%IPM.Utils.File).RemoveDirectoryTree(extractDir)
}

/// Guards the ComputeSHA256Hex output contract (64-char lowercase hex): the hash is produced
/// via the %xsd.hexBinary encoder, so this pins the length and lowercasing.
Method TestSHA256HexFormat()
{
    // Write a small known file and hash it.
    set tmp = ##class(%Library.File).TempFilename("bin")
    set stream = ##class(%Stream.FileBinary).%New()
    do stream.LinkToFile(tmp)
    do stream.Write("abc")
    do stream.%Save()
    set hex = ##class(%IPM.Lifecycle.Database).ComputeSHA256Hex(tmp)
    do ##class(%Library.File).Delete(tmp)

    do $$$AssertEquals($length(hex), 64, "SHA-256 hex is 64 characters")
    do $$$AssertEquals($zconvert(hex, "L"), hex, "SHA-256 hex is lowercase")
    // SHA-256 of "abc" is a well-known constant.
    do $$$AssertEquals(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256('abc') matches known value")
}

}
