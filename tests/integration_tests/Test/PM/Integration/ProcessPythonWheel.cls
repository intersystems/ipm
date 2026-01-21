Class Test.PM.Integration.ProcessPythonWheel Extends Test.PM.Integration.Base
{

Parameter PackageLocation = "python-wheel";

Parameter LuneNoReqsLocation = "lune-wheel-no-reqs";

Parameter LuneReqsOnlineLocation = "lune-wheel-reqs-online";

Parameter LuneReqsOfflineLocation = "lune-wheel-reqs-offline";

Parameter LuneNoWheelReqsOfflineLocation = "lune-no-wheel-reqs-offline";

Parameter PackageWithPythonDepsLocation = "package-with-python-deps";

Parameter ExportPackageWithPythonDepsLocation = "export-package-with-python-deps";

Parameter PublishWithPythonDepsLocation = "publish-with-python-deps";

Method OnAfterOneTest() As %Status
{
    // Make test environment clean by uninstalling all modules at the end of each test
    set sc = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(sc, "Successfully uninstalled all modules after test")
    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc, "Successfully deleted all repositories after test")
    return sc
}

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

    /*
    set sc = ##class(%IPM.Main).Shell("load -bypass-py-deps " _ exportDir _ "package-with-python-deps.tgz")
    do $$$AssertStatusOK(sc, "Loaded packaged module")

    // Cleanup
    set sc = ##class(%IPM.Main).Shell("uninstall package-with-python-deps")
    do $$$AssertStatusOK(sc, "Uninstalled module")
    */
    set sc = ##class(%IPM.Main).Shell("repo -delete -n localrepo")
    do $$$AssertStatusOK(sc, "Deleted local filesystem repo")
}

/// Test publishing with the -export-python-deps flag
Method TestPublishWithPythonDeps() As %Status
{

    // 1. Test the case of python dependencies defined via requirements.txt
    set moduleNameReq = "publish-with-python-just-reqs"
    set wheelsReq = ["docx2md-1.0.5-py3-none-any.whl",
                     "lxml-6.0.2-cp312-cp312-manylinux_2_26_x86_64.manylinux_2_28_x86_64.whl",
                     "pillow-12.1.0-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"]
                     set wheels = {}
    do wheels.%Set(moduleNameReq, wheelsReq)
    do ..PublishTestHandler(moduleNameReq, wheels)

    // 2. Test the case of python dependencies defined via wheel resources in module.xml
    set moduleNameWhl = "publish-with-python-just-wheels"
    set wheelsWhl = ["numpy-2.4.1-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"]
    set wheels = {}
    do wheels.%Set(moduleNameWhl, wheelsWhl)
    do ..PublishTestHandler(moduleNameWhl, wheels)

    // 3. Test the case of python dependencies both defined in module.xml and requirements.txt
    set moduleNameWhlReq = "publish-with-python-wheels-and-reqs"
    set wheelsWhlReq = ["colorama-0.4.6-py2.py3-none-any.whl",
                        "six-1.17.0-py2.py3-none-any.whl"]
    set wheels = {}
    do wheels.%Set(moduleNameWhlReq, wheelsWhlReq)
    do ..PublishTestHandler(moduleNameWhlReq, wheels)



    // 4. Test the three cases above but as dependencies of a base module being installed
    set moduleNameDeps = "publish-with-python-deps-base"
    // There are no wheels defined for this base module but each of the dependencies do have wheels to check
    set wheels = {}
    do wheels.%Set(moduleNameReq, wheelsReq)
    do wheels.%Set(moduleNameWhl, wheelsWhl)
    do wheels.%Set(moduleNameWhlReq, wheelsWhlReq)
    do ..PublishTestHandler(moduleNameDeps, wheels)
}

/// Handler method for publish test suite
Method PublishTestHandler(
	moduleName As %String,
	wheels As %DynamicObject)
{
    // Create a filesystem repository
    set dir = ..GetModuleDir("python-deps-tests", ..#PublishWithPythonDepsLocation)
    set sc = ##class(%IPM.Main).Shell("repo -fs -name localrepo -path "_dir)
    do $$$AssertStatusOK(sc, "Configured local filesystem repo")

    // Install module from local filesystem repo
    set sc = ##class(%IPM.Main).Shell("install -v localrepo/"_moduleName)
    do $$$AssertStatusOK(sc, "Installed module from local filesystem repo")

    // Create a remote repository for publishing
    set sc = ##class(%IPM.Main).Shell("repo -r -name remote -url http://registry:52773/registry -username admin -password SYS")
    do $$$AssertStatusOK(sc, "Configured remote repo")

    // Publish module to remote repository
    set sc = ##class(%IPM.Main).Shell("publish -v "_moduleName_" -r remote -export-python-deps -export-deps 1")
    do $$$AssertStatusOK(sc, "Published module "_moduleName_" to remote repository")

    // Uninstall module that came from filesystem repository
    set sc = ##class(%IPM.Main).Shell("uninstall "_moduleName)
    do $$$AssertStatusOK(sc, "Uninstalled module successfully")

    // Install published module from remote repository
    set sc = ##class(%IPM.Main).Shell("install -v remote/"_moduleName)
    do $$$AssertStatusOK(sc, "Successfully installed published module "_moduleName_" from remote repository")

    // Confirm wheels were included in packaging/publishing
    do ..AssertWheelResourcesExistForModule(wheels)

    // Uninstall the module used for this test
    set sc = ##class(%IPM.Main).Shell("uninstall "_moduleName)
    do $$$AssertStatusOK(sc, "Uninstalled module "_moduleName_" successfully")

    // Remove the repositories used for this test
    set sc = ##class(%IPM.Main).Shell("repo -delete -n localrepo")
    do $$$AssertStatusOK(sc, "Removed local filesystem repo")
    set sc = ##class(%IPM.Main).Shell("repo -delete -n remote")
    do $$$AssertStatusOK(sc, "Removed remote repo")
}

/// Given an object of <module name>-<wheel list> pairs,
/// compiles a list of resources for the module and iterates over the wheel list to check if that wheel is a resource of the module
/// 
/// Ex: wheels= { "module1": ["wheel-1.whl","wheel-2.whl"], "module2":["wheel-3.whl","wheel-4.whl"] }
Method AssertWheelResourcesExistForModule(wheels As %DynamicObject)
{
    set wheelsIter = wheels.%GetIterator()
    while wheelsIter.%GetNext(.moduleName, .moduleWheels) {
        set module = ##class(%IPM.Storage.Module).NameOpen(moduleName)
        set resourceList = ""
        set key = ""
        for {
            set resource = module.Resources.GetNext(.key)
            quit:key=""
            set resourceList = resourceList_$listbuild($zconvert(resource.Name, "l"))
        }

        set moduleWheelsIter = moduleWheels.%GetIterator()
        while moduleWheelsIter.%GetNext(, .wheel) {
            set wheelIsResource = ($listfind(resourceList, wheel) > 0)
            do $$$AssertTrue(wheelIsResource, "Wheel resource "_wheel_" is a part of the installed module "_moduleName)
        }
    }
}

}
