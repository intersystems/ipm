Class Test.PM.Unit.FileHash Extends %UnitTest.TestCase
{

Property ModuleName As %String [ InitialExpression = "unit-filehash-test" ];

// The rows written by the storage tests below need a %IPM.Storage.Module to satisfy
// ModuleNameFK. Create a bare one rather than installing a fixture module: none of these
// tests exercise the lifecycle, only FileHash's own index and property behavior.
Method OnBeforeAllTests() As %Status
{
    do ..CleanUp()
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = ..ModuleName
    set module.VersionString = "1.0.0"
    quit module.%Save()
}

Method OnAfterAllTests() As %Status
{
    do ..CleanUp()
    quit $$$OK
}

Method CleanUp()
{
    do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %IPM_Storage.FileHash WHERE ModuleName = ?", ..ModuleName)
    set module = ##class(%IPM.Storage.Module).NameOpen(..ModuleName)
    if $isobject(module) {
        do ##class(%IPM.Storage.Module).%DeleteId(module.%Id())
    }
}

/// PathHash is derived from RelativePath automatically and is case-sensitive, since paths
/// differing only in case are distinct files on Linux.
Method TestHashPath()
{
    set hash = ##class(%IPM.Storage.FileHash).HashPath("src/cls/Foo/Bar.cls")
    do $$$AssertEquals($length(hash), 40, "HashPath returns 40 hex characters")
    do $$$AssertEquals(hash, ##class(%IPM.Storage.FileHash).HashPath("src/cls/Foo/Bar.cls"), "HashPath is deterministic")
    do $$$AssertNotEquals(hash, ##class(%IPM.Storage.FileHash).HashPath("src/cls/foo/Bar.cls"), "HashPath is case-sensitive")

    set row = ##class(%IPM.Storage.FileHash).%New()
    set row.RelativePath = "src/cls/Foo/Bar.cls"
    do $$$AssertEquals(row.PathHash, hash, "Setting RelativePath populates PathHash")
}

/// A relative path far longer than a global subscript can hold must still round-trip. The index
/// is subscripted on the fixed-width PathHash, so path length no longer constrains storage.
Method TestLongPathRoundTrips()
{
    set longPath = "src/cls"
    for i = 1:1:60 {
        set longPath = longPath _ "/PackageSegment" _ i
    }
    set longPath = longPath _ "/Leaf.cls"
    do $$$AssertTrue($length(longPath) > 512, "Test path exceeds the old MAXLEN of 512 (actual: " _ $length(longPath) _ ")")

    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).StampOneFileWithHash(..ModuleName, longPath, "aaa"), "Stamping a >512-char path succeeds")
    do $$$AssertTrue(##class(%IPM.Storage.FileHash).ExistsByPath(..ModuleName, longPath), "Row exists for the long path")

    set row = ##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, longPath)
    do $$$AssertTrue($isobject(row), "Long path row opens by path")
    do $$$AssertEquals(row.RelativePath, longPath, "RelativePath round-trips in full, untruncated")

    // Re-stamping the same path updates the existing row rather than inserting a duplicate.
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).StampOneFileWithHash(..ModuleName, longPath, "bbb"), "Re-stamping the long path succeeds")
    set row = ##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, longPath)
    do $$$AssertEquals(row.Hash, "bbb", "Re-stamp updated the existing row")
}

/// Two paths differing only in case are distinct files on a case-sensitive filesystem, so both
/// must get their own row. The default SQLUPPER collation would have collided them.
Method TestCaseDistinctPathsCoexist()
{
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).StampOneFileWithHash(..ModuleName, "src/cls/Case/Upper.cls", "h1"), "Stamped mixed-case path")
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).StampOneFileWithHash(..ModuleName, "src/cls/case/upper.cls", "h2"), "Stamped lower-case path (no unique-key collision)")

    set upper = ##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, "src/cls/Case/Upper.cls")
    set lower = ##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, "src/cls/case/upper.cls")
    do $$$AssertEquals(upper.Hash, "h1", "Mixed-case path kept its own hash")
    do $$$AssertEquals(lower.Hash, "h2", "Lower-case path kept its own hash")
    do $$$AssertNotEquals(upper.%Id(), lower.%Id(), "Case-distinct paths are separate rows")
}

