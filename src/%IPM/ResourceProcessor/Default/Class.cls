Class %IPM.ResourceProcessor.Default.Class Extends %IPM.ResourceProcessor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for class definitions.";

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		If 'tGlobalScope {
			Set tPackage = $p(tName,".",1,*-1)
			Set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($Namespace)
			Set tSC = ##class(%IPM.Utils.Module).AddPackageMapping($namespace,tPackage,tSourceDB)
			If $$$ISERR(tSC) {
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	If (..Format = "") {
		Set ..Format = $Case(..FilenameExtension,"cls":"UDL",:"XML")
	}
	Quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
