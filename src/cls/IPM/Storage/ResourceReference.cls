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
Property UniqueName As %String(MAXLEN = 255, XMLPROJECTION = "NONE") [ Calculated, SqlComputeCode = {set {*} = $case({OverrideName},"":{Name},$char(0):"",:{OverrideName})}, SqlComputed ];

/// Overridden unique identifier for this resource; provided by resource processor classes.
Property OverrideName As %String(MAXLEN = 255, XMLPROJECTION = "NONE");

/// Array where key = name of child, value = ""
Property Children As array Of %String(MAXLEN = 1, XMLPROJECTION = "NONE");

Index Children On Children(KEYS);

Method ProcessorGet() As %IPM.ResourceProcessor.Abstract
{
    // Similar to LifecycleGet in Module.
    if $isobject(r%Processor) {
        quit r%Processor
    }
    set tProcessorClass = ..ProcessorClass
    if (tProcessorClass '= "") && '$$$comClassDefined(tProcessorClass) && $$$comClassDefined($$$DefaultProcessorPackageDot_tProcessorClass) {
        set tProcessorClass = $$$DefaultProcessorPackageDot_tProcessorClass
    }
    if (tProcessorClass = "") {
        // Default class for resource extension
        set tProcessorClass = ..Module.Lifecycle.GetDefaultResourceProcessor(..Name)
    }
    if (tProcessorClass = "") || '$$$comClassDefined(tProcessorClass) {
        quit $$$NULLOREF
    }
    set r%Processor = $classmethod(tProcessorClass,"%New",$this)
    quit r%Processor
}

Method ProcessorClassGet() As %String
{
    quit $replace(i%ProcessorClass, $$$DefaultProcessorPackageDot, "")
}

Method OverrideNameGet() As %String
{
    if $isobject(..Processor) {
        // This method may leave tName undefined (the default implementation, actually)
        do ..Processor.OnGetUniqueName(.tName)
    }
    if '$data(tName) {
        // Default
        set tName = $case($extract(..Name),
            "/":$char(0),
            :"")
    }
    quit tName
}

