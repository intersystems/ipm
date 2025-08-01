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
    set tSC = $$$OK
    try {
        set tName = $piece(..ResourceReference.Name,".",1,*-1)
        set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$get(pParams("Reload","ForceLocalScope"),0)
        if 'tGlobalScope && '..LoadAsDirectory {
            set tNeedExplicitMapping = '..ResourceIsMappedToDefaultDB(..ResourceReference.Name)
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

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    if (..Format = "") {
        // Default handling
        set ..Format = "UDL"
    }
    quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
