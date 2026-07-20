Class Test.PM.Integration.Sync Extends %UnitTest.TestCase
{

Property TempDir As %String;

// Native-filesystem copy of the fixture, made once. _data/sync-test/ lives on the repo's
// bind mount (slow for the many small-file copies OnAfterOneTest does between every test),
// so each restore copies from here instead of re-reading the mount every time.
Property PristineDir As %String;

Method OnBeforeAllTests() As %Status
{
    set sourceDir = ..GetModuleDir("sync-test")

    set ..PristineDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "sync-test-pristine-" _ $job)
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(..PristineDir))
    if '##class(%Library.File).CopyDir(sourceDir, ..PristineDir, 1) {
        quit $$$ERROR($$$GeneralError, "Failed to copy sync-test fixture to pristine directory")
    }

    set ..TempDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "sync-test-" _ $job)
    quit $$$OK
}

// Load a clean copy of the fixture in dev mode before each test to stamp a baseline.
// Uninstalling first handles version-change tests (e.g. TestModuleXmlChangedWarning bumps version).
Method OnBeforeOneTest(testName As %String) As %Status
{
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(..TempDir))
    if '##class(%Library.File).CopyDir(..PristineDir, ..TempDir, 1) {
        quit $$$ERROR($$$GeneralError, "Failed to restore sync-test fixture before test: " _ testName)
    }
    quit ##class(%IPM.Main).Shell("load " _ ..TempDir _ " -dev")
}

Method OnAfterOneTest(testName As %String) As %Status
{
    // Shell never throws; ignore the returned status since uninstall may fail if the test
    // left the module in a broken state — that's expected.
    do ##class(%IPM.Main).Shell("uninstall sync-test")
    do ##class(%Library.File).RemoveDirectoryTree(..TempDir)
    quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    do ##class(%IPM.Main).Shell("uninstall sync-test")
    if ..TempDir '= "" {
        do ##class(%Library.File).RemoveDirectoryTree(..TempDir)
    }
    if ..PristineDir '= "" {
        do ##class(%Library.File).RemoveDirectoryTree(..PristineDir)
    }
    quit $$$OK
}

/// GetStoredPaths returns paths that were stamped by StampModule.
Method TestGetStoredPathsReturnsStampedPaths()
{
    do $$$AssertTrue(##class(%IPM.Storage.FileHash).HasBaseline("sync-test"), "Baseline exists after load")

    kill paths
    do ##class(%IPM.Storage.FileHash).GetStoredPaths("sync-test", .paths)

    do $$$AssertTrue($data(paths("module.xml")), "module.xml in stored paths")
    do $$$AssertTrue($data(paths("src/cls/SyncTest/SuperClass.cls")), "SuperClass.cls in stored paths")
    do $$$AssertTrue($data(paths("src/inc/SyncTest.inc")), "SyncTest.inc in stored paths")
}

/// Confirm sync detects changes in a module whose file layout doesn't match the
/// SourcesRoot/Directory/package.ext convention. sync-flat-test declares SyncFlat.Flat.CLS
/// with SourcesRoot=src, but the file is at src/SyncFlat/Flat.cls (no cls/ subdirectory).
/// OnItemRelativePath derives src/cls/SyncFlat/Flat.cls, which doesn't exist — so without
/// filesystem-anchored stamping, the file never gets a baseline row and sync always reports
/// "Nothing to sync" regardless of what changed.
// This test manages its own install/uninstall because sync-flat-test uses a separate fixture
// from sync-test and must not interfere with the per-test lifecycle.
Method TestNonStandardLayoutDetectsChange()
{
    set flatTempDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "sync-flat-test-" _ $job)
    try {
        set flatSource = ..GetModuleDir("sync-flat-test")
        $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(flatTempDir))
        if '##class(%Library.File).CopyDir(flatSource, flatTempDir, 1) {
            $$$ThrowOnError($$$ERROR($$$GeneralError, "Failed to copy sync-flat-test to temp dir"))
        }

        $$$ThrowOnError(##class(%IPM.Main).Shell("load " _ flatTempDir _ " -dev"))

        set filePath = flatTempDir _ "src/SyncFlat/Flat.cls"
        do ..ReplaceInFile(filePath, "As %String", "As %Integer")

        kill params
        set params("Verbose") = 1
        do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
        set sc = ##class(%IPM.Storage.Module).Sync("sync-flat-test", .params)
        do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

        do $$$AssertStatusOK(sc, "Sync succeeds for non-standard layout module")
        do $$$AssertTrue(..FindInOutput(.output, "Sync complete"), "Sync detects the file change (not 'Nothing to sync')")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(), "TestNonStandardLayoutDetectsChange threw unexpectedly")
    }
    do ##class(%IPM.Main).Shell("uninstall sync-flat-test")
    do ##class(%Library.File).RemoveDirectoryTree(flatTempDir)
}

