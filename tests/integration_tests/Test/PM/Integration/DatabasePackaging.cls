/// Test class for database packaging functionality
Class Test.PM.Integration.DatabasePackaging Extends Test.PM.Integration.Base
{

/// Namespaces created during the current test — cleaned up in OnAfterOneTest.
Property CreatedNamespaces As %List;

/// Namespace active when the test class was invoked — restored after each test.
Property OriginalNamespace As %String;

/// Directory where .tgz packages are written during tests — wiped and recreated in OnBeforeOneTest.
Property PackageOutputDir As %String;

/// Directory holding database packages shared across tests, unlike PackageOutputDir which is
/// wiped per test. Created in OnBeforeAllTests, removed in OnAfterAllTests.
Property SharedPackageDir As %String;

/// Globals databases created per-test — cleaned up in OnAfterOneTest.
/// Separate from the routines DB so dismounting during package-database doesn't lose IPM metadata.
Property CreatedGlobalsDatabases As %List;

/// Web applications any test in this class causes to be created, by name. They live in %SYS, so
/// deleting the namespace one points at does not remove it; they are deleted in OnAfterAllTests.
/// Register with TrackWebApp before the call that creates one, so an assertion failure part-way
/// through a test still leaves the name on the list.
Property TrackedWebApps As %List;

/// Files and directories outside the test sandbox that fixtures create, such as FileCopy targets.
/// Deleted in OnAfterAllTests. Register with TrackPath before the call that creates one.
Property TrackedPaths As %List;

/// Packaging namespaces are shared across tests to avoid the ~10s overhead of creating and
/// tearing down a namespace + globals DB for every test. Each shared NS is lazily initialized
/// on first use and cleaned up in OnAfterAllTests. Tests still create their own install
/// namespaces via CreateTestNamespace — those are per-test and cleaned up in OnAfterOneTest.
///
/// Sharing is safe because package-database only reads the namespace: it copies the routines
/// database's IRIS.DAT and leaves the namespace's classes, globals and module registry alone.
/// It does mean a package built from a shared NS contains every module loaded there, so a test that
/// asserts some class is absent from an IRIS.DAT needs its own packaging namespace.
/// Any on-disk side effects (e.g. wheels downloaded by ExportPythonDependencies) are the
/// responsibility of the individual tests.
///
/// Shared NS for the majority of tests — generally along compiled-resource lines.
/// Lazily created by GetOrCreateSharedNS1; cleaned up in OnAfterAllTests.
Property SharedNS1 As %String;

/// Shared NS for Python/resource-heavy tests — generally along non-compiled-resource lines.
/// Lazily created by GetOrCreateSharedNS2; cleaned up in OnAfterAllTests.
/// Note: Each module loaded here must use a distinct PythonWheel filename — IPM disallows
/// two modules in the same namespace from claiming the same wheel. If adding a module with a
/// PythonWheel or requirements.txt, ensure it uses a wheel not already claimed by another
/// module in this namespace (e.g. lune, pycparser, six are already taken).
Property SharedNS2 As %String;

/// Globals databases for shared namespaces — tracked separately since they outlive individual tests.
/// Cleaned up in OnAfterAllTests.
Property SharedGlobalsDatabases As %List;

/// Directory this fixture puts a test-created database in, by the convention CreateTestNamespace
/// uses when it makes one. Deliberately not a Config.Databases lookup: cleanup paths run when the
/// entry is already gone, or was never created because a previous run died early.
/// Not named Test* — %UnitTest.TestCase would run it as a test case.
ClassMethod FixtureDatabaseDirectory(dbName As %String) As %String
{
    quit ##class(%Library.File).NormalizeDirectory(##class(%Library.File).ManagerDirectory() _ dbName)
}

/// Dismounts and deletes a database CreateTestNamespace created, then removes its directory.
/// Tolerates a database that is already partly or wholly gone.
ClassMethod DeleteFixtureDatabase(dbName As %String) As %Status
{
    set dbPath = ..FixtureDatabaseDirectory(dbName)
    set ns = $namespace
    set sc = $$$OK
    try {
        set $namespace = "%SYS"
        do ##class(SYS.Database).DismountDatabase(dbPath)
        if ##class(Config.Databases).Exists(dbName) {
            $$$ThrowOnError(##class(Config.Databases).Delete(dbName))
        }
        if ##class(%Library.File).Exists(##class(%Library.File).NormalizeFilename("IRIS.DAT", dbPath)) {
            $$$ThrowOnError(##class(SYS.Database).DeleteDatabase(dbPath))
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    set $namespace = ns
    if ##class(%Library.File).DirectoryExists(dbPath) {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(dbPath)
    }
    quit sc
}

/// Cached .tgz paths for modules packaged identically by more than one test, keyed by module name.
/// Reuse is safe: `load <tgz>` extracts to a temp directory and copies from there, so the archive
/// itself is never modified by an install (including the swap and tamper flows).
Property CachedPackages As array Of %String;

/// Defensive cleanup of leftover shared namespaces from interrupted previous runs.
Method OnBeforeAllTests() As %Status
{
    set ..OriginalNamespace = $namespace
    set ..SharedNS1 = ""
    set ..SharedNS2 = ""
    set ..SharedGlobalsDatabases = ""
    set ..TrackedWebApps = ""
    set ..TrackedPaths = ""

    set ..SharedPackageDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "pkg-test-shared")
    if ##class(%Library.File).DirectoryExists(..SharedPackageDir) {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(..SharedPackageDir)
    }
    do ##class(%File).CreateDirectory(..SharedPackageDir)

    for i=1:1:2 {
        set ns = "TESTDBPKGNS" _ i
        do ##class(%IPM.Test.Utils).DeleteNamespace(ns)
        // Best-effort: there is usually nothing left from a previous clean run.
        do ..DeleteFixtureDatabase(ns _ "G")
    }
    quit $$$OK
}

/// Resets test state: clears namespace/DB tracking lists and creates a clean package output
/// directory (wiping any leftover from previous runs).
Method OnBeforeOneTest() As %Status
{
    set ..CreatedNamespaces = ""
    set ..CreatedGlobalsDatabases = ""
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

    for i=1:1:$listlength(..CreatedNamespaces) {
        set ns = $listget(..CreatedNamespaces, i)
        if (ns '= "") {
            set sc = $$$ADDSC(sc, ##class(%IPM.Test.Utils).DeleteNamespace(ns))
        }
    }
    for i=1:1:$listlength(..CreatedGlobalsDatabases) {
        set dbName = $listget(..CreatedGlobalsDatabases, i)
        if dbName '= "" {
            set sc = $$$ADDSC(sc, ..DeleteFixtureDatabase(dbName))
        }
    }
    return sc
}

