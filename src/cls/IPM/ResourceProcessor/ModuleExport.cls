Class %IPM.ResourceProcessor.ModuleExport Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "In the Activate phase, exports the in-database code resources of this module (classes, routines, include files) as a Studio project in a single XML file.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "TargetFile";

/// File to which the module should be exported
Property TargetFile As %String(MAXLEN = "") [ Required ];

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	If (pPhase = "Activate") {
		Quit ..Export(..ResourceReference.Module,..TargetFile,.pParams)
	}
	Quit $$$OK
}

ClassMethod Export(pModule As %IPM.Storage.Module, pTargetFile As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		#dim tProject As %Studio.Project
		Set tSC = pModule.GetStudioProject(.tProject)
		$$$ThrowOnError(tSC)
		Set tSC = tProject.Export(pTargetFile,,0)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
