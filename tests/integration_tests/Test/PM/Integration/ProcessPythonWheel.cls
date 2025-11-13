Class Test.PM.Integration.ProcessPythonWheel Extends Test.PM.Integration.Base
{

Parameter PackageLocation = "python-wheel";

Parameter LuneNoReqsLocation = "lune-wheel-no-reqs";

Parameter LuneReqsOnlineLocation = "lune-wheel-reqs-online";

Parameter LuneReqsOfflineLocation = "lune-wheel-reqs-offline";

Parameter LuneNoWheelReqsOfflineLocation = "lune-no-wheel-reqs-offline";

Parameter PackageWithPythonDepsLocation = "package-with-python-deps";

Parameter ExportPackageWithPythonDepsLocation = "export-package-with-python-deps";

/// The PythonWheel resource processor expects to install wheels from the dist directory, as opposed to source code
ClassMethod GenerateWheel()
{
    set command = $listbuild("python3", "setup.py", "bdist_wheel")
    set dir = ..GetModuleDir("python-deps-tests", ..#PackageLocation, "modules", "python", "ipm_dummy_package")
    do ##class(%IPM.Utils.Module).RunCommand(dir, command)

    set wheel= ##class(%File).NormalizeFilename("dist/ipm_dummy_package-0.1-py3-none-any.whl", dir)
    do ##class(%File).CopyFile(wheel, ..GetModuleDir("python-deps-tests", ..#PackageLocation))
}

/// Get the version of a Python package
ClassMethod GetPythonVersion(name As %String) As %String
{
    // Note that importlib.metadata is available on Python 3.8+
    try {
        set importlib = ##class(%SYS.Python).Import("importlib")
        set metadata = importlib."import_module"("importlib.metadata")
        set ver = metadata."version"(name)
        return ver
    } catch ex {
        // In case Python version is lower than 3.8
        set packageResources = ##class(%SYS.Python).Import("pkg_resources")
        set dist = packageResources."get_distribution"(name)
        return dist."version"
    }
}

/// Remove dir or file if it exists
ClassMethod DeletePath(path As %String)
{
    if ##class(%File).DirectoryExists(path) {
        set removeSuccess = ##class(%File).RemoveDirectoryTree(path)
        if 'removeSuccess {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to remove directory: "_path))
        }
    } elseif ##class(%File).Exists(path) {
        set removeSuccess = ##class(%File).Delete(path)
        if 'removeSuccess {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to remove file: "_path))
        }
    }
}

/// Remove dir or file matching a pattern
ClassMethod DeletePattern(
	folder As %String,
	pattern As %String)
{
    set file = $zsearch(folder_pattern)
    while file '= "" {
        do ..DeletePath(file)
        set file = $zsearch("")
    }
}

/// Remove all installed copies of a package from the shared pip target
ClassMethod PurgePythonPackage(name As %String)
{
    set target = ##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
    zwrite target
    // common layouts
    //   <target>/<name>/
    //   <target>/<name>-<ver>.dist-info/
    do ..DeletePath(target_name)
    do ..DeletePattern(target, name_"-*"_".dist-info")
}

