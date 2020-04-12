Class %ZPM.PackageManager.Developer.Processor.Default.Package Extends %ZPM.PackageManager.Developer.Processor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for packages of classes included in a module.";

Parameter EXTENSION = ".CLS";

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

Property Directory As %String(MAXLEN = "") [ InitialExpression = "cls" ];

Property LoadAsDirectory As %Boolean [ InitialExpression = 1 ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "cls" ];

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

Method %OnNew(pResourceReference As %ZPM.PackageManager.Developer.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = ##super(pResourceReference)
	If (..Format = "") {
		Set ..Format = $Case(..FilenameExtension,"cls":"UDL",:"XML")
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
		Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
		If tSourceRoot'="","\/"'[$EXTRACT(tSourceRoot, *) {
			Set tSourceRoot = tSourceRoot _ "/"
		}
		
		Set tClassName = $TRANSLATE(tClassName, "%", "_")
    Set tFilenameExtension = $Piece(tClassKey, ".", *)    
		Set pResourceArray(tClassKey,"RelativePath") = tSourceRoot_..Directory_"/"_$tr(tClassName,..FilenameTranslateIdentifier,..FilenameTranslateAssociator)_"."_tFilenameExtension
	}
	Quit $$$OK
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	If (pItemName="") {
		Quit $$$ERROR($$$GeneralError, "Nothing to export")
	}
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

/// Subclasses may override to customize resource load behavior during the Reload phase.
Method OnLoad(pFullResourcePath As %String, pVerbose As %Boolean, Output pHandled As %Boolean = 0) As %Status
{
	// This works for either UDL or XML.
	Set pHandled = 1
	Set tFlags = $Select(pVerbose:"/display",1:"/nodisplay")_"/nocompile"
	Set tSC = $System.OBJ.ImportDir(pFullResourcePath,,tFlags,.tErrors,1)
	For i=1:1:$Get(tErrors) {
		Write !,$Get(tErrors(i))
		Set pHandled = 0
	}
	Quit tSC
}

}
