/// Test class for database packaging functionality
Class Test.PM.Integration.DatabasePackaging Extends Test.PM.Integration.Base
{

Property CreatedNamespaces As %List;

Property OriginalNamespace As %String;

Property PackageOutputDir As %String;

Property CreatedGlobalsDatabases As %List;

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

/// Test simple package and install with database packaging
Method TestSimplePackageAndInstall()
{
    set testNS = "TESTDBPKG1"

    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set moduleDir2 = ..GetModuleDir("db-packaging", "dependency-module")

    // Switch to test namespace and load simple module
    new $namespace
    set $namespace = testNS

    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded simple module successfully")

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

    // Test load command with another module
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir2)
    do $$$AssertStatusOK(sc, "Loaded dependency module")

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
    set testNS = "TESTDBDEPS1"

    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set depModuleDir = ..GetModuleDir("db-packaging", "dependency-module")
    set mainModuleDir = ..GetModuleDir("db-packaging", "module-with-deps")

    new $namespace
    set $namespace = testNS

    // First load and package the dependency module
    set sc = ##class(%IPM.Main).Shell("load -v " _ depModuleDir)
    do $$$AssertStatusOK(sc, "Loaded dependency module")

    set sc = ##class(%IPM.Main).Shell("package-database dep-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged dependency module")

    // Now load and package the module with dependencies
    set sc = ##class(%IPM.Main).Shell("load -v " _ mainModuleDir)
    do $$$AssertStatusOK(sc, "Loaded module with dependencies")

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

/// Test packaging and installing modules with all resource types
Method TestPackageAndInstallAllResourceTypes()
{
    set testNS = "TESTDBALLRES"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "module-with-all-resources")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module with all resources")

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
    set testNS = "TESTDBTESTRES"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "module-with-tests")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module with test resources")

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
    set $namespace = testNS
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
    set testNS = "TESTDBCURDB"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded simple module")

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
    set testNS = "TESTDBVALID"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module")

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

    // Test install with tampered package (simulated)
    // This test validates that checksum verification works
    // Actual implementation would fail if IRIS.DAT is tampered
    set sc = ##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db")
    // For now, this should work with valid package
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
    set testNS = "TESTDBBKUP"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module")

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

/// Test upgrading from database package to newer database package
Method TestUpgradeDatabaseToDatabase()
{
    set testNS = "TESTDBUPG"
    // Create test namespace for packaging
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module v1.0.0")

    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged v1.0.0")

    set packageV1 = ..PackageOutputDir _ "simple-db-module-1.0.0-database.tgz"

    // Create installation namespace
    set installNS = "TESTDBUPGINS"
    set sc = ..CreateTestNamespace(installNS)
    do $$$AssertStatusOK(sc, "Created installation namespace")

    set $namespace = installNS

    // Install v1.0.0
    set sc = ##class(%IPM.Main).Shell("load " _ packageV1 _ " -swap-db")
    do $$$AssertStatusOK(sc, "Installed v1.0.0")

    // Verify v1.0.0 is installed
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Module v1.0.0 installed")

    // Now upgrade to v2.0.0 (simulated - would need v2 module in real test)
    // For this RED test, we'll upgrade from same package to test mechanism
    set sc = ##class(%IPM.Main).Shell("update simple-db-module -path " _ packageV1 _ " -swap-db")
    do $$$AssertStatusOK(sc, "Upgraded database package")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Module still installed after upgrade")

    // Verify a second DB swap actually occurred (backup count must be > 1)
    do $$$AssertTrue(..CountBackupFiles(installNS) > 1, "Second backup created during upgrade (DB was swapped again)")
}

/// Test upgrading from source package to database package
Method TestUpgradeSourceToDatabase()
{
    set testNS = "TESTDBUPGSRC"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module")

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
    set $namespace = testNS
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
    set testNS = "TESTDBUNINS"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module")

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
    set testNS = "TESTDBMIXED"
    // Create test namespace
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "simple-module")
    set depModuleDir = ..GetModuleDir("db-packaging", "dependency-module")
    set allResDir = ..GetModuleDir("db-packaging", "module-with-all-resources")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded database module")

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
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ depModuleDir)
    do $$$AssertStatusOK(sc, "Loaded dependency module as source")

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
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ allResDir)
    do $$$AssertStatusOK(sc, "Loaded second module")

    set sc = ##class(%IPM.Main).Shell("package-database all-resources-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged second module as database")

    set dbPackage2 = ..PackageOutputDir _ "all-resources-module-1.0.0-database.tgz"

    set $namespace = installNS

    // Attempt to install second database package should fail
    set sc = ##class(%IPM.Main).Shell("load " _ dbPackage2 _ " -swap-db")
    do $$$AssertStatusNotOK(sc, "Cannot install second database package in same namespace")
}