/// A sync that errors leaves the namespace out of step with the baseline, so the paths it tried to
/// load are marked failed and forced into the next sync's change set. Without this, reverting a
/// broken file to its previously-baselined content makes its hash match again and the next sync
/// reports "Nothing to sync." while the namespace still holds the broken code (issue #1224).
Method TestFailedSyncRetriesRevertedFile()
{
    set relPath = "src/cls/SyncRetry/Reverted.cls"
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).StampOneFileWithHash(..ModuleName, relPath, "h1"), "Baselined the file at its original hash")

    set module = ##class(%IPM.Storage.Module).NameOpen(..ModuleName)
    // The file is back to its baselined content, as if the breaking edit had been reverted.
    kill allFiles, allHashes, reverseIndex
    set allFiles(relPath) = "/tmp/" _ relPath
    set allHashes(relPath) = "h1"

    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).ComputeChanges(module, .modified, .deleted, .reverseIndex, .allFiles, .allHashes, .retried), "ComputeChanges succeeded for a file matching its baseline")
    do $$$AssertNotTrue($data(modified(relPath)), "Content matching the baseline is not reported as modified")
    do $$$AssertNotTrue($data(retried(relPath)), "Nothing is retried when no sync has failed")

    // Simulate the failed sync: the path was in the change set when the pipeline errored.
    kill failedMod, failedDel
    set failedMod(relPath) = "h2"
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).MarkFailed(module, .failedMod, .failedDel, 0), "Marking the failed path succeeded")
    do $$$AssertTrue(##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, relPath).SyncFailed, "The failed path is flagged")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, relPath).Hash, "h1", "Marking a failure leaves the baseline hash alone")

    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).ComputeChanges(module, .modified, .deleted, .reverseIndex, .allFiles, .allHashes, .retried), "ComputeChanges succeeded after the failure was marked")
    do $$$AssertEquals($get(modified(relPath)), "h1", "A previously-failed path is modified even though its hash is unchanged")
    do $$$AssertTrue($data(retried(relPath)), "The forced path is reported as a retry")
    do $$$AssertNotTrue($data(deleted(relPath)), "A retried path that still exists on disk is not reported as deleted")

    // A successful sync commits the hash and ends the retry state.
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).CommitChanges(module, .modified, .deleted, 0), "Committing the retried change succeeded")
    do $$$AssertNotTrue(##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, relPath).SyncFailed, "A committed path is no longer flagged")

    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).ComputeChanges(module, .modified, .deleted, .reverseIndex, .allFiles, .allHashes, .retried), "ComputeChanges succeeded after the retry was committed")
    do $$$AssertNotTrue($data(modified(relPath)), "The path is no longer reported once its retry has been committed")
}

/// MarkFailed is called from the pipeline's error handler, where a path in the change set may have
/// no baseline row yet (a brand-new file that failed to load). Those need no marker — a missing row
/// already reads as modified — and must not cause the error handler itself to fail.
Method TestMarkFailedIgnoresUnbaselinedPath()
{
    set module = ##class(%IPM.Storage.Module).NameOpen(..ModuleName)
    kill failedMod, failedDel
    set failedMod("src/cls/SyncRetry/NeverStamped.cls") = "h9"
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).MarkFailed(module, .failedMod, .failedDel, 0), "Marking a path with no baseline row succeeds")
    do $$$AssertNotTrue(##class(%IPM.Storage.FileHash).ExistsByPath(..ModuleName, "src/cls/SyncRetry/NeverStamped.cls"), "No baseline row is invented for an unstamped path")
}