/// helper for <method>ResolveChildren</method>
ClassMethod GetChildren(
	pResourceName As %String,
	pModuleName As %String,
	pCheckModuleOwnership As %Boolean = 1,
	ByRef pResourceInfoArray,
	Output pResourceArray) As %Status
{
    set tSC = $$$OK
    try {
        kill pResourceArray
        if ($piece(pResourceName,".",*) = "PKG") {
            set tPackage = $piece(pResourceName,".",1,*-1)_"."

            if pCheckModuleOwnership {
                // Build a cache of known packages and classes (within the given package) owned by other modules,
                // or of individual classes within the package listed separately within the same module.
                set tCacheResult = ##class(%SQL.Statement).%ExecDirect(,
                    "select UniqueName from %IPM_Storage.ResourceReference "_
                    "where UniqueName != ? and UniqueName %STARTSWITH ?",
                    pResourceName, tPackage)
                if (tCacheResult.%SQLCODE < 0) {
                    set tSC = $$$ERROR($$$SQLCode,tCacheResult.%SQLCODE,tCacheResult.%Message)
                    quit
                }
                while tCacheResult.%Next(.tSC) {
                    $$$ThrowOnError(tSC)
                    set tResourceCache($$$lcase(tCacheResult.%Get("UniqueName"))) = ""
                }
            }
            // include hidden files by temporarily enable showHidden global for Studio search
            set tHidden = $get(^%SYS("Studio", "ShowHidden"), $char(0))
            set ^%SYS("Studio","ShowHidden") = 1
            // PKG extension should only cover .CLS files
            set tFilesResult = ##class(%SQL.Statement).%ExecDirect(,
                "select Name from  %Library.RoutineMgr_StudioOpenDialog(?,'',1,1,1,0,0)",
                tPackage_"*.cls,"_tPackage_"*.mac,"_tPackage_"*.int,"_tPackage_"*.inc")
            if (tFilesResult.%SQLCODE < 0) {
                set tSC = $$$ERROR($$$SQLCode,tFilesResult.%SQLCODE,tFilesResult.%Message)
                quit
            }
            while tFilesResult.%Next(.tSC) {
                if $$$ISERR(tSC) {
                    quit
                }

                set tFileName = tFilesResult.%Get("Name")
                continue:tFileName="IPM.Installer.cls"
                set tName = $piece(tFileName, ".", 1, *-1)
                set tDeployedClass = -1
                set tCheckName = tFileName
                if $$$lcase($piece(tFileName,".",*))="cls" {
                      set tDeployedClass = $$$defClassKeyGet(tName, $$$cCLASSdeployed)
                      if (tDeployedClass=2) {
                        set tCheckName = $$$defClassKeyGet(tName,$$$cCLASSgeneratedby)
                      }
                }

                if pCheckModuleOwnership {
                    // Skip resources owned by other modules (using cache).
                    if $data(tResourceCache($$$lcase(tCheckName))) {
                        continue
                    }
                    set tFoundInPackage = 0
                    for tSegment = $length(tCheckName,".")-2:-1:1 {
                        if $data(tResourceCache($$$lcase($piece(tCheckName,".",1,tSegment)_".PKG"))) {
                            set tFoundInPackage = 1
                            quit
                        }
                    }
                    if (tFoundInPackage) {
                        continue
                    }
                }

                merge pResourceArray(tFileName) = pResourceInfoArray
                if (tDeployedClass = 2) {
                    // Flag stub classes as generated, overriding the setting on the associated package.
                    // An example of this is %IPM.Storage.ResourceReferenceAttributes,
                    // which is generated by %IPM.Storage.ResourceReference.
                    // Opening the class definition results in the error:
                    // "ERROR #5360: Class '%IPM.Storage.ResourceReferenceAttributes' is a stub name and can not be opened"
                    // Note that a class having "GeneratedBy" set is not sufficient to automatically say that it is "generated" for package manager
                    // purposes, as such classes may legitimately be checked in under some circumstances.
                    set pResourceArray(tFileName,"Generated") = 1
                }
            }
            if $$$ISERR(tSC) {
                quit
            }
        } else {
            if pResourceName '= "" {
                merge pResourceArray(pResourceName) = pResourceInfoArray
            }

            // For consistency with Package behavior, list any generated stub classes as generated
            if ($piece(pResourceName,".",*) = "CLS") {
                set tClassName = $piece(pResourceName,".",1,*-1)
                if (tClassName '= "") {
                    // Start searching at the classname itself
                    set tStubClassKey = ""
                    for {
                        set tStubClassKey = $$$comMemberNext(tClassName,$$$cCLASSclasses,tStubClassKey)
                        if (tStubClassKey = "") {
                            quit
                        }
                        merge pResourceArray(tStubClassKey) = pResourceInfoArray
                        set pResourceArray(tStubClassKey,"Generated") = 1
                    }
                }
            }
        }
    } catch tException {
        set tSC = tException.AsStatus()
    }
    if $data(tHidden) {
        if (tHidden = $char(0)) {
            kill ^%SYS("Studio", "ShowHidden")
        } else {
            set ^%SYS("Studio", "ShowHidden") = tHidden
        }
    }
    quit tSC
}

/// Updates <property>Children</property> to the contents of <var>pChildren</var>. <br />
/// @Argument	pChildren			comma delimited string of Studio document names that are contained in this resource
Method UpdateChildrenFromString(pChildren As %String)
{
    // Ensure that we don't try to update mappings each time a resource's children are updated.
    new $$$ZPMDeferModifyResources
    set $$$ZPMDeferModifyResources = 1
    $$$ThrowOnError(..Children.Clear())
    set tList = $listfromstring(pChildren)
    set tPtr = 0
    while $listnext(tList, tPtr, tChildName) {
        $$$ThrowOnError(..Children.SetAt("", tChildName))
    }
    $$$ThrowOnError(..%Save(0))
}

