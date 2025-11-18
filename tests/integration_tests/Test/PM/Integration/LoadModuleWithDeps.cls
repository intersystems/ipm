Class Test.PM.Integration.LoadModuleWithDeps Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "load-export";

Method TestLoadModuleWithDependencies() As %Status
{
    /// Load from folder
    set moduleDir = ..GetModuleDir(..#ModuleFolder)
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusOK(sc, "Successfully load from folder")

    /// Load from tarball
    set tempDir = $$$FileTempDir
    set exportPath = ##class(%File).NormalizeFilename("package", tempDir)
    set tarballPath = ##class(%File).NormalizeFilename("package.tgz", tempDir)

    set sc = ##class(%IPM.Main).Shell("package load-export -v -export-deps 1 -path " _ exportPath)
    do $$$AssertStatusOK(sc, "Successfully export package as tarball")
    set sc = ##class(%IPM.Main).Shell("uninstall load-export-deps")
    do $$$AssertStatusOK(sc, "Uninstalled load-export-deps")
    set sc = ##class(%IPM.Main).Shell("uninstall load-export")
    do $$$AssertStatusOK(sc, "Uninstalled load-export")
    set sc = ##class(%IPM.Main).Shell("load -v " _ tarballPath)
    do $$$AssertStatusOK(sc, "Successfully load from tarball")

    quit $$$OK
}

Method TestParamPropagation() As %Status
{
    // Make sure developer mode is not propagated when loading modules
    set moduleDir = ..GetModuleDir(..#ModuleFolder)
    set sc = ##class(%IPM.Main).Shell("load -v -dev " _ moduleDir)
    do $$$AssertStatusOK(sc, "Successfully load from folder")

    set module = ##class(%IPM.Storage.Module).NameOpen(..#ModuleFolder, sc)
    do $$$AssertStatusOK(sc, "Opened module succesfully")
    do $$$AssertEquals(module.DeveloperMode, 1)

    set dep = ##class(%IPM.Storage.Module).NameOpen("load-export-deps", sc)
    do $$$AssertStatusOK(sc, "Opened dependency succesfully")
    do $$$AssertEquals(dep.DeveloperMode, 0)

    // Do the same for install
    set sc = ##class(%IPM.Main).Shell("repo -name oras -o -url http://oras:5000 -publish 1")
    do $$$AssertStatusOK(sc, "Successfully set up test registry")

    set sc = ##class(%IPM.Main).Shell("publish -r oras load-export -export-deps 1")
    do $$$AssertStatusOK(sc, "Successfully published module")

    set sc = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(sc, "Successfully uninstalled all modules")

    set sc = ##class(%IPM.Main).Shell("install -v -dev " _ ..#ModuleFolder)
    do $$$AssertStatusOK(sc, "Successfully installed module")

    kill module, dep
    set module = ##class(%IPM.Storage.Module).NameOpen(..#ModuleFolder, sc)
    do $$$AssertStatusOK(sc, "Opened module succesfully")
    do $$$AssertEquals(module.DeveloperMode, 1)

    set dep = ##class(%IPM.Storage.Module).NameOpen("load-export-deps", sc)
    do $$$AssertStatusOK(sc, "Opened dependency succesfully")
    do $$$AssertEquals(dep.DeveloperMode, 0)
}

}