/// A sync without -test commits the changed test file's hash, so no later change detection would
/// ever look at that file again and the edit would stay untested. The pending-test flag forces it
/// into the next sync that runs tests, and only that sync clears it.
Method TestPendingTestsRunOnNextTestSync()
{
    set relPath = "tests/unit/PendingTest/Case.cls"
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).StampOneFileWithHash(..ModuleName, relPath, "h1"), "Baselined the test file as a sync without -test would")

    set module = ##class(%IPM.Storage.Module).NameOpen(..ModuleName)
    kill allFiles, allHashes, reverseIndex
    set allFiles(relPath) = "/tmp/" _ relPath
    set allHashes(relPath) = "h1"

    kill pendingPaths
    set pendingPaths(relPath) = ""
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).MarkTestPending(..ModuleName, .pendingPaths), "Flagging the synced-but-untested path succeeded")
    do $$$AssertTrue(##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, relPath).TestPending, "The path is flagged as pending tests")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, relPath).Hash, "h1", "Flagging leaves the baseline hash alone")

    // Another sync without -test must not force it in, or every plain sync would re-report the same
    // file forever without ever being able to clear the flag.
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).ComputeChanges(module, .modified, .deleted, .reverseIndex, .allFiles, .allHashes, .retried, 0, .testPending), "ComputeChanges succeeded without runTests")
    do $$$AssertNotTrue($data(modified(relPath)), "A pending path is not forced into a sync that runs no tests")
    do $$$AssertNotTrue($data(testPending(relPath)), "Nothing is reported as pending when tests are not running")

    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).ComputeChanges(module, .modified, .deleted, .reverseIndex, .allFiles, .allHashes, .retried, 1, .testPending), "ComputeChanges succeeded with runTests")
    do $$$AssertEquals($get(modified(relPath)), "h1", "A pending path is modified even though its content is unchanged")
    do $$$AssertTrue($data(testPending(relPath)), "The forced path is reported as a deferred test run")

    // A commit from a sync that still ran no tests must leave the file pending.
    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).CommitChanges(module, .modified, .deleted, 0, 0), "Committing without clearing succeeded")
    do $$$AssertTrue(##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, relPath).TestPending, "A commit that ran no tests leaves the path pending")

    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).CommitChanges(module, .modified, .deleted, 0, 1), "Committing after running tests succeeded")
    do $$$AssertNotTrue(##class(%IPM.Storage.FileHash).OpenByPath(..ModuleName, relPath).TestPending, "Running the tests clears the pending flag")

    do $$$AssertStatusOK(##class(%IPM.Storage.FileHash).ComputeChanges(module, .modified, .deleted, .reverseIndex, .allFiles, .allHashes, .retried, 1, .testPending), "ComputeChanges succeeded after the deferred run was committed")
    do $$$AssertNotTrue($data(modified(relPath)), "The path is no longer forced once its tests have run")
}

Method TestNormalizePath()
{
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("src\cls\Foo\Bar.cls"), "src/cls/Foo/Bar.cls", "Backslashes -> forward slashes")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("src//cls///Foo.cls"), "src/cls/Foo.cls", "Consecutive slashes collapsed")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("/src/cls/Foo.cls"), "src/cls/Foo.cls", "Leading slash stripped")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("//src/Foo.cls"), "src/Foo.cls", "Multiple leading slashes stripped")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("src/cls/Foo.cls"), "src/cls/Foo.cls", "Already-normalized path unchanged")
}

