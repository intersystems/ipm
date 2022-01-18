Include (%ZPM.PackageManager.Developer.Annotation, %occErrors)

/// base class for proxy objects representing COS objects for annotations. 
/// This includes objects like Arguments which can be tagged using tags located in the 
/// comment blocks of a parent object (in this case, the argument's method). Therefore our model 
/// operates on the principle that any COS entity can be tagged, but only the subclass CommentableEntity 
/// represents entities with comment blocks (classes, methods, properties, etc.). Those comment blocks 
/// will be processed by the commented entity's proxy but the tags will be associated with the 
/// argument or whatever it is intended to modify. 
Class %ZPM.PackageManager.Developer.Annotation.CosEntity Extends (%Persistent, %XML.Adaptor) [ Abstract ]
{

/// tags that apply to (almost) every COS entity. Package name (%ZPM.PackageManager.Developer.Annotation.Tag) is omitted
Parameter CommonTags = "API.Deprecated,API.Since";

/// tags that apply to the current entity, in addition to the universal ones (see CommonTags)
Parameter AcceptableAnchorTags;

/*
/// the "Tags" relationship should have an "OnDelete = cascade" setting on the AnchorTag side, but this doesn't 
/// work because both classes are abstract (?). Therefore we tried a trigger but this doesn't work either. see prodlog 148120
*/
Relationship Tags As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag(XMLIO = "IN", XMLPROJECTION = "element", XMLTYPECONSTRAINT = "choice") [ Cardinality = many, Inverse = ParentCosEntity ];

Property CalculatedTags As list Of %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag(XMLIO = "OUT", XMLPROJECTION = "element", XMLTYPECONSTRAINT = "choice") [ Calculated ];

Property DatabaseGUID As %String(XMLPROJECTION = "none") [ SqlComputeCode = {set {*} = $classmethod({%%CLASSNAMEQ},"GetDatabaseGUID")}, SqlComputed ];

Property ObjectCounter As %Integer(XMLPROJECTION = "none") [ SqlComputeCode = {set {*} = $increment(^%ZPM.Dev.Annotation.CosEntityC)}, SqlComputed ];

/// reference to the class proxy object that the current COS entity is part of. For class proxy objects, this will return $this. 
Property OwnerClass As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy(XMLPROJECTION = "none") [ Calculated, SqlComputeCode = {set {*} = $classmethod({%%CLASSNAMEQ}, "GetOwnerClassProxyID",{%%ID}) }, SqlComputed ];

Property IdentifierText As %String(MAXLEN = 500, XMLPROJECTION = "none") [ Calculated, SqlComputeCode = {set {*} = $classmethod({%%CLASSNAMEQ},"GetIdentifierText",{%%ID})}, SqlComputed ];

Property TagNamesInUse(XMLPROJECTION = "none") [ Internal, MultiDimensional ];

Index NamespaceAwareKey On (DatabaseGUID, ObjectCounter) [ IdKey ];

ClassMethod GetDatabaseGUID() As %String
{
	/* 
	the ^%ZPM.Dev.Annotation.CosEntityG global is intended to be specific to the 
	current (data) database. If there are database mappings that don't treat 
	it the same as ^%ZPM.Dev.Annotation.CosEntityC, things will break. 
	
	Using a longer, clearer name like ^%ZPM.Dev.Annotation.CosEntityGUID fails because 
	the end is trimmed off and it resolves to ^%ZPM.Dev.Annotation.CosEntityG anyway. If 
	we want to change this we should revisit all the storage globals in the package 
	for consistency. 
	*/
	
	set tGUID = $get(^%ZPM.Dev.Annotation.CosEntityG)
	if tGUID = "" {
		set tGUID = ##class(%SYSTEM.Util).CreateGUID()
		set ^%ZPM.Dev.Annotation.CosEntityG = tGUID
	}
	
	quit tGUID
}

Method OwnerClassGet() As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy
{
	set tOwnerID = ..GetOwnerClassProxyID(..%Id())
	if tOwnerID '= 0 {
		quit ..%OpenId(tOwnerID)
	}
	quit ""
}

ClassMethod GetOwnerClassProxyID(pID As %Integer) As %Integer
{
	quit ""
}

Method IdentifierTextGet() As %String
{
	quit ..GetFriendlyIdentifier()
}

ClassMethod GetIdentifierText(pID As %Integer) As %String
{
	if '..%ExistsId(pID) {
		quit ""
	}
	
	set tObject = ..%OpenId(pID)
	if '$isobject(tObject) {
		quit ""
	}
	quit tObject.GetFriendlyIdentifier()
}

