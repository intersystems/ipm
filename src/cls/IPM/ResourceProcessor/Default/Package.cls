Class %IPM.ResourceProcessor.Default.Package Extends %IPM.ResourceProcessor.Default.Document
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for packages of classes included in a module.";

Parameter EXTENSION = "CLS";

Parameter NAMEPOSTFIX = ".";

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

Property Directory As %String(MAXLEN = "") [ InitialExpression = "cls" ];

Property LoadAsDirectory As %Boolean [ InitialExpression = 1 ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String;

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tName = $piece(..ResourceReference.Name,".",1,*-1)
        set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$get(pParams("Reload","ForceLocalScope"),0)
        if 'tGlobalScope {
            set tNeedExplicitMapping = '..ResourceIsMappedToDefaultDB(..ResourceReference.Name)
            if tNeedExplicitMapping {
                set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($namespace)
                set tSC = ##class(%IPM.Utils.Module).AddPackageMapping($namespace,tName,tSourceDB)
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

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
    set tItemKey = ""
    for {
        set tItemKey = $order(pResourceArray(tItemKey))
        if (tItemKey = "") {
            quit
        }
        set pResourceArray(tItemKey,"RelativePath") = ..OnItemRelativePath(tItemKey, $get(pResourceArray(tItemKey, "UnitTest")))
    }
    quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(
	pItemName As %String,
	pIsUnitTest As %Boolean = 0) As %String
{
    set tSourceRoot = ""
    if ('pIsUnitTest) {
        set tSourceRoot = ..ResourceReference.Module.SourcesRoot
        if tSourceRoot'="","\/"'[$extract(tSourceRoot, *) {
            set tSourceRoot = tSourceRoot _ "/"
        }
    }
    set fileNameExtension = $select(..FilenameExtension = "": $$$lcase($piece(pItemName, ".", *)), 1: ..FilenameExtension)
    set directory = ..Directory
    #; set directory = fileNameExtension
    set fileName = $translate($piece(pItemName, ".", 1, *-1),..FilenameTranslateIdentifier,..FilenameTranslateAssociator) _ "." _ fileNameExtension
    quit $select(..ResourceReference.Preload:"preload/",1:"") _ tSourceRoot _ $select(directory=$char(0):"", 1:directory _ "/") _ fileName
}

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    set ..Format = $case($$$lcase(..FilenameExtension),"xml":"XML",:"UDL")
    quit ##super(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

}
