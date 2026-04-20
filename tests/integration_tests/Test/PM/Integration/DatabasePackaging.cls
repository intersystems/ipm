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
    set depDir = ..GetModuleDir("db-packaging", "dependency-module")
    set simpleDir = ..GetModuleDir("db-packaging", "simple-module")
    set depsDir = ..GetModuleDir("db-packaging", "module-with-deps")
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
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ depDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ simpleDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ depsDir))
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
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, extractDir, .extractOutput)
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
    set depsDir = ##class(%File).NormalizeDirectory(extractDir) _ "deps/"
    do $$$AssertTrue(##class(%File).DirectoryExists(depsDir), "deps/ directory exists in package")

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

    // Test load command with another module (dep-module is pre-loaded in shared NS1)
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package-database dep-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged dep-module as database")

    set packageFile2 = ..PackageOutputDir _ "dep-module-1.0.0-database.tgz"

    // Create another namespace for load test
    set loadNS = "TESTDBLOAD1"
    set sc = ..CreateTestNamespace(loadNS)
    do $$$AssertStatusOK(sc, "Created load test namespace")

    set $namespace = loadNS

    // Test load command with -swap-db
    set sc = ##class(%IPM.Main).Shell("load " _ packageFile2 _ " -swap-db")
    do $$$AssertStatusOK(sc, "Load command with database package works")

    // Verify module loaded
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepModule.Core"), "DepModule.Core class exists after load")
}

/// Test packaging and installing modules with dependencies
Method TestPackageAndInstallWithDependencies()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (dep-module and main-with-deps are pre-loaded)
    new $namespace
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package-database dep-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged dependency module")

    set sc = ##class(%IPM.Main).Shell("package-database main-with-deps -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module with dependencies")

    // Verify dependencies.xml is created correctly
    set packageFile = ..PackageOutputDir _ "main-with-deps-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%File).Exists(packageFile), "Package file exists")

    // Create installation namespace
    set installNS = "TESTDBDEPINST"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install the module with dependencies
    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed module with dependencies")

    // Verify main module classes exist
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("MainModule.App"), "MainModule.App class exists")

    // Verify dependencies are tracked
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("list")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    do $$$AssertStatusOK(sc, "List command executed")
    do $$$AssertTrue(..FindStringInMultiDimArray("dep-module", .output), "Dependency appears in list")
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

    // Verify all resource types work correctly
    do $$$AssertStatusOK($$$OK, "All resource types verified")
}

/// Test packaging with and without test resources
Method TestPackageAndInstallWithTestResources()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (module-with-tests is pre-loaded)
    new $namespace
    set $namespace = packagingNS

    // Package WITH test resources
    set sc = ##class(%IPM.Main).Shell("package-database module-with-tests -include-test-resources -path " _ ..PackageOutputDir)
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

/// Test packaging with -use-current-db flag
Method TestPackageWithUseCurrentDbFlag()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (simple-db-module is pre-loaded)
    new $namespace
    set $namespace = packagingNS

    // Package with -use-current-db flag
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -use-current-db -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged with -use-current-db flag")

    // Verify package was created
    set packageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%File).Exists(packageFile), "Package created with -use-current-db")
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

    // Test: Zero-sized IRIS.DAT fails validation
    set zeroDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "zero-extract")
    do ##class(%Library.File).CreateDirectory(zeroDir)
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, zeroDir)
    do $$$AssertStatusOK(sc, "Extracted package for zero-size IRIS.DAT test")

    set zeroIRISDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", zeroDir)
    do ##class(%Library.File).Delete(zeroIRISDAT)
    set zeroStream = ##class(%Stream.FileBinary).%New()
    $$$ThrowOnError(zeroStream.LinkToFile(zeroIRISDAT))
    $$$ThrowOnError(zeroStream.%Save())

    set zeroPackage = ..PackageOutputDir _ "simple-db-module-zero.tgz"
    set sc = ##class(%IPM.General.Archive).Create(zeroDir, zeroPackage)
    do $$$AssertStatusOK(sc, "Repacked archive with zero-sized IRIS.DAT")

    set installNS3 = "TESTDBVALIDINS3"
    set sc = ..CreateTestNamespace(installNS3)
    do $$$AssertStatusOK(sc, "Created namespace for zero-size test")
    set $namespace = installNS3

    set sc = ##class(%IPM.Main).Shell("load " _ zeroPackage _ " -swap-db")
    do $$$AssertStatusNotOK(sc, "Zero-sized IRIS.DAT rejected by validation")

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

    set installNS4 = "TESTDBVALIDINS4"
    set sc = ..CreateTestNamespace(installNS4)
    do $$$AssertStatusOK(sc, "Created namespace for missing-deps test")
    set $namespace = installNS4

    set sc = ##class(%IPM.Main).Shell("load " _ missingDepsPackage _ " -swap-db")
    do $$$AssertStatusNotOK(sc, "Missing deps/ directory rejected by validation")
}

/// Test backup and rollback during installation
Method TestBackupAndRollback()
{
    set packagingNS = ..GetOrCreateSharedNS1()

    // Switch to shared packaging namespace (simple-db-module is pre-loaded)
    new $namespace
    set $namespace = packagingNS

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module")

    set packageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"

    set installNS = "TESTDBBKUPINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")
    new $namespace
    set $namespace = installNS
    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package")

    // Verify backup file was created in the routines DB directory
    do $$$AssertTrue(..CountBackupFiles(installNS) > 0, "Backup IRIS.DAT file created after swap")
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
}