/// Tears down shared namespaces (TESTDBPKGNS1, TESTDBPKGNS2) and their globals databases, plus the
/// tracked web applications and paths. Per-test namespaces and DBs are handled by OnAfterOneTest.
Method OnAfterAllTests() As %Status
{
    set sc = $$$OK
    set $namespace = ..OriginalNamespace

    // Web applications live in %SYS and survive namespace deletion, so they are removed by name.
    set $namespace = "%SYS"
    for i=1:1:$listlength(..TrackedWebApps) {
        set appName = $listget(..TrackedWebApps, i)
        try {
            if (appName '= "") && ##class(Security.Applications).Exists(appName) {
                $$$ThrowOnError(##class(Security.Applications).Delete(appName))
            }
        } catch ex {
            set sc = $$$ADDSC(sc, ex.AsStatus())
        }
    }
    set $namespace = ..OriginalNamespace

    for i=1:1:$listlength(..TrackedPaths) {
        try {
            do ..DeletePath($listget(..TrackedPaths, i))
        } catch ex {
            set sc = $$$ADDSC(sc, ex.AsStatus())
        }
    }

    if ..SharedNS1 '= "" {
        set sc = $$$ADDSC(sc, ##class(%IPM.Test.Utils).DeleteNamespace(..SharedNS1))
    }
    if ..SharedNS2 '= "" {
        set sc = $$$ADDSC(sc, ##class(%IPM.Test.Utils).DeleteNamespace(..SharedNS2))
    }

    if (..SharedPackageDir '= "") && ##class(%Library.File).DirectoryExists(..SharedPackageDir) {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(..SharedPackageDir)
    }

    for i=1:1:$listlength(..SharedGlobalsDatabases) {
        set dbName = $listget(..SharedGlobalsDatabases, i)
        if dbName '= "" {
            set sc = $$$ADDSC(sc, ..DeleteFixtureDatabase(dbName))
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
    // Resolved before the %SYS switch below, which cannot dispatch to this class.
    set globalsPath = ..FixtureDatabaseDirectory(globalsDBName)
    // Leftover state from a previous test run
    do ..DeleteFixtureDatabase(globalsDBName)
    set sc = $$$OK
    try {
        new $namespace
        set $namespace = "%SYS"

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

/// Moves the namespace CreateTestNamespace just registered from per-test tracking to shared
/// tracking, so OnAfterOneTest does not tear down a namespace later tests still need.
/// Call immediately after CreateTestNamespace — it operates on the last entry of each list.
Method PromoteLastCreatedToShared()
{
    set lastIdx = $listlength(..CreatedNamespaces)
    set ..CreatedNamespaces = $list(..CreatedNamespaces, 1, lastIdx - 1)
    set lastIdx = $listlength(..CreatedGlobalsDatabases)
    set lastDB = $list(..CreatedGlobalsDatabases, lastIdx)
    set ..CreatedGlobalsDatabases = $list(..CreatedGlobalsDatabases, 1, lastIdx - 1)
    set ..SharedGlobalsDatabases = ..SharedGlobalsDatabases _ $listbuild(lastDB)
}

/// Records a web application name for deletion in OnAfterAllTests.
Method TrackWebApp(appName As %String)
{
    set ..TrackedWebApps = ..TrackedWebApps _ $listbuild(appName)
}

/// Records a file or directory for deletion in OnAfterAllTests.
Method TrackPath(path As %String)
{
    set ..TrackedPaths = ..TrackedPaths _ $listbuild(path)
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
    set depModuleDir = ..GetModuleDir("db-packaging", "dep-module")
    set simpleDir = ..GetModuleDir("db-packaging", "simple-db-module")
    set withDepsDir = ..GetModuleDir("db-packaging", "main-with-deps")
    set testsDir = ..GetModuleDir("db-packaging", "module-with-tests")
    set invokesDir = ..GetModuleDir("db-packaging", "module-with-invokes")

    $$$ThrowOnError(..CreateTestNamespace(ns))
    do ..PromoteLastCreatedToShared()

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
    set mixPyDir = ..GetModuleDir("db-packaging", "module-with-mixed-python")
    set depResDir = ..GetModuleDir("db-packaging", "dep-with-resources")
    set mainResDir = ..GetModuleDir("db-packaging", "main-with-resource-deps")
    set nsWebAppDir = ..GetModuleDir("db-packaging", "module-with-ns-relative-webapp")

    $$$ThrowOnError(..CreateTestNamespace(ns))
    do ..PromoteLastCreatedToShared()

    // The source loads below create these outside the namespace.
    do ..TrackWebApp("/csp/" _ $zconvert(ns, "L") _ "/nsapp")
    do ..TrackPath(..NSAppDirectory(ns))
    do ..TrackPath(..ManagerParentFile("dep-res-data.txt"))
    do ..TrackPath(..ManagerParentFile("main-res-data.txt"))

    new $namespace
    set $namespace = ns
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ mixPyDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ depResDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ mainResDir))
    $$$ThrowOnError(##class(%IPM.Main).Shell("load -v " _ nsWebAppDir))

    set ..SharedNS2 = ns
    quit ns
}

/// Returns the path to a database package for pModule, building it in the shared packaging
/// namespace on first request and reusing the .tgz afterwards. Only for modules that multiple
/// tests need packaged with default options — tests that mutate the module or pass extra
/// packaging flags must call package-database themselves.
Method GetOrCreateDatabasePackage(
	pModule As %String,
	pVersion As %String = "1.0.0") As %String
{
    if ..CachedPackages.IsDefined(pModule) {
        quit ..CachedPackages.GetAt(pModule)
    }

    set packagingNS = ..GetOrCreateSharedNS1()
    new $namespace
    set $namespace = packagingNS
    set packageFile = ..PackageDatabase(pModule, pVersion, , ..SharedPackageDir)
    if '##class(%Library.File).Exists(packageFile) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Expected package not created: " _ packageFile))
    }
    do ..CachedPackages.SetAt(packageFile, pModule)
    quit packageFile
}

/// Runs package-database for module in the current namespace, asserts it succeeded and returns the
/// .tgz path. outputDir defaults to PackageOutputDir.
Method PackageDatabase(
	module As %String,
	version As %String = "1.0.0",
	flags As %String = "",
	outputDir As %String = "") As %String
{
    if outputDir = "" {
        set outputDir = ..PackageOutputDir
    }
    set command = "package-database " _ module _ $select(flags = "": "", 1: " " _ flags) _ " -path " _ outputDir
    do $$$AssertStatusOK(##class(%IPM.Main).Shell(command), "Packaged " _ module _ " " _ version _ " as database")
    quit ##class(%Library.File).NormalizeFilename(module _ "-" _ version _ "-database.tgz", outputDir)
}

/// Creates namespace ns, installs packageFile into it with -swap-db and asserts it succeeded.
/// Leaves $namespace set to ns, so callers new $namespace first.
Method InstallDatabasePackage(
	ns As %String,
	packageFile As %String)
{
    do $$$AssertStatusOK(..CreateTestNamespace(ns), "Created install namespace " _ ns)
    set $namespace = ns
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db"), "Installed " _ ##class(%Library.File).GetFilename(packageFile) _ " into " _ ns)
}

/// Installs a database package, runs its code and uninstalls it. The install checks the package's
/// structure and checksum before it swaps, so a successful install covers those.
Method TestSimplePackageAndInstall()
{
    new $namespace
    set installNS = "TESTDBINST1"
    do ..InstallDatabasePackage(installNS, ..GetOrCreateDatabasePackage("simple-db-module"))

    do $$$AssertEquals(##class(SimpleModule.Main).GetMessage(), "Hello from Simple DB Module", "Packaged code runs")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("simple-db-module"), "Module registered")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall simple-db-module"), "Uninstalled database package")
    do $$$AssertNotTrue(##class(%IPM.Storage.Module).NameExists("simple-db-module"), "Module record removed")
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Classes removed from namespace after uninstall")
    // The backup of the replaced database is left for the user to remove.
    do $$$AssertTrue(..CountBackupFiles(installNS) > 0, "Backup file preserved after uninstall")
}

/// Test packaging with and without test resources
Method TestPackageAndInstallWithTestResources()
{
    set packagingNS = ..GetOrCreateSharedNS1()
    set testsModuleDir = ..GetModuleDir("db-packaging", "module-with-tests")

    // Both packages have the same filename, so they go to separate directories — otherwise the
    // second package overwrites the first and both installs below exercise the same .tgz.
    set withTestsDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "with-tests")
    set noTestsDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "no-tests")

    // No-tests package first, from the shared NS, which has module-with-tests loaded without its
    // test resources. -include-tests compiles test classes into the namespace it runs in, so
    // packaging both variants from one namespace would put the tests in both packages.
    new $namespace
    set $namespace = packagingNS
    set noTestsPackage = ..PackageDatabase("module-with-tests", , , noTestsDir)

    set withTestsNS = "TESTDBWITHTESTSPKG"
    do $$$AssertStatusOK(..CreateTestNamespace(withTestsNS), "Created with-tests packaging namespace")
    set $namespace = withTestsNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ testsModuleDir), "Loaded module-with-tests from source")
    set withTestsPackage = ..PackageDatabase("module-with-tests", , "-include-tests", withTestsDir)

    do ..InstallDatabasePackage("TESTDBTESTINS1", withTestsPackage)
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.Test"), "<UnitTest> class included with -include-tests")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.TestHelper"), "Scope=test class included with -include-tests")

    do ..InstallDatabasePackage("TESTDBTESTINS2", noTestsPackage)
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.Test"), "<UnitTest> class excluded by default")
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("TestModule.TestHelper"), "Scope=test class excluded by default")
}

