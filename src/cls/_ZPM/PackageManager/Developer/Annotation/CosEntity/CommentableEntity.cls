/// base class for COS entity proxy objects representing things that can have triple-slash 
/// comment blocks in the COS source code: classes and class members. 
Class %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity Extends %ZPM.PackageManager.Developer.Annotation.CosEntity [ Abstract ]
{

/// name of class/property/parameter/whatever 
Property Name As %String(MAXLEN = 200, XMLPROJECTION = "attribute");

/// stores the NON-TAG content of the "///" description of a class or class member
Property CommentBlock As %Library.RawString;

Property IsAPI As %Boolean(XMLPROJECTION = "none") [ InitialExpression = 0 ];

/// internal flag to indicate whether we should apply inheritance of tags. 
Property SkipTagInheritance As %Boolean(XMLPROJECTION = "none") [ InitialExpression = 0 ];

ClassMethod DefaultAPITag() As %String
{
	// this implementation assumes that the relevant classes are all following the naming pattern. 
	// exceptions to this rule will override the method. 
	quit $replace($replace($classname(),"CosEntity","Tag.API"),"Proxy","")
}

Method AssignTag(pNewTag As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag, pTrackIsAPI As %Boolean = 1) As %Status
{
	set tSC = ##super(pNewTag)
	
	/* 
	does this tag qualify the object as being "API"? If the following logic gets awkward we can 
	replace it with a class parameter in the tag classes. 
	
	some hardcoding here: 
	Only tags in the API package confer API-ness on an entity. 
	Also, the Availability modifier is special. If the tag is marked as "forbidden" availability 
	then it's not enough to qualify the entity for API-ness. 
	*/
	
	if ((tSC = $$$OK) && pTrackIsAPI) {
		if pNewTag.IsAPI() { 
			if pNewTag.SupportsAvailability() {
				set ..IsAPI = (..IsAPI ||($property(pNewTag, $$$ZPMAvailabilityModifier) '= $$$ZPMAvailabilityForbidden))
			}
			else {
				set ..IsAPI = 1
			}
		}
	}
	quit tSC
}

/// go through the comment block on the current entity and parse tags from it
Method ProcessComments(pDescription As %Library.RawString) As %Status
{
	set tReturnValue = $$$OK
	try {
		set tWorkingDesc = pDescription
		
		set tLoopFailsafe = 0
		set tPriorLineWasTag = 0
		set tPreviousTag = ""
		
		#dim tNewTag As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag
		
		while 1 {
			set tLoopFailsafe = tLoopFailsafe + 1
			if tLoopFailsafe > 500 {
				$$$ThrowStatus($$$ERROR($$$GeneralError, "Got stuck in infinite loop in ProcessComments() for " _ ..GetFriendlyIdentifier()))
			}
			if tWorkingDesc = "" {
				// we're done
				quit
			}			
			
			if $extract(tWorkingDesc,1,1) = "@" {
				// it's tag-like. 
								
				/* 
				get the tag. We don't just pop the whole line off because there might be more 
				content after the tag and we want to leave it intact for the tag class to handle. 
				
				Particularly, multiline tags might look like this: 
				
				@API.Foo this is some free form commentary 
				@ that all belongs with the anchor tag and 
				@ we don't want to break it up 
				@Modifier Bar Baz
				
				Or it might be like this: 
				
				@API.Foo
				@Modifier Bar Baz
				
				So if we use the whole "pop first whitespace" we can't distinguish between new 
				lines and "remainder content" from the first line. 
				
				We tread carefully and try to extract the initial non-space text from the current "first" line. 
				We'll do this by repeatedly looking for line breaks, spaces and tabs, and whittling it down. 
				
				The "remainder" content that we pass to the tag classes may or may not begin with a line break. 
				
				The alternative would be to pass the remainder of the first line as one argument, and the 
				remaining lines as another, to the tag classes for parsing. But in some cases these would 
				need to be glued back together anyway, so neither choice is ideal or elegant. 
				*/
				
				set tTagTemp = tWorkingDesc
				
				// 13,10 is a line break, 32 is SPACE and 9 is TAB
				for tBreakString = $char(13,10), $char(32), $char(9) {
					set tFirstAppearance = $find(tTagTemp, tBreakString)
					if tFirstAppearance '= 0 {
						set tTagTemp = $extract(tTagTemp, 1, tFirstAppearance - ($length(tBreakString) + 1))
					}
				}
				set tTagName = $extract(tTagTemp, 2, *) // trim off the "@"
				set tTagClassName = $$$ZPMTagClassName(tTagName)
				
				// now we have the tag name, so we can try to find the matching tag class. 
				
				if $$$comClassDefined(tTagClassName) {
					kill tNewTag 
					set tNewTag = $classmethod(tTagClassName,"%New")
					if 'tNewTag.%IsA("%ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag") {
						if tPriorLineWasTag = 1 {
							set tErrorMsg = "'" _ tTagName _ "' is not a valid modifier for the tag '" _ tPreviousTag _ "'"
						}
						else {
							set tErrorMsg = tTagName  _ " is not a valid anchor tag; it should be modifying another tag."
						}
						$$$ThrowOnError(..StoreWarning(tErrorMsg))
					}
					else {
						// populate/initialize from source text. Remove the tag itself from the string, 
						// so that the tag class doesn't need to
						set tWorkingDesc = $extract(tWorkingDesc, $length(tTagName) + 2, *)
						set tSC = tNewTag.InitializeFromCommentText(.tWorkingDesc, $this)
						$$$ThrowOnError(tSC)
						
						// now add it to the cos entity object if desired. otherwise, validate it as being applicable, 
						// because that's normally called by AssignTag. 					
						if $parameter($classname(tNewTag), "IncludeInObjectTree") = 1 {
							set tSC = ..AssignTag(tNewTag)
							$$$ThrowOnError(tSC)
						}
						else {
							set tSC = ..ValidateTagForUse(tNewTag)
							$$$ThrowOnError(tSC)
						}
						set tPreviousTag = tTagName
					}
					set tPriorLineWasTag = 1
				}
				else {
					set tErrorMsg = "Invalid (unrecognized) tag '" _ tTagName _ "'. " _ 
						"Full line was: " _ tWorkingDesc _ ". "  
					if tTagName = "API" {
						set tErrorMsg = tErrorMsg _ "NOTE: '@API' by itself is not a valid annotation!"
					}
					elseif  tTagName = "API.Overridable" {
						set tErrorMsg = tErrorMsg _ "NOTE: it's spelled wrong; it should be @API.Overrideable"
					}
					set tSC = ..StoreWarning(tErrorMsg)
					$$$ThrowOnError(tSC)
				}
			}
			else {
				// looks tag-free. Append to the comment block. 
				
				set tWorkingLine = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).PopCommentLine(.tWorkingDesc)
				
				// BUT: if the prior line was a tag, and the current line is whitespace,
				// and the subsequent line is a tag, then skip it because it's just for clarity between tags 
				if tPriorLineWasTag && ($extract(tWorkingDesc,1,1) = "@") && ($zstrip(tWorkingLine,"*W") = "") {
					continue
				}
				
				if ..CommentBlock '= "" {
					set ..CommentBlock = ..CommentBlock _ $char(13,10)					
				}
				set ..CommentBlock = ..CommentBlock _ tWorkingLine
				set tPriorLineWasTag = 0
			}
		}
		
		// Validate the comment block
		If ..IsAPI && (..CommentBlock '= "") {
			// Wrap ..CommentBlock with <div>...</div> to permit content outside of an element enclosing all of it.
			Set tSC = ##class(%XML.XSLT.Transformer).TransformStringWithCompiledXSL("<div>"_..CommentBlock_"</div>",..GetValidationXSLT(),.pOutputStream,,.tParams)
			If $$$ISERR(tSC) {
				$$$ThrowOnError(..StoreWarning("Triple-slash comment contains invalid XML: "_$$$QUOTE(..CommentBlock)))
			}
		}
	}
	catch tException {
		set tReturnValue = tException.AsStatus()
	}
	
	quit tReturnValue
}

