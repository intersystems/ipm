Include %IPM.Common

Class %IPM.Storage.ResourceReference Extends (%Persistent, %XML.Adaptor, %IPM.Utils.ComparisonAdaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ResourceReference";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

// Property Name As %IPM.DataType.ResourceName(XMLPROJECTION = "attribute") [ Required ];

Property Name As %String(MAXLEN = 255, XMLPROJECTION = "attribute") [ Required ];

/// Name index is unique per namespace.
Index ResourceName On UniqueName [ Unique ];

Relationship Module As %IPM.Storage.Module(XMLPROJECTION = "NONE") [ Cardinality = parent, Inverse = Resources, SqlFieldName = ModuleItem ];

/// Restrict the scope in which this resource is included. Default is "all scopes"
Property Scope As %String(VALUELIST = ",test,verify", XMLPROJECTION = "ATTRIBUTE");

/// Specify if this resource is from reload directory
Property Preload As %Boolean(XMLPROJECTION = "ATTRIBUTE");

/// Specify if this resource is generated. A generated resource will not be loaded nor exported by lifecycle methods
Property Generated As %Boolean(XMLPROJECTION = "ATTRIBUTE");

/// Additional name-value pairs related to this resource
/// May be referred to in lifecycle methods
Property Attributes As array Of %String(MAXLEN = "", XMLKEYNAME = "Name", XMLNAME = "Attribute", XMLNIL = 0, XMLPROJECTION = "ELEMENT");

/// Specifies a class that handles lifecycle events for this resource
/// Typically only applicable to directory/file resources
Property ProcessorClass As %Dictionary.Classname(XMLPROJECTION = "ATTRIBUTE");

/// Transient instance of ProcessorClass
Property Processor As %IPM.ResourceProcessor.Abstract(XMLPROJECTION = "NONE") [ Transient ];

/// If set to true, this source code is not shipped in application packaging.
/// (Of course, it must be included in module packaging.)
Property Deploy As %Boolean(XMLPROJECTION = "ATTRIBUTE");

/// Unique identifier for the resource.
/// For most typical resources (classes, include files, etc.) this is set to the resource name.
/// For resources starting with /, this is set to "" by default (indicating "not required to be unique").
/// If a resource processor class is defined, this name can be customized via the OnGetUniqueName method, and override the above behaviors (via <property>OverrideName</property>)
Property UniqueName As %String(MAXLEN = 255, XMLPROJECTION = "NONE") [ Calculated, SqlComputeCode = {Set {*} = $Case({OverrideName},"":{Name},$c(0):"",:{OverrideName})}, SqlComputed ];

/// Overridden unique identifier for this resource; provided by resource processor classes.
Property OverrideName As %String(MAXLEN = 255, XMLPROJECTION = "NONE");

/// Array where key = name of child, value = ""
Property Children As array Of %String(MAXLEN = 1, XMLPROJECTION = "NONE");

Index Children On Children(KEYS);

Method ProcessorGet() As %IPM.ResourceProcessor.Abstract
{
	// Similar to LifecycleGet in Module.
	If $IsObject(r%Processor) {
		Quit r%Processor
	}
	Set tProcessorClass = ..ProcessorClass
	If (tProcessorClass '= "") && '$$$comClassDefined(tProcessorClass) && $$$comClassDefined($$$DefaultProcessorPackageDot_tProcessorClass) {
		Set tProcessorClass = $$$DefaultProcessorPackageDot_tProcessorClass
	}
	If (tProcessorClass = "") {
		// Default class for resource extension
		Set tProcessorClass = ..Module.Lifecycle.GetDefaultResourceProcessor(..Name)
	}
	If (tProcessorClass = "") || '$$$comClassDefined(tProcessorClass) {
		Quit $$$NULLOREF
	}
	Set r%Processor = $ClassMethod(tProcessorClass,"%New",$this)
	Quit r%Processor
}

Method ProcessorClassGet() As %String
{
	Quit $Replace(i%ProcessorClass, $$$DefaultProcessorPackageDot, "")
}

Method OverrideNameGet() As %String
{
	If $IsObject(..Processor) {
		// This method may leave tName undefined (the default implementation, actually)
		Do ..Processor.OnGetUniqueName(.tName)
	}
	If '$Data(tName) {
		// Default
		Set tName = $Case($Extract(..Name),
			"/":$c(0),
			:"")
	}
	Quit tName
}

