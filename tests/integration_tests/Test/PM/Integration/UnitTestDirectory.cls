Class Test.PM.Integration.UnitTestDirectory Extends Test.PM.Integration.Base
{

/// Git does not track empty directories, so the module is copied to a temp directory and its
/// empty tests directory is created there.
Method TestEmptyDirectoryWarns()
{
    set tempDir = ##class(%IPM.Utils.File).CreateTempDirectory()
    try {
        set moduleXml = ##class(%File).NormalizeFilename("module.xml", ..GetModuleDir("unit-test-dir", "empty"))
        $$$ThrowOnError(##class(%IPM.Utils.File).CopyFile(moduleXml, ##class(%File).Construct(tempDir, "module.xml")))
        $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(##class(%File).Construct(tempDir, "tests")))

        set sc = ##class(%IPM.Main).Shell("load " _ tempDir)
        do $$$AssertStatusOK(sc, "Loaded unit-test-dir-empty")

        do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
        set sc = ##class(%IPM.Main).Shell("test unit-test-dir-empty -only")
        do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)

        do $$$AssertStatusOK(sc, "test phase succeeds with an empty unit test directory")
        do $$$AssertTrue(..FindStringInMultiDimArray("WARNING", .output), "test phase prints a warning")
        do $$$AssertTrue(..FindStringInMultiDimArray("UnitTestDir.Empty", .output), "warning names the empty package")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus())
    }
    do ##class(%IPM.Main).Shell("uninstall unit-test-dir-empty")
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(tempDir)
}

Method TestMissingDirectoryFails()
{
    set moduleDir = ..GetModuleDir("unit-test-dir", "missing")
    set sc = ##class(%IPM.Main).Shell("load " _ moduleDir)
    do $$$AssertStatusOK(sc, "Loaded unit-test-dir-missing")

    set sc = ##class(%IPM.Main).Shell("test unit-test-dir-missing -only")
    do $$$AssertStatusNotOK(sc, "test phase fails when the unit test directory does not exist")
    set missingDir = ##class(%File).NormalizeDirectory(##class(%File).Construct(moduleDir, "tests"))
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ missingDir, "error names the missing directory")

    do ##class(%IPM.Main).Shell("uninstall unit-test-dir-missing")
}

}
