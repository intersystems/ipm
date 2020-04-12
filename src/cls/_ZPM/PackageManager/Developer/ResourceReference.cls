Include %ZPM.PackageManager.Common

Class %ZPM.PackageManager.Developer.ResourceReference Extends (%Persistent, %ZPM.PackageManager.Core.ResourceReference)
{

/// Name index is unique per namespace.
Index ResourceName On UniqueName [ Unique ];

Relationship Module As %ZPM.PackageManager.Developer.Module(XMLPROJECTION = "NONE") [ Cardinality = parent, Inverse = Resources ];

/// Restrict the scope in which this resource is included. Default is "all scopes"
Property Scope As %String(VALUELIST = ",test,verify", XMLPROJECTION = "ATTRIBUTE");

/// Specify if this resource is from reload directory
Property Preload As %Boolean(XMLPROJECTION = "ATTRIBUTE");

/// Specify if this resource is generated. A generated resource will not be loaded nor exported by lifecycle methods
Property Generated As %Boolean(XMLPROJECTION = "ATTRIBUTE");

/// Additional name-value pairs related to this resource
/// May be referred to in lifecycle methods
Property Attributes As array Of %String(MAXLEN = "", XMLKEYNAME = "Name", XMLNAME = "Attribute", XMLPROJECTION = "ELEMENT");

/// Specifies a class that handles lifecycle events for this resource
/// Typically only applicable to directory/file resources
Property ProcessorClass As %Dictionary.CacheClassname(XMLPROJECTION = "ATTRIBUTE");

/// Transient instance of ProcessorClass
Property Processor As %ZPM.PackageManager.Developer.Processor.Abstract(XMLPROJECTION = "NONE") [ Transient ];

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

Method ProcessorGet() As %ZPM.PackageManager.Developer.Processor.Abstract
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

Method ResolveChildren(ByRef pResourceArray) As %Status
{
	Set tSC = $$$OK
	Try {
		If ($Piece(..Name,".",*) = "PKG") {
			Set tPackage = $Piece(..Name,".",1,*-1)_"."
			
			// Build a cache of known packages and classes (within the given package) owned by other modules.
			Set tCacheResult = ##class(%SQL.Statement).%ExecDirect(,
				"select UniqueName from %ZPM_PackageManager_Developer.ResourceReference "_
				"where ""Module""->Name != ? "_
				"and UniqueName %STARTSWITH ?",
				..Module.Name, tPackage)
			If (tCacheResult.%SQLCODE < 0) {
				Set tSC = $$$ERROR($$$SQLCode,tCacheResult.%SQLCODE,tCacheResult.%Message)
				Quit
			}
			While tCacheResult.%Next(.tSC) {
				$$$ThrowOnError(tSC)
				Set tResourceCache(tCacheResult.%Get("UniqueName")) = ""
			}
			
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
				
				// Skip resources owned by other modules (using cache).
				If $Data(tResourceCache(tFileName)) {
					Continue
				}
				Set tFoundInPackage = 0
				For i=$Length(tFileName,".")-2:-1:1 {
					If $Data(tResourceCache($Piece(tFileName,".",1,i)_".PKG")) {
						Set tFoundInPackage = 1
						Quit
					}
				}
				If (tFoundInPackage) {
					Continue
				}
				
				Set tResourceArray(tFileName) = ..Module.Name
				Set tResourceArray(tFileName,"Processor") = ..Processor
				Set tResourceArray(tFileName,"Generated") = ..Generated
				Set tResourceArray(tFileName,"Preload") = ..Preload
				Set tResourceArray(tFileName,"Scope") = ..Scope
				Set tResourceArray(tFileName,"Deploy") = ..Deploy
			}
			If $$$ISERR(tSC) {
				Quit
			}
		} ElseIf (..Name [ "*") {
			Set tRS = ##class(%RoutineMgr).StudioOpenDialogFunc(..Name)
			If (tRS.%SQLCODE < 0) {
				Set tSC = $$$ERROR($$$SQLCode, tRS.%SQLCODE, tRS.%Message)
				Quit
			}
			While tRS.%Next(.tSC) {
				Set tName = tRS.Name
				Set tResourceArray(tName) = ..Module.Name
				Set tResourceArray(tName,"Processor") = ..Processor
				Set tResourceArray(tName,"Generated") = ..Generated
				Set tResourceArray(tName,"Preload") = ..Preload
				Set tResourceArray(tName,"Scope") = ..Scope
				Set tResourceArray(tName,"Deploy") = ..Deploy
			}

			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set tResourceArray(..Name) = ..Module.Name
			Set tResourceArray(..Name,"Processor") = ..Processor
			Set tResourceArray(..Name,"Generated") = ..Generated
			Set tResourceArray(..Name,"Preload") = ..Preload
			Set tResourceArray(..Name,"Scope") = ..Scope
			Set tResourceArray(..Name,"Deploy") = ..Deploy
		}
		
		If $IsObject(..Processor) {
			Set tSC = ..Processor.OnResolveChildren(.tResourceArray)
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

ClassMethod GetStatus(InternalName As %String, Output pReferenced As %Boolean, Output pEditable As %Boolean, Output pSourceModuleName As %String) As %Status
{
	Set tSC = $$$OK
	Set pReferenced = 0
	Set pEditable = 1
	Try {
		// Special case: module itself
		If ($Piece(InternalName,".",*) = "MODULE") {
			Set tName = $Piece(InternalName,".",1,*-1)
			If ##class(%ZPM.PackageManager.Developer.Module).NameExists(tName) {
				Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tName,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
				Set pReferenced = 1
				Set pEditable = 'tModule.IsLocked()
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
		Set pEditable = 'tRef.Module.IsLocked()
		Set pSourceModuleName = tRef.Module.Name
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
	// Ensure OverrideName is set (if needed).
	Set ..OverrideName = ..OverrideNameGet()
	
	// Normalize resource extension for server resources - should always be upper case.
	If ($Extract(..Name) '= "/") && (..Name [ ".") {
		Set tExt = $Piece(..Name,".",*)
		Set ..Name = $Piece(..Name,".",1,*-1)_"."_$ZConvert($Piece(..Name,".",*),"U")
	}
	Quit $$$OK
}

Trigger OnChange [ Event = INSERT/UPDATE, Foreach = row/object, Time = AFTER ]
{
	New tModule,tSC,tEx
	Set tSC = $$$OK
	Try {
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).%OpenId({Module},,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
	} Catch tEx {
		Set tSC = tEx.AsStatus()
	}
	If $$$ISERR(tSC) {
		Set %ok = 0
		Set %msg = $System.Status.GetErrorText(tSC)
	}
}

Storage Default
{
<Data name="Attributes">
<Attribute>Attributes</Attribute>
<Structure>subnode</Structure>
<Subscript>"Attributes"</Subscript>
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
</Data>
<DataLocation>{%%PARENT}("Resources")</DataLocation>
<DefaultData>ResourceReferenceDefaultData</DefaultData>
<IdLocation>^ZPM.Dev.ModuleC("Resources")</IdLocation>
<IndexLocation>^ZPM.Dev.ResourceI</IndexLocation>
<StreamLocation>^ZPM.Dev.ResourceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