/// helper for <method>ResolveChildren</method>
ClassMethod GetChildren(pResourceName As %String, pModuleName As %String, pCheckModuleOwnership As %Boolean = 1, ByRef pResourceInfoArray, Output pResourceArray) As %Status
{
	Set tSC = $$$OK
	Try {
		Kill pResourceArray
		If ($Piece(pResourceName,".",*) = "PKG") {
			Set tPackage = $Piece(pResourceName,".",1,*-1)_"."
			
			If pCheckModuleOwnership {
				// Build a cache of known packages and classes (within the given package) owned by other modules,
				// or of individual classes within the package listed separately within the same module.
				Set tCacheResult = ##class(%SQL.Statement).%ExecDirect(,
					"select UniqueName from %IPM_Storage.ResourceReference "_
					"where UniqueName != ? and UniqueName %STARTSWITH ?",
					pResourceName, tPackage)
				If (tCacheResult.%SQLCODE < 0) {
					Set tSC = $$$ERROR($$$SQLCode,tCacheResult.%SQLCODE,tCacheResult.%Message)
					Quit
				}
				While tCacheResult.%Next(.tSC) {
					$$$ThrowOnError(tSC)
					Set tResourceCache($$$lcase(tCacheResult.%Get("UniqueName"))) = ""
				}
			}
			// include hidden files by temporarily enable showHidden global for Studio search
			Set tHidden = $Get(^%SYS("Studio", "ShowHidden"), $Char(0))
			Set ^%SYS("Studio","ShowHidden") = 1
			// PKG extension should only cover .CLS files
			Set tFilesResult = ##class(%SQL.Statement).%ExecDirect(,
        		"select Name from  %Library.RoutineMgr_StudioOpenDialog(?,'',1,1,1,0,0)",
				tPackage_"*.cls,"_tPackage_"*.mac,"_tPackage_"*.int,"_tPackage_"*.inc")
			If (tFilesResult.%SQLCODE < 0) {
				Set tSC = $$$ERROR($$$SQLCode,tFilesResult.%SQLCODE,tFilesResult.%Message)
				Quit
			}
			While tFilesResult.%Next(.tSC) {
				If $$$ISERR(tSC) {
					Quit
				}
				
        		Set tFileName = tFilesResult.%Get("Name")
        		continue:tFileName="IPM.Installer.cls"
        		Set tName = $Piece(tFileName, ".", 1, *-1)
        		Set tDeployedClass = -1
        		Set tCheckName = tFileName
        		If $$$lcase($Piece(tFileName,".",*))="cls" {
          			Set tDeployedClass = $$$defClassKeyGet(tName, $$$cCLASSdeployed)
          			If (tDeployedClass=2) {
				    	Set tCheckName = $$$defClassKeyGet(tName,$$$cCLASSgeneratedby)
          			}
        		}
				
				If pCheckModuleOwnership {
					// Skip resources owned by other modules (using cache).
					If $Data(tResourceCache($$$lcase(tCheckName))) {
						Continue
					}
					Set tFoundInPackage = 0
					For tSegment = $Length(tCheckName,".")-2:-1:1 {
						If $Data(tResourceCache($$$lcase($Piece(tCheckName,".",1,tSegment)_".PKG"))) {
							Set tFoundInPackage = 1
							Quit
						}
					}
					If (tFoundInPackage) {
						Continue
					}
				}
				
				Merge pResourceArray(tFileName) = pResourceInfoArray
				If (tDeployedClass = 2) {
					// Flag stub classes as generated, overriding the setting on the associated package.
					// An example of this is %IPM.Storage.ResourceReferenceAttributes,
					// which is generated by %IPM.Storage.ResourceReference.
					// Opening the class definition results in the error:
					// "ERROR #5360: Class '%IPM.Storage.ResourceReferenceAttributes' is a stub name and can not be opened"
					// Note that a class having "GeneratedBy" set is not sufficient to automatically say that it is "generated" for package manager
					// purposes, as such classes may legitimately be checked in under some circumstances.
					Set pResourceArray(tFileName,"Generated") = 1
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			If pResourceName '= "" {
				Merge pResourceArray(pResourceName) = pResourceInfoArray
			}
			
			// For consistency with Package behavior, list any generated stub classes as generated
			If ($Piece(pResourceName,".",*) = "CLS") {
				Set tClassName = $Piece(pResourceName,".",1,*-1)
				If (tClassName '= "") {
					// Start searching at the classname itself
					Set tStubClassKey = ""
					For {
						Set tStubClassKey = $$$comMemberNext(tClassName,$$$cCLASSclasses,tStubClassKey)
						If (tStubClassKey = "") {
							Quit
						}
						Merge pResourceArray(tStubClassKey) = pResourceInfoArray
						Set pResourceArray(tStubClassKey,"Generated") = 1
					}
				}
			}
		}
	} Catch tException {
		Set tSC = tException.AsStatus()
	}
	If $Data(tHidden) {
		If (tHidden = $Char(0)) {
			Kill ^%SYS("Studio", "ShowHidden")
		} Else {
			Set ^%SYS("Studio", "ShowHidden") = tHidden
		}
	}
	Quit tSC
}

