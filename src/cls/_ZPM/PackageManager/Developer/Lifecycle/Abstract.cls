Include (%syGluedef, %ZPM.PackageManager.Common)

/// @PublicAPI
Class %ZPM.PackageManager.Developer.Lifecycle.Abstract Extends %RegisteredObject [ Abstract ]
{

/// $ListBuild list of phases in this lifecycle. <br />
/// For each phase name, an instance method named "%<phase name>" must be defined in the class with a return type of %Status.
Parameter PHASES;

Property Module As %ZPM.PackageManager.Developer.Module [ Private ];

Property PhaseList As %List;

Method %OnNew(pModule As %ZPM.PackageManager.Developer.Module) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..Module = pModule
	Quit $$$OK
}

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	Quit $$$OK
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Quit $$$OK
}

/// This method defines what a complete phase means for a given list of phases
ClassMethod GetCompletePhases(pOnePhase As %List) As %List
{
	quit pOnePhase
}

Method %DispatchMethod(pMethod As %String, ByRef pParams, Args...) [ ServerOnly = 1 ]
{
	if $listfind(..#PHASES,pMethod)=0 do $zu(96,3,$$$ERNOMETHOD,1,"","method "_pMethod_" of class "_$classname())
	quit ..Module.ExecutePhases(..Module.Name,$lb(pMethod),1,.pParams)
}

/// Merges default parameters into pParams
/// For now, just looks at ^SYS("PackageManager","DefaultParameters")
ClassMethod GetDefaultParameters(ByRef pParams, pPhases As %List)
{
	Merge pParams = ^SYS("PackageManager","DefaultParameters")
}

/// Returns the default resource processor class to use for a given resource name.
ClassMethod GetDefaultResourceProcessor(pResourceName As %String) As %Dictionary.CacheClassname
{
	If ($Extract(pResourceName) = "/") {
		Quit ""
	}
	Set tExtension = $Piece(pResourceName,".",*)
	Set tShortName = $Case(tExtension,
		"PKG":"Package",
		"CLS":"Class",
		"INC":"Include",
		"MAC":"Routine",
		"LOC":"LocalizedErrorMessages",
		"GBL":"Global",
		"DFI":"DeepSeeItem",
		"LUT":"Interoperability",
		"X12":"Interoperability",
		"ESD":"Interoperability",
		"DTL":"Class",
		"BPL":"Class",
		:"Document")
	If (tShortName = "") {
		Quit ""
	}
	Quit $$$DefaultProcessorPackageDot_"Default."_tShortName
}

}
