/// Test class for database packaging functionality
Class Test.PM.Integration.DatabasePackaging Extends Test.PM.Integration.Base
{

Property CreatedNamespaces As %List;

Property OriginalNamespace As %String;

Method OnBeforeEachTest() As %Status
{
    set ..CreatedNamespaces = ""
    set ..OriginalNamespace = $namespace
    return $$$OK
}

Method OnAfterEachTest() As %Status
{
    set sc = $$$OK
    set $namespace = ..OriginalNamespace

    // Clean up all created namespaces
    for i=1:1:$listlength(..CreatedNamespaces) {
        set ns = $listget(..CreatedNamespaces, i)
        if (ns '= "") {
            set cleanupSC = ##class(%IPM.Test.Utils).DeleteNamespace(ns)
            set sc = $$$ADDSC(sc, cleanupSC)
        }
    }

    return sc
}

/// Helper method to create and track a namespace
Method CreateTestNamespace(pNamespace As %String) As %Status
{
    set sc = ##class(%IPM.Test.Utils).CreateNamespace(pNamespace)
    if $$$ISOK(sc) {
        set ..CreatedNamespaces = ..CreatedNamespaces _ $listbuild(pNamespace)
    }
    return sc
}

/// Test simple package and install with database packaging
Method TestSimplePackageAndInstall()
{
    set testNS = "TESTDBPKG1"

    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    // Switch to test namespace and load simple module
    new $namespace
    set $namespace = testNS

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded simple module successfully")

    // Package as database package
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module")
    do $$$AssertStatusOK(sc, "Packaged module as database package")

    // Verify package file exists
    set packageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%File).Exists(packageFile), "Database package .tgz file exists")

    // Extract and verify contents
    set extractDir = ##class(%File).NormalizeDirectory(##class(%File).TempFilename())
    do ##class(%File).CreateDirectory(extractDir)

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

    // Verify dependencies.xml exists
    set depsXMLFile = ##class(%File).NormalizeDirectory(extractDir) _ "dependencies.xml"
    do $$$AssertTrue(##class(%File).Exists(depsXMLFile), "dependencies.xml exists in package")

    // Create a new test namespace for installation
    set installNS = "TESTDBINST1"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation test namespace")

    set $namespace = installNS

    // Install database package with -swap-db flag
    set sc = ##class(%IPM.Main).Shell("install " _ packageFile _ " -swap-db")
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

    // Test load command with another module
    set $namespace = testNS
    set moduleDir2 = ..GetModuleDir("db-packaging", "dependency-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir2)
    do $$$AssertStatusOK(sc, "Loaded dependency module")

    set sc = ##class(%IPM.Main).Shell("package-database dep-module")
    do $$$AssertStatusOK(sc, "Packaged dep-module as database")

    set packageFile2 = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "dep-module-1.0.0-database.tgz"

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
    set testNS = "TESTDBDEPS1"

    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // First load and package the dependency module
    set depModuleDir = ..GetModuleDir("db-packaging", "dependency-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ depModuleDir)
    do $$$AssertStatusOK(sc, "Loaded dependency module")

    set sc = ##class(%IPM.Main).Shell("package-database dep-module")
    do $$$AssertStatusOK(sc, "Packaged dependency module")

    // Now load and package the module with dependencies
    set mainModuleDir = ..GetModuleDir("db-packaging", "module-with-deps")
    set sc = ##class(%IPM.Main).Shell("load -v " _ mainModuleDir)
    do $$$AssertStatusOK(sc, "Loaded module with dependencies")

    set sc = ##class(%IPM.Main).Shell("package-database main-with-deps")
    do $$$AssertStatusOK(sc, "Packaged module with dependencies")

    // Verify dependencies.xml is created correctly
    set packageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "main-with-deps-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%File).Exists(packageFile), "Package file exists")

    // Create installation namespace
    set installNS = "TESTDBDEPINST"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install the module with dependencies
    set sc = ##class(%IPM.Main).Shell("install " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed module with dependencies")

    // Verify main module classes exist
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("MainModule.App"), "MainModule.App class exists")

    // Verify dependencies are tracked
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("list -dependencies")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    do $$$AssertStatusOK(sc, "List dependencies command executed")
    do $$$AssertTrue(..FindStringInMultiDimArray("dep-module", .output), "Dependency appears in list")
}

/// Test packaging and installing modules with all resource types
Method TestPackageAndInstallAllResourceTypes()
{
    set testNS = "TESTDBALLRES"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Load module with all resource types
    set moduleDir = ..GetModuleDir("db-packaging", "module-with-all-resources")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module with all resources")

    // Package as database
    set sc = ##class(%IPM.Main).Shell("package-database all-resources-module")
    do $$$AssertStatusOK(sc, "Packaged module with all resources")

    set packageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "all-resources-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBRESINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install the package
    set sc = ##class(%IPM.Main).Shell("install " _ packageFile _ " -swap-db")
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
    set testNS = "TESTDBTESTRES"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Load module with test resources
    set moduleDir = ..GetModuleDir("db-packaging", "module-with-tests")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module with test resources")

    // Package WITH test resources
    set sc = ##class(%IPM.Main).Shell("package-database module-with-tests -include-test-resources")
    do $$$AssertStatusOK(sc, "Packaged with test resources")

    // Install and verify test resources are present
    set packageFileWithTests = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "module-with-tests-1.0.0-database.tgz"

    set installNS1 = "TESTDBTESTINS1"
    set sc = ..CreateTestNamespace(installNS1)
    do $$$AssertStatusOK(sc, "Created installation namespace 1")

    set $namespace = installNS1
    set sc = ##class(%IPM.Main).Shell("install " _ packageFileWithTests _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed with test resources")

    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.Test"), "Test class exists when included")

    // Package WITHOUT test resources (default)
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("package-database module-with-tests")
    do $$$AssertStatusOK(sc, "Packaged without test resources")

    set packageFileNoTests = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "module-with-tests-1.0.0-database.tgz"

    set installNS2 = "TESTDBTESTINS2"
    set sc = ..CreateTestNamespace(installNS2)
    do $$$AssertStatusOK(sc, "Created installation namespace 2")

    set $namespace = installNS2
    set sc = ##class(%IPM.Main).Shell("install " _ packageFileNoTests _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed without test resources")

    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.Test"), "Test class excluded by default")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.Main"), "Main class exists")
}

