Class %IPM.ResourceProcessor.PythonWheel Extends %IPM.ResourceProcessor.Abstract
{

Parameter ATTRIBUTES As STRING = "Name,Directory,ExtraPipFlags";

Parameter DESCRIPTION As STRING = "Installs a Python wheel package.";

Property Name As %IPM.DataType.PythonWheelName;

Property Directory As %IPM.DataType.ResourceDirectory;

Property ExtraPipFlags As %IPM.DataType.CommandLineArgs;

/// Called as phase <var>pPhase</var> is executed for the resource. If <var>pResourceHandled</var> is set to true,
/// then the default behavior for that resource will be bypassed in the current phase.
/// Currently, this is only used in the Verify phase, because of different handling of intermediate error statuses.
/// TODO: Implement for standard database resources (.INC, .CLS, etc.)
Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
    If (pPhase '= "Initialize") {
        Set pResourceHandled = 0
        Quit $$$OK
    }

    Try {
        Set pResourceHandled = 1
        Set verbose = $GET(pParams("Verbose"))
        Set root = ..ResourceReference.Module.Root
        Set wheel = ##class(%File).NormalizeDirectory(..Directory, root)
        Set wheel = ##class(%File).NormalizeFilename(..Name, wheel)

        If '##class(%File).Exists(wheel) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Wheel file """_wheel_""" not found."))
        }

        If verbose {
            Write !,"Installing wheel package """_wheel_"""..."
        }

        Set pipCaller = ##class(%IPM.Lifecycle.Base).ResolvePipCaller(.pParams)
        Set target = ##class(%File).NormalizeDirectory("python", ##class(%File).ManagerDirectory())
        Set command = pipCaller _ $ListBuild("install", wheel, "-t", target) _ $ListFromString(..ExtraPipFlags, " ")
        If verbose {
            Write !,"Running command: ",command
        }
        $$$ThrowOnError(##class(%IPM.Utils.Module).RunCommand(, command))
    } Catch ex {
        Set pResourceHandled = 0
        Return ex.AsStatus()
    }
    Return $$$OK
}

}