/// Updates <property>Children</property> to the contents of <var>pChildren</var>. <br />
/// @Argument	pChildren			comma delimited string of Studio document names that are contained in this resource
Method UpdateChildrenFromString(pChildren As %String)
{
	// Ensure that we don't try to update mappings each time a resource's children are updated.
	New $$$ZPMDeferModifyResources
	Set $$$ZPMDeferModifyResources = 1
	$$$ThrowOnError(..Children.Clear())
	Set tList = $ListFromString(pChildren)
	Set tPtr = 0
	While $ListNext(tList, tPtr, tChildName) {
		$$$ThrowOnError(..Children.SetAt("", tChildName))
	}
	$$$ThrowOnError(..%Save(0))
}

/// Returns true if the resource is in scope for the current module lifecycle operation.
/// May also be used to test if the resource's scope matches the current phase.
Method IsInScope(pCurrentPhase As %String = "", Output pInCurrentPhase As %Boolean = 0) As %Boolean
{
	If (..Scope = "") {
		Quit 1
	}
	
	Set tScopeLower = $ZConvert(..Scope,"L")
	If (tScopeLower = $ZConvert(pCurrentPhase,"L")) {
		Set pInCurrentPhase = 1
		Quit 1
	}
	
	Set tPhaseLower = ""
	Set tPointer = 0
	Set tInScope = 0
	While $ListNext(..Module.Lifecycle.PhaseList,tPointer,tPhase) {
		If ($ZConvert(tPhase,"L") = tScopeLower) {
			Set tInScope = 1
			Quit
		}
	}
	Quit tInScope
}