/// Because the tags live in a relationship, we cannot expect the contents to have consistent output, which would 
/// result in some level of false positive "changes" in the API over time. The sequencing is needed to ensure that our 
/// API documentation can be used for change tracking. To avoid this issue, we use the following workaround which 
/// orders the tags using element name, which we assume to be unique within each COS entity proxy. 
Method CalculatedTagsGet() As %Collection.AbstractListOfObj [ CodeMode = objectgenerator ]
{
	// use an array collection to get things in order 
	set tCodeStream = %code
	do ##class(%ZPM.Utils.CodeGeneration).BuildRelationshipSorter(tCodeStream, "Tags", "ShortTagName()")
	
	quit $$$OK
}

/// a text string for identifying things in error messages and whatnot
Method GetFriendlyIdentifier() As %String
{
	quit ""
}

Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	set tReturnVal = $$$OK
	try {
		do ..ValidateTags()
	}
	catch tException {
		set tReturnVal = tException
	}
	
	quit tReturnVal
}

/// validates tags for object validity and also applies logic rules. no return value; throws exceptions if there 
/// are showstopper problems. Some non-critical issues may simply cause output warnings. The various overrides 
/// all call ##super and they are all called when we finish loading/building the info for a class (with all its 
/// contents) and we're about to save the class proxy and its entire object tree. 
Method ValidateTags()
{
	// base implementation is a no-op
	quit
}

ClassMethod AcceptableTagList() As %Library.List
{
	quit $listfromstring(..#CommonTags) _ $listfromstring(..#AcceptableAnchorTags)
}

Method ValidateTagForUse(pNewTag As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag) As %Status
{
	// note: this test cannot be applied during object validation because some tags objects are discarded, 
	// not saved. We might want to move the "on validation" content ("ValidateTags") in here as well. 
	
	// is this a tag we're allowed to use? 
	set tShortName = pNewTag.ShortTagName()
	
	if $listfind(..AcceptableTagList(), tShortName) = 0 {
		quit $$$ERROR($$$GeneralError, "Tag " _ tShortName _ " not valid for entity " _ $classname())
	}
	
	quit $$$OK
}

Method AssignTag(pNewTag As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag) As %Status
{
	set tShortName = pNewTag.ShortTagName() // can safely assumed to be nonempty
	if $data(..TagNamesInUse(tShortName)) {
		quit $$$ERROR($$$GeneralError, "Multiple " _ tShortName _ " tags found for " _..GetFriendlyIdentifier())
	}
	
	set tValidationStatus = ..ValidateTagForUse(pNewTag)
	if $$$ISERR(tValidationStatus) {
		quit tValidationStatus
	}
	set pNewTag.ParentCosEntity = $this
	set ..TagNamesInUse(tShortName) = ""
	quit $$$OK
}

/// builds a simple array of the class names of all the tag objects connected to this entity
Method InitializeTagNameArray(ByRef pTagList, Output pTagCount As %Integer)
{
	kill pTagList
	set pTagCount = 0
	
	#dim tLoopTag as %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag
	
	set tKey = ""
	while 1 {
		set tLoopTag = ..Tags.GetNext(.tKey)
		if tKey = "" {
			quit
		}
		
		set pTagList($classname(tLoopTag)) = 1
		set pTagCount = pTagCount + 1
	}
}

/// callback to give subclasses the opportunity to refuse to inherit a tag (supports the "DoesNotInheritTags" tag
/// in <class>CommentableEntity</class>)
Method ShouldRefuseTag(pCandidateTag As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag) As %Boolean
{
	quit 0
}

/// called on dummy object instances representing XML override info. Returns the relevant data as an array for later use. 
Method GetTagsAsArray(ByRef pInfoArray)
{
	kill pInfoArray
	#dim tTag as %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag
	set tKey = ""
	while 1 {
		set tTag = ..Tags.GetNext(.tKey)
		if tTag = "" {
			quit
		}
		
		if tTag.IsAPI() {			
			kill tWorking
			set tWorking = 1
			
			/* since tTag is only known to be an instance of AnchorTag, we can't assume 
			 that it has an Availability property or a Version property, so we use 
			 $property to reference them (if the "supports" method tells us to). */
			if tTag.SupportsAvailability() {
				set tWorking($$$ZPMAvailabilityModifier) = $property(tTag, $$$ZPMAvailabilityModifier)
			}
			if tTag.SupportsVersionValue() {
				set tWorking("Version") = $property(tTag, "Version")
			}
			
			set tShortTagName = tTag.ShortTagName()
			merge pInfoArray(tShortTagName) = tWorking
		}
	}
	
	/* sample array structure: 
	
	pInfoArray("API.Overrideable")=1
	pInfoArray("API.Overrideable","Availability")="Universal"
	pInfoArray("API.Method")=1
	pInfoArray("API.Method","Availability")="Universal"
	*/
}

Method InheritTags(ByRef pExtantTagList, ByRef pTagTally As %Integer, pSourceCosEntity As CosEntity, ByRef pTagOverrides, ByRef pOverridesFound)
{
	// apply overrides, if any
	
	#dim tLoopTag as %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag
	#dim tNewTag as %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag
	
	kill pOverridesFound
	
	set tKey = ""
	while 1 {
		set tLoopTag = pSourceCosEntity.Tags.GetNext(.tKey)
		if tKey = "" {
			quit
		}
		
		if $data(pExtantTagList($classname(tLoopTag))) = 0 {
			// we found an unfamiliar tag. 
			// This logic is all based on the assumption that a member will only have at most 
			// one tag of each type. 
			
			if tLoopTag.Inherited = 0 {
				continue // skip it; it's not meant to be inherited
			}
			
			if ..ShouldRefuseTag(tLoopTag) {
				continue
			}
			
			set tNewTag = tLoopTag.%ConstructClone()
			
			// is it in the overrides? If so, overlay modifiers before saving
			set tShortTagName = tNewTag.ShortTagName()
			if $data(pTagOverrides(tShortTagName)) {
				kill tOverridesForTag
				merge tOverridesForTag = pTagOverrides(tShortTagName)
				do tNewTag.ApplyPropertyValues(.tOverridesForTag, $this)
				
				// now that it's handled, cross it off
				kill pTagOverrides(tShortTagName)
				set pOverridesFound(tShortTagName) = ""
			}
			
			set tSC = ..AssignTag(tNewTag)
			$$$ThrowOnError(tSC)
			set pExtantTagList($classname(tNewTag)) = 1
			set pTagTally = pTagTally + 1
		}
	}
}

Method SupplyMissingTags()
{
	set tTagList = ..AcceptableTagList()
	set tPointer = 0
	set tExistingListInitialized = 0
	
	while $listnext(tTagList, tPointer, tTagName) {
		set tTagClassName = $$$ZPMTagClassName(tTagName)
		if $parameter(tTagClassName, "AddIfOmitted") = 1 {
			// is it actually missing? Do we have a list of what tags are already present? 
			if tExistingListInitialized = 0 {
				set tKey = "" 
				while 1 {
					set tTag = ..Tags.GetNext(.tKey)
					if tKey = "" {
						quit
					}
					
					set tExistingList($classname(tTag)) = 1
				}
				set tExistingListInitialized = 1
			}
			
			// now we can tell whether it's missing
			if $data(tExistingList(tTagClassName)) = 0 {			
				set tNewTag = $classmethod(tTagClassName, "ConstructMissingMandatoryTag")
				set tSC = ..AssignTag(tNewTag, 0)
				$$$ThrowOnError(tSC)
			}
		}
	}
}

Method StoreWarning(pWarningText As %String) As %Status
{
	/*
	This method doesn't determine the "context" automatically because it may be part of 
	an object under construction, or an object that will never actually be saved, so its 
	relationships may not be in place and it may not be able to detect its "owner" class and so on. 
	The method relies on the callers providing full info. 
	*/
	
	if $get(%ModuleName) = "" {
		quit $$$OK
	}
	
	if $namespace '= %HomeNamespace {
		// make sure to store the warning in our home namespace
		new $namespace
		set $namespace = %HomeNamespace
	}
	
	set tWarning = ##class(%ZPM.PackageManager.Developer.Annotation.Warning).%New()
	set tWarning.ModuleName = %ModuleName
	set tWarning.WarningText = pWarningText 
	set tWarning.OriginatingEntityIdentifierText = ..GetFriendlyIdentifier()
	set tSC = tWarning.%Save()
	quit tSC
}

