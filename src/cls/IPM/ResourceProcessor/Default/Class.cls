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
    set tSC = $$$OK
    try {
        set tName = $piece(..ResourceReference.Name,".",1,*-1)
        set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$get(pParams("Reload","ForceLocalScope"),0)
        if 'tGlobalScope {
            set tNeedExplicitMapping = '..ResourceIsMappedToDefaultDB(..ResourceReference.Name)
            if tNeedExplicitMapping {
                set tPackage = $piece(tName,".",1,*-1)
                set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($namespace)
                set tSC = ##class(%IPM.Utils.Module).AddPackageMapping($namespace,tPackage,tSourceDB)
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
    if $listfind($listbuild("BPL","DTL"), $$$ucase($piece(pItemName, ".", *))) {
        set $piece(pItemName, ".", *) = "cls"
    }
    if (..Format = "") {
        set ..Format = $case(..FilenameExtension,"cls":"UDL",:"XML")
    }
    quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
