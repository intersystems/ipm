/// Tests that loading a module skips files that IRIS cannot import, such as the .DS_Store files
/// macOS Finder creates.
Class Test.PM.Integration.UnsupportedFiles Extends Test.PM.Integration.Base
{

/// The fixture has unsupported files in a package directory and in the preload directory. The
/// preload class processes a resource and records each phase it runs in, so it runs in Reload
/// only if preload compiled it.
Method TestLoadSkipsUnsupportedFiles()
{
    kill ^IPMTest("UnsupportedFiles")
    set moduleDir = ..GetModuleDir("unsupported-files")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ moduleDir), "Loaded module with unsupported files")
    do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("Test.Unsupported.MyClass"), "Class in package directory was compiled")
    do $$$AssertTrue($get(^IPMTest("UnsupportedFiles", "Reload")), "Class in preload directory was compiled before Reload")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall unsupported-files"), "Uninstalled module")
    kill ^IPMTest("UnsupportedFiles")
}

}
