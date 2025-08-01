/// Additional inteface for source control extensions to implement to plug in to module lifecycles.
Class %IPM.ExtensionBase.SourceControl.Interface [ Abstract ]
{

/// Name of page to help configure source control on a per-module basis
Parameter SETTINGSPAGE;

Parameter NOPREFIXCHARCODE = 8;

ClassMethod %GetClass() As %String [ Final ]
{
    set tExtensionClass = ##class(%Studio.SourceControl.Interface).SourceControlClassGet()
    if (tExtensionClass = "") {
        quit ""
    }

    if '$classmethod(tExtensionClass,"%Extends","%IPM.ExtensionBase.Composite") {
        quit ""
    }

    set tPrimaryClass = $classmethod(tExtensionClass,"GetPrimaryExtensionClass")
    if (tPrimaryClass = "") {
        quit ""
    }

    if '$classmethod(tPrimaryClass,"%Extends",$classname()) {
        quit ""
    }

    quit $classname(tPrimaryClass)
}

ClassMethod %GetPage() As %String [ Final ]
{
    set tClass = ..%GetClass()
    if (tClass = "") { quit "" }
    quit $parameter(tClass,"SETTINGSPAGE")
}

ClassMethod %OnBeforePhase(
	pModule As %IPM.Storage.Module,
	pPhase As %String,
	ByRef pParams) As %Status [ Final ]
{
    set tClass = ..%GetClass()
    if (tClass = "") {
        quit $$$OK
    }
    quit $classmethod(tClass,"OnBeforePhase",pModule,pPhase,.pParams)
}

ClassMethod %OnAfterPhase(
	pModule As %IPM.Storage.Module,
	pPhase As %String,
	ByRef pParams) As %Status [ Final ]
{
    set tClass = ..%GetClass()
    if (tClass = "") {
        quit $$$OK
    }
    quit $classmethod(tClass,"OnAfterPhase",pModule,pPhase,.pParams)
}

ClassMethod %OnChangeModuleRoot(pModule As %IPM.Storage.Module) As %Status [ Final ]
{
    set tClass = ..%GetClass()
    if (tClass = "") {
        quit $$$OK
    }
    quit $classmethod(tClass,"OnChangeModuleRoot",pModule)
}

ClassMethod %OnModifyResources(pModule As %IPM.Storage.Module) As %Status [ Final ]
{
    set tClass = ..%GetClass()
    if (tClass = "") {
        quit $$$OK
    }
    quit $classmethod(tClass,"OnModifyResources",pModule)
}

ClassMethod %OnMakeModuleEditable(pModule As %IPM.Storage.Module) As %Status [ Final ]
{
    set tClass = ..%GetClass()
    if (tClass = "") {
        quit $$$OK
    }
    quit $classmethod(tClass,"OnMakeModuleEditable",pModule)
}

/// Invoked prior to running build processes
ClassMethod %OnBeforeBuild(pIsDev As %Boolean) As %Status [ Final ]
{
    // Turn on storage checking by setting this flag (it sets a % variable)
    // This is done here because ..%GetClass() may return "" in some build contexts.
    set $$$BuildFlag = 1
    set tClass = ..%GetClass()
    if (tClass = "") {
        quit $$$OK
    }
    quit $classmethod(tClass,"OnBeforeBuild",pIsDev)
}

/// Invoked after running build processes
/// Should be called even if the build fails
ClassMethod %OnAfterBuild(
	pIsDev As %Boolean,
	pSuccessful As %Boolean) As %Status [ Final ]
{
    // Turn off storage checking
    // This is done here because ..%GetClass() may return "" in some build contexts.
    kill $$$BuildFlag
    set tClass = ..%GetClass()
    if (tClass = "") {
        quit $$$OK
    }
    quit $classmethod(tClass,"OnAfterBuild",pIsDev,pSuccessful)
}

/// Follows a similar pattern to %Studio.SourceControl.Interface, but permits all methods defined in the current Studio extension.
/// Moves %SourceControl (which must be defined!) to a different variable name, New's %SourceControl, then runs <var>pMethod</var>
/// of that object with <var>pArgs...</var>.
/// If expected to return a value, will return what this method does (most often a %Status); otherwise, will just do $method.
/// Much low-level (^%apiOBJ, etc.) import/export code behaves differently when %SourceControl is defined, so this is typically necessary
/// and always safest.
ClassMethod %SourceControlMethod(
	pMethod,
	pArgs...) As %Status
{
    set tmp = %SourceControl
    new %SourceControl
    if $quit {
        // If called in a way that requires a value to be returned, invoke pMethod in the same way.
        quit $method(tmp, pMethod, pArgs...)
    } else {
        do $method(tmp, pMethod, pArgs...)
    }
}

/// Invoked after zpm "init" to configure settings for this source control class
/// Default implementation is a no-op
ClassMethod Configure() As %Status
{
    quit $$$OK
}

/// Invoked before each lifecycle phase
ClassMethod OnBeforePhase(
	pModule As %IPM.Storage.Module,
	pPhase As %String,
	ByRef pParams) As %Status [ Abstract, Internal ]
{
    quit $$$OK
}

/// Invoked after each lifecycle phase
ClassMethod OnAfterPhase(
	pModule As %IPM.Storage.Module,
	pPhase As %String,
	ByRef pParams) As %Status [ Abstract, Internal ]
{
    quit $$$OK
}

/// Invoked when the list of resources for a module changes.
ClassMethod OnModifyResources(pModule As %IPM.Storage.Module) As %Status [ Abstract, Internal ]
{
    quit $$$OK
}

/// Invoked when an existing module is reloaded from a different directory than its known module root
ClassMethod OnChangeModuleRoot(pModule As %IPM.Storage.Module) As %Status
{
    quit $$$OK
}

/// Invoked when the user has attempted to edit a module document reported by the active Studio extension as read-only (i.e., because it is not checked out)
ClassMethod OnMakeModuleEditable(pModule As %IPM.Storage.Module) As %Status
{
    quit $$$OK
}

/// Invoked before build process runs
ClassMethod OnBeforeBuild(pIsDev As %Boolean) As %Status
{
    quit $$$OK
}

/// Invoked after build process runs
ClassMethod OnAfterBuild(
	pIsDev As %Boolean,
	pSuccessful As %Boolean) As %Status
{
    quit $$$OK
}

}
