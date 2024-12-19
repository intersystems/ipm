Class %IPM.ResourceProcessor.Default.Routine Extends %IPM.ResourceProcessor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for routines.";

/// May be set to determine the value of <property>Extension</property> based on a static value rather than based on the resource name.
Parameter EXTENSION = "MAC";

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "") [ InitialExpression = "rtn" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "rtn" ];

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		If 'tGlobalScope && '..LoadAsDirectory {
			Set tNeedExplicitMapping = ..ResourceIsMappedToDefaultDB(..ResourceReference.Name)
			If tNeedExplicitMapping {
				Set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($Namespace)
				Set tSC = ##class(%IPM.Utils.Module).AddRoutineMapping($namespace,tName,,tSourceDB)
				If $$$ISERR(tSC) {
					Quit
				}
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
		// Default handling
		Set ..Format = "UDL"
	}
	Quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
