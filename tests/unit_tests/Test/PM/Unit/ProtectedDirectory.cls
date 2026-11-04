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

/// Checks the list directly because every configured database directory also holds an IRIS.DAT,
/// which IsProtectedDirectory checks first.
Method TestDatabaseDirectoriesIncludesConfigured()
{
    set dir = $piece(##class(%SYS.Namespace).GetGlobalDest($namespace), "^", 2)
    set target = $zconvert(##class(%File).NormalizeDirectory(dir), "L")
    set databaseDirs = ##class(%IPM.Utils.File).DatabaseDirectories()
    set found = 0
    set pointer = 0
    while 'found && $listnext(databaseDirs, pointer, databaseDir) {
        set found = ($zconvert(##class(%File).NormalizeDirectory(databaseDir), "L") = target)
    }
    do $$$AssertTrue(found, dir_" is a configured database directory")
}

/// Covers a database IRIS does not know about, such as one dismounted and removed from the configuration.
Method TestDirectoryWithIrisDatIsProtected()
{
    set dir = ##class(%IPM.Utils.File).CreateTempDirectory()
    try {
        // IRIS refuses to write a file named IRIS.DAT, so write another name and rename it.
        set file = ##class(%Stream.FileBinary).%New()
        $$$ThrowOnError(file.LinkToFile(##class(%File).TempFilename("dat", dir)))
        $$$ThrowOnError(file.Write("not a real database"))
        $$$ThrowOnError(file.%Save())
        set tempName = file.Filename
        kill file
        if '##class(%File).Rename(tempName, ##class(%File).Construct(dir, "IRIS.DAT")) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Could not rename "_tempName_" to IRIS.DAT"))
        }
        do $$$AssertTrue(##class(%IPM.Utils.File).IsProtectedDirectory(dir), dir_" is protected")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(), "An exception occurred in TestDirectoryWithIrisDatIsProtected.")
    }
    do ##class(%File).RemoveDirectoryTree(dir)
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
