Class %IPM.ResourceProcessor.Default.LocalizedMessages Extends (%IPM.ResourceProcessor.Default.Document, %IPM.ResourceProcessor.LocalizationExport)
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for localized error messages.";

/// May be set to determine the value of <property>Extension</property> based on a static value rather than based on the resource name.
/// The only expected use case at this point is class packages (.PKG, but Extension will be .CLS)
Parameter EXTENSION = "LOC";

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "") [ InitialExpression = "localize" ];

/// Export format - list of acceptable values may differ by subclass.
Property Format As %String(VALUELIST = ",XML,UDL") [ InitialExpression = "XML" ];

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Set tVerbose = $Get(pParams("Verbose"),0)
	// Handle export of messages file for localization using the LocalizationExport resource processor class.
	If (..Filename = "") {
		// Default
		Set ..Filename = "/localize/"_$Translate($Piece(..ResourceReference.Name,".",1,*-1),".")_".xml"
	}
	If (pPhase = "Compile") {
		// Uses CompileList rather than Compile to support custom document type (.LOC)
		Set tSC = $System.OBJ.CompileList(..ResourceReference.Name,$Select(tVerbose:"d",1:"-d")_..Flags)
	}
	Quit $$$ADDSC(tSC,##class(%IPM.ResourceProcessor.LocalizationExport)$This.OnBeforePhase(pPhase,.pParams))
}

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResourceHandled = 0
	Try {
		If (pPhase = "Compile") {
			Set pResourceHandled = 1
		} Else {
			Set tSC = ##super(pPhase,.pParams,.pResourceHandled)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		If 'tGlobalScope {
			Set tNeedExplicitMapping = ..ResourceIsMappedToDefaultDB(tName_".INC")
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

}
