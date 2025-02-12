Class %IPM.ResourceProcessor.PythonWheel Extends %IPM.ResourceProcessor.Abstract
{

Parameter ATTRIBUTES As STRING = "Name,Directory,ExtraPipFlags";

Parameter DESCRIPTION As STRING = "Installs a Python wheel package.";

Property Name As %IPM.DataType.PythonWheelName [ Required ];

Property Directory As %IPM.DataType.ResourceDirectory [ InitialExpression = "wheels" ];

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

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
    Set pItemHandled = 0
    Set verbose = $Get(pParams("Verbose"))

    Set source = ##class(%File).NormalizeDirectory(..Directory, ..ResourceReference.Module.Root)
    Set source = ##class(%File).NormalizeFilename(..Name, source)
    Set source = ##class(%File).NormalizeFilenameWithSpaces(source)

    Set dir = ##class(%File).GetDirectory(pFullExportPath)
    If (##class(%File).Exists(dir)) && ('##class(%File).DirectoryExists(dir)) {
        Return $$$ERROR($$$GeneralError, "File """_dir_""" exists and is not a directory. Failed to export item: "_..Name)
    }
    If '##class(%File).DirectoryExists(dir) {
        If '##class(%File).CreateDirectoryChain(dir, .return) {
            Return $$$ERROR($$$GeneralError, "Failed to create directory "_dir_", OS returned code: "_-return)
        }
    }
    If verbose {
        Write !,"Copying wheel item '"_source_"' to '"_pFullExportPath_"'"
    }
    Set pItemHandled = ##class(%File).CopyFile(source, pFullExportPath, 1, .return)
    If 'pItemHandled {
        Return $$$ERROR($$$GeneralError, "Failed to copy "_source_" to "_pFullExportPath_", OS returned code: "_-return)
    }
    Quit $$$OK
}

Method OnResolveChildren(ByRef pResourceArray, pCheckModuleOwnership As %Boolean) As %Status
{
    Set key = $Order(pResourceArray(""))
    If key = "" {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Empty resource array for PythonWheel resource processor: "_..Name))
    }
    Set pResourceArray(key, "RelativePath") = ..Directory _"/"_..Name
    Quit $$$OK
}

}
