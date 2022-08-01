/// base class for proxy classes representing class members: properties, 
/// parameters, methods, etc., for common code
Class %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassMemberProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity [ Abstract ]
{

Parameter DictionaryKey;

Relationship ParentClass As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy [ Cardinality = one, Inverse = Members, OnDelete = cascade ];

/// name of owner class; used during construction because the class member may not have had its ParentClass 
/// relationship populated yet (or it may not end up being saved anyway). Not projected to XML. 
Property ParentClassName As %Dictionary.Classname(XMLPROJECTION = "none");

Index ParentClassIndex On ParentClass;

ClassMethod GetOwnerClassProxyID(pID As %Integer) As %Integer
{
	try { 
		set tRetVal = ..%OpenId(pID).ParentClass.%Id()
	}
	catch {
		set tRetVal = 0
	}
	quit tRetVal
}

Method GetFriendlyIdentifier() As %String
{
	set tMemberType = $replace($piece($classname(),".",6),"Proxy","")
	quit "class " _ ..ParentClassName _ ", " _ tMemberType _ " " _ ..Name
}

Method GetSortingKey() As %String
{
	quit ..#DictionaryKey _ "." _ ..Name
}

Method HandleExtraProperties()
{
	// no-op - handle fields specific to the type of class member
}

ClassMethod SkipProxy(pParentClassName As %Dictionary.Classname, pMemberName As %String) As %Boolean
{
	quit 0
}

ClassMethod BuildProxies(pParentClassProxy As ClassProxy)
{
	set tMemberName = ""
	while 1 {
		set tMemberName = $$$comMemberNext(pParentClassProxy.Name, ..#DictionaryKey, tMemberName)
		if tMemberName = "" {
			quit
		}
		
		if ..SkipProxy(pParentClassProxy.Name, tMemberName) {
			continue
		}
		
	  	set tNewProxy = ..%New()
	  	set tNewProxy.Name = tMemberName
	  	set tNewProxy.ParentClassName = pParentClassProxy.Name
	  	
	  	do tNewProxy.HandleExtraProperties()
	  	
	  	// descriptions live in ^oddDEF, so we use a $$$def... macro. 
		set tDescription = $$$defMemberKeyGet(pParentClassProxy.Name, ..#DictionaryKey, tMemberName, $$$cXXXXdescription)
		if tDescription '= "" {
		  	set tSC = tNewProxy.ProcessComments(tDescription)
			$$$ThrowOnError(tSC)
		}
		
		/* 
		Also, if we found local ^oddDEF content that means the member is declared explicitly in this class, 
		maybe as an override. This means that we should not encounter override data for the member in the XData block. 
		If we do, we log a warning and wipe out that override content in order to "ignore" it. 
		
		Note that we already check for this in the ClassProxy class when we initialize the array but we check again anyway. 
		*/
			
		if $$$defMemberDefined(pParentClassProxy.Name, ..#DictionaryKey, tMemberName) {
			if $data(pParentClassProxy.TagOverrideData(..#DictionaryKey, tMemberName)) > 0 {
				do tNewProxy.StoreWarning("XData tag override data found for defined member; this is not allowed when the member appears explicitly. Use comment tags on the member instead.")
				kill pParentClassProxy.TagOverrideData(..#DictionaryKey, tMemberName)
			}
		}
		
		do tNewProxy.HandleTagInheritance(pParentClassProxy)
		
		// are there any leftover items in the pTagOverrides array? If so, we need to add them. The XML that produces this stuff might include
		// tags that were absent (and not automatically supplied by the "mandatory" feature) from the superclasses
		
		kill tTagOverrides
		merge tTagOverrides = pParentClassProxy.TagOverrideData(tNewProxy.#DictionaryKey, tNewProxy.Name)
		set tLoop = "" 
		while 1 {
			set tLoop = $order(tTagOverrides(tLoop))
			quit:tLoop=""
			
			set tLoopTagClassName = $$$ZPMTagClassName(tLoop)
			set tNewTag = $classmethod(tLoopTagClassName, "%New")
			kill tOverridesForTag
			merge tOverridesForTag = tTagOverrides(tLoop)
			do tNewTag.ApplyPropertyValues(.tOverridesForTag, tNewProxy)
			
			set tSC = tNewProxy.AssignTag(tNewTag)
			$$$ThrowOnError(tSC)
		}
		
		// we only care about API stuff. This property will have been set based on tags found in the comments. 
		if tNewProxy.IsAPI {
			// note we don't add the missing "mandatory" tags until after checking whether it's "API", because 
			// otherwise non-API classes will look "API" because of those tags
			do tNewProxy.SupplyMissingTags()
		
			// skip internal stuff like %%OID. May need a separate overrideable method for this. 
			// We do this late in the loop so that we can show warnings. Note that the "internal" 
			// flag is stored in ^oddDEF, not ^oddCOM, so we use a $$$def... macro. 
			if $$$defMemberKeyGet(pParentClassProxy.Name, ..#DictionaryKey, tMemberName, $$$cXXXXinternal) = 1 {
				set tSC = tNewProxy.StoreWarning("API tags found for Internal class member")
				$$$ThrowOnError(tSC)
				continue
			}
			set tNewProxy.ParentClass = pParentClassProxy
			
			if 'pParentClassProxy.IsAPI {
				// Flag the parent class as API, UNLESS:
				// * pParentClassProxy has @API.Extensible = Forbidden (or missing)
				// * tNewProxy is only API because @API.Overrideable '= Forbidden
				set tTagMakesClassAPI = 1
				set tHasExtensibleTag = pParentClassProxy.HasTag("API.Extensible",.tAvailability)
				set tOverrideableTagClass = $$$ZPMTagClassName("API.Overrideable")
				if ('tHasExtensibleTag) || (tAvailability = $$$ZPMAvailabilityForbidden) {
					set tTagMakesClassAPI = 0
					set tKey = ""
					while 'tTagMakesClassAPI {
						set tTag = tNewProxy.Tags.GetNext(.tKey)
						if (tTag = $$$NULLOREF) {
							quit
						}
						if $classname(tTag) = tOverrideableTagClass {
							// disregard the API.Overrideable tag if the class is not extensible.
							continue
						}
						if tTag.IsAPI() && tTag.SupportsAvailability() {
							// We are only interested in @API.<member type> annotations - @API.Since and @API.Deprecated don't count.
							set tTagMakesClassAPI = ($property(tTag, $$$ZPMAvailabilityModifier) '= $$$ZPMAvailabilityForbidden)
						}
					}
				}
				set pParentClassProxy.IsAPI = tTagMakesClassAPI
			}
		}
	}
}

Method GetSortedSuperclassList(pClassName As %Dictionary.Classname) As %String
{
	set tImmediateSuperclasses = $$$comClassKeyGet(pClassName, $$$cCLASSsuper)
	set tInheritanceDirection = $$$defClassKeyGet(pClassName, $$$cCLASSinheritance)
	if $get(tInheritanceDirection,"") = "" {
		set tInheritanceDirection = "left"
	}
	
	set tFailsafe = 0
	set tNaiveList = $listfromstring(tImmediateSuperclasses)
	
	if tInheritanceDirection '= "left" {
		// need to reverse it; no handy $ function to reverse a list
		set tPointer = 0
		set tReversedList = ""
		while $listnext(tNaiveList, tPointer, tSuperclassName) {
			set tReversedList = $listbuild(tSuperclassName) _ tReversedList
		}
		quit tReversedList
	}
	else {
		quit tNaiveList
	}
}

/// inherit API tag content for a class member, if it overrides something from a superclass
Method HandleTagInheritance(pParentClassProxy As ClassProxy)
{
	/*
	The implementation of inheritance handling in the ClassProxy class only pays attention to the PrimarySuper 
	classes (the primary super, its primary super, and so on). This is because the class annotation only cares 
	about the primary, but may need to go deep into that chain to find comment content. That's the 
	"HandleClassInheritance" method in the ClassProxy class. 
	
	Class members, however, can be inherited from any superclass. The comment content we care about 
	is the superclass tags that indicate whether the member is overrideable etc.
	
	The problem is that the member may be inherited via a long path, and the tag comment may not be 
	in a module class or in the immediate ancestor. We need to backtrack through the inheritance tree to 
	find the most recent ancestor member with a nonempty comment block or module annotation proxy objects. 
	If that turns out to be in a non-module class, we're done. Otherwise we want to inherit tags and/or raise 
	warnings about violations. 
	*/
	
	set tSuperClassList = ..GetSortedSuperclassList(..ParentClassName)
	
	// make a lookup array of the tags we have
	do ..InitializeTagNameArray(.tTagList, .tTagCount)
	
	// how many tags are there in the "full set"?
	set tTotalTagLimit = $listlength(..AcceptableTagList())
	
	/*
	if the member extends/overrides a member in a superclass, then we prefer to get the 
	information from one of the module annotation classes. For non-module classes we have to 
	refer to the class dictionary. 
	
	However, it is possible for a class to extend/override a member from a module class 
	that exists as a ClassProxy while the member was not designated as an API member in the superclass
	(maybe because it was inherited from somewhere else, or maybe we're extending a class in the same module
	and we don't want the member to be API in the other class) and thus it is not found in the ClassMemberProxy 
	table. We have to tread carefully to pick those up from the dictionary as well. 
	*/ 
	
	// we'll need to hop around between namespaces if the superclasses are mapped in
	new $namespace
	
	// an array collection of cached queries, by namespace
	#dim tAvailabilityQueries as %Library.ArrayOfObjects 
	set tAvailabilityQueries = ##class(%Library.ArrayOfObjects).%New()
	
	#dim tLoopMember as ClassMemberProxy
	set tPointer = 0
	while $listnext(tSuperClassList, tPointer, tSuperclassName) {
		set $namespace = %HomeNamespace
		if $$$comMemberDefined(tSuperclassName, ..#DictionaryKey, ..Name) {
			// this superclass HAS the member. If we can find it in the proxy tables, great; if not, 
			// use the dictionary. 
				
			set tParentMemberProxyFound = 0
			
			// where is it from? is it a module class?
			set tSuperclassNamespace = ..NamespaceForModuleClass(tSuperclassName, .tProxyID)
			if tSuperclassNamespace '= "" {
				if tSuperclassNamespace '= $namespace {
					set $namespace = tSuperclassNamespace
				}
				
				// we don't have a good index on classmembers. To create one we would probably 
				// need to create a calculated property to distinguish different kinds of members, 
				// so the unique expression would be classname/membertype/membername. Without it, 
				// we have to loop to find the match (if it exists). 
				
				// if we can't verify overrideability, we need a warning
				set tOverrideabilityVerified = 0
				
				set tSuperClassProxy = ##class(ClassProxy).%OpenId(tProxyID,,.tSC)
				$$$ThrowOnError(tSC)
				
				set tKey = ""
				while 1 {
					set tLoopMember = tSuperClassProxy.Members.GetNext(.tKey)
					if tKey = "" {
						quit
					}
					if ($classname(tLoopMember) = $classname()) && (tLoopMember.Name = ..Name) {
						// we found the parent member. get tags & comment as needed
						set tParentMemberProxyFound = 1
						
						// first, look at the text comment (description) ... do we need to inherit it? 
						if (..CommentBlock = "") && (tLoopMember.CommentBlock '= "") {
							set ..CommentBlock = tLoopMember.CommentBlock
						}
						
						// now look at annotations 
						
						// override data to apply; overrides inherited tag info	for this member
						kill tTagOverrides
						kill tOverridesFound
						merge tTagOverrides = pParentClassProxy.TagOverrideData(..#DictionaryKey, ..Name)
						do ..InheritTags(.tTagList, .tTagCount, tLoopMember, .tTagOverrides, .tOverridesFound)
						set tTagLoop = ""
						while 1 {
							set tTagLoop = $order(tOverridesFound(tTagLoop))
							quit:tTagLoop=""
							kill pParentClassProxy.TagOverrideData(..#DictionaryKey, ..Name, tTagLoop)
						}
						
						// special handling? 
						do ..SpecialMemberInheritance(tLoopMember)
						
						// warnings for extensibility etc.
						if tSuperClassProxy.ModuleName '= %ModuleName {
							if $get(tOverrideTagQueryReady($namespace),0) = 0 {
								set tSQL = "select Availability "
									_ "from %ZPM_PackageManager_Developer_Annotation_Tag_API.Overrideable " 
									_ "where ParentCosEntity = ?"
								set tExtensibilityStatement = ##class(%SQL.Statement).%New()
								set tSC = tExtensibilityStatement.%Prepare(tSQL)
								$$$ThrowOnError(tSC)
							
								set tOverrideTagQueryReady($namespace) = 1
								set tSC = tAvailabilityQueries.SetAt(tExtensibilityStatement, $namespace)
								$$$ThrowOnError(tSC)
							}
							else {
								set tExtensibilityStatement = tAvailabilityQueries.GetAt($namespace)
							}
							
							// note: the following is quite similar to the matching code in the ClassProxy class but 
							// it is not refactored because there are a lot of little differences
							set tRecords = tExtensibilityStatement.%Execute(tLoopMember.%Id())
							if tRecords.%SQLCODE < 0 {
								set tSQLError = $$$ERROR($$$SQLCode,tRecords.%SQLCODE,tRecords.%Message) 
								set tContextError = $$$ERROR($$$GeneralError, "Failed to query overrideability info for " _ tLoopMember.GetFriendlyIdentifier())
								$$$ThrowStatus($$$EMBEDSC(tContextError, tSQLError))
							}
							
							if tRecords.%SQLCODE = 0 {
								if tRecords.%Next() {
									set tAvailability = tRecords.%Get("Availability")
									if tAvailability '= $$$ZPMAvailabilityForbidden {
										set tOverrideabilityVerified = 1
									}
								}
							}
						} // if the superclass was in another module
						
						// we found the member in the module proxy data; we can quit looping over the members in the superclass
						quit
					} // if we found the parent member in the proxy tables
				} // looping over members in the superclass
				
				// we're still looping through superclasses; the current superclass has the member, but
				// tParentMemberProxyFound only indicates whether we found it in the persistent annotation objects. 
				
				/*
				Do we need a warning about what's being overridden? 
				We know that the current member has the same name as a member of a superclass that has a class proxy. 
				
				First, we only care if the parent class is in a different module. 
				
				Next, if we found a member proxy for the parent member, we rely on the tags 
				(or lack thereof) we found there. If we didn't find it, we need a warning. 
				
				Finally, we only care if the current method is an actual override and not just a 
				"silent" inheritance from the parent class. 
				*/
				
				if tSuperClassProxy.ModuleName '= %ModuleName {
					if (tParentMemberProxyFound = 0) || (tOverrideabilityVerified = 0) {
						set $namespace = %HomeNamespace // switch back to the home namespace where we can check ^oddCOM
						set tOrigin = $$$comMemberKeyGet(..ParentClassName, ..#DictionaryKey, ..Name, $$$cXXXXorigin)
						if tOrigin = ..ParentClassName {
							// current class overrides the member
							// note that we aren't talking about "Tag" overrides, only COS member overrides
							
							// Did the member come from a non-module class in the first place? 
							
							set tSuperOrigin = $$$comMemberKeyGet(tSuperclassName, ..#DictionaryKey, ..Name, $$$cXXXXorigin)
							
							set tSuperOriginNamespace = ..NamespaceForModuleClass(tSuperOrigin)
							if tSuperOriginNamespace '= "" {
								// we don't need to switch to that namespace or open the origin class; all we needed to 
								// know was whether the origin was from a module class. 
								set tSC = ..StoreWarning("Class member overrides a member from class " _ tSuperclassName _ " in module " _ tSuperClassProxy.ModuleName _ ", but that parent member isn't marked as overrideable")
								$$$ThrowOnError(tSC)
							}
						}
					}
				}
				
				// can we quit out of the loop early (because we've got all the tags and a nonempty comment block)? 
				if (tTagCount = tTotalTagLimit) && (..CommentBlock '= "") {
					quit
				}
				
				// if we got this far, we should jump back to the home namespace for safety
				set $namespace = %HomeNamespace
			}
			else {
				// the superclass is not from a module. All we care about is whether we already have a comment block; 
				// if not, we will want to continue below and copy it from above. 
				if ..CommentBlock '= "" {
					quit
				}
			}
			
			if ('tParentMemberProxyFound) && (..CommentBlock = "") {
				/* 
				we couldn't find it in the proxies, so use the dictionary to get it from the 
				superclass. However, it might not be stored there, because it might be inherited 
				from somewhere else. So we look up the member origin first. 
				*/
				
				if $$$comMemberKeyDefined(tSuperclassName, ..#DictionaryKey, ..Name, $$$cXXXXorigin) {
					set tOriginClass = $$$comMemberKeyGet(tSuperclassName, ..#DictionaryKey, ..Name, $$$cXXXXorigin)
					if tOriginClass '= "" {
						set ..CommentBlock = $$$defMemberKeyGet(tOriginClass, ..#DictionaryKey, ..Name, $$$cXXXXdescription)
						quit
					}
				}
			} // looking up comment from dictionary
			
			// the superclass has the member; we can quit looping over the other superclasses 
			quit
		}
	} // looping over superclasses
}

/// overridden by member proxy classes that require extra handling (e.g. Methods, to handle arguments & return value)
Method SpecialMemberInheritance(pSuperMember As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassMemberProxy)
{
}

Storage Default
{
<Data name="ClassMemberProxyDefaultData">
<Subscript>"ClassMemberProxy"</Subscript>
<Value name="1">
<Value>ParentClass</Value>
</Value>
<Value name="2">
<Value>ParentClassName</Value>
</Value>
</Data>
<DefaultData>ClassMemberProxyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