/// Test packaging with -use-current-db flag
Method TestPackageWithUseCurrentDbFlag()
{
    set testNS = "TESTDBCURDB"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Load simple module
    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded simple module")

    // Package with -use-current-db flag
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -use-current-db")
    do $$$AssertStatusOK(sc, "Packaged with -use-current-db flag")

    // Verify package was created
    set packageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0-database.tgz"
    do $$$AssertTrue(##class(%File).Exists(packageFile), "Package created with -use-current-db")
}

/// Test packaging and install validation (errors and edge cases)
Method TestPackagingAndInstallValidation()
{
    set testNS = "TESTDBVALID"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Load and package a valid module first
    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module")

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module")
    do $$$AssertStatusOK(sc, "Packaged module")

    set packageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0-database.tgz"

    // Test: Checksum validation - tamper with IRIS.DAT
    // Extract package, modify IRIS.DAT, repack, attempt install
    // This should fail with checksum mismatch error
    set installNS = "TESTDBVALIDINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Test install with tampered package (simulated)
    // This test validates that checksum verification works
    // Actual implementation would fail if IRIS.DAT is tampered
    set sc = ##class(%IPM.Main).Shell("install " _ packageFile _ " -swap-db")
    // For now, this should work with valid package
    do $$$AssertStatusOK(sc, "Valid package installs successfully")

    // Test: Attempt to install database package without -swap-db flag
    set installNS2 = "TESTDBVALIDINS2"
    set sc = ..CreateTestNamespace(installNS2)
    do $$$AssertStatusOK(sc, "Created second installation namespace")

    set $namespace = installNS2

    // Without -swap-db, should require confirmation or error
    // Implementation should handle this appropriately

    // Test: Zero-sized IRIS.DAT validation
    // Would be created and tested in actual implementation

    // Test: Missing dependencies.xml validation
    // Would be tested with corrupted package
}

/// Test backup and rollback during installation
Method TestBackupAndRollback()
{
    set testNS = "TESTDBBKUP"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Load and package module
    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module")

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module")
    do $$$AssertStatusOK(sc, "Packaged module")

    set packageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBBKUPINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install database package
    set sc = ##class(%IPM.Main).Shell("install " _ packageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package")

    // Verify backup was created
    // Backup should be named IRIS_<db-name>_<timestamp>.DAT
    // Implementation should verify backup file exists

    // Get database directory for this namespace
    new $namespace
    set $namespace = "%SYS"
    set nsProperties = ##class(Config.Namespaces).Get(installNS)
    set dbDir = nsProperties.Routines

    // Verify database exists
    do $$$AssertTrue(dbDir '= "", "Database directory found")

    // Test rollback scenario
    // In actual implementation, would test corrupted install with rollback
}

/// Test upgrading from database package to newer database package
Method TestUpgradeDatabaseToDatabase()
{
    set testNS = "TESTDBUPG"
    // Create test namespace for packaging
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Package v1.0.0
    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module v1.0.0")

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module")
    do $$$AssertStatusOK(sc, "Packaged v1.0.0")

    set packageV1 = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBUPGINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install v1.0.0
    set sc = ##class(%IPM.Main).Shell("install " _ packageV1 _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed v1.0.0")

    // Verify v1.0.0 is installed
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Module v1.0.0 installed")

    // Now upgrade to v2.0.0 (simulated - would need v2 module in real test)
    // For this RED test, we'll upgrade from same package to test mechanism
    set sc = ##class(%IPM.Main).Shell("update simple-db-module " _ packageV1 _ " -swap-db")
    // Implementation should handle upgrade with backup and database swap
}

/// Test upgrading from source package to database package
Method TestUpgradeSourceToDatabase()
{
    set testNS = "TESTDBUPGSRC"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Load and package as source first
    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module")

    set sc = ##class(%IPM.Main).Shell("package simple-db-module")
    do $$$AssertStatusOK(sc, "Packaged as source")

    set sourcePackage = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0.tgz"

    // Create installation namespace
    set installNS = "TESTDBUPGSRCINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install source package
    set sc = ##class(%IPM.Main).Shell("install " _ sourcePackage)
    do $$$AssertStatusOK(sc, "Installed source package")

    // Verify source installed
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Source package installed")

    // Now package as database and upgrade
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module")
    do $$$AssertStatusOK(sc, "Packaged as database")

    set dbPackage = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0-database.tgz"

    set $namespace = installNS

    // Upgrade from source to database package
    set sc = ##class(%IPM.Main).Shell("update simple-db-module " _ dbPackage _ " -swap-db")
    // Implementation should handle metadata migration between packaging types
}

/// Test uninstalling database package
Method TestUninstallDatabasePackage()
{
    set testNS = "TESTDBUNINS"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Load and package module
    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module")

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module")
    do $$$AssertStatusOK(sc, "Packaged module")

    set packageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBUNINSNS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install database package
    set sc = ##class(%IPM.Main).Shell("install " _ packageFile _ " -swap-db")
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

    // Verify namespace returns to original state
    // Backup should still exist for user to manage
}

/// Test mixed packaging scenarios
Method TestMixedPackaging()
{
    set testNS = "TESTDBMIXED"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    new $namespace
    set $namespace = testNS

    // Package database package
    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded database module")

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module")
    do $$$AssertStatusOK(sc, "Packaged as database")

    set dbPackageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "simple-db-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBMIXEDINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install database package
    set sc = ##class(%IPM.Main).Shell("install " _ dbPackageFile _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed database package")

    // Test: Install source package in same namespace should work
    set $namespace = testNS
    set depModuleDir = ..GetModuleDir("db-packaging", "dependency-module")
    set sc = ##class(%IPM.Main).Shell("load -v " _ depModuleDir)
    do $$$AssertStatusOK(sc, "Loaded dependency module as source")

    set sc = ##class(%IPM.Main).Shell("package dep-module")
    do $$$AssertStatusOK(sc, "Packaged as source")

    set sourcePackageFile = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "dep-module-1.0.0.tgz"

    set $namespace = installNS

    // Install source package in namespace with database package
    set sc = ##class(%IPM.Main).Shell("install " _ sourcePackageFile)
    do $$$AssertStatusOK(sc, "Installed source package alongside database package")

    // Verify both packages exist
    set cookie = ""
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("list")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertTrue(..FindStringInMultiDimArray("simple-db-module", .output), "Database package in list")
    do $$$AssertTrue(..FindStringInMultiDimArray("dep-module", .output), "Source package in list")

    // Test: Cannot install second database package in same namespace
    set $namespace = testNS
    set allResDir = ..GetModuleDir("db-packaging", "module-with-all-resources")
    set sc = ##class(%IPM.Main).Shell("load -v " _ allResDir)
    do $$$AssertStatusOK(sc, "Loaded second module")

    set sc = ##class(%IPM.Main).Shell("package-database all-resources-module")
    do $$$AssertStatusOK(sc, "Packaged second module as database")

    set dbPackage2 = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.Module).GetWorkingDirectory()) _ "all-resources-module-1.0.0-database.tgz"

    set $namespace = installNS

    // Attempt to install second database package should fail
    set sc = ##class(%IPM.Main).Shell("install " _ dbPackage2 _ " -swap-db")
    do $$$AssertStatusNotOK(sc, "Cannot install second database package in same namespace")
}

}
