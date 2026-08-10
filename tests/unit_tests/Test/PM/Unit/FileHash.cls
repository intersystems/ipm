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

Method TestNormalizePath()
{
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).NormalizePath("src\cls\Foo\Bar.cls"), "src/cls/Foo/Bar.cls", "Backslashes -> forward slashes")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).NormalizePath("src//cls///Foo.cls"), "src/cls/Foo.cls", "Consecutive slashes collapsed")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).NormalizePath("/src/cls/Foo.cls"), "src/cls/Foo.cls", "Leading slash stripped")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).NormalizePath("//src/Foo.cls"), "src/Foo.cls", "Multiple leading slashes stripped")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).NormalizePath("src/cls/Foo.cls"), "src/cls/Foo.cls", "Already-normalized path unchanged")
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