/// Write <var>content</var> to a new file, creating its directory if needed.
Method WriteFileAt(
	path As %String,
	content As %String) [ Private ]
{
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(##class(%File).GetDirectory(path)))
    set file = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(file.LinkToFile(path))
    do file.Write(content)
    $$$ThrowOnError(file.%Save())
}

/// %IPM.Utils.File:WalkDirectories backs both sync's change detection and the filesystem
/// repository cache scan, so depth capping, the filename filter and the skipped directories all
/// have callers depending on them.
Method TestWalkDirectories()
{
    set root = ##class(%IPM.Utils.File).CreateTempDirectory()
    try {
        // module.xml in the root and in a/ share content, so they must also share a hash.
        do ..WriteFileAt(root_"module.xml", "<Module><Name>same</Name></Module>")
        do ..WriteFileAt(root_"a/module.xml", "<Module><Name>same</Name></Module>")
        do ..WriteFileAt(root_"a/notes.txt", "not a manifest")
        do ..WriteFileAt(root_"a/b/module.xml", "<Module><Name>deep</Name></Module>")
        do ..WriteFileAt(root_".git/module.xml", "<Module><Name>vcs</Name></Module>")

        set dirs(1) = root

        // Unlimited depth, filtered to module.xml
        do $$$AssertStatusOK(##class(%IPM.Utils.File).WalkDirectories(.dirs, root, 0, "module.xml", 1, .files, .hashes), "Walked the tree filtering on module.xml")
        do $$$AssertTrue($data(files("module.xml")), "Found module.xml in the root")
        do $$$AssertTrue($data(files("a/module.xml")), "Found module.xml one level down")
        do $$$AssertTrue($data(files("a/b/module.xml")), "Found module.xml two levels down")
        do $$$AssertTrue('$data(files(".git/module.xml")), ".git was not descended into")
        do $$$AssertTrue('$data(files("a/notes.txt")), "Filename filter excluded notes.txt")

        do $$$AssertEquals($length(hashes("module.xml")), 40, "Hash is 40 hex characters")
        do $$$AssertEquals($zconvert(hashes("module.xml"), "L"), hashes("module.xml"), "Hash is lowercase hex")
        do $$$AssertEquals(hashes("a/module.xml"), hashes("module.xml"), "Identical content hashes identically")
        do $$$AssertNotEquals(hashes("a/b/module.xml"), hashes("module.xml"), "Different content hashes differently")

        // Depth cap: a file exactly at the cap is kept, anything below is never visited.
        kill files, hashes
        do $$$AssertStatusOK(##class(%IPM.Utils.File).WalkDirectories(.dirs, root, 1, "module.xml", 1, .files, .hashes), "Walked the tree with depth capped at 1")
        do $$$AssertTrue($data(files("module.xml")), "Root module.xml still found at depth 1")
        do $$$AssertTrue($data(files("a/module.xml")), "File exactly at the depth cap is kept")
        do $$$AssertTrue('$data(files("a/b/module.xml")), "File below the depth cap is not visited")

        // No filter and no hashing: every file, empty hashes.
        kill files, hashes
        do $$$AssertStatusOK(##class(%IPM.Utils.File).WalkDirectories(.dirs, root, 0, "", 0, .files, .hashes), "Walked the tree unfiltered without hashing")
        do $$$AssertTrue($data(files("a/notes.txt")), "Empty filter keeps non-manifest files")
        do $$$AssertEquals(hashes("a/notes.txt"), "", "Hashing off leaves hashes empty")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(), "No error while walking directories")
    }
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(root)
}

/// A module with <SourcesRoot>.</SourcesRoot> composes every resource path as SourcesRoot_"/"_Directory,
/// so paths reach normalization as "./cls/Foo.cls" while the directory walk and the stored baseline key
/// the same file as "cls/Foo.cls". Both spellings have to collapse to one, or the sync reverse index
/// never matches a changed path and edits under such a resource are silently dropped.
Method TestNormalizePathDotSegments()
{
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("./cls/Foo.cls"), "cls/Foo.cls", "Leading ./ stripped (SourcesRoot='.')")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath(".\cls\Foo.cls"), "cls/Foo.cls", "Leading .\ stripped after slash translation")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath(".//cls/Foo.cls"), "cls/Foo.cls", "Leading ./ with doubled slash")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("././cls/Foo.cls"), "cls/Foo.cls", "Repeated leading ./ (SourcesRoot='./.')")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("src/./cls/Foo.cls"), "src/cls/Foo.cls", "Interior ./ segment dropped")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("/./cls/Foo.cls"), "cls/Foo.cls", "Leading /./ collapsed")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("./cls/"), "cls/", "Trailing slash preserved (GetSyncDirectory prefix scans)")
    // SourcesRoot="." with no Directory reduces to the module root itself, not a file.
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("."), "", "Bare '.' is the module root, not a path")
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("./"), "", "'./' is the module root, not a path")
    // ".." is not a path this pipeline should ever see and is deliberately left alone rather than
    // resolved, so a stray one stays visibly wrong instead of silently escaping the module root.
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("../cls/Foo.cls"), "../cls/Foo.cls", "Parent-dir segments are not resolved")
    // A dot inside a name is not a "." segment.
    do $$$AssertEquals(##class(%IPM.Utils.File).NormalizePath("cls/.hidden/Foo.cls"), "cls/.hidden/Foo.cls", "Dot-prefixed directory name preserved")
}

