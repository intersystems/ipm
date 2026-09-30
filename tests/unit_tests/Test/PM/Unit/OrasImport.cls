/// Tests importing ORAS in a process that was denied access to it.
/// The tests change sys.path and sys.modules, which belong to the process rather than the test, so
/// OnAfterOneTest restores both before later tests in the same process import ORAS.
Class Test.PM.Unit.OrasImport Extends %UnitTest.TestCase
{

/// sys.path and the oras modules in sys.modules from before the test
Property SavedImportState As %SYS.Python;

/// Scratch directory for the oras packages the tests set up
Property TempDir As %String;

Method OnBeforeOneTest(testname As %String) As %Status
{
    set ..SavedImportState = ..SaveImportState()
    set ..TempDir = ..MakeTempDir()
    return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
    do ..RestoreImportState(..SavedImportState)
    do ..RemoveTempDir(..TempDir)
    return $$$OK
}

Method TestIsOrasUnreadable()
{
    do $$$AssertNotTrue(##class(%IPM.Repo.Oras.PackageService).IsOrasUnreadable(..TempDir), "A directory without oras is not reported as unreadable")
    do ..CopyRealOras(..TempDir)
    do $$$AssertNotTrue(##class(%IPM.Repo.Oras.PackageService).IsOrasUnreadable(..TempDir), "A readable oras is not reported as unreadable")

    if '..PermissionsAreEnforced() {
        do $$$LogMessage("Skipping the unreadable case, since file permissions do not restrict this process")
        return
    }
    do ..SetOrasReadable(..TempDir, 0)
    do $$$AssertTrue(##class(%IPM.Repo.Oras.PackageService).IsOrasUnreadable(..TempDir), "An oras that cannot be listed is reported as unreadable")
}

/// An oras directory Python cannot find __init__.py in is imported as an empty namespace package, and stays in sys.modules.
Method TestImportOrasProviderAfterNamespacePackage()
{
    do ..MakeEmptyOras(..TempDir)
    do ..HideRealOras(..TempDir)
    do ..AssertOrasProviderNotFound()

    do ..PrependToSavedPath(..TempDir)
    set provider = ##class(%IPM.Repo.Oras.PackageService).ImportOrasProvider()
    do $$$AssertEquals(provider."__name__", "oras.provider", "oras.provider is imported once the real oras is back on sys.path")
}

/// Python caches the empty listing it got for an oras it could not read, so it stays not found after the permissions are fixed.
Method TestImportOrasProviderAfterPermissionsFixed()
{
    if '..PermissionsAreEnforced() {
        do $$$LogMessage("Skipping, since file permissions do not restrict this process")
        return
    }
    do ..CopyRealOras(..TempDir)
    do ..HideRealOras(..TempDir)
    do ..SetOrasReadable(..TempDir, 0)
    do ..AssertOrasProviderNotFound()

    do ..SetOrasReadable(..TempDir, 1)
    // The real oras's dependencies are next to it
    do ..PrependToSavedPath(..TempDir)
    set provider = ##class(%IPM.Repo.Oras.PackageService).ImportOrasProvider()
    do $$$AssertTrue(provider."__file__" [ ..TempDir, "oras.provider is imported from the repaired oras: "_provider."__file__")
}

Method AssertOrasProviderNotFound()
{
    set error = ""
    try {
        do ##class(%SYS.Python).Import("oras.provider")
    } catch e {
        set error = e.DisplayString()
    }
    do $$$AssertTrue(error [ "ModuleNotFoundError", "Importing oras.provider fails with ModuleNotFoundError: "_error)
}

/// Replaces sys.path with the saved one, preceded by directory. Leaves sys.modules and the import caches as they are.
Method PrependToSavedPath(directory As %String) [ Language = python ]
{
    import sys

    sys.path[:] = [directory] + list(self.SavedImportState[0])
}

ClassMethod SaveImportState() As %SYS.Python [ Language = python ]
{
    import sys

    modules = {name: module for name, module in sys.modules.items() if (name == "oras") or name.startswith("oras.")}
    return (list(sys.path), modules)
}

ClassMethod RestoreImportState(state As %SYS.Python) [ Language = python ]
{
    import importlib
    import sys

    path, modules = state
    sys.path[:] = path
    for name in [name for name in sys.modules if (name == "oras") or name.startswith("oras.")]:
        del sys.modules[name]
    sys.modules.update(modules)
    importlib.invalidate_caches()
}

/// Makes directory the only place on sys.path with an oras, and forgets any oras already imported.
ClassMethod HideRealOras(directory As %String) [ Language = python ]
{
    import importlib
    import os
    import sys

    sys.path[:] = [path for path in sys.path if not os.path.isdir(os.path.join(path, "oras"))] + [directory]
    for name in [name for name in sys.modules if (name == "oras") or name.startswith("oras.")]:
        del sys.modules[name]
    importlib.invalidate_caches()
}

/// Whether removing a directory's permissions stops this process from listing it, which is not the case for root or on Windows
ClassMethod PermissionsAreEnforced() As %Boolean [ Language = python ]
{
    import os

    return hasattr(os, "geteuid") and (os.geteuid() != 0)
}

ClassMethod CopyRealOras(directory As %String) [ Language = python ]
{
    import importlib.util
    import os
    import shutil

    source = importlib.util.find_spec("oras").submodule_search_locations[0]
    shutil.copytree(source, os.path.join(directory, "oras"))
}

ClassMethod MakeEmptyOras(directory As %String) [ Language = python ]
{
    import os

    os.mkdir(os.path.join(directory, "oras"))
}

ClassMethod SetOrasReadable(
	directory As %String,
	readable As %Boolean) [ Language = python ]
{
    import os

    os.chmod(os.path.join(directory, "oras"), 0o755 if readable else 0)
}

ClassMethod MakeTempDir() As %String [ Language = python ]
{
    import tempfile

    return tempfile.mkdtemp()
}

ClassMethod RemoveTempDir(directory As %String) [ Language = python ]
{
    import os
    import shutil

    if os.path.isdir(os.path.join(directory, "oras")):
        os.chmod(os.path.join(directory, "oras"), 0o755)
    shutil.rmtree(directory)
}

}