Method HasTag(pShortClassName As %String, Output pAvailability As %String = "", Output pVersionValue As %String = "") As %Boolean
{
	#dim tTag as %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag
	set tExpectedClass = $$$ZPMTagClassName(pShortClassName)
	set tKey = ""
	while 1 {
		set tTag = ..Tags.GetNext(.tKey)
		if tTag = "" {
			quit
		}
		
		if ($classname(tTag) = tExpectedClass) {
			/* since tTag is only known to be an instance of AnchorTag, we can't assume 
			 that it has an Availability property or a Version property, so we use 
			 $property to reference them (if the "supports" method tells us to). */
			if tTag.SupportsAvailability() {
				set pAvailability = $property(tTag, $$$ZPMAvailabilityModifier)
			}
			if tTag.SupportsVersionValue() {
				set pVersionValue = $property(tTag, "Version")
			}
			return 1
		}
	}
	quit 0
}

Storage Default
{
<Data name="CosEntityDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^%ZPM.Dev.Annotation.CosEntityD</DataLocation>
<DefaultData>CosEntityDefaultData</DefaultData>
<IdLocation>^%ZPM.Dev.Annotation.CosEntityD</IdLocation>
<IndexLocation>^%ZPM.Dev.Annotation.CosEntityI</IndexLocation>
<StreamLocation>^%ZPM.Dev.Annotation.CosEntityS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
