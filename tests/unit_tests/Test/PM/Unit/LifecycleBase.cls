Class Test.PM.Unit.LifecycleBase Extends %UnitTest.TestCase
{

Method TestVersionedPythonName()
{
    // Each entry: $lb(dylib path, expected versioned name or "")
    // Focus: Linux .so paths. macOS .dylib and Windows .dll are not handled
    // (versioned detection falls through to unversioned PATH search on those platforms).
    set cases = $listbuild(
        $listbuild("/usr/lib64/libpython3.12.so.1.0", "python3.12"),
        $listbuild("/usr/lib64/libpython3.12.so",     "python3.12"),
        $listbuild("/usr/lib/libpython3.11.so.1.0",   "python3.11"),
        $listbuild("/usr/lib/libpython3.so",          ""),
        $listbuild("/usr/lib/libpython.so",           ""),
        $listbuild("/usr/local/Frameworks/Python.framework/libpython3.12.dylib", ""),
        $listbuild("",                                "")
    )

    set ptr = 0
    while $listnext(cases, ptr, case) {
        set $listbuild(dylib, expected) = case
        set actual = ##class(%IPM.Lifecycle.Base).VersionedPythonName(dylib)
        if '$$$AssertEquals(actual, expected) {
            do $$$LogMessage("Failed for dylib='" _ dylib _ "': expected='" _ expected _ "' got='" _ actual _ "'")
        }
    }
}

}
