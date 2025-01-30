Class Test.PM.Integration.ProcessPythonWheel Extends Test.PM.Integration.Base
{

Parameter PackageLocation = "python-wheel";

ClassMethod GenerateWheel()
{
    break "L"
    Set command = $ListBuild("python3", "setup.py", "bdist_wheel")
    Set dir = ..GetModuleDir(..#PackageLocation, "modules", "python", "ipm_dummy_package")
    Do ##class(%IPM.Utils.Module).RunCommand(dir, command)

    Set wheel= ##class(%File).NormalizeFilename("dist/ipm_dummy_package-0.1-py3-none-any.whl", dir)
    Do ##class(%File).CopyFile(wheel, ..GetModuleDir(..#PackageLocation))
}

Method TestPythonWheelResource()
{
    Do ..GenerateWheel()
    Set dir = ..GetModuleDir(..#PackageLocation)
    Set sc = ##class(%IPM.Main).Shell("load -v " _ dir)
    Do $$$AssertStatusOK(sc, "Successfully installed python-wheel resource")

    Try {
        Set dummyPackage = ##class(%SYS.Python).Import("ipm_dummy_package") 
        Do $$$AssertSuccess("Successfully imported python-wheel resource")
    } Catch ex {
        Do $$$AssertFailure("Failed to import python-wheel resource: "_ex.AsStatus())
    }
}

}
