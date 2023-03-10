/// Additional inteface for source control extensions to implement to plug in to module lifecycles.
Class %IPM.ExtensionBase.SourceControl.Interface [ Abstract ]
{

/// Name of page to help configure source control on a per-module basis
Parameter SETTINGSPAGE;

Parameter NOPREFIXCHARCODE = 8;

ClassMethod %GetClass() As %String [ Final ]
{
	Set tExtensionClass = ##class(%Studio.SourceControl.Interface).SourceControlClassGet()
	If (tExtensionClass = "") {
		Quit ""
	}
	
	If '$ClassMethod(tExtensionClass,"%Extends","%IPM.ExtensionBase.Composite") {
		Quit ""
	}
	
	Set tPrimaryClass = $ClassMethod(tExtensionClass,"GetPrimaryExtensionClass")
	If (tPrimaryClass = "") {
		Quit ""
	}
	
	If '$ClassMethod(tPrimaryClass,"%Extends",$ClassName()) {
		Quit ""
	}
	
	Quit $ClassName(tPrimaryClass)
}

ClassMethod %GetPage() As %String [ Final ]
{
	Set tClass = ..%GetClass()
	If (tClass = "") { Quit "" }
	Quit $Parameter(tClass,"SETTINGSPAGE")
}

ClassMethod %OnBeforePhase(pModule As %IPM.Storage.Module, pPhase As %String, ByRef pParams) As %Status [ Final ]
{
	Set tClass = ..%GetClass()
	If (tClass = "") {
		Quit $$$OK
	}
	Quit $ClassMethod(tClass,"OnBeforePhase",pModule,pPhase,.pParams)
}

ClassMethod %OnAfterPhase(pModule As %IPM.Storage.Module, pPhase As %String, ByRef pParams) As %Status [ Final ]
{
	Set tClass = ..%GetClass()
	If (tClass = "") {
		Quit $$$OK
	}
	Quit $ClassMethod(tClass,"OnAfterPhase",pModule,pPhase,.pParams)
}

ClassMethod %OnChangeModuleRoot(pModule As %IPM.Storage.Module) As %Status [ Final ]
{
	Set tClass = ..%GetClass()
	If (tClass = "") {
		Quit $$$OK
	}
	Quit $ClassMethod(tClass,"OnChangeModuleRoot",pModule)
}

ClassMethod %OnModifyResources(pModule As %IPM.Storage.Module) As %Status [ Final ]
{
	Set tClass = ..%GetClass()
	If (tClass = "") {
		Quit $$$OK
	}
	Quit $ClassMethod(tClass,"OnModifyResources",pModule)
}

ClassMethod %OnMakeModuleEditable(pModule As %IPM.Storage.Module) As %Status [ Final ]
{
	Set tClass = ..%GetClass()
	If (tClass = "") {
		Quit $$$OK
	}
	Quit $ClassMethod(tClass,"OnMakeModuleEditable",pModule)
}

/// Invoked prior to running build processes
ClassMethod %OnBeforeBuild(pIsDev As %Boolean) As %Status [ Final ]
{
	// Turn on storage checking by setting this flag (it sets a % variable)
	// This is done here because ..%GetClass() may return "" in some build contexts.
	Set $$$BuildFlag = 1
	Set tClass = ..%GetClass()
	If (tClass = "") {
		Quit $$$OK
	}
	Quit $ClassMethod(tClass,"OnBeforeBuild",pIsDev)
}

/// Invoked after running build processes
/// Should be called even if the build fails
ClassMethod %OnAfterBuild(pIsDev As %Boolean, pSuccessful As %Boolean) As %Status [ Final ]
{
	// Turn off storage checking
	// This is done here because ..%GetClass() may return "" in some build contexts.
	Kill $$$BuildFlag
	Set tClass = ..%GetClass()
	If (tClass = "") {
		Quit $$$OK
	}
	Quit $ClassMethod(tClass,"OnAfterBuild",pIsDev,pSuccessful)
}

/// Follows a similar pattern to %Studio.SourceControl.Interface, but permits all methods defined in the current Studio extension.
/// Moves %SourceControl (which must be defined!) to a different variable name, New's %SourceControl, then runs <var>pMethod</var>
/// of that object with <var>pArgs...</var>.
/// If expected to return a value, will return what this method does (most often a %Status); otherwise, will just do $method.
/// Much low-level (^%apiOBJ, etc.) import/export code behaves differently when %SourceControl is defined, so this is typically necessary
/// and always safest.
ClassMethod %SourceControlMethod(pMethod, pArgs...) As %Status
{
	Set tmp = %SourceControl
	New %SourceControl
	If $Quit {
		// If called in a way that requires a value to be returned, invoke pMethod in the same way.
		Quit $Method(tmp, pMethod, pArgs...)
	} Else {
		Do $Method(tmp, pMethod, pArgs...)
	}
}

/// Invoked after zpm "init" to configure settings for this source control class
/// Default implementation is a no-op
ClassMethod Configure() As %Status
{
	Quit $$$OK
}

/// Invoked before each lifecycle phase
ClassMethod OnBeforePhase(pModule As %IPM.Storage.Module, pPhase As %String, ByRef pParams) As %Status [ Abstract, Internal ]
{
	Quit $$$OK
}

/// Invoked after each lifecycle phase
ClassMethod OnAfterPhase(pModule As %IPM.Storage.Module, pPhase As %String, ByRef pParams) As %Status [ Abstract, Internal ]
{
	Quit $$$OK
}

/// Invoked when the list of resources for a module changes.
ClassMethod OnModifyResources(pModule As %IPM.Storage.Module) As %Status [ Abstract, Internal ]
{
	Quit $$$OK
}

/// Invoked when an existing module is reloaded from a different directory than its known module root
ClassMethod OnChangeModuleRoot(pModule As %IPM.Storage.Module) As %Status
{
	Quit $$$OK
}

/// Invoked when the user has attempted to edit a module document reported by the active Studio extension as read-only (i.e., because it is not checked out)
ClassMethod OnMakeModuleEditable(pModule As %IPM.Storage.Module) As %Status
{
	Quit $$$OK
}

/// Invoked before build process runs
ClassMethod OnBeforeBuild(pIsDev As %Boolean) As %Status
{
	Quit $$$OK
}

/// Invoked after build process runs
ClassMethod OnAfterBuild(pIsDev As %Boolean, pSuccessful As %Boolean) As %Status
{
	Quit $$$OK
}

}