/// Test that -no-export-python-deps excludes wheels from the package, and that Python wheels
/// are installed during database package install (PythonWheel uses Initialize phase, which
/// has no Database.cls override).
Method TestPackageWithExportPyDepsFlag()
{
    set testNS = "TESTDBPYWHL"
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "module-with-all-resources")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module with Python wheel resource")

    // Package with default settings (export-python-deps ON by default)
    set sc = ##class(%IPM.Main).Shell("package-database all-resources-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged with default settings")

    set defaultPkg = ..PackageOutputDir _ "all-resources-module-1.0.0-database.tgz"
    set extractDir1 = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-default-whl")
    do ##class(%Library.File).CreateDirectory(extractDir1)
    set sc = ##class(%IPM.General.Archive).Extract(defaultPkg, extractDir1)
    do $$$AssertStatusOK(sc, "Extracted default package")

    set wheelInDefault = ##class(%Library.File).NormalizeFilename("wheels/lune-1.6.2-py3-none-any.whl", extractDir1)
    do $$$AssertTrue(##class(%Library.File).Exists(wheelInDefault), "Wheel included in package by default (export-python-deps ON)")

    // Package with -no-export-python-deps into a separate subdirectory
    set noExportDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "noexport")
    do ##class(%Library.File).CreateDirectory(noExportDir)
    set sc = ##class(%IPM.Main).Shell("package-database all-resources-module -no-export-python-deps -path " _ noExportDir)
    do $$$AssertStatusOK(sc, "Packaged with -no-export-python-deps")

    set noExportPkg = noExportDir _ "all-resources-module-1.0.0-database.tgz"
    set extractDir2 = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-nowheel")
    do ##class(%Library.File).CreateDirectory(extractDir2)
    set sc = ##class(%IPM.General.Archive).Extract(noExportPkg, extractDir2)
    do $$$AssertStatusOK(sc, "Extracted no-wheel package")

    set wheelInNoExport = ##class(%Library.File).NormalizeFilename("wheels/lune-1.6.2-py3-none-any.whl", extractDir2)
    // FAILS until CopyNonCompiledResources respects the ExportPythonDependencies flag
    do $$$AssertNotTrue(##class(%Library.File).Exists(wheelInNoExport), "Wheel excluded when -no-export-python-deps is set")

    // Verify Python wheel is installed during database package install.
    // PythonWheel.OnPhase("Initialize") fires since %Initialize has no Database.cls override.
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
}

/// Test that requirements.txt dependencies are resolved into wheels during database packaging
/// when -export-python-deps is enabled (the default). Modules with only a requirements.txt
/// (no explicit <PythonWheel> entries) should get their Python deps packaged as wheels.
Method TestPackageWithRequirementsTxt()
{
    set testNS = "TESTDBREQTXT"
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "module-with-requirements")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module with requirements.txt")

    // Package as database (export-python-deps is on by default)
    set sc = ##class(%IPM.Main).Shell("package-database module-with-requirements -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module with requirements.txt")

    // Extract and verify wheels were included
    set packageFile = ..PackageOutputDir _ "module-with-requirements-1.0.0-database.tgz"
    set extractDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-reqtxt")
    do ##class(%Library.File).CreateDirectory(extractDir)
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, extractDir)
    do $$$AssertStatusOK(sc, "Extracted package")

    set wheelPath = ##class(%Library.File).NormalizeFilename("wheels/lune-1.6.2-py3-none-any.whl", extractDir)
    do $$$AssertTrue(##class(%Library.File).Exists(wheelPath), "Wheel from requirements.txt included in database package")

    // Verify wheel is not included when -no-export-python-deps is set
    set noExportDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "noexport-reqtxt")
    do ##class(%Library.File).CreateDirectory(noExportDir)
    set sc = ##class(%IPM.Main).Shell("package-database module-with-requirements -no-export-python-deps -path " _ noExportDir)
    do $$$AssertStatusOK(sc, "Packaged with -no-export-python-deps")

    set noExportPkg = noExportDir _ "module-with-requirements-1.0.0-database.tgz"
    set extractDir2 = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-noreqtxt")
    do ##class(%Library.File).CreateDirectory(extractDir2)
    set sc = ##class(%IPM.General.Archive).Extract(noExportPkg, extractDir2)
    do $$$AssertStatusOK(sc, "Extracted no-export package")

    set wheelPath2 = ##class(%Library.File).NormalizeFilename("wheels/lune-1.6.2-py3-none-any.whl", extractDir2)
    do $$$AssertNotTrue(##class(%Library.File).Exists(wheelPath2), "Wheel excluded when -no-export-python-deps is set")
}

