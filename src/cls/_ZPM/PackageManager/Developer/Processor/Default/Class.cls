Class %ZPM.PackageManager.Developer.Processor.Default.Class Extends %ZPM.PackageManager.Developer.Processor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for class definitions.";

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

Property FilenameExtension As %String [ InitialExpression = "cls" ];

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		If 'tGlobalScope {
			Set tPackage = $p(tName,".",1,*-1)
			Set tSourceDB = ##class(%ZPM.PackageManager.Developer.Utils).GetRoutineDatabase($Namespace)
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).AddPackageMapping($namespace,tPackage,tSourceDB)
			If $$$ISERR(tSC) {
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %OnNew(pResourceReference As %ZPM.PackageManager.Developer.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = ##super(pResourceReference)
	If (..Format = "") {
		Set ..Format = $Case($$$lcase(..FilenameExtension),"cls":"UDL",:"XML")
	}
  Set ..Directory = ""
	Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
  Set tVerbose = $Get(pParams("Verbose"))
	If ..Format = "XML" {
		Set tSC = $System.OBJ.Export(pItemName,pFullExportPath,"-d")
	} ElseIf (..Format = "UDL") {
		Set tSC = $System.OBJ.ExportUDL(pItemName,pFullExportPath,"-d")
	}
	Set pItemHandled = 1
	If $$$ISOK(tSC),tVerbose {
		WRITE !,"Exported '",pItemName,"' to ",pFullExportPath
	}
	Quit tSC
}

}