/// Test install validation (errors and edge cases). The happy path is covered by
/// TestSimplePackageAndInstall, so this test only exercises the rejection cases.
Method TestPackagingAndInstallValidation()
{
    new $namespace
    set packageFile = ..GetOrCreateDatabasePackage("simple-db-module")

    // Test: Tampered IRIS.DAT fails checksum validation
    set tamperDir = ..ExtractPackage(packageFile, "tamper-extract")

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
    do $$$AssertStatusOK(##class(%IPM.General.Archive).Create(tamperDir, tamperedPackage), "Repacked tampered archive")

    // Every rejection below runs in this namespace: each is rejected by ValidateBeforeSwap, which runs
    // entirely before the swap, so the namespace's routines DB stays pristine for the next one.
    set installNS = "TESTDBVALIDINS"
    do $$$AssertStatusOK(..CreateTestNamespace(installNS), "Created namespace for rejected installs")
    set $namespace = installNS

    set sc = ##class(%IPM.Main).Shell("load " _ tamperedPackage _ " -swap-db")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "SHA-256", "Tampered IRIS.DAT rejected with a SHA-256 checksum mismatch")
    // The record is saved once module.xml loads, so a pre-swap rejection must roll it back.
    do $$$AssertNotTrue(##class(%IPM.Storage.Module).NameExists("simple-db-module"), "No module record left behind by a pre-swap rejection")

    // Test: Missing deps/ directory fails validation
    set missingDepsDir = ..ExtractPackage(packageFile, "missing-deps-extract")
    do ##class(%Library.File).RemoveDirectoryTree(##class(%Library.File).NormalizeDirectory("deps", missingDepsDir))
    set missingDepsPackage = ..PackageOutputDir _ "simple-db-module-missing-deps.tgz"
    do $$$AssertStatusOK(##class(%IPM.General.Archive).Create(missingDepsDir, missingDepsPackage), "Repacked archive without deps/ directory")

    set sc = ##class(%IPM.Main).Shell("load " _ missingDepsPackage _ " -swap-db")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "deps/", "Package with no deps/ directory rejected by validation")

    // Test: module.xml without a <Checksum> element fails validation.
    set noChecksumDir = ..ExtractPackage(packageFile, "no-checksum-extract")
    set moduleXML = ..ReadPackageModuleXML(noChecksumDir)
    // Strip the whole element rather than blanking its text: an empty <Checksum> would fail the
    // checksum comparison instead, which the tampering case above already covers.
    set checksumStart = $find(moduleXML, "<Checksum") - $length("<Checksum")
    do $$$AssertTrue(checksumStart > 0, "Packaged module.xml has a <Checksum> element to remove")
    set checksumEnd = $find(moduleXML, "</Checksum>")
    do ..WritePackageModuleXML(noChecksumDir, $extract(moduleXML, 1, checksumStart - 1) _ $extract(moduleXML, checksumEnd, *))
    set noChecksumPackage = ..PackageOutputDir _ "simple-db-module-no-checksum.tgz"
    do $$$AssertStatusOK(##class(%IPM.General.Archive).Create(noChecksumDir, noChecksumPackage), "Repacked archive without <Checksum>")

    set sc = ##class(%IPM.Main).Shell("load " _ noChecksumPackage _ " -swap-db")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "Checksum", "module.xml without a <Checksum> element rejected by validation")

    // Test: a <Mapping> whose source database doesn't exist fails validation. The checksum covers
    // IRIS.DAT only, so editing module.xml doesn't trip it.
    set badMapDir = ..ExtractPackage(packageFile, "bad-mapping-extract")
    set moduleXML = ..ReadPackageModuleXML(badMapDir)
    do $$$AssertTrue(moduleXML [ "<Module>", "Packaged module.xml has a <Module> element to extend")
    do ..WritePackageModuleXML(badMapDir, $replace(moduleXML, "<Module>", "<Module><Mapping Name=""DbPkgBadMap.GBL"" Source=""DBPKGNOSUCHDB""/>", 1, 1))
    set badMapPackage = ..PackageOutputDir _ "simple-db-module-bad-mapping.tgz"
    do $$$AssertStatusOK(##class(%IPM.General.Archive).Create(badMapDir, badMapPackage), "Repacked archive with a bad <Mapping>")

    set sc = ##class(%IPM.Main).Shell("load " _ badMapPackage _ " -swap-db")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "DBPKGNOSUCHDB", "<Mapping> with a missing source database rejected by validation")

    // A swap leaves a backup behind, so none here means none of the four rejections swapped.
    do $$$AssertEquals(..CountBackupFiles(installNS), 0, "No DB swap occurred — every rejection is pre-swap")
}

/// Test upgrading from source package to database package
Method TestUpgradeSourceToDatabase()
{
    new $namespace
    set dbPackage = ..GetOrCreateDatabasePackage("simple-db-module")
    set $namespace = ..GetOrCreateSharedNS1()
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("package simple-db-module -path " _ ..PackageOutputDir _ "simple-db-module-1.0.0/"), "Packaged as source")
    set sourcePackage = ..PackageOutputDir _ "simple-db-module-1.0.0.tgz"

    set installNS = "TESTDBUPGSRCINS"
    do $$$AssertStatusOK(..CreateTestNamespace(installNS), "Created installation namespace")
    set $namespace = installNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ sourcePackage), "Installed source package")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("update simple-db-module -path " _ dbPackage _ " -swap-db"), "Upgraded from source to database package")
    set module = ##class(%IPM.Storage.Module).NameOpen("simple-db-module")
    do $$$AssertEquals(module.Packaging, "database", "Module packaging changed to 'database' after source-to-database upgrade")
    do $$$AssertTrue(..CountBackupFiles(installNS) > 0, "DB swap occurred during source-to-database upgrade")
}

/// A source module can be installed alongside a database package, but a second database package
/// in the same namespace is rejected.
Method TestMixedPackaging()
{
    new $namespace
    set dbPackageFile = ..GetOrCreateDatabasePackage("simple-db-module")
    set dbPackage2 = ..GetOrCreateDatabasePackage("dep-module")
    set packagingNS = ..GetOrCreateSharedNS1()

    set installNS = "TESTDBMIXEDINS"
    do ..InstallDatabasePackage(installNS, dbPackageFile)

    // dep-module is pre-loaded in shared NS1; package it as source first (no cache — source flow)
    set $namespace = packagingNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("package dep-module -path " _ ..PackageOutputDir _ "dep-module-1.0.0/"), "Packaged as source")
    set sourcePackageFile = ..PackageOutputDir _ "dep-module-1.0.0.tgz"

    set $namespace = installNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ sourcePackageFile), "Installed source package alongside database package")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("simple-db-module"), "Database package still installed")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("dep-module"), "Source package installed")

    set sc = ##class(%IPM.Main).Shell("load " _ dbPackage2 _ " -swap-db")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "Only one database package", "Second database package in the same namespace rejected by the one-package-per-namespace constraint")
}

