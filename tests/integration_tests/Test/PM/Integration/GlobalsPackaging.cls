Class Test.PM.Integration.GlobalsPackaging Extends Test.PM.Integration.Base
{

/// Verifies that packaging a module with a globals resource and SourcesRoot
/// exports the file to the correct path and produces a loadable tarball.
Method TestGlobalsPackageWithSourcesRoot()
{
    set sc = $$$OK
    try {
        set moduleDir = ..GetModuleDir("globals")

        // Ensure clean state before loading from source
        do ##class(%IPM.Main).Shell("uninstall globals-test")

        set sc = ##class(%IPM.Main).Shell("load " _ moduleDir)
        do $$$AssertStatusOK(sc, "Loaded globals-test module successfully.")

        set tempDir = ##class(%Library.File).TempFilename() _ "dir"
        set sc = ##class(%IPM.Main).Shell("globals-test package -DPath=" _ tempDir)
        do $$$AssertStatusOK(sc, "Packaged globals-test module successfully.")

        set outDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).TempFilename() _ "dir-out")
        set sc = ##class(%IPM.General.Archive).Extract(tempDir _ ".tgz", outDir, .extractOutput)
        do $$$AssertStatusOK(sc, "Extracted tarball.")

        do $$$AssertTrue(##class(%File).Exists(outDir _ "src/gbl/My.Settings.xml"), "Global exported to src/gbl/My.Settings.xml (SourcesRoot respected).")

        // Uninstall before loading from tarball to get a clean load assertion
        do ##class(%IPM.Main).Shell("uninstall globals-test")

        set sc = ##class(%IPM.Main).Shell("load " _ tempDir _ ".tgz")
        do $$$AssertStatusOK(sc, "Loaded globals-test from tarball successfully.")

        do $$$AssertEquals($get(^My.Settings("Parameter")), 42, "^My.Settings imported correctly from tarball.")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(), "An exception occurred.")
    }
}

}