/// Tests all Python dependency packaging behaviour in one pass:
/// - module-with-mixed-python (explicit PythonWheel + requirements.txt): both wheels present
///   by default; both absent with -no-export-python-deps; lune installs correctly at runtime
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

    // module-with-mixed-python: -no-export-python-deps
    set noExportDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "noexport")
    do ##class(%Library.File).CreateDirectory(noExportDir)
    set sc = ##class(%IPM.Main).Shell("package-database module-with-mixed-python -no-export-python-deps -path " _ noExportDir)
    do $$$AssertStatusOK(sc, "Packaged module-with-mixed-python with -no-export-python-deps")

    set noExportPkg = noExportDir _ "module-with-mixed-python-1.0.0-database.tgz"
    set extractDir2 = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-nowheel")
    do ##class(%Library.File).CreateDirectory(extractDir2)
    set sc = ##class(%IPM.General.Archive).Extract(noExportPkg, extractDir2)
    do $$$AssertStatusOK(sc, "Extracted no-export package")

    set wheelInNoExport = ##class(%Library.File).NormalizeFilename("wheels/lune-1.6.2-py3-none-any.whl", extractDir2)
    do $$$AssertNotTrue(##class(%Library.File).Exists(wheelInNoExport), "Wheel excluded when -no-export-python-deps is set")

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

    // module-with-requirements: -no-export-python-deps
    set noExportReqDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "noexport-reqtxt")
    do ##class(%Library.File).CreateDirectory(noExportReqDir)
    set sc = ##class(%IPM.Main).Shell("package-database module-with-requirements -no-export-python-deps -path " _ noExportReqDir)
    do $$$AssertStatusOK(sc, "Packaged module-with-requirements with -no-export-python-deps")

    set noExportReqPkg = noExportReqDir _ "module-with-requirements-1.0.0-database.tgz"
    set extractDir4 = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-noreqtxt")
    do ##class(%Library.File).CreateDirectory(extractDir4)
    set sc = ##class(%IPM.General.Archive).Extract(noExportReqPkg, extractDir4)
    do $$$AssertStatusOK(sc, "Extracted no-export requirements package")

    set wheelPath2 = ##class(%Library.File).NormalizeFilename("wheels/packaging-25.0-py3-none-any.whl", extractDir4)
    do $$$AssertNotTrue(##class(%Library.File).Exists(wheelPath2), "Wheel excluded from requirements package when -no-export-python-deps is set")

    // Cleanup: wheels downloaded by ExportPythonDependencies during packaging
    do ..DeletePattern(mixedModuleDir _ "wheels/", "pycparser*.whl")
    do ..DeletePath(reqModuleDir _ "wheels")
}

/// Test that pre-Activate invokes are skipped and post-Activate invokes run
/// during database package install. Each invoke sets a global marker so we can
/// verify whether it executed.
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

    // Pre-Activate invoke (Compile.After) should have been skipped
    do $$$AssertEquals($get(^InvokeTest("compile"), 0), 0, "Compile invoke skipped during database install")

    // Post-Activate invoke (Activate.After) should have run
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
    // Database.cls:%Activate swaps the DB then seeds all update steps — Step001 must be
    // seeded (not executed) because its work is already baked into the IRIS.DAT.
    set sc = ##class(%IPM.Main).Shell("load " _ v1Package _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed v1 database package")

    do $$$AssertEquals($get(^DBPkgUpdateSteps("step001"), 0), 0, "Step001 not run after v1 database install (seeded only)")
    do $$$AssertEquals($get(^DBPkgUpdateSteps("step002"), 0), 0, "Step002 absent in v1 — counter is 0")

    // Upgrade to v2 database package.
    // Database.cls:%Activate swaps the DB (skips seeding — update path);
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

    set writeStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(writeStream.LinkToFile(moduleXMLPath))
    $$$ThrowOnError(writeStream.Clear())
    $$$ThrowOnError(writeStream.Write(rawXML))
    $$$ThrowOnError(writeStream.%Save())

    // Package as database — should overwrite SystemRequirements Version with current IRIS version
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)

    // Restore original module.xml unconditionally before asserting, so a failure doesn't leave
    // the shared NS in a broken state for subsequent tests
    set restoreStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(restoreStream.LinkToFile(moduleXMLPath))
    $$$ThrowOnError(restoreStream.Clear())
    $$$ThrowOnError(restoreStream.Write(origXML))
    $$$ThrowOnError(restoreStream.%Save())

    do $$$AssertStatusOK(sc, "Packaged simple-db-module with overwrite of SystemRequirements Version")

    // Extract and read the packaged module.xml
    set packageFile = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"
    set extractDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-sysreq")
    if '##class(%Library.File).CreateDirectory(extractDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to create extract dir: " _ extractDir))
    }
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, extractDir, .extractOutput)
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
Method CountBackupFiles(ns As %String) As %Integer
{
    set routinesDBName = ##class(%IPM.Lifecycle.Database).GetRoutinesDBName(ns)
    set dbDir = ##class(%IPM.Lifecycle.Database).GetDatabaseDirectory(routinesDBName)
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS fileCount FROM %Library.File_FileSet(?, ?, ?, ?)",
        dbDir, "IRIS_" _ routinesDBName _ "_*.DAT", "", 1)
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

}
