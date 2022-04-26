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
			Set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($Namespace)
			Set tPackage = $p(tName,".",1,*-1)
			// Check if current file exists in the the routine database of the current namespace exists in current namespace('s database)
			// If yes, skip creating unnecessary mappings
			// (Spec,Dir=1,OrderBy=1,SystemFiles=1,Flat,NotStudio=0,ShowGenerated=0,Filter,RoundTime=0,Mapped=0)
			// Set mapped=0 since we only want to check whether the file exists in the current routine DB
			Set tResult = ##class(%Library.RoutineMgr).StudioOpenDialogFunc("tName.*",1,1,1,,,,,,0)
			Set tNeedExplicitMapping = 1
			While tResult.%Next(.tSC) {
				If $$$ISERR(tSC) {
					Quit
				}
				if ($ZConvert(tResult.%Get("Name"),"U") = $ZConvert(tName, "U")) {
					Set tNeedExplicitMapping = 0
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
			If tNeedExplicitMapping {
				Set tPackage = $p(tName,".",1,*-1)
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
	If (..Format = "") {
		Set ..Format = $Case(..FilenameExtension,"cls":"UDL",:"XML")
	}
	Quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
