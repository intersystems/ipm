Class %IPM.ResourceProcessor.Copy Extends %IPM.ResourceProcessor.AbstractCompilable
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Resource processor to copy the specified resource from the (Source) database to the target namespace (respecting mappings configured for that namespace) during the Reload phase.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Source,Overwrite,CompileAfter,Flags";

/// Name of the namespace we are copying the resources from
Property Source As %String [ Required ];

/// If set to false (default is true), resources that already exist in the current/target namespace will not be overwritten.
Property Overwrite As %Boolean [ InitialExpression = 1 ];

/// Namespace to which the resources will be copied (managed internally)
Property Target As %String [ Private ];

/// Cache of resources discovered in the target namespace
Property TargetResourceCache As %String [ MultiDimensional, Private, Transient ];

Method TargetSet(%val) As %Status
{
    if (..Target '= %val) {
        kill ..TargetResourceCache
    }
    set i%Target = %val
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    // Copy specified resources from the Source namespace to current namespace
    set tSC = $$$OK
    new $namespace
    try {
        if (pPhase="Reload") {
            set tQuals = $select($get(pParams("Verbose")):"/display",1:"/nodisplay")
            set tFileName = ##class(%File).TempFilename("xml")
            set ..Target = $namespace
            set $namespace = ..Source
            if (..Target = ..Source) {
                // no-op
                quit
            }
            // Call ResolveChildren with second arg 0 to ignore module ownership
            // for classes/subpackages within .PKG resources.
            $$$ThrowOnError(..ResourceReference.ResolveChildren(.tResourceArray, 0))
            if '..Overwrite {
                set $namespace = ..Target
                set tKey = ""
                for {
                    set tKey = $order(tResourceArray(tKey))
                    quit:tKey=""

                    if ##class(%Library.RoutineMgr).Exists(tKey) {
                        kill tResourceArray(tKey)
                    }
                }
                set $namespace = ..Source
            }
            if $data(tResourceArray) {
                $$$ThrowOnError($system.OBJ.Export(.tResourceArray,tFileName,tQuals))
                set $namespace = ..Target
                $$$ThrowOnError($system.OBJ.Load(tFileName,"/nocompile/checkuptodate"_tQuals))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    if (pPhase = "Compile") && (..Source = $namespace) {
        // No need to compile the resource if we're already in the right namespace.
        set pResourceHandled = 1
    }
    quit $$$OK
}

Method OnResolveChildren(
	ByRef pResourceArray,
	pCheckModuleOwnership As %Boolean) As %Status
{
    // For each child detected, see if the individual class or any more granular package containing is part of any module. If so, clear it from the array of child resources.
    // Otherwise, indicate that the resource is generated (meaning "do not attempt to load/export").

    set tSC = $$$OK

    // When called from OnAfterPhase, compare against resources/modules present in the target namespace.
    new $namespace
    set $namespace = ..Target
    try {
        set tKey = ""
        for {
            set tKey = $order(pResourceArray(tKey))
            if (tKey = "") {
                quit
            }

            if (tKey = ..ResourceReference.Name) {
                set pResourceArray(tKey,"Generated") = 1
                continue
            }

            set tSourceName = $piece(..ResourceReference.Name,".",*-1)
            set tName = $piece(tKey,".",1,*-1)
            set tExt = $piece(tKey,".",*)

            // Check cache first (for common packages)
            if $data(..TargetResourceCache(tKey)) {
                kill pResourceArray(tKey)
                continue
            } elseif (tExt = "CLS") {
                for i=$length(tName,".")-1:-1:1 {
                    set tPackageKey = $piece(tName,".",1,i)_".PKG"
                    if (tPackageKey = ..ResourceReference.Name) {
                        quit
                    }

                    if $data(..TargetResourceCache(tPackageKey)) {
                        kill pResourceArray(tKey)
                        continue
                    }
                }
            }

            // Then check persistent records for all modules
            if ##class(%IPM.Storage.ResourceReference).ResourceNameExists(tKey) {
                // Resource exists as part of some module.
                // Don't include it in the copy.
                kill pResourceArray(tKey)
                set ..TargetResourceCache(tKey) = ""
                continue
            } elseif (tExt = "CLS") {
                // See if a subpackage is defined as part of some module.
                // Don't include it in the copy either.
                for i=$length(tName,".")-1:-1:1 {
                    set tPackageKey = $piece(tName,".",1,i)_".PKG"
                    if (tPackageKey = ..ResourceReference.Name) {
                        quit
                    }
                    if ##class(%IPM.Storage.ResourceReference).ResourceNameExists(tPackageKey) {
                        kill pResourceArray(tKey)
                        set ..TargetResourceCache(tPackageKey) = ""
                        quit
                    }
                }
            }

            // If we haven't killed it, indicate that it's generated.
            if $data(pResourceArray(tKey)) {
                set pResourceArray(tKey,"Generated") = 1
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnGetUniqueName(Output pUniqueName)
{
    // Validation occurs elsewhere via SQL.
    set pUniqueName = $char(0)
}

}
