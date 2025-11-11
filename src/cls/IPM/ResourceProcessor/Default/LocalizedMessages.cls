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

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    set tVerbose = $get(pParams("Verbose"),0)
    // Handle export of messages file for localization using the LocalizationExport resource processor class.
    if (..Filename = "") {
        // Default
        set ..Filename = "/localize/"_$translate($piece(..ResourceReference.Name,".",1,*-1),".")_".xml"
    }
    if (pPhase = "Compile") {
        // Uses CompileList rather than Compile to support custom document type (.LOC)
        set tSC = $system.OBJ.CompileList(..ResourceReference.Name,$select(tVerbose:"d",1:"-d")_..Flags)
    }
    quit $$$ADDSC(tSC,##class(%IPM.ResourceProcessor.LocalizationExport)$this.OnBeforePhase(pPhase,.pParams))
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set pResourceHandled = 0
    try {
        if (pPhase = "Compile") {
            set pResourceHandled = 1
        } else {
            set tSC = ##super(pPhase,.pParams,.pResourceHandled)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tName = $piece(..ResourceReference.Name,".",1,*-1)
        set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$get(pParams("Reload","ForceLocalScope"),0)
        if 'tGlobalScope {
            set tNeedExplicitMapping = '..ResourceIsMappedToDefaultDB(tName_".INC")
            if tNeedExplicitMapping {
                set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($namespace)
                set tSC = ##class(%IPM.Utils.Module).AddRoutineMapping($namespace,tName,,tSourceDB)
                if $$$ISERR(tSC) {
                    quit
                }
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