Method GetValidationXSLT() As %XML.XSLT.CompiledStyleSheet [ Private ]
{
	Set tSC = ##class(%ZPM.PackageManager.Core.CompiledXSLTCache).GetCompiledStyleSheet("%ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity","ValidationXSLT",.tCompiledXSLT)
	$$$ThrowOnError(tSC)
	Quit tCompiledXSLT
}

/// Simple XSLT that repeats back the input document.
/// The XSLT will fail if the input document is poorly formed.
XData ValidationXSLT
{
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="xml" />
<xsl:template match="@* | node()">
<xsl:copy>
<xsl:apply-templates select="@* | node()"/>
</xsl:copy>
</xsl:template>
</xsl:stylesheet>
}

Method ValidateTags()
{
	do ##super()
	
	/*
	some business logic: if a class or member proxy has an @API.Deprecated tag, it should 
	also have an @API.Object or @API.Method or @API.Property or whatever. Otherwise it makes no 
	sense; Deprecated indicates "yes this is in the API but it's going away eventually". 
	non-object classes like an Abstract code API class (a classmethod library) should not be 
	flagged as Deprecated; rather, its methods should be marked individually. 
	
	The same applies to "Since". 
	*/
	
	set tDeprecatedFound = 0
	set tSinceFound = 0
	set tDefaultAPITagFound = 0
	set tDefaultTag = ..DefaultAPITag()
	
	set tKey = ""
	while 1 {
		set tTagObjectClassName = $classname(..Tags.GetNext(.tKey))
		if tKey = "" {
			quit
		}
		
		if tTagObjectClassName = "%ZPM.PackageManager.Developer.Annotation.Tag.API.Deprecated" {
			set tDeprecatedFound = 1
		}
		elseif tTagObjectClassName = "%ZPM.PackageManager.Developer.Annotation.Tag.API.Since" {
			set tSinceFound = 1
		}
		elseif tTagObjectClassName = tDefaultTag {
			set tDefaultAPITagFound = 1
		}
	}
	
	if tDefaultAPITagFound = 0 {
		if tDeprecatedFound = 1 {
			set tSC = ..StoreWarning("@API.Deprecated tag found on non-API entity")
			$$$ThrowOnError(tSC)
		}
		if tSinceFound = 1 {
			set tSC = ..StoreWarning("@API.Since tag found on non-API entity")
			$$$ThrowOnError(tSC)
		}
	}
}

