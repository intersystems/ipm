/// Resource processor for IRIS Interoperability productions stored as decomposed PTD files.
/// The production class is fully constituted by importing PTD files from the ptd/ subdirectory.
Class %IPM.ResourceProcessor.DecomposedProduction Extends %IPM.ResourceProcessor.Abstract
{

Parameter DESCRIPTION As STRING = "Manages an IRIS Interoperability production class constituted from PTD files in the ptd/ subdirectory.";

Parameter ATTRIBUTES As STRING = "Name";

/// The class name of the production to manage.
Property Name As %String(MAXLEN = "") [ Required ];

Method OnGetUniqueName(Output pUniqueName)
{
    set pUniqueName = ..Name _ ".CLS"
}

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set sc = $$$OK
    try {
        set sc = ##super(pPhase, .pParams)
        if $$$ISERR(sc) {
            quit
        }

        if (pPhase = "Validate") {
            set sysReqs = ..ResourceReference.Module.SystemRequirements
            if '$isobject(sysReqs) || (sysReqs.Interoperability '= "enabled") {
                set sc = $$$ERROR($$$GeneralError, $$$FormatText("Module '%1' must declare Interoperability in SystemRequirements to use the DecomposedProduction resource processor.", ..ResourceReference.Module.Name))
                quit
            }

            if '##class(%Dictionary.ClassDefinition).%ExistsId("%Studio.SourceControl.Production") {
                set sc = $$$ERROR($$$GeneralError, "DecomposedProduction resource processor is not supported on this InterSystems IRIS version.")
                quit
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set sc = $$$OK
    try {
        set sc = ##super(pPhase, .pParams)
        if $$$ISERR(sc) {
            quit
        }

        if (pPhase = "Compile") {
            // See %Studio.SourceControl.Production for details on how decomposed productions are represented on the file system
            set ptdDir = ..ResourceReference.Module.Root _ "ptd/" _ $translate(..Name, ".", "_") _ "/"
            set sc = ##class(%Studio.SourceControl.Production).ImportPTDsDir(ptdDir)
            if $$$ISERR(sc) {
                quit
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

Method OnResolveChildren(
	ByRef pResourceArray,
	pCheckModuleOwnership As %Boolean) As %Status
{
    // the production class itself should NOT be controlled by another package resource
    set pResourceArray(..Name _ ".CLS") = ""
    quit $$$OK
}

Method OnBeforeArtifact(
	pExportDirectory As %String,
	pWorkingDirectory As %String,
	ByRef pParams) As %Status
{
    set sc = $$$OK
    try {
        if (pExportDirectory = pWorkingDirectory) {
            quit
        }

        if '..ResourceReference.Deploy {
            set subDir = "ptd/" _ $translate(..Name, ".", "_") _ "/"
            set sc = ##class(%IPM.Utils.File).CopyDir(
                pExportDirectory _ subDir,
                pWorkingDirectory _ subDir)
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set sc = $$$OK
    try {
        if (pPhase = "Clean") {
            set pResourceHandled = 1

            set sc = ##class(Ens.Director).GetProductionStatus(.runningName, .state)
            if $$$ISERR(sc) {
                quit
            }

            if (state '= 0) && (runningName = ..Name) {
                set timeout = ##class(Ens.Director).GetRunningProductionShutdownTimeout()
                set sc = ##class(Ens.Director).StopProduction(timeout)
                if $$$ISERR(sc) {
                    quit
                }
            }

            set sc = ##class(Ens.Director).DeleteProduction(..Name)
            if $$$ISERR(sc) {
                quit
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

}
