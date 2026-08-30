Include %occInclude

/// Provides a centralized set of utility methods for interacting with
/// the Embedded Python engine within the IPM (InterSystems Package Manager) framework. <br/>
/// This class handles environment verification, version retrieval, and
/// common Python operations used during the module lifecycle (install, uninstall, etc.).
Class %IPM.Utils.Python
{

ClassMethod GetPythonVersion(Output pyVersion As %String) As %Status
{
    set pyVersion = ""
    set sc = ..IsPythonEnabled()
    if $$$ISERR(sc) {
        quit sc
    }

    try {
        set tSysModule = ##class(%SYS.Python).Import("sys")
        set vInfo = tSysModule."version_info"
        set pyVersion = vInfo.major _ "." _ vInfo.minor _ "." _ vInfo.micro
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod IsPythonEnabled() As %Status
{
	if '$system.CLS.IsMthd("%SYS.Python", "Import") {
		return $$$ERROR($$$PythonGeneralError, "Embedded Python is not available in this instance.")
	}
    return $$$OK
}

ClassMethod ResolvePipCaller(pParams) [ CodeMode = expression ]
{
##class(%IPM.Lifecycle.Base).ResolvePipCaller(.pParams)
}

ClassMethod PythonManagerDir() [ CodeMode = expression ]
{
##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
}

}
