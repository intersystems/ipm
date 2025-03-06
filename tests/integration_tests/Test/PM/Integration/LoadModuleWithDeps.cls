Class Test.PM.Integration.LoadModuleWithDeps Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "load-export";

Method TestLoadModuleWithDependencies() As %Status
{
    /// Load from folder
    Set moduleDir = ..GetModuleDir(..#ModuleFolder)
    Set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    Do $$$AssertStatusOK(sc, "Successfully load from folder")

    /// Load from tarball
    Set tempDir = $$$FileTempDir
    Set exportPath = ##class(%File).NormalizeFilename("package", tempDir)
    Set tarballPath = ##class(%File).NormalizeFilename("package.tgz", tempDir)

    Set sc = ##class(%IPM.Main).Shell("package load-export -v -export-deps 1 -path " _ exportPath)
    Do $$$AssertStatusOK(sc, "Successfully export package as tarball")
    Set sc = ##class(%IPM.Main).Shell("uninstall load-export-deps")
    Do $$$AssertStatusOK(sc, "Uninstalled load-export-deps")
    Set sc = ##class(%IPM.Main).Shell("uninstall load-export")
    Do $$$AssertStatusOK(sc, "Uninstalled load-export")
    Set sc = ##class(%IPM.Main).Shell("load -v " _ tarballPath)
    Do $$$AssertStatusOK(sc, "Successfully load from tarball")

    Quit $$$OK
}

}
