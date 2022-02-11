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
	If (..Target '= %val) {
		Kill ..TargetResourceCache
	}
	Set i%Target = %val
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	// Copy specified resources from the Source namespace to current namespace
	Set tSC = $$$OK
	New $Namespace
	Try {
		If pPhase="Reload" {
			Set tQuals = $Select($g(pParams("Verbose")):"/display",1:"/nodisplay")
			Set tFileName = ##class(%File).TempFilename("xml")
			Set ..Target = $Namespace
			Set $Namespace = ..Source
			If (..Target = ..Source) {
				// no-op
				Quit
			}
			// Call ResolveChildren with second arg 0 to ignore module ownership
			// for classes/subpackages within .PKG resources.
			$$$ThrowOnError(..ResourceReference.ResolveChildren(.tResourceArray, 0))
			If '..Overwrite {
				Set $Namespace = ..Target
				Set tKey = ""
				For {
					Set tKey = $Order(tResourceArray(tKey))
					Quit:tKey=""
					
					If ##class(%Library.RoutineMgr).Exists(tKey) {
						Kill tResourceArray(tKey)
					}
				}
				Set $Namespace = ..Source
			}
			If $Data(tResourceArray) {
				$$$ThrowOnError($System.OBJ.Export(.tResourceArray,tFileName,tQuals))
				Set $Namespace = ..Target
		        $$$ThrowOnError($System.OBJ.Load(tFileName,"/nocompile/checkuptodate"_tQuals))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
	If (pPhase = "Compile") && (..Source = $Namespace) {
		// No need to compile the resource if we're already in the right namespace.
		Set pResourceHandled = 1
	}
	Quit $$$OK
}

Method OnResolveChildren(ByRef pResourceArray, pCheckModuleOwnership As %Boolean) As %Status
{
	// For each child detected, see if the individual class or any more granular package containing is part of any module. If so, clear it from the array of child resources.
	// Otherwise, indicate that the resource is generated (meaning "do not attempt to load/export").
	
	Set tSC = $$$OK
	
	// When called from OnAfterPhase, compare against resources/modules present in the target namespace.
	New $Namespace
	Set $Namespace = ..Target
	Try {
		Set tKey = ""
		For {
			Set tKey = $Order(pResourceArray(tKey))
			If (tKey = "") {
				Quit
			}
			
			If (tKey = ..ResourceReference.Name) {
				Set pResourceArray(tKey,"Generated") = 1
				Continue
			}
			
			Set tSourceName = $Piece(..ResourceReference.Name,".",*-1)
			Set tName = $Piece(tKey,".",1,*-1)
			Set tExt = $Piece(tKey,".",*)
			
			// Check cache first (for common packages)
			If $Data(..TargetResourceCache(tKey)) {
				Kill pResourceArray(tKey)
				Continue
			} ElseIf (tExt = "CLS") {
				For i=$Length(tName,".")-1:-1:1 {
					Set tPackageKey = $Piece(tName,".",1,i)_".PKG"
					If (tPackageKey = ..ResourceReference.Name) {
						Quit
					}
					
					If $Data(..TargetResourceCache(tPackageKey)) {
						Kill pResourceArray(tKey)
						Continue
					}
				}
			}
			
			// Then check persistent records for all modules
			If ##class(%IPM.Storage.ResourceReference).ResourceNameExists(tKey) {
				// Resource exists as part of some module.
				// Don't include it in the copy.
				Kill pResourceArray(tKey)
				Set ..TargetResourceCache(tKey) = ""
				Continue
			} ElseIf (tExt = "CLS") {
				// See if a subpackage is defined as part of some module.
				// Don't include it in the copy either.
				For i=$Length(tName,".")-1:-1:1 {
					Set tPackageKey = $Piece(tName,".",1,i)_".PKG"
					If (tPackageKey = ..ResourceReference.Name) {
						Quit
					}
					If ##class(%IPM.Storage.ResourceReference).ResourceNameExists(tPackageKey) {
						Kill pResourceArray(tKey)
						Set ..TargetResourceCache(tPackageKey) = ""
						Quit
					}
				}
			}
			
			// If we haven't killed it, indicate that it's generated.
			If $Data(pResourceArray(tKey)) {
				Set pResourceArray(tKey,"Generated") = 1
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnGetUniqueName(Output pUniqueName)
{
	// Validation occurs elsewhere via SQL.
	Set pUniqueName = $c(0)
}

}
