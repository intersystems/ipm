Class %IPM.ResourceProcessor.Default.Package Extends %IPM.ResourceProcessor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for packages of classes included in a module.";

Parameter EXTENSION = "CLS";

Parameter NAMEPOSTFIX = ".";

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

Property Directory As %String(MAXLEN = "") [ InitialExpression = "cls" ];

Property FilenameTranslateIdentifier As %String [ InitialExpression = ".%" ];

Property FilenameTranslateAssociator As %String [ InitialExpression = "/_" ];

Property LoadAsDirectory As %Boolean [ InitialExpression = 1 ];

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		If 'tGlobalScope {
			Set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($Namespace)
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
				Set tSC = ##class(%IPM.Utils.Module).AddPackageMapping($namespace,tName,tSourceDB)
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

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
	Set tItemKey = ""
	For {
		Set tItemKey = $Order(pResourceArray(tItemKey))
		If (tItemKey = "") {
			Quit
		}
		Set pResourceArray(tItemKey,"RelativePath") = ..OnItemRelativePath(tItemKey, $Get(pResourceArray(tItemKey, "UnitTest")))
	}
	Quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String, pIsUnitTest As %Boolean = 0) As %String
{
  if ('pIsUnitTest) {
    Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
    If tSourceRoot'="","\/"'[$EXTRACT(tSourceRoot, *) {
      Set tSourceRoot = tSourceRoot _ "/"
    }
  } else {
    Set tSourceRoot = ..Directory
  }
  set fileNameExtension = $$$lcase($Piece(pItemName, ".", *))
  set directory = fileNameExtension
  set fileName = $tr($Piece(pItemName, ".", 1, *-1),..FilenameTranslateIdentifier,..FilenameTranslateAssociator) _ "." _ fileNameExtension
	Quit $Select(..ResourceReference.Preload:"preload/",1:"") _ tSourceRoot _ directory _ "/" _ fileName
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
  set ..Format = "UDL"
	Quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
