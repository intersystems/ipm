Include %ZPM.PackageManager.Developer.Annotation

/// Base class for "anchor" tags (that is, tags that do not modify or continue other tags). Note that 
/// ALL subclasses of this class must be in the package %ZPM.PackageManager.Developer.Annotation.Tag; this 
/// is an assumption in the method <method>ShortTagName</method>. 
Class %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag Extends (%Persistent, %XML.Adaptor) [ Abstract ]
{

/// Contains keywords for modifiers that are universally applicable to all tags. Not intended to be overridden. 
Parameter UniversalModifiers [ Final ] = "TagNotInherited";

/// note that we tried using a COSEXPRESSION to generate the XMLNAME from the class name, 
/// using the obvious simple rule: $replace($piece($classname(),".",6,*),".","_") . 
/// 
/// While this works when evaluated with $parameter(), the XML writer can't use it because it relies on 
/// run-time expression execution and the XML output is done via generated code. 
/// 
/// Using a curly-braces "evaluate at compile time" expression also does not work, even if we use %classname instead 
/// of $classname(); maybe the XML.Adaptor code generation doesn't support the {} syntax regardless. 
/// 
/// See prodlog 148118
/// 
/// So we have to provide the obvious XMLNAME value explicitly in all the tag subclasses. 
Parameter XMLNAME;

/// flag to indicate whether a COS entity that allows this tag should always have XML for that tag, 
/// even if it's omitted from the annotations. Such extra XML representation will not use a default 
/// instance of the tag, but one constructed by calling <method>ConstructMissingMandatoryTag</method>. This 
/// allows us to have different behavior between a) omitted things and b) things included without 
/// modifiers, e.g. "Extensible" by itself should have "universal" availability, while omission means "forbidden". 
Parameter AddIfOmitted = 0;

/// whether we should add this tag object to the entity's Tags. We set this to 0 in tag classes that affect 
/// the tag processing behavior but which should not appear in the API XML. This is necessary because there 
/// is no way to exclude it from the XML; setting the XMLENABLED parameter to 0 causes errors because every 
/// class referenced by an xml-enabled class (when generating XML) must be enabled also, and the tags are all
/// mixed together in the ..Tags relationship of the COS entity object. We could also try to store them 
/// differently in the COS entity but that would make all the other tag handling more complex. 
Parameter IncludeInObjectTree = 1;

/// note that this relationship should have an "OnDelete = cascade" keyword, but this does not work correctly. 
/// Attempting to accomplish the same effect with an "on delete" trigger in the CosEntity table also does not work. 
/// see prodlog 148120
/// Therefore, anytime we delete CosEntity objects we must explicitly delete its related AnchorTag objects first. 
Relationship ParentCosEntity As %ZPM.PackageManager.Developer.Annotation.CosEntity [ Cardinality = one, Inverse = Tags ];

Index ParentCosEntityIndex On ParentCosEntity;

Property TagClassName As %String(MAXLEN = 500, XMLPROJECTION = "none") [ SqlComputeCode = {set {*} = {%%CLASSNAMEQ}}, SqlComputed ];

Index NamespaceAwareIndex On (ParentCosEntity, TagClassName) [ IdKey ];

/// reference to the class proxy object that <property>ParentCosEntity</property> is part of. For class proxy objects, this will return $this. 
Property OwnerClass As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy(XMLPROJECTION = "none") [ Calculated, SqlComputeCode = {set {*} = $classmethod({%%CLASSNAMEQ}, "GetOwnerClassProxyID",{%%ID}) }, SqlComputed ];

/// By default, all tags are inherited. Tags on a class are inherited by its subclasses, and tags on a class's members
/// are inherited by the members in subclasses. However, we allow a modifier to block this, like so: 
/// <example>
/// /// @API.Property  
/// /// @Modifier TagNotInherited 
/// </example>
/// Using this modifier only affects the behavior of the annotation tags. It does not affect how the COS members are inherited, 
/// that's the domain of COS. The modifier can apply to any tag. 
Property Inherited As %Boolean(XMLPROJECTION = "none") [ InitialExpression = 1 ];

Method OwnerClassGet() As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy
{
	quit ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy).%OpenId(..GetOwnerClassProxyID(..%Id()))
}

ClassMethod GetOwnerClassProxyID(pID As %Integer) As %Integer
{
	set tParentCosObj = ..%OpenId(pID).ParentCosEntity	
	quit tParentCosObj.GetOwnerClassProxyID(tParentCosObj.%Id())
}

ClassMethod ConstructMissingMandatoryTag() As AnchorTag
{
	set tNewTag = ..%New() // default implementation just returns a default instance
	if tNewTag.SupportsAvailability() {
		// only examples of mandatory tags that support availability are "extensible" and "overrideable"; both 
		// should be "forbidden" if omitted. If that changes, then we can override this method separately on various subclasses. 
		set $property(tNewTag,$$$ZPMAvailabilityModifier) = $$$ZPMAvailabilityForbidden
	}
	quit tNewTag
}

