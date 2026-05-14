Class Test.PM.Integration.PythonReferenceLifeCycle Extends Test.PM.Integration.Base
{

Method TestDependencyRegistration()
{
	#define NormalizeDirectory(%dir) ##class(%File).NormalizeDirectory(%dir)
	#Define NormalizeFilename(%file,%dir) ##class(%File).NormalizeFilename(%file,%dir)

	set testRoot = $$$NormalizeDirectory($get(^UnitTestRoot))
	set module1Dir = $$$NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/pythonref-lifecycle/module1/")
	set requiredLibsFile = $$$NormalizeFilename("requirements.txt",module1Dir)

	set file = ##class(%File).%New(requiredLibsFile)
	set sc = file.Open("R")
	$$$ThrowOnError(sc)
	while 'file.AtEnd {
	    set lib = file.ReadLine()
	    quit:lib=""
	    set lib = $zstrip(lib, "<>W")
	    set pythonLibs(lib)=""
	}
	do file.Close()

	set status = ..RunCommand("load "_module1Dir)
	do $$$AssertStatusOK(status,"Loaded demo-module1 module successfully. " _ module1Dir)

	do ..VerifyDependenciesInstalled("demo-module1", .pythonLibs, 1)

	set module2Dir = $$$NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/pythonref-lifecycle/module2/")
	set status = ..RunCommand("load "_module2Dir)
	do $$$AssertStatusOK(status,"Loaded demo-module2 module successfully. " _ module2Dir)

	do ..VerifyDependenciesInstalled("demo-module2", .pythonLibs, 2)

	do ..UninstallWithModifier(.pythonLibs)

	do $$$LogMessage("Reinstall the module for no-op uninstall test")

    // reinstall the modules
	set status = ..RunCommand("load "_module1Dir)
	do $$$AssertStatusOK(status,"Loaded demo-module1 module successfully. " _ module2Dir)
	set status = ..RunCommand("load "_module2Dir)
	do $$$AssertStatusOK(status,"Loaded demo-module2 module successfully. " _ module2Dir)

    do $$$LogMessage("Verifying the  python library 'requests' installed as pypi demo-module2")

    set pyRefOref = ##class(%IPM.Storage.PythonReference).%OpenId("requests")
    if $isobject(pyRefOref) {
        do $$$AssertTrue(pyRefOref.SourceType="pypi", "Python library 'requests' has expected SourceType of 'pypi' for demo-module2")
    } else {
        do $$$AssertNotTrue(1, "Python library 'requests' has not expected SourceType of 'pypi' for demo-module2")
    }

    do $$$LogMessage("Load the demo-module3 with '/home/irisowner/zpm/wheels/requests-2.32.4-py3-none-any.whl' dependency in requriements.txt")

    set module3Dir = $$$NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/pythonref-lifecycle/module3/")
    set status = ..RunCommand("load "_module3Dir)
    do $$$AssertStatusOK(status,"Loaded demo-module3 module successfully. " _ module3Dir)

    do $$$LogMessage("Verifying the whl dependency is overwritten for demo-module3")

    set pyRefOref = ##class(%IPM.Storage.PythonReference).%OpenId("requests")
    if $isobject(pyRefOref) {
        do $$$AssertTrue(pyRefOref.SourceType="whl", "Python library 'requests' has expected SourceType of 'whl' for demo-module3. whl path is "_pyRefOref.WheelPath)
    } else {
        do $$$AssertNotTrue(1, "Python library 'requests' has not expected SourceType of 'whl' for demo-module3")
    }

	do ..NoOpUninstall(.pythonLibs)

	do ..UninstallPyLibsEntriesManually(.pythonLibs)
}

Method VerifyDependenciesInstalled(
	pModule As %String,
	ByRef PythonLibs,
	ExpectedRefCount As %Integer)
{
    set module = ##class(%IPM.Storage.Module).NameOpen(pModule)
	if '$isobject(module) {
	    do $$$AssertNotTrue(0,"Module "_pModule_" is not installed.")
	    quit
	}
	do $$$AssertTrue(1,"Module "_pModule_" is installed.")
	do $$$LogMessage("Verifying python dependencies for module "_pModule_"...")
	set key=""
	for {
	    set pyRefOref = module.PythonDependencies.GetNext(.key)
	    quit:key=""
	    set libName = $$$lcase($piece(key,"=="))
	    if $data(PythonLibs(libName)) {
            do $$$AssertTrue(1, "Python library "_libName_" is expected to be installed for module "_pModule)
	        do $$$AssertTrue(pyRefOref.RefCount=ExpectedRefCount, "Python library "_libName_" has expected reference count of "_pyRefOref.RefCount_" for module "_pModule)
	    }else {
	        do $$$AssertNotTrue(0, "Python library "_libName_" is NOT expected to be installed for module "_pModule)
        }
	}
}

