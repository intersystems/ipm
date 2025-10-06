Class Test.PM.Integration.ProcessPythonWheel Extends Test.PM.Integration.Base
{

Parameter PackageLocation = "python-wheel";

Parameter LuneNoReqsLocation = "lune-wheel-no-reqs";

Parameter LuneReqsOnlineLocation = "lune-wheel-reqs-online";

Parameter LuneReqsOfflineLocation = "lune-wheel-reqs-offline";

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
ClassMethod PythonVersionOf(name As %String) As %String
{
    // Note that importlib.metadata is available on Python 3.8+
    try {
        set importlib = ##class(%SYS.Python).Import("importlib")
        set metadata = importlib."import_module"("importlib.metadata")
        set ver = metadata."version"(name)
        return ver
    } catch ex {
        // In case Python version is lower than 3.8
        set pkgres = ##class(%SYS.Python).Import("pkg_resources")
        set dist = pkgres."get_distribution"(name)
        return dist."version"
    }
}

/// Remove dir or file if it exists
ClassMethod DeletePath(path As %String)
{
    if ##class(%File).DirectoryExists(path) {
        do ##class(%File).RemoveDirectoryTree(path)
    } elseif ##class(%File).Exists(path) {
        do ##class(%File).Delete(path)
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
        set wheelVer = ..PythonVersionOf("lune")
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
            set reqVer = ..PythonVersionOf("lune")
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
    set sc = ##class(%IPM.Main).Shell("load -v " _ dir)
    do $$$AssertStatusOK(sc, "Successfully installed lune-wheel resource")
    try {
        set lunePackage = ##class(%SYS.Python).Import("lune")
        do $$$AssertSuccess("Successfully imported lune-wheel resource using wheel")
        set wheelVer = ..PythonVersionOf("lune")
        do $$$AssertEquals(wheelVer, "1.6.2")
    } catch ex {
        do $$$AssertFailure("Failed to import lune-wheel resource: "_ex.AsStatus())
    }
}

}
