Class Test.PM.Unit.FileHash Extends %UnitTest.TestCase
{

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

    // Edge cases
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("Foo.cls"), "Foo.CLS", "Single-segment path")
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/cls/A/B/C/Deep.cls"), "A.B.C.Deep.CLS", "Deep package hierarchy")
    // IPM own classes: callers handle %-prefix namespace fallback; this method doesn't add %
    do $$$AssertEquals(##class(%IPM.Storage.FileHash).RelPathToDocName("src/cls/IPM/Main.cls"), "IPM.Main.CLS", "IPM class — no % prefix added")
}

}