/// Returns true if the resource is in scope for the current module lifecycle operation.
/// May also be used to test if the resource's scope matches the current phase.
Method IsInScope(
	pCurrentPhase As %String = "",
	Output pInCurrentPhase As %Boolean = 0) As %Boolean
{
    if (..Scope = "") {
        quit 1
    }

    set tScopeLower = $zconvert(..Scope,"L")
    if (tScopeLower = $zconvert(pCurrentPhase,"L")) {
        set pInCurrentPhase = 1
        quit 1
    }

    set tPhaseLower = ""
    set tPointer = 0
    set tInScope = 0
    while $listnext(..Module.Lifecycle.PhaseList,tPointer,tPhase) {
        if ($zconvert(tPhase,"L") = tScopeLower) {
            set tInScope = 1
            quit
        }
    }
    quit tInScope
}

/// Returns an array of resources composing this resource, with the names as subscripts of <var>pResourceArray</var>.
/// If <var>pCheckModuleOwnership</var> is 0 (the default is 1), for .PKG resources, all classes in the package will
/// be included (even if they are actually part of another module).
Method ResolveChildren(
	ByRef pResourceArray,
	pCheckModuleOwnership As %Boolean = 1) As %Status
{
    set tSC = $$$OK
    try {
        // all child classes start with the same array of resource-related info; pre-build it and pass in

        set tArrayRepresentation = ..Module.Name
        set tArrayRepresentation("Processor") = ..Processor
        set tArrayRepresentation("Generated") = ..Generated
        set tArrayRepresentation("Preload") = ..Preload
        set tArrayRepresentation("Scope") = ..Scope
        set tArrayRepresentation("Deploy") = ..Deploy

        set tSC = ..GetChildren(..Name, ..Module.Name, pCheckModuleOwnership, .tArrayRepresentation, .tResourceArray)
        if $$$ISERR(tSC) {
            quit
        }

        // now add further info based on the processor object
        if $isobject(..Processor) {
            set tSC = ..Processor.OnResolveChildren(.tResourceArray, pCheckModuleOwnership)
            if $$$ISERR(tSC) {
                quit
            }
        }

        merge pResourceArray = tResourceArray
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// For performance reasons, this should be used rather than <method>ResourceNameExists</method>.
ClassMethod NonNullResourceNameExists(
	pResourceName As %String,
	Output pID As %Integer = "") As %Boolean
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
    if SQLCODE = 100 {
        &sql(SELECT ResourceReference INTO :pID FROM %IPM_Storage.ResourceReference_Children WHERE element_key = :pResourceName)
    }
    quit $case(SQLCODE,0:1,:0)
}

/// For performance reasons, this should be used rather than <method>ResourceNameOpen</method>.
ClassMethod NonNullResourceNameOpen(
	pResourceName As %String,
	pConcurrency As %Integer = -1,
	Output pSC As %Status = {$$$OK}) As %IPM.Storage.ResourceReference
{
    // ResourceNameOpen is generated as:
    /*
    zResourceNameOpen(K1,concurrency=-1,sc) public { Set:'($data(sc)#2) sc=1
     i ..ResourceNameExists(K1,.id){ s return=..%OpenId(id,concurrency,.sc) } Else { s sc=$$Error^%apiOBJ(5770,"ResourceName",K1),return="" }
     QUIT return }
    */
    if ..NonNullResourceNameExists(pResourceName,.tID) {
        set tResult = ..%OpenId(tID,pConcurrency,.pSC)
    } else {
        set pSC = $$$ERROR($$$KeyValueNotFoundOpen,"ResourceName",pResourceName)
        set tResult = $$$NULLOREF
    }
    quit tResult
}

ClassMethod GetStatus(
	InternalName As %String,
	Output pReferenced As %Boolean,
	Output pEditable As %Boolean,
	Output pSourceModuleName As %String,
	Output pMessage As %String) As %Status
{
    set tSC = $$$OK
    set pReferenced = 0
    set pEditable = 1
    set pSourceModuleName = ""
    set pMessage = ""
    try {
        // Special case: module itself
        if ($piece(InternalName,".",*) = "ZPM") {
            set tName = $piece(InternalName,".",1,*-1)
            if ##class(%IPM.Storage.Module).NameExists(tName) {
                set tModule = ##class(%IPM.Storage.Module).NameOpen(tName,,.tSC)
                if $$$ISERR(tSC) {
                    quit
                }
                set pReferenced = 1
                set pEditable = 1 //Still allow editing
                if tModule.IsLocked() {
                    set pMessage = $$$FormatText("WARNING: Module '%1' is not installed in developer mode and should not be modified.", tName)
                }
            }
            quit
        }

        // Otherwise, we're dealing with an actual resource reference.
        set tRef = ""
        if ..ResourceNameExists(InternalName) {
            set tRef = ..ResourceNameOpen(InternalName,,.tSC)
        } elseif ($piece(InternalName,".",*) = "CLS") {
            // Classes may be included by package.
            for i=$length(InternalName,".")-2:-1:1 {
                set tPackage = $piece(InternalName,".",1,i)_".PKG"
                if ..ResourceNameExists(tPackage) {
                    set tRef = ..ResourceNameOpen(tPackage,,.tSC)
                    quit
                }
            }
        }
        if $$$ISERR(tSC) || (tRef = $$$NULLOREF) {
            quit
        }

        set pReferenced = 1
        set pEditable = 'tRef.Module.IsLocked()
        set pSourceModuleName = tRef.Module.Name
        if tRef.Module.IsLocked() {
            set pMessage = $$$FormatText("Module '%1' has not been loaded/installed in development mode, so its resources may not be modified.", tRef.Module.Name)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
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
    set tSC = $$$OK
    try {
        // Ensure OverrideName is set (if needed).
        set ..OverrideName = ..OverrideNameGet()

        // Normalize resource extension for server resources - should always be upper case.
        if (..ProcessorClass '= "FileCopy") {
            if ($extract(..Name) '= "/") {
                set tExt = $piece(..Name,".",*)
                set ..Name = $piece(..Name,".",1,*-1)_"."_$zconvert($piece(..Name,".",*),"U")
            }
        }

        // See if resource already exists as part of a different module.
        if ..NonNullResourceNameExists(..UniqueName,.tExistingID) && (tExistingID '= ..%Id()) {
            set tOtherInstance = ..%OpenId(tExistingID,,.tSC)
            if $$$ISERR(tSC) {
                quit
            }
            if (tOtherInstance.Module.Name = ..Module.Name) {
                set tMsg = $$$FormatText("Resource '%1' is listed more than once in module '%2'",..Name,..Module.Name)
            } else {
                set tMsg = $$$FormatText("Resource '%1' is explicitly part of module '%2', and cannot also be in module '%3'",..Name,tOtherInstance.Module.Name,..Module.Name)
            }
            set tSC = $$$ERROR($$$GeneralError,tMsg)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Trigger OnChange [ Event = INSERT/UPDATE, Foreach = row/object, Time = AFTER ]
{
    new tModule,tSC,tEx
    set tSC = $$$OK
    try {
        if $data($$$ZPMDeferModifyResources) {
            quit
        }
        set tModule = ##class(%IPM.Storage.Module).%OpenId({ModuleItem},,.tSC)
        if $$$ISERR(tSC) {
            quit
        }

        // TODO: Defer somehow, for the event of multiple changes to the same module's resources being %Save'd at the same time??
        set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnModifyResources(tModule)
    } catch tEx {
        set tSC = tEx.AsStatus()
    }
    if $$$ISERR(tSC) {
        set %ok = 0
        set %msg = $system.Status.GetErrorText(tSC)
    }
}

Method GetSortKey() As %String
{
    if $extract(..Name) = "/" {
        // CSP/other filesystem resources go last.
        // These may not be uniquely named (!), so add the current OREF as an integer.
        quit "9_"_..Name_"_"_(+$this)
    }
    set tName = $piece(..Name,".",1,*-1)
    set tExtension = $piece(..Name,".",*)

    // Packages/classes first (alphabetically and possibly intermixed)
    // Then routines (alphabetically)
    // Then includes (alphabetically)
    // Then everything else, in alphabetical order by extension and then by name.
    set tPrefix = $case(tExtension,
        "PKG":"1",
        "CLS":"1",
        "MAC":"2",
        "INC":"3",
        :"4_"_tExtension)

    // Distinguish resources with names of a common sort order, but different extensions
    set tSuffix = $case(tExtension,
        "CLS":"_CLS",
        "PKG":"_PKG",
        :"")

    quit tPrefix_"_"_tName_tSuffix
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
