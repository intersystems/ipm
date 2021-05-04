Class %ZPM.PackageManager.Developer.Processor.Default.Package Extends %ZPM.PackageManager.Developer.Processor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for packages of classes included in a module.";

Parameter EXTENSION = "CLS";

Parameter NAMEPOSTFIX = ".";

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

Property Directory As %String(MAXLEN = "") [ InitialExpression = "cls" ];

Property LoadAsDirectory As %Boolean [ InitialExpression = 1 ];

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		If 'tGlobalScope {
			Set tSourceDB = ##class(%ZPM.PackageManager.Developer.Utils).GetRoutineDatabase($Namespace)
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).AddPackageMapping($namespace,tName,tSourceDB)
			If $$$ISERR(tSC) {
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
	Set tClassKey = ""
	For {
		Set tClassKey = $Order(pResourceArray(tClassKey))
		If (tClassKey = "") {
			Quit
		}
		Set tClassName = $Piece(tClassKey,".",1,*-1)
		Set pResourceArray(tClassKey,"RelativePath") = ..OnItemRelativePath(tClassName_".CLS")
	}
	Quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
	Quit $Select(..ResourceReference.Preload:"preload/",1:"")_..Directory_"/"_$tr($Piece(pItemName,".",1,*-1),..FilenameTranslateIdentifier,..FilenameTranslateAssociator)_"."_..FilenameExtension
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	If (..Format = "") {
		Set ..Format = $Case(..FilenameExtension,"cls":"UDL",:"XML")
	}
	Quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