/// Sync with no files changed on disk since the last load/sync reports nothing to do.
Method TestNoChangeIsNoOp()
{
    do $$$AssertTrue(##class(%IPM.Storage.FileHash).HasBaseline("sync-test"), "Baseline rows exist after load")

    kill params
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync with no changes succeeds")
    do $$$AssertTrue(..FindInOutput(.output, "Nothing to sync"), "Reports nothing to sync")
}

/// Simulates a module installed before this feature existed (zero FileHash baseline rows).
/// The first sync call must self-heal by stamping a baseline rather than failing or reporting
/// every tracked file as changed; only a second sync call (after a real edit) detects changes.
Method TestMigrationFromNoBaseline()
{
    set deleteRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %IPM_Storage.FileHash WHERE ModuleName = ?", "sync-test")
    do $$$AssertTrue(deleteRS.%SQLCODE >= 0, "Deleted existing baseline rows to simulate a pre-sync-feature module")
    do $$$AssertNotTrue(##class(%IPM.Storage.FileHash).HasBaseline("sync-test"), "No baseline rows remain")

    set filePath = ..TempDir _ "src/cls/SyncTest/SuperClass.cls"
    do ..ReplaceInFile(filePath, """original""", """modified""")

    kill params
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "First sync after baseline loss succeeds")
    do $$$AssertTrue(..FindInOutput(.output, "Baseline established"), "First sync self-heals by establishing a baseline")
    do $$$AssertTrue(##class(%IPM.Storage.FileHash).HasBaseline("sync-test"), "Baseline rows now exist")

    // The edit made before the self-heal is captured in the new baseline (not retroactively
    // detected), so a second sync with no further changes reports nothing to do.
    kill params2, output2
    set params2("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie2)
    set sc2 = ##class(%IPM.Storage.Module).Sync("sync-test", .params2)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie2, .output2)
    do $$$AssertStatusOK(sc2, "Second sync succeeds")
    do $$$AssertTrue(..FindInOutput(.output2, "Nothing to sync"), "Second sync finds no changes (baseline already reflects the modified file)")

    // A genuinely new edit after the baseline is established is detected normally.
    do ..ReplaceInFile(filePath, """modified""", """modified again""")
    kill params3, output3
    set params3("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie3)
    set sc3 = ##class(%IPM.Storage.Module).Sync("sync-test", .params3)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie3, .output3)
    do $$$AssertStatusOK(sc3, "Third sync succeeds")
    do $$$AssertTrue(..FindInOutput(.output3, "Sync complete"), "Third sync detects the post-baseline edit normally")
}

/// A modified class file is detected and recompiled by sync.
Method TestModifiedClassRecompiles()
{
    set filePath = ..TempDir _ "src/cls/SyncTest/SuperClass.cls"
    do ..ReplaceInFile(filePath, """original""", """modified""")

    kill params
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync after class modification succeeds")
    do $$$AssertTrue(..FindInOutput(.output, "Sync complete"), "Reports sync complete")
}

/// Editing a superclass recompiles its subclasses via the u-flag, even though the
/// subclass's own file on disk never changed.
Method TestSuperclassEditRecompilesSubclass()
{
    // Add property to SuperClass — SubClass recompiles via u-flag
    set filePath = ..TempDir _ "src/cls/SyncTest/SuperClass.cls"
    do ..ReplaceInFile(filePath, "Property BaseValue", "Property NewProp As %String;" _ $char(10) _ $char(10) _ "Property BaseValue")

    kill params
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do $$$AssertStatusOK(sc, "Sync after superclass edit succeeds (subclass recompiles via u-flag)")
}

/// Editing an include file recompiles classes that include it, even though those class files
/// on disk are unchanged. SyncTest.Consumer includes SyncTest.INC and calls $$$SyncTestValue.
Method TestIncludeEditRecompilesConsumer()
{
    set incPath = ..TempDir _ "src/inc/SyncTest.inc"
    do ..ReplaceInFile(incPath, """original-include""", """modified-include""")

    kill params
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do $$$AssertStatusOK(sc, "Sync after include edit succeeds")
    do $$$AssertEquals(##class(SyncTest.Consumer).GetMacroValue(), "modified-include", "Consumer reflects updated macro value after include sync")
}

/// A file outside every tracked resource (e.g. under node_modules/) is ignored by sync
/// and never given a baseline row.
Method TestUntrackedFileIgnored()
{
    set junkDir = ..TempDir _ "node_modules/"
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(junkDir))
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(junkDir _ "x.js"))
    $$$ThrowOnError(stream.Write("junk"))
    $$$ThrowOnError(stream.%Save())
    set stream = ""

    kill params
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync ignores untracked files")
    do $$$AssertNotTrue(..FindInOutput(.output, "x.js"), "Untracked file not mentioned in sync output")
    do $$$AssertNotTrue(##class(%IPM.Storage.FileHash).ModulePathIndexExists("sync-test", "node_modules/x.js"), "No FileHash row for untracked file")
}

/// A deleted file is left alone unless -delete is passed. With -delete, the corresponding
/// server-side class is removed.
Method TestDeleteSkippedByDefault()
{
    set filePath = ..TempDir _ "src/cls/SyncTest/Deletable.cls"
    do ##class(%Library.File).Delete(filePath)

    // Without -delete: class still present
    kill params
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do $$$AssertStatusOK(sc, "Sync without -delete succeeds")
    do $$$AssertTrue($$$comClassDefined("SyncTest.Deletable"), "Deletable class still exists without -delete flag")

    // With -delete: class is removed from server
    kill params
    set params("ProcessDeletes") = 1
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do $$$AssertStatusOK(sc, "Sync with -delete succeeds")
    do $$$AssertNotTrue($$$comClassDefined("SyncTest.Deletable"), "Deletable class removed after -delete sync")
}

/// Deleting a superclass (with -delete) leaves its subclass referencing a now-missing class.
/// The post-delete recompile pass (SyncApplyDeletes + SyncCompile) must still run and surface
/// this as a compile error, rather than silently leaving the subclass in a stale-but-compiled state.
Method TestDeleteRecompilesDependents()
{
    set filePath = ..TempDir _ "src/cls/SyncTest/SuperClass.cls"
    do ##class(%Library.File).Delete(filePath)

    do $$$AssertTrue($$$comClassDefined("SyncTest.SubClass"), "SubClass still compiled before delete sync")

    kill params
    set params("ProcessDeletes") = 1
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)

    do $$$AssertStatusNotOK(sc, "Sync with -delete fails: SubClass now references a deleted superclass")
    do $$$AssertNotTrue($$$comClassDefined("SyncTest.SuperClass"), "SuperClass was removed from the server")
}

/// A changed module.xml is detected and its manifest reloaded, with a warning that a full
/// reload may still be needed to apply manifest-level changes (mappings, dependencies, etc.).
Method TestModuleXmlChangedWarning()
{
    set filePath = ..TempDir _ "module.xml"
    do ..ReplaceInFile(filePath, "<Version>1.0.0</Version>", "<Version>1.0.1</Version>")

    kill params
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync after module.xml change succeeds")
    do $$$AssertTrue(..FindInOutput(.output, "module.xml changed"), "Warning about module.xml change is shown")
}


/// Without -test, a changed test-phase class is loaded but not executed. With -test, it is
/// executed and its results are shown.
Method TestSyncTestFlag()
{
    set filePath = ..TempDir _ "tests/unit/SyncTest/Tests/Trivial.cls"
    do ..ReplaceInFile(filePath, "This test always passes.", "This test always passes (modified).")

    // Without RunTests: loads the changed test but does not execute it
    kill params
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    do $$$AssertStatusOK(sc, "Sync without RunTests loads but does not run tests")
    do $$$AssertNotTrue(..FindInOutput(.output, "Test Results"), "No test results without RunTests flag")

    // Modify again so the file shows as changed on the next sync
    do ..ReplaceInFile(filePath, "(modified).", "(modified again).")

    // With RunTests: executes the changed test-phase test class
    kill params, output
    set params("RunTests") = 1
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    do $$$AssertStatusOK(sc, "Sync with RunTests runs changed tests")
    do $$$AssertTrue(..FindInOutput(.output, "Test Results"), "Test results shown with RunTests flag")
    do $$$AssertTrue(..FindInOutput(.output, "SyncTest.Tests.Trivial begins"), "Changed test class actually ran, not just compiled")
}

/// Editing an existing test class and adding a brand-new test class in the same resource,
/// in the same sync call, batches both changed classes into a single RunTest invocation
/// (one "Test Results:" block) rather than one call per class — and both tests still run.
Method TestSyncTestFlagBatchesMultipleChangedClasses()
{
    set existingFilePath = ..TempDir _ "tests/unit/SyncTest/Tests/Trivial.cls"
    do ..ReplaceInFile(existingFilePath, "This test always passes.", "This test always passes (modified).")

    set newFilePath = ..TempDir _ "tests/unit/SyncTest/Tests/BatchedNew.cls"
    set newClassContent = "Class SyncTest.Tests.BatchedNew Extends %UnitTest.TestCase" _ $char(10) _ "{" _ $char(10)
    set newClassContent = newClassContent _ "Method TestBatchedNewPasses()" _ $char(10) _ "{" _ $char(10)
    set newClassContent = newClassContent _ "    do $$$AssertTrue(1, ""BatchedNew always passes."")" _ $char(10) _ "}" _ $char(10) _ "}" _ $char(10)
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(newFilePath))
    $$$ThrowOnError(stream.Write(newClassContent))
    $$$ThrowOnError(stream.%Save())
    set stream = ""

    kill params
    set params("RunTests") = 1
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync with two changed classes in one resource succeeds")
    // "ClassName begins ..." / "ClassName passed" only appear when the test runner actually
    // executes that class — unlike a bare class-name substring, which also matches the
    // "Loading file .../Trivial.cls" and "Compiling class SyncTest.Tests.Trivial" lines
    // that show up regardless of whether the test itself ran.
    do $$$AssertTrue(..FindInOutput(.output, "SyncTest.Tests.Trivial begins"), "Modified existing class actually ran, not just compiled")
    do $$$AssertTrue(..FindInOutput(.output, "SyncTest.Tests.BatchedNew begins"), "New class in the same resource actually ran, not just compiled")

    set testResultsCount = 0
    set lineKey = ""
    for {
        set lineKey = $order(output(lineKey), 1, line)
        quit:lineKey=""
        if line [ "Test Results:" {
            set testResultsCount = testResultsCount + 1
        }
    }
    do $$$AssertEquals(testResultsCount, 1, "Both changed classes ran in a single batched Test Results block, not one per class")
}


/// With two UnitTest resources present, a changed test class in one resource's directory
/// must only be dispatched through that owning resource — not through every Test processor
/// in the module (which would waste a reload+compile+RunTest cycle per extra resource).
Method TestSyncTestFlagOnlyRunsOwningResource()
{
    set filePath = ..TempDir _ "tests/unit/SyncTest/Tests/Trivial.cls"
    do ..ReplaceInFile(filePath, "This test always passes.", "This test always passes (modified).")

    kill params
    set params("RunTests") = 1
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync with RunTests succeeds")
    do $$$AssertTrue(..FindInOutput(.output, "SyncTest.Tests.Trivial begins"), "Changed test in tests/unit actually ran, not just compiled")
    do $$$AssertNotTrue(..FindInOutput(.output, "SyncTest2.Tests.Trivial2"), "Unrelated test in tests/unit2 was not run")
}

/// Running sync with no module name syncs every module currently in development mode.
Method TestSyncAllDevModeModules()
{
    kill params
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Main).Shell("sync")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync with no module name (sync-all) succeeds")
    do $$$AssertTrue(..FindInOutput(.output, "Nothing to sync"), "sync-test reports nothing to sync (no changes since baseline)")
}

/// Sync fails with an error when given a module name that isn't installed.
Method TestSyncModuleNotFound()
{
    kill params
    set sc = ##class(%IPM.Storage.Module).Sync("this-module-does-not-exist", .params)
    do $$$AssertStatusNotOK(sc, "Sync fails for a module that doesn't exist")
}

/// Sync fails with an error when the target module is not in development mode.
Method TestSyncNonDevModeModule()
{
    // Reload without -dev so the installed module is not in development mode.
    // OnAfterOneTest uninstalls, and OnBeforeOneTest will reinstall -dev for the next test.
    do ##class(%IPM.Main).Shell("uninstall sync-test")
    $$$ThrowOnError(##class(%IPM.Main).Shell("load " _ ..TempDir))

    kill params
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do $$$AssertStatusNotOK(sc, "Sync fails for a module not in development mode")
}

/// module.xml adds a brand-new <Resource> in the same edit that changes the version.
/// After SyncCheckModuleXml reloads the manifest, the newly-declared resource's files
/// must be tracked and picked up in that same sync call (not require a separate 'reload').
Method TestModuleXmlAddsResourcePicksUpNewFile()
{
    set clsFilePath = ..TempDir _ "src/cls/SyncTest/AddedByManifest.cls"
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(clsFilePath))
    $$$ThrowOnError(stream.Write("Class SyncTest.AddedByManifest" _ $char(10) _ "{" _ $char(10) _ "}" _ $char(10)))
    $$$ThrowOnError(stream.%Save())
    set stream = ""

    set moduleXmlPath = ..TempDir _ "module.xml"
    do ..ReplaceInFile(moduleXmlPath, "<Version>1.0.0</Version>", "<Version>1.0.1</Version>")
    do ..ReplaceInFile(moduleXmlPath, "<Resource Name=""SyncTest.Consumer.CLS"" />", "<Resource Name=""SyncTest.Consumer.CLS"" />" _ $char(10) _ "      <Resource Name=""SyncTest.AddedByManifest.CLS"" />")

    kill params
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync after module.xml adds a resource succeeds")
    do $$$AssertTrue(..FindInOutput(.output, "module.xml changed"), "Warning about module.xml change is shown")
    do $$$AssertTrue($$$comClassDefined("SyncTest.AddedByManifest"), "Newly-declared resource's class was loaded and compiled in the same sync call")
}

/// A sync that fails to compile leaves its baseline uncommitted, so the same file is
/// re-detected as changed and retried on the next sync once the error is fixed.
Method TestFailedCompileRetries()
{
    // Introduce a syntax error
    set filePath = ..TempDir _ "src/cls/SyncTest/SuperClass.cls"
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(filePath))
    $$$ThrowOnError(stream.Write("Class SyncTest.SuperClass { INVALID SYNTAX HERE }"))
    $$$ThrowOnError(stream.%Save())
    set stream = ""

    kill params
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do $$$AssertStatusNotOK(sc, "Sync fails with syntax error")

    // Fix and retry — CommitChanges was skipped on failure, so file is still detected as changed
    set fixContent = "Class SyncTest.SuperClass" _ $char(10) _ "{" _ $char(10) _ $char(10)
        _ "ClassMethod GetValue() As %String" _ $char(10) _ "{" _ $char(10)
        _ "    quit ""fixed""" _ $char(10) _ "}" _ $char(10) _ $char(10) _ "}" _ $char(10)
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(filePath))
    $$$ThrowOnError(stream.Write(fixContent))
    $$$ThrowOnError(stream.%Save())
    set stream = ""

    kill params
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do $$$AssertStatusOK(sc, "Sync succeeds after fixing syntax error (retry works)")
}

/// Returns the path to a fixture directory under _data/.
/// Matches the convention from Test.PM.Integration.Base.GetModuleDir.
ClassMethod GetModuleDir(subfolders... As %String) As %String
{
    set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set testRoot = ##class(%File).GetDirectory(testRoot)
    set moduleDir = ##class(%File).Construct(testRoot, "_data", subfolders...)
    quit ##class(%File).NormalizeDirectory(moduleDir)
}

/// Read a file, replace oldStr with newStr, write back.
ClassMethod ReplaceInFile(filePath As %String, oldStr As %String, newStr As %String)
{
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(filePath))
    set content = ""
    while 'stream.AtEnd {
        set content = content _ stream.ReadLine() _ $char(10)
    }
    set stream = ""
    set content = $replace(content, oldStr, newStr)
    set writeStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(writeStream.LinkToFile(filePath))
    $$$ThrowOnError(writeStream.Write(content))
    $$$ThrowOnError(writeStream.%Save())
}

ClassMethod FindInOutput(ByRef output, searchString As %String) As %Boolean
{
    set sub = ""
    for {
        set sub = $order(output(sub), 1, line)
        quit:sub=""
        if line [ searchString {
            return 1
        }
    }
    return 0
}

}
