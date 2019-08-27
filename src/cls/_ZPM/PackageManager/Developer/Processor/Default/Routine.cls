Class %ZPM.PackageManager.Developer.Processor.Default.Routine Extends %ZPM.PackageManager.Developer.Processor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for routines.";

/// Characters in the filename to use as the associator in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and change "%" to "_"
Property FilenameTranslateAssociator As %String [ InitialExpression = "/_" ];

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "") [ InitialExpression = "mac" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "mac" ];

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		If 'tGlobalScope {
			Set tSourceDB = ##class(%ZPM.PackageManager.Developer.Utils).GetRoutineDatabase($Namespace)
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).AddRoutineMapping($namespace,tName,"MAC",tSourceDB)
			If $$$ISERR(tSC) {
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Subclasses may override to customize resource load behavior during the Reload phase.
Method OnLoad(pFullResourcePath As %String, pVerbose As %Boolean, Output pHandled As %Boolean = 0) As %Status
{
	Set pHandled = 1
	Set tFlags = $Select(pVerbose:"/display",1:"/nodisplay")_"/nocompile"
	Set tSC = $System.OBJ.Load(pFullResourcePath,tFlags,.errors,1)
	For i=1:1:$Get(errors) {
		Write !,$Get(errors(i))
		Set pHandled = 0
	}
	Quit tSC
}

}