/// Document names reach the sync pipeline from two sources that disagree on extension case:
/// RelPathToDocName yields "Foo.Bar.CLS" while a resource's ResolveChildren yields "Foo.Bar.cls".
/// CanonicalDocName is what lets one be used to look up the other.
Method TestCanonicalDocName()
{
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).CanonicalDocName("Foo.Bar.cls"), "Foo.Bar.CLS", "Lowercase extension upper-cased")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).CanonicalDocName("Foo.Bar.CLS"), "Foo.Bar.CLS", "Already-canonical name unchanged")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).CanonicalDocName("Foo.Bar.Cls"), "Foo.Bar.CLS", "Mixed-case extension upper-cased")
    // The two producers of document names must land on the same subscript.
    set fromResolveChildren = ##class(%IPM.Storage.FileHash).CanonicalDocName("SyncTest.SuperClass.cls")
    set fromRelPath = ##class(%IPM.Storage.FileHash).CanonicalDocName(##class(%IPM.Storage.FileHash).RelPathToDocName("src/cls/SyncTest/SuperClass.cls"))
    do $$$AssertEquals(fromResolveChildren, fromRelPath, "ResolveChildren-style and path-derived names canonicalize to the same key")
    // Package/name casing is significant and must survive untouched; only the extension is folded.
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).CanonicalDocName("foo.bAr.cls"), "foo.bAr.CLS", "Only the extension is case-folded")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).CanonicalDocName("MyRoutine.mac"), "MyRoutine.MAC", "Routine extension upper-cased")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).CanonicalDocName("NoExtension"), "NoExtension", "Name with no extension unchanged")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).CanonicalDocName(""), "", "Empty name unchanged")
}

Method TestRelPathToDocName()
{
    // Standard layouts
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/cls/Foo/Bar.cls"), "Foo.Bar.CLS", "Standard src/cls/ layout")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/inc/SyncTest.inc"), "SyncTest.INC", "Include file")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/mac/MyRoutine.mac"), "MyRoutine.MAC", "MAC routine")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/int/MyRoutine.int"), "MyRoutine.INT", "INT routine")

    // Non-compilable files return "" so they are never routed as server-side documents
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("static/config.txt"), "", "Non-compilable extension")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("module.xml"), "", "module.xml")

    // Flat layout: 'SyncFlat' is not a prefix dir, becomes the package component
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/SyncFlat/Flat.cls"), "SyncFlat.Flat.CLS", "Flat layout (no cls/ subdir)")

    // Preload resources live under preload/ (a sibling of SourcesRoot), so 'preload' is a
    // prefix directory like src/cls — it must not become part of the document name.
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("preload/cls/SyncBoot/Boot.cls"), "SyncBoot.Boot.CLS", "Preload class")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("preload/inc/SyncBoot.inc"), "SyncBoot.INC", "Preload include")

    // Edge cases
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("Foo.cls"), "Foo.CLS", "Single-segment path")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/cls/A/B/C/Deep.cls"), "A.B.C.Deep.CLS", "Deep package hierarchy")
    // IPM own classes: callers handle %-prefix namespace fallback; this method doesn't add %
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/cls/IPM/Main.cls"), "IPM.Main.CLS", "IPM class — no % prefix added")
}

}