/// given a class name (usually a superclass of a class we're examining), this method 
/// returns the name of the namespace where that class's module's annotation data has 
/// been composed (if applicable), which may be the same as the current working namespace. 
/// If the class is a non-module class, we return the empty string. 
ClassMethod NamespaceForModuleClass(pClassName As %Dictionary.Classname, Output pObjectID As %Integer) As %String
{
	kill pObjectID
	
	if $data($$$ZPMClassOriginInfo(pClassName),tReturnValue) > 0 {
		set pObjectID = $get($$$ZPMClassOriginInfo(pClassName, "ID"))
		quit tReturnValue
	}
	
	set tReturnValue = ""
	set tBlacklist = $listbuild("Ens","EnsLib","EnsPortal")
	
	// we skip classes in packages from the above blacklist. 
	// We also skip classes that begin with "%", unless the second character is "Z"
	// (so that we include %ZPM etc.)
	
	if ($listfind(tBlacklist,$piece(pClassName,".",1)) = 0) 
			&& (($extract(pClassName,1,1) '= "%") || ($extract(pClassName,2,2) = "Z")) {
		
		// we need to investigate 
		if ##class(%Library.RoutineMgr).IsMapped(pClassName_".CLS", .tSource) {
			// the class is mapped from somewhere
			/*			
			A possible efficiency improvement here would be to check whether the other namespace 
			has any data in the data global for the persistent annotation data tables. We tried 
			this (see below) but it always comes up 0 and we end up skipping everything; maybe the 
			string format of tSource is incorrect for this usage (?)
			
			if $data(^|tSource|HS.PM.Dev.Annotation.CosEntityD) = 0 {
				// the other namespace doesn't have any annotation data at all; don't bother
				quit tReturnValue
			}
			*/
			
			new $namespace
			set $namespace = tSource
		}
		
		try {
			if ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy).ClassOnlyExists(pClassName, .pObjectID) {
				set tReturnValue = $namespace
				set tReturnValue("ID") = pObjectID
			}
		}
		catch tException {
		}
	}
	
	merge $$$ZPMClassOriginInfo(pClassName) = tReturnValue
	quit $get(tReturnValue)
}

/// apply the "DoesNotInheritTags" effect. 
Method ShouldRefuseTag(pCandidateTag As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag) As %Boolean
{
	quit ..SkipTagInheritance
	/*
	Notes: it might be tempting to say that the "overrideable" and "extensible" tags should be exempted from 
	this treatment, but we do want to allow someone to have an extensible class that is then extended elsewhere 
	as a non-extensible class. So that kind of thing is a valid example. 
	
	Also, note that this implementation means that having the "DoesNotInheritTags" tag on a class only affects 
	the inheritance of class tags ... it has no effect on the inheritance of tags in the members of the class. 
	Implementing that would be awkward because we process comments on members before the member proxy is 
	added to the class proxy's "members" relationship/collection. Therefore we would need to pass this information 
	several steps down the call stack instead of just referencing it as ..ParentClass.SkipTagInheritance in 
	an override at the ClassMemberProxy class level. 
	
	If we want the "do not inherit" tag to affect the entire class, that's doable, but it is inconsistent with 
	our other tags; none of them affect the member objects. 
	*/
}

Storage Default
{
<Data name="CommentableEntityDefaultData">
<Subscript>"CommentableEntity"</Subscript>
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>CommentBlock</Value>
</Value>
<Value name="3">
<Value>IsAPI</Value>
</Value>
<Value name="4">
<Value>SkipTagInheritance</Value>
</Value>
</Data>
<DefaultData>CommentableEntityDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
