Class %IPM.ResourceProcessor.Test Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Loads unit tests (extending %UnitTest.TestCase) from the specified directory and runs them during (Phase). For modules in development mode, the unit tests are always loaded and are not deleted after they are run.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Phase,Package,Class,ManagerClass,Format,ExportFlags";

/// Phase in which the unit tests run - "test" (dev namespace), "verify" (separate, clean namespace), or "test,verify" (to run in both cases).
Property Phase As %IPM.DataType.ListOfOptions(VALUELIST = ",test,verify") [ InitialExpression = {$listbuild("test")}, Required ];

// NOTE: Either Package or Class MUST be defined.

/// Package containing unit tests - this will be mapped properly on development systems, and unit tests won't be deleted in the "test" phase if any classes in it exist.
Property Package As %String(MAXLEN = 255);

/// Class containing unit tests - this will be mapped properly on development systems, and unit tests won't be deleted in the "test" phase
Property Class As %String(MAXLEN = 255);

/// Extension to use internally based on whether the resource is a package or a class
Property Extension As %String [ Calculated, Internal ];

Method ExtensionGet() As %String [ CodeMode = expression ]
{
$case(..Package '= "", 1: ".PKG", : ".CLS")
}

/// Class extending %UnitTest.Manager to use to run unit tests
Property ManagerClass As %Dictionary.Classname [ InitialExpression = "%IPM.Test.Manager" ];

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

/// Flags/qualifiers to export items with.
Property ExportFlags As %String(MAXLEN = "");

/// Embedded processor to handle unit test resources as a package.
Property EmbeddedProcessor As %IPM.ResourceProcessor.Default.Document [ Private ];

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
        if (pPhase = "Reload") {
            // Only load unit tests if we're in developer mode.
            if $get(pParams("DeveloperMode")) {
                // LoadTestDirectory rather than recursive $System.OBJ.LoadDir to omit _ directories.
                set tSC = ##class(%IPM.Test.Manager).LoadTestDirectory(tUnitTestDir,tVerbose,.tLoadedList,..Format)
                $$$ThrowOnError(tSC)

                set tSC = ##class(%IPM.Storage.LoadedResource).TrackResourceNames(..ResourceReference.Module.Name,..ResourceReference.UniqueName,tLoadedList)
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method TestsShouldRun(
	pPhase As %String,
	ByRef pParams) As %Boolean
{
    set tPathMatch = 1
    set tTestPath = ""
    if (..Package '= "") {
        if $data(pParams("UnitTest","Suite"),tTestSuite)#2 {
            set tTestPath = $translate(tTestSuite,"/\","..")
        } elseif $data(pParams("UnitTest","Case"),tTestCase)#2 {
            set tTestPath = tTestCase
        }
    }
    if (tTestPath '= "") {
        if (..Package '= "") {
            if $length(tTestPath) > $length(..Package) {
                set tPathMatch = ($extract(tTestPath,1,$length(..Package)) = ..Package)
            } else {
                set tPathMatch = ($extract(..Package,1,$length(tTestPath)) = tTestPath)
            }
        } elseif (..Class '= "") {
            // No action needed, the pParams are ignored for this case so tPatchMatch
            // always equals 1
        }
    }
    quit tPathMatch && ($listfind(..Phase,$zconvert(pPhase,"L")) > 0)
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        // Initialize test result accumulator for this phase if not already initialized (i.e., we're at top level, not nested)
        // This way nested Shell calls append to parent's AllResults instead of wiping it
        if '$data(^||%UnitTest.Manager.AllResultsCount) {
            kill ^||%UnitTest.Manager.AllResults
            set ^||%UnitTest.Manager.AllResultsCount = 0
        }

        // Track where this phase's results start (for nested phases)
        set phaseStartIndex = $get(^||%UnitTest.Manager.AllResultsCount, 0)

        if ..TestsShouldRun(pPhase,.pParams) {
            // In test/verify phase, run unit tests.
            set tVerbose = $get(pParams("Verbose"), 0)
            set tFlags = $select(tVerbose:"/display=all",1:"/display=none")
            set explicitQuiet = ($data(pParams("Verbose")) && (pParams("Verbose") = 0))
            if explicitQuiet {
                set suppressor = ##class(%IPM.Utils.OutputSuppressor).%New()
            }

            // Ensure unit tests and related classes are loaded.
            set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
            if $data(pParams("UnitTest","Case"), earlyCase)#2 {
                // Load the full directory so base classes are available before compiling the target case.
                $$$ThrowOnError(##class(%IPM.Test.Manager).LoadTestDirectory(tUnitTestDir, tVerbose, , ..Format))
            } elseif $data(pParams("UnitTest","Suite"), earlySuite)#2 {
                set suiteDir = ##class(%File).NormalizeDirectory(tUnitTestDir_$replace(earlySuite,".","\"))
                $$$ThrowOnError(##class(%IPM.Test.Manager).LoadTestDirectory(suiteDir, tVerbose, , ..Format))
            } else {
                $$$ThrowOnError(##class(%IPM.Test.Manager).LoadTestDirectory(tUnitTestDir, tVerbose, , ..Format))
            }

            set tCompileFlags = "ck"_$select(tVerbose:"d",1:"-d")
            set tDoDelete = 1
            set tTestSpec = ""
            if (..Package '= "") {
                if $data(pParams("UnitTest","Case"), tTestCase)#2 {
                    $$$ThrowOnError($system.OBJ.Compile(tTestCase, tCompileFlags))
                } else {
                    $$$ThrowOnError($system.OBJ.CompilePackage(..Package, tCompileFlags))
                }

                // See if package contains any classes.
                // If it does, we won't delete the classes after running the test.
                // It's assumed that the version of these classes on disk is the authority.
                set tNextClass = $order(^oddDEF(..Package_"."))
                if ($extract(tNextClass,1,$length(..Package)) = ..Package) {
                    set tDoDelete = 0
                }

                set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir)
                if $data(pParams("UnitTest","Suite"),tTestSuite) {
                    set tTestSubDir = $replace(tTestSuite,".","\")
                    set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
                } elseif $data(pParams("UnitTest","Case"),tTestCase) {
                    set tTestSpec = ":"_tTestCase
                    // Target the directory that contains this specific test case.
                    set tTestSubDir = $replace($piece(tTestCase,".",1,*-1),".","/")
                    // Avoid nested directories
                    set tFlags = tFlags_"/norecursive"
                    set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
                    if $data(pParams("UnitTest","Method"),tTestMethod) {
                        set tTestSpec = tTestSpec_":"_tTestMethod
                    }
                } else {
                    set tTestSubDir = $replace(..Package,".","\")
                    set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
                }
            } elseif (..Class '= "") {
                $$$ThrowOnError($system.OBJ.Compile(..Class, tCompileFlags))
                // See if class exists.
                // If it does, we won't delete the class after running the test.
                // It's assumed that the version on disk is the authority.
                if $$$comClassDefined(..Class) {
                    set tDoDelete = 0
                }

                // Since this is only a class, we do not support "Suite" or "Case".
                // Only support "Method"
                set tTestCase = ..Class
                set tTestSpec = ":"_tTestCase
                // Target the directory that contains this specific test case.
                set tTestSubDir = $replace($piece(tTestCase,".",1,*-1),".","/")
                // Avoid nested directories
                set tFlags = tFlags_"/norecursive"
                set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
                if $data(pParams("UnitTest","Method"),tTestMethod) {
                    set tTestSpec = tTestSpec_":"_tTestMethod
                }
            }
            if 'tDoDelete {
                set tFlags = tFlags_"/nodelete"
            }

            set tFlags = tFlags_$get(pParams("UnitTest","Flags"))

            set tManagerClass = $get(pParams("UnitTest","ManagerClass"),..ManagerClass)
            if (tManagerClass = "") {
                set tManagerClass = "%IPM.Test.Manager"
            }
            merge tUserParams = pParams("UnitTest","UserParam")

            if $data(^UnitTestRoot,tOldUnitTestRoot) // Stash ^UnitTestRoot
            set ^UnitTestRoot = tUnitTestDir
            set tSC = $classmethod(tManagerClass,"RunTest",tTestSpec,tFlags,.tUserParams)

            // If running integration tests in the verify phase, uninstall all modules after each test
            if $get(pParams("verifyNamespace"))'="" {
                set oldNamespace = $namespace
                new $namespace
                set $namespace = pParams("verifyNamespace")
                $$$ThrowOnError(##class(%IPM.Utils.Module).UninstallAll(1,.pParams))
                set $namespace = oldNamespace
            }

            zkill ^UnitTestRoot
            $$$ThrowOnError(tSC)

            set suppressor = ""
            $$$ThrowOnError(..ReportTestResults(phaseStartIndex, tVerbose, .pParams))
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if $data(tOldUnitTestRoot,^UnitTestRoot) // Restore ^UnitTestRoot
    quit tSC
}

/// Shared result-reporting tail for OnPhase and OnSyncRunTests: resolves the test-run's log
/// index, optionally exports full results to a file, then writes the "Test Results:" summary
/// (format-specific output class, or the legacy default) and throws if FailuresAreFatal and
/// any test in this phase failed. Callers must clear their own OutputSuppressor (if any)
/// before calling — the file-export step is unaffected by device redirection, but the summary
/// write below is not.
ClassMethod ReportTestResults(
    phaseStartIndex As %Integer,
    verbose As %Boolean,
    ByRef params) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        set testIndex = $get(^||%UnitTest.Manager.AllResults($get(^||%UnitTest.Manager.AllResultsCount)))
        if testIndex = "" {
            set testIndex = $order(^UnitTest.Result(""),-1)
        }
        if $data(params("outputfile"), outputFile) {
            set fileExtension = $zconvert($piece(outputFile,".",*),"L")
            set outputClass = $case(fileExtension,
                "json":"%IPM.Test.JsonOutput",
                "yaml":"%IPM.Test.YamlOutput",
                "toon":"%IPM.Test.ToonOutput",
                "xml":"%IPM.Test.JUnitOutput",
                :"")
            if outputClass = "" {
                $$$ThrowOnError($$$ERROR($$$GeneralError,"Unsupported output-file extension '."_fileExtension_"'. Use .json, .yaml, .toon, or .xml."))
            }
            set outputDir = ##class(%File).GetDirectory(outputFile)
            if outputDir '= "" {
                $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(outputDir))
            }
            $$$ThrowOnError($classmethod(outputClass,"ToFile",outputFile))
        }

        set outputFormat = $get(params("outputformat"))
        if outputFormat = "" {
            set outputFormat = ##class(%IPM.Repo.UniversalSettings).GetTestReportFormat()
        }

        write !!,"Test Results:"
        if outputFormat '= "" {
            set outputClass = "%IPM.Test."_$zconvert(outputFormat,"w")_"Output"
            if '$$$defClassDefined(outputClass) {
                $$$ThrowOnError($$$ERROR($$$GeneralError,"Unknown output format: "_outputFormat))
            }
            $$$ThrowOnError($classmethod(outputClass,"OutputToDevice",testIndex,verbose,1))
        } else {
            $$$ThrowOnError(##class(%IPM.Test.Abstract).OutputToDevice(testIndex,verbose,0))
        }
        write !
        // Detect and report unit test failures as an error from this phase.
        // OutputFailures shows legacy red FAILED lines only when no format is active.
        if $get(params("UnitTest","FailuresAreFatal"),1) {
            if outputFormat = "" {
                do ##class(%IPM.Test.Manager).OutputFailures(phaseStartIndex)
            }
            $$$ThrowOnError(##class(%IPM.Test.Manager).GetAllTestsStatus(,phaseStartIndex))
        }
        write !
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
    set tSC = $$$OK
    try {
        set tModuleName = ..ResourceReference.Module.Name
        set tResourceInfo = tModuleName
        set tResourceInfo("Generated") = 0
        set tResourceInfo("Preload") = 0
        set tResourceInfo("Scope") = ..Phase
        set tResourceInfo("Deploy") = 0
        set tResourceInfo("Processor") = $this
        set tResourceInfo("UnitTest") = 1
        set tResource = $case(..Package '= "", 1: ..Package, : ..Class)_..Extension
        // GetChildren has Output semantics — it kills its output array before populating it.
        // Use tClassArray as the intermediate to avoid killing any existing entries in pResourceArray.
        kill tClassArray
        $$$ThrowOnError(##class(%IPM.Storage.ResourceReference).GetChildren(tResource,tModuleName,1,.tResourceInfo,.tClassArray))
        $$$ThrowOnError(..EmbeddedProcessor.OnResolveChildren(.tClassArray))
        merge pResourceArray = tClassArray
        // pResourceArray("Scope") is read by GetResolvedReferences for the HasScope check.
        // tResourceInfo("Scope") above stamps each child class node — different consumers.
        set pResourceArray("Scope") = ..Phase
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
    set pUniqueName = $case(..Package '= "", 1: ..Package, : ..Class)_..Extension
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
    set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
    set pInfo.SourceControlAware = 1
    set pInfo.Prefix = $case(..Package '= "", 1: ..Package_".", : ..Class)
    set pInfo.RelativePath = ..ResourceReference.Name
    set pInfo.ResourceType = "cls"
    quit $$$OK
}

Method %OnNew(pResourceReference As %IPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = ##super(pResourceReference)
    if (..Package '= "") {
        set ..EmbeddedProcessor = ##class(%IPM.ResourceProcessor.Default.Package).%New(pResourceReference)
        set ..EmbeddedProcessor.Directory = ..ResourceReference.Name
    } elseif (..Class '= "") {
        set ..EmbeddedProcessor = ##class(%IPM.ResourceProcessor.Default.Class).%New(pResourceReference)
    }
    set ..EmbeddedProcessor.ExportFlags = ..ExportFlags
    if (..Format '= "") {
        set ..EmbeddedProcessor.Format = ..Format
        set ..EmbeddedProcessor.FilenameExtension = $case(..Format,"XML":"xml","UDL":"cls")
    }
    quit tSC
}

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    // Path resources (Name="/tests/...") are handled by directory-copy in ExportSingleModule,
    // not by ExportUDL. Returning here with pItemHandled=0 lets ExportSingleModule fall through
    // to that branch. Delegating to EmbeddedProcessor would attempt ExportUDL("/tests/"), which fails.
    if ($extract(pItemName) = "/") {
        quit $$$OK
    }
    quit ..EmbeddedProcessor.OnExportItem(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
    quit ..EmbeddedProcessor.OnItemRelativePath(pItemName)
}

Method SupportsSync() As %Boolean
{
    quit 1
}

/// Enumerate test files on disk so sync can detect brand-new test classes.
/// ResolveChildren (via GetChildren's StudioOpenDialog query) only sees already-compiled
/// classes, so a test file that was never compiled — e.g. one just added to the test
/// directory — is otherwise invisible to ComputeChanges until something else compiles it
/// first. This live directory scan closes that gap.
Method OnSyncResolveFiles(Output relPaths) As %Status
{
    set sc = $$$OK
    try {
        set unitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root _ ..ResourceReference.Name)
        set moduleRoot = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root)
        if '##class(%File).DirectoryExists(unitTestDir) {
            quit
        }
        kill walkFiles
        $$$ThrowOnError(##class(%IPM.Storage.FileHash).WalkFilesRecursive(unitTestDir, moduleRoot, .walkFiles, "cls"))
        set relPath = ""
        for {
            set relPath = $order(walkFiles(relPath))
            quit:relPath=""
            set relPaths(relPath) = ""
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

Method OnSync(ByRef modifiedPaths, ByRef deletedPaths, ByRef params, Output handled As %Boolean = 0) As %Status
{
    set sc = $$$OK
    set handled = 1
    try {
        set verbose = $get(params("Verbose"))
        set unitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root _ ..ResourceReference.Name)

        // Reload all test files in the directory, then compile so %Extends checks are valid below.
        // New test classes may not yet be in ^oddDEF, so we can't limit to changed files here.
        // Test resources are not AbstractCompilable, so SyncCompile never touches them —
        // OnSync owns the full load+compile cycle for this resource type.
        $$$ThrowOnError(##class(%IPM.Test.Manager).LoadTestDirectory(unitTestDir, verbose, .loadedList, ..Format))
        if ..Package '= "" {
            $$$ThrowOnError($system.OBJ.CompilePackage(..Package, "ck"_$select(verbose:"d",1:"-d")))
        } elseif ..Class '= "" {
            $$$ThrowOnError($system.OBJ.Compile(..Class, "ck"_$select(verbose:"d",1:"-d")))
        }

        // Record changed TestCase subclasses for SyncRunTests.
        // relPath is relative to module root (e.g. "tests/unit/SyncTest/Tests/Trivial.cls").
        // Strip the resource directory prefix (e.g. "tests/unit/") to get the package-relative path.
        set resourceDir = ##class(%IPM.Storage.FileHash).NormalizePath(..ResourceReference.Name)
        set relPath = ""
        for {
            set relPath = $order(modifiedPaths(relPath))
            quit:relPath=""

            // Strip resource directory prefix to get path relative to the test dir
            set packageRelPath = relPath
            if $extract(packageRelPath, 1, $length(resourceDir)) = resourceDir {
                set packageRelPath = $extract(packageRelPath, $length(resourceDir) + 1, *)
            }
            // Convert path to class name: "SyncTest/Tests/Trivial.cls" -> "SyncTest.Tests.Trivial"
            set fileName = $piece(packageRelPath, "/", *)
            set baseName = $piece(fileName, ".", 1, *-1)
            set dirPart = $piece(packageRelPath, "/", 1, *-1)
            set className = $select(dirPart '= "": $translate(dirPart, "/", ".") _ "." _ baseName, 1: baseName)
            if $zconvert($piece(fileName, ".", *), "U") = "CLS"
                && $$$comClassDefined(className)
                && $classmethod(className, "%Extends", "%UnitTest.TestCase") {
                set params("Sync", "ChangedTestCases", className) = ..ResourceReference.Name
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Called once per resource by SyncRunTests: runs every changed test-phase case belonging
/// to this resource in a single RunTest invocation instead of one call per class.
/// classInfo(className) = "" for each changed TestCase class in this resource.
/// Assumes OnSync already loaded and compiled these classes earlier in the same sync() call,
/// so no reload/recompile happens here — only testspec construction, RunTest, and reporting.
Method OnSyncRunTests(ByRef classInfo, ByRef params) As %Status
{
    set sc = $$$OK
    try {
        set verbose = $get(params("Verbose"), 0)
        set unitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root _ ..ResourceReference.Name)

        // Initialize test result accumulator for this phase if not already initialized (i.e., we're at top level, not nested)
        // Mirrors OnPhase's accumulator so multiple resources synced in one -test run share one result set.
        if '$data(^||%UnitTest.Manager.AllResultsCount) {
            kill ^||%UnitTest.Manager.AllResults
            set ^||%UnitTest.Manager.AllResultsCount = 0
        }
        set phaseStartIndex = $get(^||%UnitTest.Manager.AllResultsCount, 0)

        // Build one testspec covering every changed class in this resource. Classes sharing
        // a subdirectory must join with ";" within ONE "dir:Class1;Class2" entry — repeating
        // the same dirPart across separate comma-joined entries is invalid grammar (RunTest
        // treats each comma-separated entry as its own testsuite scope; a second entry naming
        // the same dir errors instead of adding to the first). Distinct subdirectories become
        // separate comma-joined entries so unrelated sibling test classes elsewhere in the
        // resource are not swept in. dirPart is derived from className (its inverse) rather
        // than passed in, since a TestCase class name always mirrors its on-disk path.
        kill byDir
        set className = ""
        for {
            set className = $order(classInfo(className))
            quit:className=""
            set dirPart = $translate($piece(className, ".", 1, *-1), ".", "/")
            set byDir(dirPart, className) = ""
        }
        set testSpec = ""
        set dirPart = ""
        for {
            set dirPart = $order(byDir(dirPart))
            quit:dirPart=""
            set classList = ""
            set className = ""
            for {
                set className = $order(byDir(dirPart, className))
                quit:className=""
                set classList = classList _ $select(classList="":"", 1: ";") _ className
            }
            set testSpec = testSpec _ $select(testSpec="":"", 1: ",") _ dirPart _ ":" _ classList
        }

        set explicitQuiet = ($data(params("Verbose")) && (params("Verbose") = 0))
        if explicitQuiet {
            set suppressor = ##class(%IPM.Utils.OutputSuppressor).%New()
        }

        set flags = $select(verbose:"/display=all",1:"/display=none")_"/nodelete/norecursive"

        if $data(^UnitTestRoot,oldUnitTestRoot) // Stash ^UnitTestRoot
        set ^UnitTestRoot = unitTestDir
        set managerClass = $get(params("UnitTest","ManagerClass"),..ManagerClass)
        if (managerClass = "") {
            set managerClass = "%IPM.Test.Manager"
        }
        merge userParams = params("UnitTest","UserParam")
        set sc = $classmethod(managerClass,"RunTest",testSpec,flags,.userParams)
        zkill ^UnitTestRoot
        $$$ThrowOnError(sc)

        set suppressor = ""
        $$$ThrowOnError(..ReportTestResults(phaseStartIndex, verbose, .params))
    } catch e {
        set sc = e.AsStatus()
    }
    if $data(oldUnitTestRoot,^UnitTestRoot) // Restore ^UnitTestRoot
    quit sc
}

Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
    if ((..Package = "") && (..Class = "")) || ((..Package '= "") && (..Class '= "")) {
        return $$$ERROR($$$GeneralError, "EXACTLY ONE of 'Package' or 'Class' attributes must be specified")
    }
    quit $$$OK
}

}