/// A database install replaces the namespace's routines DB wholesale, so any module whose code
/// lives in that DB would lose its classes while its metadata (in the globals DB) survived.
/// Verifies that install is rejected in that case and that uninstalling the module clears the way.
///
/// Also verifies the two exemptions: the package's own transitive dependencies (their code is in
/// the incoming IRIS.DAT) and modules with no routines-DB code do not trigger the rejection.
Method TestInstallRejectedWhenModulesWouldBeOrphaned()
{
    set depModuleDir = ..GetModuleDir("db-packaging", "dep-module")
    set noCodeDir = ..GetModuleDir("db-packaging", "module-without-code")
    do ..TrackPath(..ManagerParentFile("no-code-data.txt"))

    new $namespace
    set dbPackage = ..GetOrCreateDatabasePackage("simple-db-module")

    // main-with-deps depends on dep-module, so dep-module's code ships inside this IRIS.DAT
    set withDepsPackage = ..GetOrCreateDatabasePackage("main-with-deps")

    // --- Rejection: a source module with classes in the routines DB blocks the install ---
    set installNS = "TESTDBORPHANINS"
    do $$$AssertStatusOK(..CreateTestNamespace(installNS), "Created install namespace")
    set $namespace = installNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ depModuleDir), "Loaded dep-module from source into install namespace")

    set sc = ##class(%IPM.Main).Shell("load " _ dbPackage _ " -swap-db")
    set errorText = $system.Status.GetErrorText(sc)
    do $$$AssertTrue(errorText [ "dep-module", "Install rejected, naming dep-module as the module the swap would orphan")
    do $$$AssertTrue(errorText [ "uninstall", "Error tells the user to uninstall first")
    do $$$AssertEquals(..CountBackupFiles(installNS), 0, "No DB swap occurred — rejection is pre-swap")

    // --- Uninstalling the blocking module clears the way ---
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall dep-module"), "Uninstalled dep-module")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ dbPackage _ " -swap-db"), "Install succeeds once the blocking module is uninstalled")

    // --- Exemption: a module with no routines-DB code does not block ---
    // module-without-code has only a FileCopy resource, which lives on the filesystem rather
    // than in the routines DB, so the swap cannot orphan it.
    set installNS2 = "TESTDBORPHANINS2"
    do $$$AssertStatusOK(..CreateTestNamespace(installNS2), "Created second install namespace")
    set $namespace = installNS2
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ noCodeDir), "Loaded module-without-code from source")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ dbPackage _ " -swap-db"), "Module with no routines-DB code does not block the install")

    // --- Exemption: the package's own transitive dependencies do not block ---
    // dep-module is installed as source here, but main-with-deps carries its code and metadata,
    // so the swap replaces rather than orphans it.
    set installNS3 = "TESTDBORPHANINS3"
    do $$$AssertStatusOK(..CreateTestNamespace(installNS3), "Created third install namespace")
    set $namespace = installNS3
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ depModuleDir), "Loaded dep-module from source into third namespace")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ withDepsPackage _ " -swap-db"), "Packaged dependency does not block the install")
}

/// Upgrading a database package whose dependency tree changed shape must not be blocked by the
/// orphan check and dependencies that no longer ship in the new IRIS.DAT must have their stale
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
/// rather than the flattened set fails on deptree-leaf and one that ignores transitive additions
/// fails on deptree-extra.
///
/// deptree-parent and deptree-stable also carry an <UpdatePackage>, so the version bumps double as
/// coverage that the root's and a dependency's update steps are seeded on install and run on upgrade.
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
    set v1Package = ..PackageDatabase("deptree-parent")

    // --- Reshape the tree in the packaging NS, then package v2 ---
    // deptree-added and deptree-extra are new; deptree-stable gains the deptree-extra edge at 2.0.0.
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ extraDir), "Loaded deptree-extra")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ addedDir), "Loaded deptree-added")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("update deptree-stable -path " _ stableV2Dir), "Updated deptree-stable to 2.0.0")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("update deptree-parent -path " _ parentV2Dir), "Updated deptree-parent to 2.0.0")

    // The package ships whatever is in the namespace, so a dependency the new version drops has to
    // leave the namespace before packaging. `update` only reshapes the dependency tree.
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall deptree-dropped"), "Uninstalled the dropped dependency")
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Dropped"), "deptree-dropped code gone from the packaging namespace")
    set v2Package = ..PackageDatabase("deptree-parent", "2.0.0")

    // --- Install v1 into a clean namespace ---
    do ..InstallDatabasePackage("TESTDBDEPTREEINST", v1Package)
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("DepTree.Dropped"), "deptree-dropped code in v1 IRIS.DAT")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-dropped"), "deptree-dropped metadata registered from v1 deps/")
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-leaf"), "deptree-leaf metadata registered from v1 deps/")

    // --- Upgrade to v2 ---
    // Every module installed here arrived inside v1's IRIS.DAT, so none of them may trigger the
    // orphan rejection — including deptree-dropped, which v2 no longer carries.
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("update deptree-parent -path " _ v2Package _ " -swap-db"), "Upgrade not blocked by the orphan check despite the reshaped tree")

    // Dropped dependency: code is gone from the new IRIS.DAT, so its metadata must go too
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
    do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("deptree-stable"), "deptree-stable metadata retained")

    // A dependency's own update steps run during a database upgrade, matching a source upgrade:
    // deptree-stable went 1.0.0 -> 2.0.0, so its new Step002 must run while Step001, seeded at the
    // v1 install, stays skipped. Without ApplyUpdateSteps in the dependency phase list both stay 0.
    do $$$AssertEquals($get(^DBPkgDepTreeSteps("step002"), 0), 1, "Dependency Step002 ran exactly once during the database upgrade")
    do $$$AssertEquals($get(^DBPkgDepTreeSteps("step001"), 0), 0, "Dependency Step001 never ran — seeded at the v1 install")

    // The root's own update steps behave the same way.
    do $$$AssertEquals($get(^DBPkgDepTreeParentSteps("step002"), 0), 1, "Root Step002 ran exactly once during the database upgrade")
    do $$$AssertEquals($get(^DBPkgDepTreeParentSteps("step001"), 0), 0, "Root Step001 never ran — seeded at the v1 install")
}

/// Python wheels ship in a database package by default: an explicit <PythonWheel> (lune) and a
/// requirements.txt dependency (pycparser). -export-python-deps 0 leaves both out. The packaged
/// lune wheel is installed when the package is.
Method TestPythonDependencyPackaging()
{
    // Capture module dirs before NS switch — GetModuleDir uses ^UnitTestRoot which is only set here
    set mixedModuleDir = ..GetModuleDir("db-packaging", "module-with-mixed-python")

    set packagingNS = ..GetOrCreateSharedNS2()
    new $namespace
    set $namespace = packagingNS

    set defaultPkg = ..PackageDatabase("module-with-mixed-python")
    set wheelsDir = ##class(%Library.File).NormalizeDirectory("wheels", ..ExtractPackage(defaultPkg, "extract-mixpy"))
    do $$$AssertTrue(..CountFiles(wheelsDir, "lune*.whl") > 0, "Explicit PythonWheel (lune) included by default")
    do $$$AssertTrue(..CountFiles(wheelsDir, "pycparser*.whl") > 0, "requirements.txt wheel (pycparser) included by default")

    set noExportDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "noexport")
    set noExportPkg = ..PackageDatabase("module-with-mixed-python", , "-export-python-deps 0", noExportDir)
    set noExportWheels = ##class(%Library.File).NormalizeDirectory("wheels", ..ExtractPackage(noExportPkg, "extract-nowheel"))
    do $$$AssertEquals(..CountFiles(noExportWheels, "*.whl"), 0, "No wheels shipped with -export-python-deps 0")

    // Runtime install: PythonWheel.OnPhase("Initialize") fires (no Database.cls override)
    do ..PurgePythonPackage("lune")
    do ..InstallDatabasePackage("TESTDBPYWHLINS", defaultPkg)
    try {
        do ##class(%SYS.Python).Import("lune")
        do $$$AssertSuccess("lune importable after database install")
        do $$$AssertEquals(..GetPythonVersion("lune"), "1.6.2", "lune version is the packaged one")
    } catch ex {
        do $$$AssertFailure("Failed to import lune after database install: " _ ex.AsStatus())
    }

    // Cleanup: wheels downloaded by ExportPythonDependencies during packaging
    do ..DeletePattern(mixedModuleDir _ "wheels/", "pycparser*.whl")
}

