Class %IPM.ResourceProcessor.ModuleExport Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "In the Activate phase, exports the in-database code resources of this module (classes, routines, include files) as a Studio project in a single XML file.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "TargetFile";

/// File to which the module should be exported
Property TargetFile As %String(MAXLEN = "") [ Required ];

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    if (pPhase = "Activate") {
        quit ..Export(..ResourceReference.Module,..TargetFile,.pParams)
    }
    quit $$$OK
}

ClassMethod Export(
	pModule As %IPM.Storage.Module,
	pTargetFile As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        #dim tProject As %Studio.Project
        set tSC = pModule.GetStudioProject(.tProject)
        $$$ThrowOnError(tSC)
        set tSC = tProject.Export(pTargetFile,"/createdirs",0)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