Method UninstallWithModifier(ByRef PythonLibs)
{
	do $$$LogMessage("Verifying the reference count before uninstall the demo-module1 with -with-py modifier...")

	do ..VerifyPythonLibRefCount(.PythonLibs, 2)
	do $$$LogMessage("uninstall the modules with modifier -with-py")
	set status = ..RunCommand("uninstall demo-module1 -with-py")
	do $$$AssertStatusOK(status,"Uninstalled demo-module1 successfully.")

	do ..VerifyPythonLibRefCount(.PythonLibs, 1)
	set status = ..RunCommand("uninstall demo-module2 -with-py")
	do $$$AssertStatusOK(status,"Uninstalled demo-module2 successfully.")
	do ..VerifyPythonLibExist(.PythonLibs)
}

Method VerifyPythonLibExist(ByRef PythonLibs)
{
	set pyLib=""
	do $$$LogMessage("Verifying python libraries exist...")
	for {
	    set pyLib = $order(PythonLibs(pyLib)) quit:pyLib=""
	    set libName = $$$lcase($piece(pyLib,"=="))
	    set pyRefOref = ##class(%IPM.Storage.PythonReference).%OpenId(libName)
	    do $$$AssertTrue('$isobject(pyRefOref), "Python library "_libName_" not exists in PythonReference storage.")
	}
    do $$$LogMessage("Verifying python libraries exist check completed.")
}

Method NoOpUninstall(ByRef PythonLibs)
{
    do $$$LogMessage("executing NoOpUninstall: uninstall modules without -with-py modifier")
	for module="demo-module1","demo-module2","demo-module3" {
	    do $$$LogMessage("uninstall "_module_" the  modules without removing python libraries...")
	    set status = ..RunCommand("uninstall "_module)
	    do $$$AssertStatusOK(status,"Uninstalled "_module_" successfully.")
	    do ..VerifyDependenciesInstalled(module, .PythonLibs, 2)
	}
}

Method VerifyPythonLibRefCount(
	ByRef PythonLibs,
	ExpectedRefCount As %Integer)
{
	set pyLib=""
	do $$$LogMessage("Verifying python library reference counts. The count should 2.")
	for {
	    set pyLib = $order(PythonLibs(pyLib)) quit:pyLib=""
	    set libName = $$$lcase($piece(pyLib,"=="))
	    set pyRefOref = ##class(%IPM.Storage.PythonReference).%OpenId(libName)
	    do $$$AssertTrue(pyRefOref.RefCount=ExpectedRefCount, "Python library "_libName_" has expected reference count of "_pyRefOref.RefCount)
	}
}

Method UninstallPyLibsEntriesManually(ByRef PythonLibs)
{
	set pyLib=""
	do $$$LogMessage("Uninstalling python libraries entries manually...")
	try {
	    for {
	        set pyLib = $order(PythonLibs(pyLib))
	        quit:pyLib=""
	        set libName = $$$lcase($piece(pyLib,"=="))
	        continue:'##class(%IPM.Storage.PythonReference).%ExistsId(libName)
	        do $$$LogMessage("uninstall the python library "_libName_" via pip...")
	        do ##class(%IPM.Storage.PythonReference).UninstallPythonLibrary(libName)
	        set status = ##class(%IPM.Storage.PythonReference).%DeleteId(libName)
	        do $$$AssertTrue(status,"Removed python library "_libName_" from PythonReference storage.")
	    }
	} catch ex {
	    do $$$AssertNotTrue(1,"Exception occurred during uninstalling python libraries entries manually: "_ex.DisplayString())
	}
    do $$$LogMessage("Uninstalling python libraries entries completed.")
}

Method RunCommand(pCommand As %String) As %Status [ CodeMode = expression ]
{
##class(%IPM.Main).Shell(pCommand)
}

}