/// Compile.After and Activate.After invokes run during a database install: the swap happens inside
/// %Reload, so every invoke from Reload.After onward runs against the mounted database.
/// The install namespace has its own globals database, so the markers the source load set in the
/// packaging namespace are not visible there.
Method TestInvokeBehaviorDuringDatabaseInstall()
{
    set packagingNS = ..GetOrCreateSharedNS1()
    new $namespace
    set $namespace = packagingNS
    set packageFile = ..PackageDatabase("module-with-invokes")

    do ..InstallDatabasePackage("TESTDBINVKINS", packageFile)
    do $$$AssertEquals($get(^InvokeTest("compile")), 1, "Compile invoke ran during database install")
    do $$$AssertEquals($get(^InvokeTest("activate")), 1, "Activate invoke ran during database install")
}

/// Mappings, then a failure after the swap.
///
/// Installing v1 applies the <Mapping> elements of the root and of a dependency that also has a
/// <CPF>, the combination that deadlocks when mappings are applied inside the install's transaction.
///
/// The v2 package is broken after it is built, because packaging loads each fixture from source
/// first: deleting dep-with-cpf's staged CPF file makes its Initialize fail after the swap. That
/// failure keeps the new state: the v2 module record, the removal of the dependency v2 dropped and
/// v2's new mapping, applied before the dependency pass. Re-running the update from the intact
/// package then succeeds.
Method TestMappingsAndPostSwapFailure()
{
    set depMapDir = ..GetModuleDir("db-packaging", "dep-with-mapping")
    set v1Dir = ..GetModuleDir("db-packaging", "module-with-mappings-v1")
    set depCPFDir = ..GetModuleDir("db-packaging", "dep-with-cpf")
    set v2Dir = ..GetModuleDir("db-packaging", "module-with-mappings-v2")

    set packagingNS = "TESTDBMAPPKG"
    do $$$AssertStatusOK(..CreateTestNamespace(packagingNS), "Created packaging namespace")
    new $namespace
    set $namespace = packagingNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ depMapDir), "Loaded dep-with-mapping")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ v1Dir), "Loaded module-with-mappings 1.0.0")
    set v1Package = ..PackageDatabase("module-with-mappings")

    // The package ships whatever is in the namespace, so the dropped dependency has to leave it.
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ depCPFDir), "Loaded dep-with-cpf")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("update module-with-mappings -path " _ v2Dir), "Updated module-with-mappings to 2.0.0")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall dep-with-mapping"), "Uninstalled the dropped dependency")
    set v2Package = ..PackageDatabase("module-with-mappings", "2.0.0")

    set brokenDir = ..ExtractPackage(v2Package, "post-swap-broken")
    set depStageDir = ##class(%IPM.Lifecycle.Database).GetDependencyStagingDir(brokenDir, "dep-with-cpf")
    set stagedCPF = ##class(%Library.File).NormalizeFilename("dep-with-cpf.cpf", ##class(%Library.File).NormalizeDirectory("src/cpf", depStageDir))
    do $$$AssertTrue(##class(%Library.File).Delete(stagedCPF), "Deleted dep-with-cpf's staged CPF file (setup)")

    set installNS = "TESTDBMAPINS"
    do ..InstallDatabasePackage(installNS, v1Package)
    do ..AssertGlobalMapped(installNS, "DbPkgRootMap", "Root mapping applied during install")
    do ..AssertGlobalMapped(installNS, "DbPkgDepMap", "Dependency mapping applied during install")

    set output = ..CaptureCall("%IPM.Main", "Shell", "update module-with-mappings -path " _ brokenDir _ " -swap-db")
    do $$$AssertTrue(output [ "a later step failed", "Update fails after the swap")
    set module = ##class(%IPM.Storage.Module).NameOpen("module-with-mappings")
    do $$$AssertEquals($select($isobject(module): module.VersionString, 1: ""), "2.0.0", "Module record kept at the new version")
    do $$$AssertNotTrue(##class(%IPM.Storage.Module).NameExists("dep-with-mapping"), "Dropped dependency's record removed")
    do ..AssertGlobalMapped(installNS, "DbPkgV2Map", "Mapping applied before the failure kept")
    do $$$AssertTrue(output [ "Re-run the same update command", "Failure tells the user to re-run the update")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("update module-with-mappings -path " _ v2Package _ " -swap-db"), "Re-running the update from the intact package succeeds")
}

/// Asserts that namespace ns maps globalName from IRISTEMP, as the mapping fixtures declare.
Method AssertGlobalMapped(
	ns As %String,
	globalName As %String,
	message As %String)
{
    new $namespace
    set $namespace = "%SYS"
    do $$$AssertStatusOK(##class(Config.MapGlobals).Get(ns, globalName, .props), message)
    do $$$AssertEquals($get(props("Database")), "IRISTEMP", message _ ", from IRISTEMP")
}

/// A module.xml declaring <Packaging>database</Packaging> with no IRIS.DAT beside it is rejected
/// rather than loaded as source.
Method TestSourceManifestDeclaringDatabaseRejected()
{
    set moduleDir = ..GetModuleDir("db-packaging", "source-declaring-database")
    new $namespace
    set ns = "TESTDBSRCDECL"
    do $$$AssertStatusOK(..CreateTestNamespace(ns), "Created namespace")
    set $namespace = ns

    set sc = ##class(%IPM.Main).Shell("load " _ moduleDir)
    do $$$AssertStatusNotOK(sc, "Load rejected")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "IRIS.DAT", "Error says the IRIS.DAT is missing")
    do $$$AssertNotTrue(##class(%IPM.Storage.Module).NameExists("source-declaring-database"), "No module record left behind")
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SourceDeclaringDatabase.Main"), "Nothing loaded as source")
}

/// <Global> resources of the root and of its dependencies are warned about, since their data lives
/// in the globals database and is not shipped.
Method TestWarnsAboutGlobals()
{
    set depDir = ..GetModuleDir("db-packaging", "dep-with-global")
    set rootDir = ..GetModuleDir("db-packaging", "module-with-global")
    new $namespace
    set ns = "TESTDBGLOBALPKG"
    do $$$AssertStatusOK(..CreateTestNamespace(ns), "Created packaging namespace")
    set $namespace = ns
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ depDir), "Loaded dep-with-global")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load -v " _ rootDir), "Loaded module-with-global")

    set output = ..CaptureModuleWarning("module-with-global", "WarnGlobalsNotShipped", 0)
    do $$$AssertTrue(output [ "'DbPkgRootGlobal.GBL' in this module", "Warning names the root's global")
    do $$$AssertTrue(output [ "'DbPkgDepGlobal.GBL' in dependency 'dep-with-global'", "Warning names the dependency's global")
}

/// Verifies that a module whose web application is relative to the installing namespace packages
/// and installs correctly: the <FileCopy> directory of static files lands under the install
/// namespace's CSP directory and the <WebApplication> is created with the install namespace's
/// name, path and NameSpace.
///
/// module-with-ns-relative-webapp uses ${cspdir}${namespaceLower} in both the FileCopy target and
/// the web application name and path, so the application created by the source load in the
/// packaging namespace has a different name and path from the one the install must create. That
/// makes the assertions here sensitive to expressions being resolved at package time rather than
/// install time.
///
/// A reinstall at the end covers CreateOrUpdateWebApp's Modify path, which a fresh install never
/// reaches.
Method TestNamespaceRelativeWebAppAppliedDuringInstall()
{
    set packagingNS = ..GetOrCreateSharedNS2()
    set installNS = "TESTDBNSWEBINS"
    set appDir = ..NSAppDirectory(installNS)
    set appName = "/csp/" _ $zconvert(installNS, "L") _ "/nsapp"
    do ..TrackWebApp(appName)
    do ..TrackPath(appDir)
    // A leftover target directory would let the file assertions below pass on stale files.
    do ..DeletePath(appDir)

    new $namespace
    set $namespace = packagingNS
    set packageFile = ..PackageDatabase("module-with-ns-relative-webapp")

    do ..InstallDatabasePackage(installNS, packageFile)
    // The FileCopy resource is a directory, so the whole tree is copied, nested files included.
    do $$$AssertTrue(##class(%Library.File).Exists(##class(%Library.File).NormalizeFilename("index.html", appDir)), "Top-level static file exists under the install namespace CSP directory")
    do $$$AssertTrue(##class(%Library.File).Exists(##class(%Library.File).NormalizeFilename("app.js", ##class(%Library.File).NormalizeDirectory("assets", appDir))), "Nested static file exists under the install namespace CSP directory")

    set $namespace = "%SYS"
    do $$$AssertStatusOK(##class(Security.Applications).Get(appName, .appProps), "Web application named for the install namespace was created")
    do $$$AssertEquals($get(appProps("NameSpace")), installNS, "Web application points at the install namespace")
    do $$$AssertEquals(##class(%Library.File).NormalizeDirectory($get(appProps("Path"))), appDir, "Web application path resolved to the install namespace CSP directory")

    // A reinstall finds the application already there, so CreateOrUpdateWebApp takes its Modify
    // path. Pointing Path somewhere stale first makes the correction observable.
    set staleProps("Path") = ##class(%Library.File).NormalizeDirectory("stale-nsapp", ##class(%Library.File).NormalizeDirectory("csp", $system.Util.InstallDirectory()))
    do $$$AssertStatusOK(##class(Security.Applications).Modify(appName, .staleProps), "Pointed the web application at a stale path")

    set $namespace = installNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ packageFile _ " -swap-db"), "Reinstalled database package over the existing install")

    set $namespace = "%SYS"
    do $$$AssertStatusOK(##class(Security.Applications).Get(appName, .updatedProps), "Read web application properties after reinstall")
    do $$$AssertEquals(##class(%Library.File).NormalizeDirectory($get(updatedProps("Path"))), appDir, "Reinstall corrected the stale web application path")
    do $$$AssertEquals($get(updatedProps("NameSpace")), installNS, "Reinstall left the web application on the install namespace")
}

/// Verifies packaging-type-aware registry filtering via zot (http://oras:5000). A version holds
/// either a source or a database package, so dep-module 1.0.0 is published as source first, then
/// replaced by a database package. Verifies: source install (no -swap-db), dependency resolution
/// picking source, a helpful error when only a database package is available and -swap-db is not
/// specified, and database install (-swap-db).
Method TestPublishDatabaseWithORAS()
{
    // dep-module and main-with-deps are pre-loaded in NS1; zot is configured there at NS init time.
    set packagingNS = ..GetOrCreateSharedNS1()

    set installNS = "TESTDBORASINSTNS"
    do $$$AssertStatusOK(..CreateTestNamespace(installNS), "Created ORAS install namespace")

    new $namespace
    set $namespace = installNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000"), "Configured zot registry in install NS")

    // --- Pre-test cleanup: purge any stale versions from a prior run ---
    set $namespace = packagingNS
    do ##class(%IPM.Main).Shell("unpublish zot/dep-module all -f")
    do ##class(%IPM.Main).Shell("unpublish zot/main-with-deps all -f")

    // --- Source packages ---
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish dep-module -r zot"), "Published dep-module as source to zot")
    // main-with-deps exercises the dependency filtering path
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish main-with-deps -r zot"), "Published main-with-deps as source to zot")

    set $namespace = installNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("install dep-module"), "Installed dep-module (source) without -swap-db")
    do $$$AssertEquals(##class(%IPM.Storage.Module).NameOpen("dep-module").Packaging, "module", "dep-module packaging is module (source) after non-swap-db install")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall dep-module -f"), "Uninstalled dep-module before next step")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("install main-with-deps"), "Installed main-with-deps (source)")
    do $$$AssertEquals(##class(%IPM.Storage.Module).NameOpen("dep-module").Packaging, "module", "dep-module resolved as source when installing main-with-deps")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall main-with-deps -f"), "Uninstalled main-with-deps")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall dep-module -f"), "Uninstalled dep-module after main-with-deps test")

    // --- Replace dep-module 1.0.0 with a database package ---
    set $namespace = packagingNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("unpublish zot/dep-module 1.0.0 -f"), "Unpublished source version of dep-module from zot")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish-database dep-module -r zot"), "Published dep-module as database to zot")

    set $namespace = installNS
    set sc = ##class(%IPM.Main).Shell("install dep-module")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "-swap-db", "Install without -swap-db fails and points at -swap-db when only a database package is available")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("install dep-module -swap-db"), "Installed dep-module with -swap-db")
    do $$$AssertEquals(##class(%IPM.Storage.Module).NameOpen("dep-module").Packaging, "database", "dep-module packaging is database after -swap-db install")

    // --- Cleanup ---
    // Errors are ignored: a failed publish above leaves nothing to unpublish.
    set $namespace = packagingNS
    do ##class(%IPM.Main).Shell("unpublish zot/dep-module all -f")
    do ##class(%IPM.Main).Shell("unpublish zot/main-with-deps all -f")
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

/// Returns how many files under dir match pattern, or 0 if dir does not exist.
ClassMethod CountFiles(
	dir As %String,
	pattern As %String) As %Integer
{
    quit:'##class(%Library.File).DirectoryExists(dir) 0
    quit ##class(%IPM.Utils.File).FindFiles(dir, pattern)
}

/// Counts IRIS_<dbname>_*.DAT backup files in the routines DB directory for a namespace.
Method CountBackupFiles(ns As %String) As %Integer
{
    set routinesDBName = ##class(%IPM.Utils.Module).GetRoutineDatabase(ns)
    quit ..CountFiles(##class(%IPM.Utils.Module).GetDatabaseDirectory(routinesDBName), "IRIS_" _ routinesDBName _ "_*.DAT")
}

/// Path of name in the parent of the manager directory, where the fixtures' ${mgrdir}../<name>
/// FileCopy targets land.
ClassMethod ManagerParentFile(name As %String) As %String
{
    quit ##class(%Library.File).NormalizeFilename(name, ##class(%Library.File).ParentDirectoryName(##class(%Library.File).ManagerDirectory()))
}

/// Directory module-with-ns-relative-webapp copies its files to when installed in ns,
/// ${cspdir}${namespaceLower}/nsapp/.
ClassMethod NSAppDirectory(ns As %String) As %String
{
    set cspDir = ##class(%Library.File).NormalizeDirectory("csp", $system.Util.InstallDirectory())
    // Construct, because NormalizeDirectory(name, dir) returns "" until the CSP directory exists.
    quit ##class(%Library.File).NormalizeDirectory(##class(%Library.File).Construct(cspDir, $zconvert(ns, "L"), "nsapp"))
}

/// Calls method on target, a class name or an object, and returns everything it wrote.
ClassMethod CaptureCall(
	target,
	method As %String,
	args...) As %String
{
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set exception = ""
    try {
        if $isobject(target) {
            do $method(target, method, args...)
        } else {
            do $classmethod(target, method, args...)
        }
    } catch ex {
        set exception = ex
    }
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .lines)

    if exception '= "" {
        throw exception
    }

    // One string, so assertions can match a warning by substring.
    set text = ""
    set key = ""
    for {
        set key = $order(lines(key))
        quit:key=""
        set text = text _ lines(key) _ $char(10)
    }
    quit text
}

/// Runs one of %IPM.Lifecycle.Database's packaging warnings for moduleName, installed in the current
/// namespace, and returns what it wrote. Cheaper than a package-database run, which also dismounts and
/// copies the routines database.
ClassMethod CaptureModuleWarning(
	moduleName As %String,
	warningMethod As %String,
	args...) As %String
{
    set module = ##class(%IPM.Storage.Module).NameOpen(moduleName, , .sc)
    $$$ThrowOnError(sc)
    quit ..CaptureCall(##class(%IPM.Lifecycle.Database).%New(module), warningMethod, args...)
}

/// Extracts packageFile into a fresh directory named label under PackageOutputDir and returns it,
/// so tests can assert on what the package contains.
Method ExtractPackage(
	packageFile As %String,
	label As %String) As %String
{
    set extractDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ label)
    if ##class(%Library.File).DirectoryExists(extractDir) {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(extractDir)
    }
    if '##class(%Library.File).CreateDirectoryChain(extractDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to create extract dir: " _ extractDir))
    }
    $$$ThrowOnError(##class(%IPM.General.Archive).Extract(packageFile, extractDir))
    quit extractDir
}

/// Reads a whole file into a string. A single Read() stops at the chunk size, which would leave
/// substring assertions matching against a truncated document.
ClassMethod ReadFile(path As %String) As %String
{
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(path))
    set text = ""
    while 'stream.AtEnd {
        set text = text _ stream.Read()
    }
    quit text
}

/// Returns the text of dir/module.xml.
ClassMethod ReadPackageModuleXML(dir As %String) As %String
{
    quit ..ReadFile(##class(%Library.File).NormalizeFilename("module.xml", dir))
}

/// Replaces the contents of dir/module.xml with xml.
ClassMethod WritePackageModuleXML(
	dir As %String,
	xml As %String)
{
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(##class(%Library.File).NormalizeFilename("module.xml", dir)))
    $$$ThrowOnError(stream.Clear())
    $$$ThrowOnError(stream.Write(xml))
    $$$ThrowOnError(stream.%Save())
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

/// A dependency's non-compiled and config-only resources must be applied during a database
/// install, not silently dropped: FileCopy, CPF, requirements.txt wheels, Generated resources and
/// <Invoke> elements all belong to the dependency, whose lifecycle phases run after the swap.
/// The install fails if a dependency's staged CPF file is missing, so a successful install also
/// covers that one being staged.
///
/// Also pins Initialize-phase precedence. Both modules merge a CPF touching the same setting; the
/// dependency's merge happens after the root's Initialize has already passed, so the root
/// re-asserts its own merge afterwards and its value must be the one that survives.
Method TestDependencyResourcesAppliedDuringInstall()
{
    set depResDir = ..GetModuleDir("db-packaging", "dep-with-resources")
    set packagingNS = ..GetOrCreateSharedNS2()
    // Packaging downloads the dependency's requirements.txt wheels into its source directory.
    do ..TrackPath(##class(%Library.File).NormalizeDirectory("wheels", depResDir))

    new $namespace
    set $namespace = packagingNS
    set packageFile = ..PackageDatabase("main-with-resource-deps")

    // A dependency's requirements.txt wheel is staged and added to its manifest as a
    // <PythonWheel>, the only route by which the install gets it.
    set extractDir = ..ExtractPackage(packageFile, "dep-staging-check")
    set depStageDir = ##class(%IPM.Lifecycle.Database).GetDependencyStagingDir(extractDir, "dep-with-resources")
    do $$$AssertTrue(..CountFiles(##class(%Library.File).NormalizeDirectory("wheels", depStageDir), "six*.whl") > 0, "Dependency requirements.txt wheel (six) staged under deps-files/")
    set depManifest = ##class(%Library.File).NormalizeFilename("dep-with-resources.xml", ##class(%IPM.Lifecycle.Database).GetDepsDir(extractDir))
    do $$$AssertTrue(..ReadFile(depManifest) [ "PythonWheel", "Dependency manifest declares the added <PythonWheel>")

    // The source load in the packaging namespace already created the dependency's FileCopy target.
    set depCopyTarget = ..ManagerParentFile("dep-res-data.txt")
    do ..DeletePath(depCopyTarget)

    do ..InstallDatabasePackage("TESTDBDEPRESINS", packageFile)
    do $$$AssertEquals(##class(DepRes.Generated).GetGeneratedValue(), "Dependency generated value", "Dependency Generated resource shipped in the IRIS.DAT")
    do $$$AssertTrue(##class(%Library.File).Exists(depCopyTarget), "Dependency FileCopy applied during install")
    do $$$AssertEquals($get(^DBPkgDepInvoked, 0), 1, "Dependency <Invoke> ran exactly once during install")

    // Root CPF value wins: the dependency merged after the root's Initialize, so the root
    // re-asserted its own merge afterwards.
    do ..AssertGlobals8KB(170000, "Root CPF value survives — re-asserted after the dependency merge")
}

/// Asserts the [config] globals 8KB-buffer setting both CPF fixtures target.
/// Read-back property name matches the one Test.PM.Integration.CPFMerge asserts on.
/// A CPF merge is instance-wide, not namespace-scoped, so this test leaves globals8kb at the
/// root fixture's value for whatever runs next. Test.PM.Integration.CPFMerge asserts its own
/// value after its own merge, so it is unaffected by run order — but any new test that reads
/// globals8kb without merging first must not assume the instance default.
Method AssertGlobals8KB(
	expected As %Integer,
	message As %String)
{
    new $namespace
    set $namespace = "%SYS"
    do $$$AssertStatusOK(##class(Config.config).Get(.props), "Read [config] section")
    do $$$AssertEquals(props("globals8kb"), expected, message)
}

/// Copying the routines database for a package, in a dedicated namespace so the dismount does not
/// disturb the shared ones.
///
/// The copy must hold a class loaded moments earlier. That is what guards the dismount: a copy of a
/// still-mounted IRIS.DAT reads only what is on disk and misses blocks still in the buffer pool.
/// The good copy runs first, before any other dismount could flush the buffers for it.
///
/// A failed copy still remounts, because leaving a namespace's code database dismounted is worse
/// than any packaging error. A staging directory that does not exist is enough to fail the copy:
/// NormalizeFilename returns "" for a destination whose directory is absent.
///
/// Finally, a module whose compiled code is gone from the namespace does not produce a package
/// silently missing that code, because the package phase chain's Compile stops it first.
Method TestCopyRoutinesDatabase()
{
    set simpleDir = ..GetModuleDir("db-packaging", "simple-db-module")
    set copyNS = "TESTDBCOPY"
    do $$$AssertStatusOK(..CreateTestNamespace(copyNS), "Created packaging namespace")
    new $namespace
    set $namespace = copyNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ simpleDir), "Loaded simple-db-module")

    // Called from inside copyNS, as %Package does, so the database being dismounted is the one on
    // this process's namespace stack.
    set stagingDir = ##class(%Library.File).NormalizeDirectory(..PackageOutputDir _ "copy-dismount")
    do $$$AssertTrue(##class(%Library.File).CreateDirectoryChain(stagingDir), "Created staging dir")
    do ##class(%IPM.Lifecycle.Database).CopyRoutinesDatabase(copyNS, stagingDir)
    do $$$AssertTrue(..StagedDATContains(##class(%Library.File).NormalizeFilename("IRIS.DAT", stagingDir), "SimpleModule.Main"), "Staged IRIS.DAT holds code loaded just before the copy")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Routines database remounted after the copy")

    set missingDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).Construct(..PackageOutputDir, "no-such-staging-dir"))
    set caught = ""
    try {
        do ##class(%IPM.Lifecycle.Database).CopyRoutinesDatabase(copyNS, missingDir)
    } catch ex {
        set caught = ex
    }
    do $$$AssertNotEquals(caught, "", "Packaging reports the failed copy rather than succeeding silently")
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SimpleModule.Main"), "Routines database remounted after the failed copy")

    // Delete the code but leave the module registered, which is the state a source tree loaded into
    // one namespace and packaged from another leaves behind.
    do $$$AssertStatusOK($system.OBJ.Delete("SimpleModule.Main.CLS", "-d"), "Deleted the module's class")
    set sc = ##class(%IPM.Main).Shell("package-database simple-db-module -path " _ ..PackageOutputDir)
    do $$$AssertTrue($$$ISERR(sc), "Packaging fails when the root module's declared classes are missing")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "SimpleModule.Main", "Compile phase error names the missing class")
}

/// Reports whether a staged IRIS.DAT holds needle anywhere in its blocks. A class name appears
/// verbatim in the database's global subscripts, so this is enough to tell a complete copy from one
/// missing the blocks that were still buffered.
/// Chunks overlap by the needle's length so a match spanning a chunk boundary is not missed.
Method StagedDATContains(
	datFile As %String,
	needle As %String) As %Boolean
{
    set stream = ##class(%Stream.FileBinary).%New()
    do $$$AssertStatusOK(stream.LinkToFile(datFile), "Opened the staged IRIS.DAT")

    set found = 0
    set tail = ""
    while 'stream.AtEnd {
        set chunk = tail _ stream.Read(32768)
        if $find(chunk, needle) {
            set found = 1
            quit
        }
        set tail = $extract(chunk, *-($length(needle) - 1), *)
    }

    quit found
}

/// A dependency whose code is not in the namespace draws a warning naming it. Without it the package
/// installs and the dependency's code simply does not exist.
/// The cases that must stay quiet share this namespace rather than paying for one of their own.
Method TestWarnsWhenDependencyCodeMissing()
{
    set depDir = ..GetModuleDir("db-packaging", "dep-module")
    set mainDir = ..GetModuleDir("db-packaging", "main-with-deps")
    set missingNS = "TESTDBMISSINGDEP"
    do $$$AssertStatusOK(..CreateTestNamespace(missingNS), "Created packaging namespace")
    new $namespace
    set $namespace = missingNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ depDir), "Loaded dep-module")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ mainDir), "Loaded main-with-deps")

    set missingWarning = "no code from dependency 'dep-module'"
    // A module's own dependency is not extra content, since it belongs in the package.
    do $$$AssertNotTrue(..CaptureModuleWarning("main-with-deps", "WarnOtherModulesInDatabase") [ "also holds code from", "No extra-contents warning for a namespace holding only the module and its dependency")
    do $$$AssertNotTrue(..CaptureModuleWarning("main-with-deps", "WarnMissingDependencyCode") [ missingWarning, "No missing-code warning while the dependency's code is present")

    do $$$AssertStatusOK($system.OBJ.Delete("DepModule.Core.CLS", "-d"), "Deleted the dependency's class")
    do $$$AssertTrue(..CaptureModuleWarning("main-with-deps", "WarnMissingDependencyCode") [ missingWarning, "Warned that the dependency's code is missing")
}

/// A namespace holding an unrelated module warns that the unrelated code ships too.
Method TestWarnsAboutUnrelatedModulesInDatabase()
{
    set simpleDir = ..GetModuleDir("db-packaging", "simple-db-module")
    set depDir = ..GetModuleDir("db-packaging", "dep-module")
    set extraNS = "TESTDBEXTRACONTENTS"
    do $$$AssertStatusOK(..CreateTestNamespace(extraNS), "Created packaging namespace")
    new $namespace
    set $namespace = extraNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ simpleDir), "Loaded simple-db-module")
    // dep-module is not a dependency of simple-db-module, it is just also there.
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ depDir), "Loaded dep-module")

    do $$$AssertTrue(..CaptureModuleWarning("simple-db-module", "WarnOtherModulesInDatabase") [ "also holds code from dep-module", "Warned that unrelated module code ships in the package")
}

/// Test classes already compiled into the database ship whether or not -include-tests was passed, so
/// their presence has to be reported when it was not.
Method TestWarnsAboutTestClassesWithoutIncludeTests()
{
    set testsDir = ..GetModuleDir("db-packaging", "module-with-tests")
    set testDocNS = "TESTDBTESTDOCSPRESENT"
    do $$$AssertStatusOK(..CreateTestNamespace(testDocNS), "Created packaging namespace")
    new $namespace
    set $namespace = testDocNS
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ testsDir), "Loaded module-with-tests")
    // Put the test-scoped class in the database without asking the package for it.
    do $$$AssertStatusOK($system.OBJ.LoadDir(##class(%Library.File).NormalizeDirectory(testsDir _ "src"), "ck", , 1), "Compiled the module's source tree, tests included")

    set output = ..CaptureModuleWarning("module-with-tests", "WarnTestCodeAlreadyInDatabase")
    do $$$AssertTrue(output [ "TestModule.TestHelper.CLS", "Warned that a test-scoped class already in the database will ship")
    do $$$AssertNotTrue(output [ "TestModule.Main.CLS", "Did not report a non-test class")
}

/// A namespace whose routines and globals are the same database is warned about on both sides: the
/// swap replaces its globals along with IPM's own registry and packaging ships them.
/// Asserted against the warning methods rather than a real install or package, which would wreck the
/// registry the assertions depend on.
Method TestWarnsWhenRoutinesDatabaseIsGlobalsDatabase()
{
    // %IPM.Test.Utils.CreateNamespace leaves Routines = Globals = <NS>. CreateTestNamespace is the
    // helper that then gives the namespace a separate globals DB.
    set sameNS = "TESTDBSAMEDB"
    do $$$AssertStatusOK(##class(%IPM.Test.Utils).CreateNamespace(sameNS), "Created namespace with one database")
    set ..CreatedNamespaces = ..CreatedNamespaces _ $listbuild(sameNS)
    set splitNS = "TESTDBSPLITDB"
    do $$$AssertStatusOK(..CreateTestNamespace(splitNS), "Created namespace with a separate globals DB")

    set installWarning = "for routines and globals"
    set packagingWarning = "will ship inside this package"
    set class = "%IPM.Lifecycle.Database"
    do $$$AssertTrue(..CaptureCall(class, "WarnRoutinesDatabaseIsGlobalsDatabase", sameNS) [ installWarning, "Install warned about the shared routines/globals database")
    do $$$AssertTrue(..CaptureCall(class, "WarnPackagingRoutinesDatabaseIsGlobalsDatabase", sameNS) [ packagingWarning, "Packaging warned that the namespace's globals ship in the package")
    do $$$AssertNotTrue(..CaptureCall(class, "WarnRoutinesDatabaseIsGlobalsDatabase", splitNS) [ installWarning, "No install warning when globals live in their own database")
    do $$$AssertNotTrue(..CaptureCall(class, "WarnPackagingRoutinesDatabaseIsGlobalsDatabase", splitNS) [ packagingWarning, "No packaging warning when globals live in their own database")
}

}
