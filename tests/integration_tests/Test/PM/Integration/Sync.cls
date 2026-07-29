Class Test.PM.Integration.Sync Extends %UnitTest.TestCase
{

Property TempDir As %String;

Method OnBeforeAllTests() As %Status
{
    set sourceDir = ..GetModuleDir("sync-test")

    set ..TempDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "sync-test-" _ $job)
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(..TempDir))
    if '##class(%Library.File).CopyDir(sourceDir, ..TempDir, 1) {
        quit $$$ERROR($$$GeneralError, "Failed to copy sync-test fixture to temp directory")
    }

    // Load in dev mode — this stamps the baseline via %Compile hook.
    quit ##class(%IPM.Main).Shell("load " _ ..TempDir _ " -dev")
}

// Uninstall and restore the fixture after each test to prevent state leakage between tests.
// Uninstalling first handles version-change tests (e.g. TestModuleXmlChangedWarning bumps version).
Method OnAfterOneTest(testName As %String) As %Status
{
    try {
        // Uninstall may fail if the test left the module in a broken state — that's expected.
        do ##class(%IPM.Main).Shell("uninstall sync-test")
    } catch {}
    do ##class(%Library.File).RemoveDirectoryTree(..TempDir)
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(..TempDir))
    if '##class(%Library.File).CopyDir(..GetModuleDir("sync-test"), ..TempDir, 1) {
        quit $$$ERROR($$$GeneralError, "Failed to restore sync-test fixture after test: " _ testName)
    }
    quit ##class(%IPM.Main).Shell("load " _ ..TempDir _ " -dev")
}

Method OnAfterAllTests() As %Status
{
    // OnAfterOneTest already uninstalled and reloaded after the last test.
    // This just removes the temp directory.
    if ..TempDir '= "" {
        do ##class(%Library.File).RemoveDirectoryTree(..TempDir)
    }
    quit $$$OK
}

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

Method TestSuperclassEditRecompilesSubclass()
{
    // Add property to SuperClass — SubClass recompiles via u-flag
    set filePath = ..TempDir _ "src/cls/SyncTest/SuperClass.cls"
    do ..ReplaceInFile(filePath, "Property BaseValue", "Property NewProp As %String;" _ $char(10) _ $char(10) _ "Property BaseValue")

    kill params
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do $$$AssertStatusOK(sc, "Sync after superclass edit succeeds (subclass recompiles via u-flag)")
}

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

Method TestNonSyncProcessorWarning()
{
    set filePath = ..TempDir _ "static/config.txt"
    do ..ReplaceInFile(filePath, "static file content", "modified static content")

    kill params
    set params("Verbose") = 1
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set sc = ##class(%IPM.Storage.Module).Sync("sync-test", .params)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

    do $$$AssertStatusOK(sc, "Sync with non-sync processor file change succeeds")
    do $$$AssertTrue(..FindInOutput(.output, "does not support sync"), "Warning about non-sync resource shown")
}

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
    do $$$AssertTrue(..FindInOutput(.output, "SyncTest.Tests.Trivial"), "Changed test class appears in output")
}

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
