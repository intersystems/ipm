Class Test.PM.Unit.ModuleTemplate Extends %UnitTest.TestCase
{

Method TestGroupClassesUsesDeepestSharedPackage()
{
    set items("/m/src/cls/MyApp/Local/Foo/A.cls") = "MyApp.Local.Foo.A.cls"
    set items("/m/src/cls/MyApp/Local/Foo/A.cls", "Directory") = "cls"
    set items("/m/src/cls/MyApp/Local/Foo/B.cls") = "MyApp.Local.Foo.B.cls"
    set items("/m/src/cls/MyApp/Local/Foo/B.cls", "Directory") = "cls"
    set items("/m/src/cls/MyApp/Local/Bar/C.cls") = "MyApp.Local.Bar.C.cls"
    set items("/m/src/cls/MyApp/Local/Bar/C.cls", "Directory") = "cls"
    set items("/m/src/cls/Other/Util/D.cls") = "Other.Util.D.cls"
    set items("/m/src/cls/Other/Util/D.cls", "Directory") = "cls"
    set items("/m/src/E.cls") = "E.cls"
    set items("/m/src/mac/Routine.mac") = "Routine.mac"
    set items("/m/src/mac/Routine.mac", "Directory") = "mac"
    do ##class(%IPM.Storage.ModuleTemplate).GroupClasses(.items, .packages)
    do $$$AssertEquals($get(packages("/cls", "MyApp")), "MyApp.Local")
    do $$$AssertEquals($get(packages("/cls", "Other")), "Other.Util")
    do $$$AssertEquals($order(packages("/cls", "Other")), "")
    do $$$AssertEquals($order(packages("/cls")), "")
    // Classes without a package and other items stay as individual resources
    do $$$AssertEquals($order(items("")), "/m/src/E.cls")
    do $$$AssertEquals($order(items("/m/src/E.cls")), "/m/src/mac/Routine.mac")
    do $$$AssertEquals($order(items("/m/src/mac/Routine.mac")), "")
}

}
