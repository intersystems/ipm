/// Integration test of list -python to display the list of installed python libarires
Class Test.PM.Integration.TestListPython Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "load-installed";

/// lightweight library used for python pip installation and uninstallation.
Parameter TestPackageName = "six";

Method TestListPython() As %Status
{
    set sc = ..verifyPythonAvailable(.pipcaller)
    set sc = ##class(%IPM.Main).Shell("list -py")
    do $$$AssertStatusOK(sc, "before installing the package "_..#TestPackageName)

    set tInstallStatus = ..InstallPythonPackage(pipcaller)
    do $$$AssertStatusOK(tInstallStatus, "Installation of test package '"_..#TestPackageName_"' must succeed.")

    set sc = ##class(%IPM.Main).Shell("list -py")
    do $$$AssertStatusOK(sc, "after installation the package "_..#TestPackageName)

    set tInstallStatus = ..UninstallPythonPackage(pipcaller)

    set sc = ##class(%IPM.Main).Shell("list -py")
    do $$$AssertStatusOK(sc, "after uninstalled the package "_..#TestPackageName)

    quit $$$OK
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

Method verifyPythonAvailable(Output pPipcaller As %String) As %Status
{
    set target = ##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
	if '$system.CLS.IsMthd("%SYS.Python", "Import") {
		throw ##class(%Exception.General).%New("Embedded Python is not available in this instance.")
	}
    set pPipcaller = ##class(%IPM.Storage.Module).%New().LifecycleGet().ResolvePipCaller()
    quit $$$OK
}

}
