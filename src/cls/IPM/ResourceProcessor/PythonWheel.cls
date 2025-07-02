Include %IPM.Formatting

Class %IPM.ResourceProcessor.PythonWheel Extends %IPM.ResourceProcessor.Abstract
{

Parameter ATTRIBUTES As STRING = "Name,Directory,ExtraPipFlags";

Parameter DESCRIPTION As STRING = "Installs a Python wheel package.";

Property Name As %IPM.DataType.PythonWheelName [ Required ];

Property Directory As %IPM.DataType.ResourceDirectory [ InitialExpression = "wheels" ];

Property ExtraPipFlags As %IPM.DataType.CommandLineArgs;

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    if (pPhase '= "Initialize") {
        set pResourceHandled = 0
        quit $$$OK
    }

    try {
        set pResourceHandled = 1
        set verbose = $get(pParams("Verbose"))
        set root = ..ResourceReference.Module.Root
        set wheel = ##class(%File).NormalizeDirectory(..Directory, root)
        set wheel = ##class(%File).NormalizeFilename(..Name, wheel)

        if '##class(%File).Exists(wheel) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Wheel file """_wheel_""" not found."))
        }

        if verbose {
            write !,"Installing wheel package """_wheel_"""..."
        }

        set pipCaller = ##class(%IPM.Lifecycle.Base).ResolvePipCaller(.pParams)
        set target = ##class(%File).NormalizeDirectory("python", ##class(%File).ManagerDirectory())
        set command = pipCaller _ $listbuild("install", wheel, "-t", target) _ $listfromstring(..ExtraPipFlags, " ")
        if verbose {
            write !,"Running command: ",command
        }
        $$$ThrowOnError(##class(%IPM.Utils.Module).RunCommand(, command))
    } catch ex {
        set pResourceHandled = 0
        // Special case: we want the installation of IPM to continue, even if the wheel package fails to install
        if ..ResourceReference.Module.Name = $$$IPMModuleName {
            set errMsg = $$$FormatText("Skipping installation of python wheel '%1' due to error: '%2'. ", ..Name, ex.AsStatus())
            set errMsg = errMsg _ "You may need to install this wheel manually or from PyPI to use certain features of IPM."
            write !, $$$FormattedLine($$$Red, errMsg)
            return $$$OK
        }
        return ex.AsStatus()
    }
    return $$$OK
}

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    set pItemHandled = 0
    set verbose = $get(pParams("Verbose"))

    set source = ##class(%File).NormalizeDirectory(..Directory, ..ResourceReference.Module.Root)
    set source = ##class(%File).NormalizeFilename(..Name, source)
    set source = ##class(%File).NormalizeFilenameWithSpaces(source)

    set dir = ##class(%File).GetDirectory(pFullExportPath)
    if (##class(%File).Exists(dir)) && ('##class(%File).DirectoryExists(dir)) {
        return $$$ERROR($$$GeneralError, "File """_dir_""" exists and is not a directory. Failed to export item: "_..Name)
    }
    if '##class(%File).DirectoryExists(dir) {
        if '##class(%File).CreateDirectoryChain(dir, .return) {
            return $$$ERROR($$$GeneralError, "Failed to create directory "_dir_", OS returned code: "_-return)
        }
    }
    if verbose {
        write !,"Copying wheel item '"_source_"' to '"_pFullExportPath_"'"
    }
    set pItemHandled = ##class(%File).CopyFile(source, pFullExportPath, 1, .return)
    if 'pItemHandled {
        return $$$ERROR($$$GeneralError, "Failed to copy "_source_" to "_pFullExportPath_", OS returned code: "_-return)
    }
    quit $$$OK
}

Method OnResolveChildren(
	ByRef pResourceArray,
	pCheckModuleOwnership As %Boolean) As %Status
{
    set key = $order(pResourceArray(""))
    if key = "" {
        quit $$$ERROR($$$GeneralError, "Empty resource array for PythonWheel resource processor: "_..Name)
    }
    set pResourceArray(key, "RelativePath") = ..Directory _"/"_..Name
    quit $$$OK
}

}