Method TestPythonWheelResource()
{
    do ..GenerateWheel()
    set dir = ..GetModuleDir("python-deps-tests", ..#PackageLocation)
    set sc = ##class(%IPM.Main).Shell("load -v " _ dir)
    do $$$AssertStatusOK(sc, "Successfully installed python-wheel resource")
    try {
        set dummyPackage = ##class(%SYS.Python).Import("ipm_dummy_package")
        do $$$AssertSuccess("Successfully imported python-wheel resource")
    } catch ex {
        do $$$AssertFailure("Failed to import python-wheel resource: "_ex.AsStatus())
    }
}

/// Testing case where only Python wheel and no requirements.txt is present
Method TestWheelPresent()
{
    do ..PurgePythonPackage("lune")
    set dir = ..GetModuleDir("python-deps-tests", ..#LuneNoReqsLocation)
    set sc = ##class(%IPM.Main).Shell("load -v " _ dir)
    do $$$AssertStatusOK(sc, "Successfully installed lune-wheel resource")
    try {
        set lunePackage = ##class(%SYS.Python).Import("lune")
        do $$$AssertSuccess("Successfully imported lune-wheel resource using wheel")
        set wheelVer = ..GetPythonVersion("lune")
        do $$$AssertEquals(wheelVer, "1.6.2")
    } catch ex {
        do $$$AssertFailure("Failed to import lune-wheel resource: "_ex.AsStatus())
    }
}

/// Testing case where Python wheel and requirements.txt is present. System connected to Internet.
/// requirements.txt takes precedence.
Method TestWheelAndReqsPresentOnline()
{
    do ..PurgePythonPackage("lune")
    set dir = ..GetModuleDir("python-deps-tests", ..#LuneReqsOnlineLocation)
    set sc = ##class(%IPM.Main).Shell("load -v " _ dir)
    do $$$AssertStatusOK(sc, "Successfully installed lune-wheel resource")
    try {
        set httprequest = ##class(%Net.HttpRequest).%New()
        set httprequest.Server="www.example.com"
        do httprequest.Get("/")
        if httprequest.HttpResponse '= "" {
            set lunePackage = ##class(%SYS.Python).Import("lune")
            do $$$AssertSuccess("Successfully imported lune-wheel resource using requirements.txt")
            set reqVer = ..GetPythonVersion("lune")
            do $$$AssertEquals(reqVer, "1.6.4")
        }
    } catch ex {
        do $$$AssertFailure("Failed to import lune-wheel resource: "_ex.AsStatus())
    }
}

/// Testing case where Python wheel and requirements.txt is present. System not connected to Internet.
/// Wheel takes precedence.
Method TestWheelAndReqsPresentOffline()
{
    do ..PurgePythonPackage("lune")
    set dir = ..GetModuleDir("python-deps-tests", ..#LuneReqsOfflineLocation)
    set sc = ##class(%IPM.Main).Shell("load -v -bypass-py-deps " _ dir)
    do $$$AssertStatusOK(sc, "Successfully installed lune-wheel resource")
    try {
        set lunePackage = ##class(%SYS.Python).Import("lune")
        do $$$AssertSuccess("Successfully imported lune-wheel resource using wheel")
        set wheelVer = ..GetPythonVersion("lune")
        do $$$AssertEquals(wheelVer, "1.6.2")
    } catch ex {
        do $$$AssertFailure("Failed to import lune-wheel resource: "_ex.AsStatus())
    }
}

/// Testing case where Python wheel is not present and requirements.txt is present. System not connected to Internet.
Method TestNoWheelAndReqsPresentOffline()
{
    do ..PurgePythonPackage("lune")
    set dir = ..GetModuleDir("python-deps-tests", ..#LuneNoWheelReqsOfflineLocation)
    set sc = ##class(%IPM.Main).Shell("load -v " _ dir)
    do $$$AssertStatusNotOK(sc, "Failed to install lune-wheel resource")
}

/// Package with -export-python-deps should write wheel resources into module.xml
Method TestPackageWithPythonDeps() As %Status
{
    do ..PurgePythonPackage("lune")
    do ..PurgePythonPackage("ansible")
    set dir = ..GetModuleDir("python-deps-tests", ..#PackageWithPythonDepsLocation)

    // Use a local filesystem repo to install the test module into the namespace
    set sc = ##class(%IPM.Main).Shell("repo -fs -name localrepo -path " _ dir)
    do $$$AssertStatusOK(sc, "Configured local filesystem repo")

    set sc = ##class(%IPM.Main).Shell("install -v localrepo/package-with-python-deps")
    do $$$AssertStatusOK(sc, "Installed module from local filesystem repo")

    set exportDir = ..GetModuleDir("python-deps-tests", ..#ExportPackageWithPythonDepsLocation)

    set exportTarball = ..GetModuleDir("python-deps-tests", ..#ExportPackageWithPythonDepsLocation, "package-with-python-deps")

    // Run package with the python-deps export flag
    set sc = ##class(%IPM.Main).Shell("package package-with-python-deps -v -export-python-deps -path "_ exportTarball)
    do $$$AssertStatusOK(sc, "Packaged module with -export-python-deps")

    set sc = ##class(%IPM.Main).Shell("uninstall package-with-python-deps")
    do $$$AssertStatusOK(sc, "Uninstalled module")

    set sc = ##class(%IPM.Main).Shell("load -bypass-py-deps " _ exportDir _ "package-with-python-deps.tgz")
    do $$$AssertStatusOK(sc, "Loaded packaged module")

    // Cleanup
    set sc = ##class(%IPM.Main).Shell("uninstall package-with-python-deps")
    do $$$AssertStatusOK(sc, "Uninstalled module")
    set sc = ##class(%IPM.Main).Shell("repo -delete -n localrepo")
    do $$$AssertStatusOK(sc, "Deleted local filesystem repo")
}

}