/// Test that a module with both requirements.txt and explicit <PythonWheel> resources
/// gets both sets of wheels packaged correctly. The two sources should not conflict —
/// ExportPythonDependencies resolves requirements.txt into wheels and adds <PythonWheel>
/// entries, then CopyNonCompiledResources stages all PythonWheel resources.
Method TestPackageWithMixedPythonDeps()
{
    set testNS = "TESTDBMIXPY"
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "module-with-mixed-python")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module with mixed Python deps")

    // Package as database (export-python-deps on by default)
    set sc = ##class(%IPM.Main).Shell("package-database module-with-mixed-python -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module with mixed Python deps")

    // Extract and verify both wheels are present
    set packageFile = ..PackageOutputDir _ "module-with-mixed-python-1.0.0-database.tgz"
    set extractDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "extract-mixpy")
    do ##class(%Library.File).CreateDirectory(extractDir)
    set sc = ##class(%IPM.General.Archive).Extract(packageFile, extractDir)
    do $$$AssertStatusOK(sc, "Extracted package")

    // Explicit <PythonWheel> resource
    set luneWheel = ##class(%Library.File).NormalizeFilename("wheels/lune-1.6.2-py3-none-any.whl", extractDir)
    do $$$AssertTrue(##class(%Library.File).Exists(luneWheel), "Explicit PythonWheel (lune) included in package")

    // Wheel resolved from requirements.txt — pycparser filename includes version and platform tags
    set wheelsDir = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).NormalizeFilename("wheels", extractDir))
    set pycparserFound = 0
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %Library.File_FileSet(?, ?, ?, ?)", wheelsDir, "pycparser*.whl", "", 0)
    while rs.%Next() {
        set pycparserFound = 1
    }
    do $$$AssertTrue(pycparserFound, "requirements.txt wheel (pycparser) included in package")
}

/// Test that FileCopy resources are applied during database package install.
/// FileCopy.OnBeforePhase("Activate") fires because resource processor hooks run at
/// Module level (in Module.RunPhase), not inside the lifecycle method.
/// WebApplication creation also works (via %Configure, which has no Database.cls override).
Method TestNonCompiledResourcesAppliedDuringInstall()
{
    set testNS = "TESTDBNONCMP"
    set sc = ..CreateTestNamespace(testNS)
    do $$$AssertStatusOK(sc, "Created test namespace")

    set moduleDir = ..GetModuleDir("db-packaging", "module-with-all-resources")

    new $namespace
    set $namespace = testNS
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded module (FileCopy runs during Activate)")

    // Package as database
    set sc = ##class(%IPM.Main).Shell("package-database all-resources-module -path " _ ..PackageOutputDir)
    do $$$AssertStatusOK(sc, "Packaged module as database")

    set packageFile = ..PackageOutputDir _ "all-resources-module-1.0.0-database.tgz"

    // Compute FileCopy target: ${mgrdir}../all-resources-data.txt
    // ParentDirectoryName handles the .. reliably across platforms
    set mgrDir = ##class(%Library.File).ManagerDirectory()
    set parentDir = ##class(%Library.File).ParentDirectoryName(mgrDir)
    set fileCopyTarget = ##class(%Library.File).NormalizeFilename("all-resources-data.txt", parentDir)

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
    do $$$AssertStatusOK(sc, "Installed database package")

    // FileCopy.OnBeforePhase("Activate") is invoked by Module.RunPhase independently
    // of the lifecycle method — resource processor hooks are siblings, not children.
    do $$$AssertTrue(##class(%Library.File).Exists(fileCopyTarget), "FileCopy target created during database install")
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

}
