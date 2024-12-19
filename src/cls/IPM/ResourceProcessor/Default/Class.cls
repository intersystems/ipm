Class %IPM.ResourceProcessor.Default.Class Extends %IPM.ResourceProcessor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for class definitions.";

Parameter EXTENSION = "CLS";

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

Property FilenameExtension As %String [ InitialExpression = "cls" ];

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		If 'tGlobalScope {
			Set tNeedExplicitMapping = ..ResourceIsMappedToDefaultDB(..ResourceReference.Name)
			If tNeedExplicitMapping {
				Set tPackage = $p(tName,".",1,*-1)
				Set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($Namespace)
				Set tSC = ##class(%IPM.Utils.Module).AddPackageMapping($namespace,tPackage,tSourceDB)
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
  If $ListFind($ListBuild("BPL","DTL"), $$$ucase($Piece(pItemName, ".", *))) {
    Set $Piece(pItemName, ".", *) = "cls"
  }
	If (..Format = "") {
		Set ..Format = $Case(..FilenameExtension,"cls":"UDL",:"XML")
	}
	Quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
