Class Test.PM.Unit.ProtectedDirectory Extends %UnitTest.TestCase
{

Method TestSystemDirectoriesAreProtected()
{
    set installDir = $system.Util.InstallDirectory()
    set mgrDir = ##class(%File).ManagerDirectory()
    set cspDir = ##class(%File).NormalizeDirectory("csp", installDir)
    set libDir = ##class(%File).NormalizeDirectory("lib", installDir)
    set dirs = $listbuild(
        installDir,
        $system.Util.DataDirectory(),
        mgrDir,
        $system.Util.BinaryDirectory(),
        libDir,
        cspDir,
        ##class(%File).NormalizeDirectory("sys", cspDir),
        ##class(%File).NormalizeDirectory("broker", cspDir),
        ##class(%File).NormalizeDirectory("enslib", cspDir),
        ##class(%File).NormalizeDirectory(##class(%File).Construct(mgrDir, "python")),
        ##class(%File).NormalizeDirectory(##class(%File).Construct(libDir, "python")),
        ##class(%IPM.Repo.UniversalSettings).GetModuleRoot())
    set pointer = 0
    while $listnext(dirs, pointer, dir) {
        do $$$AssertTrue(##class(%IPM.Utils.File).IsProtectedDirectory(dir), dir_" is protected")
    }
}

Method TestAncestorIsProtected()
{
    set installDir = $system.Util.InstallDirectory()
    set parent = ##class(%File).ParentDirectoryName(installDir)
    do $$$AssertTrue(##class(%IPM.Utils.File).IsProtectedDirectory(parent), parent_" is protected")
    set root = $select($$$isWINDOWS: $extract(installDir, 1, 3), 1: "/")
    do $$$AssertTrue(##class(%IPM.Utils.File).IsProtectedDirectory(root), root_" is protected")
}

Method TestSubdirectoryIsNotProtected()
{
    set installDir = $system.Util.InstallDirectory()
    set dirs = $listbuild(
        ##class(%File).NormalizeDirectory(##class(%File).Construct(installDir, "csp", "myapp")),
        ##class(%File).NormalizeDirectory(##class(%File).Construct(installDir, "mgr", "python", "mypkg")),
        ##class(%File).NormalizeDirectory(##class(%File).Construct(##class(%IPM.Repo.UniversalSettings).GetModuleRoot(), "mymodule", "1.0.0")))
    set pointer = 0
    while $listnext(dirs, pointer, dir) {
        do $$$AssertNotTrue(##class(%IPM.Utils.File).IsProtectedDirectory(dir), dir_" is not protected")
    }
}

/// Module targets arrive in whatever form the author wrote, e.g. ${mgrDir}/../csp without a trailing slash.
Method TestUnnormalizedPathIsProtected()
{
    set mgrDir = ##class(%File).ManagerDirectory()
    set dir = mgrDir_"/../csp"
    do $$$AssertTrue(##class(%IPM.Utils.File).IsProtectedDirectory(dir), dir_" is protected")
}

/// Windows and macOS file systems are case-insensitive by default.
Method TestDifferentCaseIsProtected()
{
    set dir = $zconvert(##class(%File).ManagerDirectory(), "U")
    do $$$AssertTrue(##class(%IPM.Utils.File).IsProtectedDirectory(dir), dir_" is protected")
}

}