/// Returns an array of resources composing this resource, with the names as subscripts of <var>pResourceArray</var>.
/// If <var>pCheckModuleOwnership</var> is 0 (the default is 1), for .PKG resources, all classes in the package will
/// be included (even if they are actually part of another module).
Method ResolveChildren(ByRef pResourceArray, pCheckModuleOwnership As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		// all child classes start with the same array of resource-related info; pre-build it and pass in
		
		Set tArrayRepresentation = ..Module.Name
		Set tArrayRepresentation("Processor") = ..Processor
		Set tArrayRepresentation("Generated") = ..Generated
		Set tArrayRepresentation("Preload") = ..Preload
		Set tArrayRepresentation("Scope") = ..Scope
		Set tArrayRepresentation("Deploy") = ..Deploy
	
		Set tSC = ..GetChildren(..Name, ..Module.Name, pCheckModuleOwnership, .tArrayRepresentation, .tResourceArray)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// now add further info based on the processor object
		If $IsObject(..Processor) {
			Set tSC = ..Processor.OnResolveChildren(.tResourceArray, pCheckModuleOwnership)
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		Merge pResourceArray = tResourceArray
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// For performance reasons, this should be used rather than <method>ResourceNameExists</method>.
ClassMethod NonNullResourceNameExists(pResourceName As %String, Output pID As %Integer = "") As %Boolean
{
	// ResourceNameExists is generated as:
	/*
	new %ROWCOUNT,SQLCODE,temp
	 ;---&sql(SELECT %ID INTO :id FROM %IPM_Storage.ResourceReference WHERE (:K1 is not null and UniqueName = :K1) OR (:K1 IS NULL AND UniqueName IS NULL))
 	 ;--- ** SQL PUBLIC Variables: %ROWCOUNT, %ROWID, %msg, K1, SQLCODE, id
	do %0do
	Quit $select('SQLCODE:1,1:0)
	*/
	// Because UniqueName may be null (and indeed needs to be in many reasonable cases), this query generates a seriously bogus plan involving a temp table.
	&sql(SELECT %ID INTO :pID FROM %IPM_Storage.ResourceReference WHERE (:pResourceName is not null and UniqueName = :pResourceName))
	If SQLCODE = 100 {
		&sql(SELECT ResourceReference INTO :pID FROM %IPM_Storage.ResourceReference_Children WHERE element_key = :pResourceName)
	}
	Quit $Case(SQLCODE,0:1,:0)
}

/// For performance reasons, this should be used rather than <method>ResourceNameOpen</method>.
ClassMethod NonNullResourceNameOpen(pResourceName As %String, pConcurrency As %Integer = -1, Output pSC As %Status = {$$$OK}) As %IPM.Storage.ResourceReference
{
	// ResourceNameOpen is generated as:
	/*
	zResourceNameOpen(K1,concurrency=-1,sc) public { Set:'($data(sc)#2) sc=1
	 i ..ResourceNameExists(K1,.id){ s return=..%OpenId(id,concurrency,.sc) } Else { s sc=$$Error^%apiOBJ(5770,"ResourceName",K1),return="" }
	 QUIT return }
	*/
	If ..NonNullResourceNameExists(pResourceName,.tID) {
		Set tResult = ..%OpenId(tID,pConcurrency,.pSC)
	} Else {
		Set pSC = $$$ERROR($$$KeyValueNotFoundOpen,"ResourceName",pResourceName)
		Set tResult = $$$NULLOREF
	}
	Quit tResult
}

ClassMethod GetStatus(InternalName As %String, Output pReferenced As %Boolean, Output pEditable As %Boolean, Output pSourceModuleName As %String, Output pMessage As %String) As %Status
{
	Set tSC = $$$OK
	Set pReferenced = 0
	Set pEditable = 1
	Set pSourceModuleName = ""
	Set pMessage = ""
	Try {
		// Special case: module itself
		If ($Piece(InternalName,".",*) = "ZPM") {
			Set tName = $Piece(InternalName,".",1,*-1)
			If ##class(%IPM.Storage.Module).NameExists(tName) {
				Set tModule = ##class(%IPM.Storage.Module).NameOpen(tName,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
				Set pReferenced = 1
				Set pEditable = 1 //Still allow editing
				If tModule.IsLocked() {
					Set pMessage = $$$FormatText("WARNING: Module '%1' is not a snapshot version and should not be modified.", tName)
				}
			}
			Quit
		}
		
		// Otherwise, we're dealing with an actual resource reference.
		Set tRef = ""
		If ..ResourceNameExists(InternalName) {
			Set tRef = ..ResourceNameOpen(InternalName,,.tSC)
		} ElseIf ($Piece(InternalName,".",*) = "CLS") {
			// Classes may be included by package.
			For i=$Length(InternalName,".")-2:-1:1 {
				Set tPackage = $Piece(InternalName,".",1,i)_".PKG"
				If ..ResourceNameExists(tPackage) {
					Set tRef = ..ResourceNameOpen(tPackage,,.tSC)
					Quit
				}
			}
		}
		If $$$ISERR(tSC) || (tRef = $$$NULLOREF) {
			Quit
		}
		
		Set pReferenced = 1
		Set pEditable = 'tRef.Module.IsLocked() && tRef.Module.DeveloperMode
		Set pSourceModuleName = tRef.Module.Name
		If tRef.Module.IsLocked() {
			Set pMessage = $$$FormatText("WARNING: Module '%1' is a released (non-snapshot) version, so its resources may not be modified.", tRef.Module.Name)
		} ElseIf 'tRef.Module.DeveloperMode {
			Set pMessage = $$$FormatText("Module '%1' has not been loaded/installed in development mode, so its resources may not be modified.", tRef.Module.Name)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// This callback method is invoked by the <METHOD>%Save</METHOD> method to 
/// provide notification that the object is being saved. It is called before 
/// any data is written to disk.
/// 
/// <P><VAR>insert</VAR> will be set to 1 if this object is being saved for the first time.
/// 
/// <P>If this method returns an error then the call to <METHOD>%Save</METHOD> will fail.
Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	Try {
		// Ensure OverrideName is set (if needed).
		Set ..OverrideName = ..OverrideNameGet()
		
		// Normalize resource extension for server resources - should always be upper case.
    If (..ProcessorClass '= "FileCopy") { 
      If ($Extract(..Name) '= "/") {
        Set tExt = $Piece(..Name,".",*)
        Set ..Name = $Piece(..Name,".",1,*-1)_"."_$ZConvert($Piece(..Name,".",*),"U")
      }
    }
		
		// See if resource already exists as part of a different module.
		If ..NonNullResourceNameExists(..UniqueName,.tExistingID) && (tExistingID '= ..%Id()) {
			Set tOtherInstance = ..%OpenId(tExistingID,,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
			If (tOtherInstance.Module.Name = ..Module.Name) {
				Set tMsg = $$$FormatText("Resource '%1' is listed more than once in module '%2'",..Name,..Module.Name)
			} Else {
				Set tMsg = $$$FormatText("Resource '%1' is explicitly part of module '%2', and cannot also be in module '%3'",..Name,tOtherInstance.Module.Name,..Module.Name)
			}
			Set tSC = $$$ERROR($$$GeneralError,tMsg)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	
	Quit tSC
}

Trigger OnChange [ Event = INSERT/UPDATE, Foreach = row/object, Time = AFTER ]
{
	New tModule,tSC,tEx
	Set tSC = $$$OK
	Try {
		If $Data($$$ZPMDeferModifyResources) {
			Quit
		}
		Set tModule = ##class(%IPM.Storage.Module).%OpenId({ModuleItem},,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// TODO: Defer somehow, for the event of multiple changes to the same module's resources being %Save'd at the same time??
		Set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnModifyResources(tModule)
	} Catch tEx {
		Set tSC = tEx.AsStatus()
	}
	If $$$ISERR(tSC) {
		Set %ok = 0
		Set %msg = $System.Status.GetErrorText(tSC)
	}
}

Method GetSortKey() As %String
{
	If $Extract(..Name) = "/" {
		// CSP/other filesystem resources go last.
		// These may not be uniquely named (!), so add the current OREF as an integer.
		Quit "9_"_..Name_"_"_(+$This)
	} Else {
		Set tName = $Piece(..Name,".",1,*-1)
		Set tExtension = $Piece(..Name,".",*)
		
		// Packages/classes first (alphabetically and possibly intermixed)
		// Then routines (alphabetically)
		// Then includes (alphabetically)
		// Then everything else, in alphabetical order by extension and then by name.
		Set tPrefix = $Case(tExtension,
			"PKG":"1",
			"CLS":"1",
			"MAC":"2",
			"INC":"3",
			:"4_"_tExtension)
			
		// Distinguish resources with names of a common sort order, but different extensions
		Set tSuffix = $Case(tExtension,
			"CLS":"_CLS",
			"PKG":"_PKG",
			:"")
			
		Quit tPrefix_"_"_tName_tSuffix
	}
}

Storage Default
{
<Data name="Attributes">
<Attribute>Attributes</Attribute>
<Structure>subnode</Structure>
<Subscript>"Attributes"</Subscript>
</Data>
<Data name="Children">
<Attribute>Children</Attribute>
<Structure>subnode</Structure>
<Subscript>"Children"</Subscript>
</Data>
<Data name="ResourceReferenceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Scope</Value>
</Value>
<Value name="4">
<Value>Preload</Value>
</Value>
<Value name="5">
<Value>Generated</Value>
</Value>
<Value name="6">
<Value>ProcessorClass</Value>
</Value>
<Value name="7">
<Value>Deploy</Value>
</Value>
<Value name="8">
<Value>UniqueName</Value>
</Value>
<Value name="9">
<Value>OverrideName</Value>
</Value>
<Value name="10">
<Value>IsAPI</Value>
</Value>
</Data>
<DataLocation>{%%PARENT}("Resources")</DataLocation>
<DefaultData>ResourceReferenceDefaultData</DefaultData>
<IdLocation>^IPM.Storage.ResourceReferenceC("Resources")</IdLocation>
<IndexLocation>^IPM.Storage.ResourceReferenceI</IndexLocation>
<StreamLocation>^IPM.Storage.ResourceReferenceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
