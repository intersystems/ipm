/// Integration test for the 'list -py' command to verify the output of installed Python libraries.
Class Test.PM.Integration.ListInstPythonLibrariesTest Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "load-installed";

/// lightweight library used for python pip installation and uninstallation.
Parameter TestPackageName = "six";

Method TestListPython()
{
    set status = ..VerifyPythonAvailable(.pipcaller)
    do $$$AssertStatusOK(status, " Verify python is available "_..#TestPackageName)

    set status = ##class(%IPM.Main).Shell("list -py")
    do $$$AssertStatusOK(status, "before installing the package "_..#TestPackageName)

    set status = ..InstallPythonPackage(pipcaller)
    do $$$AssertStatusOK(status, "Installation of test package '"_..#TestPackageName_"' must succeed.")

    set status = ##class(%IPM.Main).Shell("list -py")
    do $$$AssertStatusOK(status, "after installation the package "_..#TestPackageName)

    set status = ..UninstallPythonPackage(pipcaller)
    do $$$AssertStatusOK(status, "uninstalled the package "_..#TestPackageName)

    set status = ##class(%IPM.Main).Shell("list -py")
    do $$$AssertStatusOK(status, "after uninstalled the package "_..#TestPackageName)
}

Method InstallPythonPackage(pPipCaller As %List) As %Status
{
    set target = ##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
    set command = pPipCaller_$listbuild("install",..#TestPackageName,"-t",target)
    set status = ##class(%IPM.Utils.Module).RunCommand(target, command,.stdout)
    quit status
}

Method UninstallPythonPackage(pPipCaller As %List) As %Status
{
    set target = ##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
    set command = pPipCaller_$listbuild("uninstall","-y",..#TestPackageName,"--break-system-packages")
    set status = ##class(%IPM.Utils.Module).RunCommand(target, command,.stdout)
    quit status
}

Method VerifyPythonAvailable(Output pPipcaller As %String) As %Status
{
    set status=1, pPipCaller=""
    set target = ##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
	if '$system.CLS.IsMthd("%SYS.Python", "Import") {
		set status = $$$ERROR($$$PythonGeneralError,"Embedded Python is not available in this instance.")
        return status
	}
    set pPipcaller = ##class(%IPM.Storage.Module).%New().LifecycleGet().ResolvePipCaller()
    quit status
}

}