/// private helper method; throws exceptions. 
Method ProcessModifiers(ByRef pCommentBlock As %Library.RawString, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity) [ Private ]
{
	set tFailsafe = 0
	set tAcceptableModifierList = $listfromstring($zconvert(..#UniversalModifiers,"U"))	
	set tAvailabilityUCase = $zconvert($$$ZPMAvailabilityModifier,"U")
	if ..SupportsAvailability() {
		set tAcceptableModifierList = tAcceptableModifierList _ $listbuild(tAvailabilityUCase) 
	}
	
	while $extract(pCommentBlock, 1, $length("@Modifier")) = "@Modifier" {
		set tFailsafe = tFailsafe + 1
		if tFailsafe > 500 {
			quit
		}
		
		set tModifierLine = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).PopCommentLine(.pCommentBlock)
		set pCommentBlock = $zstrip(pCommentBlock, "<W")
		
		// pop the "@Modifier" off 
		set tJunk = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).PopWhitespacePiece(.tModifierLine)

		// now get the modifier name
		set tModifierName = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).PopWhitespacePiece(.tModifierLine)
		
		if tModifierName = "" {
			$$$ThrowOnError(pContextObject.StoreWarning("Invalid modifier tag found with no modifier name (identifier)"))
			continue // move on to next line ... 
		}
		
		// uppercase it so we can be case-insensitive
		set tModifierName = $zconvert(tModifierName,"U")
		
		if $listfind(tAcceptableModifierList,tModifierName) = 0 {
			$$$ThrowOnError(pContextObject.StoreWarning("Tag " _ $classname() _ " does not support modifier " _ tModifierName))
			continue
		}
		
		// If the modifier family gets big then we can adapt the following to something less hardcoded. 
		if tModifierName = tAvailabilityUCase {	
			// we already verified that the tag supports the modifier; this means that it must extend %ZPM.PackageManager.Developer.Annotation.Tag.SupportsAvailability
			set $property($this, $$$ZPMAvailabilityModifier) = $zstrip(tModifierLine, "*W")
		} elseif tModifierName = "TAGNOTINHERITED" {
			set ..Inherited = 0
		} else {
			// ??
		}
		
		set tHandled(tModifierName) = 1
	}
}

ClassMethod ShortTagName() As %String
{
	quit $piece($classname(), ".", $length($$$ZPMTagPackageName,".")+1,*)
}

/// helper method for further content on the tag line after the tag itself. throws exceptions. 
/// expects the comment block to begin with the "remainder" after the initial tag has been 
/// removed, with the line break and anything preceding it still present. Leaves the 
/// block in a state with that remainder gone, and beginning with the next real line. 
Method HandleExtraContent(ByRef pCommentBlock As %Library.RawString = "", pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity) [ Private ]
{
	if $length(pCommentBlock) = 0 {
		// nothing left ... valid case of no modifiers or other stuff
		quit
	}
	
	// defaults to case where there is no extra content expected; remove the line break and clean up
	if $extract(pCommentBlock, 1, 2) '= $char(13,10) {
		set tSC = pContextObject.StoreWarning("Invalid extra content for " _ ..ShortTagName() 
			_ " tag: " _ $extract(pCommentBlock, 1, 10))
		$$$ThrowOnError(tSC)
	}
	
	set pCommentBlock = $extract(pCommentBlock, 3, *) // remove the line break
	set pCommentBlock = $zstrip(pCommentBlock, "<W") // whitespace
}

Method InitializeFromCommentText(ByRef pCommentBlock As %Library.RawString, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity) As %Status
{
	set tReturnValue = $$$OK
	try {
		set pCommentBlock = $zstrip(pCommentBlock, "<W") // leading whitespace
		
		do ..HandleExtraContent(.pCommentBlock, pContextObject)
		
		do ..ProcessModifiers(.pCommentBlock, pContextObject)		
	}
	catch tException {
		set tReturnValue = tException.AsStatus()
	}
	
	quit tReturnValue
}

Method IsAPI() As %Boolean
{
	// note that we are forced to wrap the macro on the right side of the "=" in parentheses because it has an underscore in its definition
	if $extract($classname(), 1, $length($$$ZPMTagPackageName _ ".API")) = ($$$ZPMTagPackageName _ ".API") {
		quit 1
	}
	quit 0
}

Method SupportsAvailability() As %Boolean
{
	quit ..%Extends("%ZPM.PackageManager.Developer.Annotation.Tag.SupportsAvailability")
}

Method SupportsVersionValue() As %Boolean
{
	quit ..%Extends("%ZPM.PackageManager.Developer.Annotation.Tag.SupportsVersionValue")
}

/// tags can have properties that either appear as "extra content" in the same tag line (e.g. @API.Deprecated 2.12.4), or as 
/// modifiers on a separate line (e.g. @Modifier Availability Universal). Many of these also need to be able to be overridden 
/// in APIANNOTATIONS XData blocks, which we parse into arrays for easier processing. This method is for applying those properties/attributes
/// coming from the XData blocks. <br/>
/// This leaves us supporting exactly two: the Availability modifier and the Version properties for Deprecated and Since. But 
/// the intent is to support more options later if needed. <br/>
/// The array passed in should be of the form pPropertyValues("Property") = "Value"
Method ApplyPropertyValues(ByRef pPropertyValues, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity)
{
	if ..SupportsAvailability() {
		set $property($this, $$$ZPMAvailabilityModifier) = $get(pPropertyValues($$$ZPMAvailabilityModifier),$property($this, $$$ZPMAvailabilityModifier))
	}
	
	if ..SupportsVersionValue() {
		do $method($this, "ValidateAndAssignVersion", $get(pPropertyValues("Version")), pContextObject, ..ShortTagName())
	}
}

Storage Default
{
<Data name="AnchorTagDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ParentCosEntity</Value>
</Value>
<Value name="3">
<Value>Inherited</Value>
</Value>
</Data>
<DataLocation>^%ZPM.Dev.Annotation.AnchorTagD</DataLocation>
<DefaultData>AnchorTagDefaultData</DefaultData>
<IdLocation>^%ZPM.Dev.Annotation.AnchorTagD</IdLocation>
<IndexLocation>^%ZPM.Dev.Annotation.AnchorTagI</IndexLocation>
<StreamLocation>^%ZPM.Dev.Annotation.AnchorTagS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
