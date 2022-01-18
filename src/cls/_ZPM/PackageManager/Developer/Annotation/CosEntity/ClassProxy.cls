Include %occErrors

Class %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity
{

Parameter XMLNAME = "Class";

Parameter AcceptableAnchorTags = "API.Object,API.Object.Instantiable,API.Extensible,DoesNotInheritTags";

Property ModuleName As %String(XMLPROJECTION = "none") [ Required ];

/// array representation of tag override data found in APIANNOTATIONS XData block, if any. See <method>BuildProxy</method> for details. 
Property TagOverrideData [ MultiDimensional ];

Index ModuleAndClass On (Name, ModuleName) [ PrimaryKey ];

Index ModuleIndex On ModuleName;

Index ClassOnly On Name [ Unique ];

Index ClassProxyExtentIndex [ Extent ];

Relationship Members As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassMemberProxy(XMLIO = "IN", XMLPROJECTION = "element", XMLTYPECONSTRAINT = "substitutiongroup") [ Cardinality = many, Inverse = ParentClass ];

Property CalculatedMembers As list Of %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassMemberProxy(XMLIO = "OUT", XMLPROJECTION = "element", XMLTYPECONSTRAINT = "substitutiongroup") [ Calculated ];

Relationship NonModuleSuperclasses As %ZPM.PackageManager.Developer.Annotation.CosEntity.NonModuleSuperclass(XMLIO = "IN", XMLPROJECTION = "element", XMLTYPECONSTRAINT = "substitutiongroup") [ Cardinality = children, Inverse = AppliesTo ];

Property CalculatedNonModuleSuperclasses As list Of %ZPM.PackageManager.Developer.Annotation.CosEntity.NonModuleSuperclass(XMLIO = "OUT", XMLPROJECTION = "element", XMLTYPECONSTRAINT = "substitutiongroup") [ Calculated ];

ClassMethod DefaultAPITag() As %String
{
	quit "%ZPM.PackageManager.Developer.Annotation.Tag.API.Object"
}

Method GetFriendlyIdentifier() As %String
{
	quit "class " _ ..Name
}

ClassMethod GetOwnerClassProxyID(pID As %Integer) As %Integer
{
	quit pID
}

Method CalculatedMembersGet() As %Collection.AbstractListOfObj [ CodeMode = objectgenerator ]
{
	// use an array collection to get things in order 
	set tCodeStream = %code
	do ##class(%ZPM.Utils.CodeGeneration).BuildRelationshipSorter(tCodeStream, "Members", "GetSortingKey()")
	
	quit $$$OK
}

Method CalculatedNonModuleSuperclassesGet() As %Collection.AbstractListOfObj [ CodeMode = objectgenerator ]
{
	// use an array collection to get things in order 
	set tCodeStream = %code
	do ##class(%ZPM.Utils.CodeGeneration).BuildRelationshipSorter(tCodeStream, "NonModuleSuperclasses", "ClassName")
	
	quit $$$OK
}

/// given a class name, populate the class proxy with annotations etc. 
ClassMethod BuildProxy(pModuleName As %String, pClassName As %Dictionary.Classname, pListOfModulesDependedOn As %Library.List, Output pNewProxy As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy) As %Status
{
	set tReturnVal = $$$OK 
	try {
		if pClassName = "" {  
			quit
		}
		
		if '$$$comClassDefined(pClassName) {
			$$$ThrowStatus($$$ERROR($$$CompiledClassDoesNotExist, pClassName))
		}
		
		set pNewProxy = ..%New()
		set pNewProxy.ModuleName = pModuleName
		set pNewProxy.Name = pClassName
		
  		set tClassDescription = $$$defClassKeyGet(pClassName, $$$cCLASSdescription)  
  		set tPrimarySuperChain = $$$comClassKeyGet(pClassName, $$$cCLASSprimarysuper)
  		set tImmediateSuperclasses = $$$comClassKeyGet(pClassName, $$$cCLASSsuper) // the set of classes in the "extends" clause
  		
  		// is there an XData block with tag override content? 
  		if $$$defMemberDefined(pClassName, $$$cCLASSxdata, "APIANNOTATIONS") {
	  		
	  		// rather than open the Dictionary object we'll get the XML content from ^oddDEF directly, for speed. 
	  		// If we were to do it using the %Dictionary, it would look like this: 		
	  		//set tClassXData = ##class(%Dictionary.XDataDefinition).%OpenId(pClassName_"||APIANNOTATIONS")
	  		//set tSC = tReader.OpenStream(tClassXData.Data)
	  		// If opening an XData object from the dictionary isn't as bad as opening a class object, we could do that instead. 
	  		
	  		set tTempStream = ##class(%Stream.TmpCharacter).%New()
	  		set tXDataLoop = ""
	  		while 1 {
		  		set tXDataLoop = $$$defSubMemberNext(pClassName, $$$cCLASSxdata, "APIANNOTATIONS", $$$cXDATAdata, tXDataLoop)
		  		quit:tXDataLoop=""
		  		
		  		set tXLine = $$$defMemberArrayGet(pClassName, $$$cCLASSxdata, "APIANNOTATIONS", $$$cXDATAdata, tXDataLoop)
		  		do tTempStream.Write(tXLine)
	  		}
	  		do tTempStream.Rewind()
	  		
	  		// now load it into an XML reader and build a temporary tree of class proxy objects using our existing class family
	  		set tReader = ##class(%XML.Reader).%New()
	  		set tSC = tReader.OpenStream(tTempStream)
	  		$$$ThrowOnError(tSC)
	  		do tReader.Correlate("API",$classname())
	  		#dim tOverrideDummy as %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy
	  		do tReader.Next(.tOverrideDummy, .tSC)
	  		$$$ThrowOnError(tSC)
	  		
	  		// now we extract the relevant info from the temporary objects and store it in an array for easier use
	  		set tKey = ""
	  		while 1 {
		  		set tTestMember = tOverrideDummy.Members.GetNext(.tKey)
		  		if tKey = "" {
			  		quit
		  		}
		  		
		  		if $$$defMemberDefined(pNewProxy.Name, tTestMember.#DictionaryKey,tTestMember.Name) {
			  		set tSC = pNewProxy.StoreWarning("Class " _ pNewProxy.Name _ "'s API XML contains data for a member that is overridden in the class. " _ 
			  				"The XML will be ignored; the new tag values should be tags on the member.")
			  		$$$ThrowOnError(tSC)
		  		}
		  		else {
		  			// get a simple array describing the override content. It will be initially subscripted by the oddDEF member type key and the member name
		  			do tTestMember.GetTagsAsArray(.tOverrideInfoTemp)
		  			merge pNewProxy.TagOverrideData(tTestMember.#DictionaryKey,tTestMember.Name) = tOverrideInfoTemp
		  		}
	  		}
	  		
	  		// and discard the temporary object tree
	  		kill tOverrideDummy
	  		
	  		/*
	  		Example: if the XData looks like this: 	  		
	  		
			<API>
				<Property Name="AllWelcome">
			      <API_Overrideable Availability="Universal"></API_Overrideable>
			    </Property>
				<Method Name="OverrideThisMethod">
					<API_Method Availability="Universal"/>
				</Method>
				<Method Name="AnotherSecretMethod">
					<API_Method Availability="InterSystems"/>
				</Method>
			</API>
	  		
	  		... then the array looks like this: 
	  		 
			pNewProxy.TagOverrideData("a","AllWelcome","API.Overrideable")=1
			pNewProxy.TagOverrideData("a","AllWelcome","API.Overrideable","Availability")="Universal"
			pNewProxy.TagOverrideData("m","AnotherSecretMethod","API.Method")=1
			pNewProxy.TagOverrideData("m","AnotherSecretMethod","API.Method","Availability")="InterSystems"
			pNewProxy.TagOverrideData("m","OverrideThisMethod","API.Method")=1
			pNewProxy.TagOverrideData("m","OverrideThisMethod","API.Method","Availability")="Universal"
			
			Note: we need to use this array into BuildProxies() so that we can replace the tag values as they 
			are added to the proxy objects. If we build them naively and then try to go back and overlay the content 
			at the end, that's insufficient because the values affect whether things are marked as "API" and so on. 
	  		*/
  		}
		
		// first process the class itself (especially to see if the class is @API.Extensible, which impacts treatment of overrideable members)
		set tSC = pNewProxy.ProcessComments(tClassDescription)
		$$$ThrowOnError(tSC)
		do pNewProxy.HandleClassInheritance(tPrimarySuperChain)	
		do pNewProxy.CheckExtensionFromSuperclasses(tImmediateSuperclasses, tPrimarySuperChain, pListOfModulesDependedOn)
  		
  		// then process all class members
		do ##class(QueryProxy).BuildProxies(pNewProxy)
		do ##class(QueryMethodProxy).BuildProxies(pNewProxy)
		do ##class(ParameterProxy).BuildProxies(pNewProxy)
		do ##class(PropertyProxy).BuildProxies(pNewProxy)
		do ##class(MethodProxy).BuildProxies(pNewProxy)
		
		if pNewProxy.IsAPI {
			do pNewProxy.SupplyMissingTags()
		}
		
		// now save the class object
		set tSC = pNewProxy.%Save()
		$$$ThrowOnError(tSC)
	}
	catch tException {
		set tReturnVal = tException.AsStatus()
	}
	
	quit tReturnVal
}

/// looks at all the immediate superclasses and checks whether any of them are non-extensible 
/// members of other modules, etc. 
Method CheckExtensionFromSuperclasses(pImmediateSuperclasses As %String, pPrimarySuperChain As %String, pListOfModulesDependedOn As %Library.List)
{
	set tSuperClassList = $listfromstring(pImmediateSuperclasses)
	set tExtensibilityQueryReady = 0
	
	// we'll need to hop around between namespaces if the superclasses are mapped in
	new $namespace
	
	#dim tAvailabilityQueries as %Library.ArrayOfObjects 
	set tAvailabilityQueries = ##class(%Library.ArrayOfObjects).%New()
	
	set tPointer = 0
	while $listnext(tSuperClassList, tPointer, tSuperclassName) {
		set $namespace = %HomeNamespace
		
		set tSuperclassNamespace = ..NamespaceForModuleClass(tSuperclassName, .tSuperclassProxyID)
		
		if tSuperclassNamespace '= "" {
			// we found a class proxy for the superclass. Note that we do not "quit" from the "while" loop
			// at the end of this "if" block, because a class can extend more than one superclass, and we 
			// want to check them all
			set $namespace = tSuperclassNamespace
			
			set tSuperClassModuleName = ..ModuleNameGetStored(tSuperclassProxyID)			
			if tSuperClassModuleName '= %ModuleName {
				// the superclass is in another module. 
				
				// do we have that other module in our dependency tree? 
				if $listfind(pListOfModulesDependedOn,tSuperClassModuleName) = 0 {
					set tSC = ..StoreWarning("Class " _ ..Name _ " extends " _ tSuperclassName _ " from module " _ tSuperClassModuleName _ ", which is not specified as a dependency in the module manifest for " _ %ModuleName)
					$$$ThrowOnError(tSC)
					if tSuperclassNamespace = %HomeNamespace {
						/*
						If we have a dependency on another module, it must be declared unless 
						the other module resides in another namespace. We do not support cross-namespace 
						dependency declaration, although we support cross-namespace subclassing in practice. 
						If it's a cross-namespace situation we just log the warning and proceed, but if 
						it's in the same namespace we move on to the next superclass in the list
						*/
						continue 
					}
				}
				
				// is it extensible? 
				if $get(tExtensibilityQueryReady($namespace), 0) = 0 {
					set tSQL = "select Availability from %ZPM_PackageManager_Developer_Annotation_Tag_API.Extensible " 
						_ "where OwnerClass = ?"
					set tExtensibilityStatement = ##class(%SQL.Statement).%New()
					set tSC = tExtensibilityStatement.%Prepare(tSQL)
					$$$ThrowOnError(tSC)
					
					set tExtensibilityQueryReady($namespace) = 1
					set tSC = tAvailabilityQueries.SetAt(tExtensibilityStatement, $namespace)
					$$$ThrowOnError(tSC)
				}
				else {
					set tExtensibilityStatement = tAvailabilityQueries.GetAt($namespace)
				}
				
				set tRecords = tExtensibilityStatement.%Execute(tSuperclassProxyID)
				if tRecords.%SQLCODE < 0 {
					set tSQLError = $$$ERROR($$$SQLCode,tRecords.%SQLCODE,tRecords.%Message) 
					set tContextError = $$$ERROR($$$GeneralError, "Failed to query extensibility info for class " _ $get(tLoopClassName))
					$$$ThrowStatus($$$EMBEDSC(tContextError, tSQLError))
				}
				
				set tFoundOK = 0
				if tRecords.%SQLCODE = 0 {
					if tRecords.%Next() {
						set tAvailability = tRecords.%Get("Availability")
						if tAvailability '= $$$ZPMAvailabilityForbidden {
							set tFoundOK = 1
						}
					}
				}
				
				if tFoundOK = 0 {
					set tSC = ..StoreWarning("Class " _ ..Name _ " extends " _ tSuperclassName _ " from module " _ tSuperClassModuleName _ ", but that parent class is not marked as extensible")
					$$$ThrowOnError(tSC)
				}
				
				// pick up all of the non-module superclasses we get via this particular superclass
				set tKey = ""
				set tSuperClassModule = ..%OpenId(tSuperclassProxyID,,.tSC)
				$$$ThrowOnError(tSC)
				
				while 1 {
					set tNonModuleSuper = tSuperClassModule.NonModuleSuperclasses.GetNext(.tKey)
					if tKey = "" {
						quit
					}
					set tNonModuleSuperclasses(tNonModuleSuper.ClassName) = 1
				}	
			}
		}
		else {
			// we're extending a non-module class
			set tNonModuleSuperclasses(tSuperclassName) = 1
		}
	}
	
	// now we create persistent info about the non-module superclasses, for inclusion in the API manifest for full disclosure
	set tNonModuleSuperName = "" 
	while 1 {
		set tNonModuleSuperName = $order(tNonModuleSuperclasses(tNonModuleSuperName))
		if tNonModuleSuperName = "" {
			quit
		}
		
		set tNewNonModuleSuper = ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.NonModuleSuperclass).%New()
		set tNewNonModuleSuper.ClassName = tNonModuleSuperName
		set tNewNonModuleSuper.InPrimaryAncestry = ($find(pPrimarySuperChain, "~" _ tNonModuleSuperName _ "~") > 0)
		set tNewNonModuleSuper.AppliesTo = $this
		
		// current instance is not yet saved, so we don't %Save() here 
	}
}

Method HandleClassInheritance(pPrimarySuper As %String)
{
	set tSuperClassList = $listfromstring(pPrimarySuper,"~")
	
	// trim out the empty initial item and the current class name item, as well as the empty item at the end
	set tSuperClassList = $list(tSuperClassList,3,*-1)
	
	/*
	For classes we only care about inheriting info from the primary superclass, recursively. 
	
	The .PrimarySuper property of the dictionary object looks like this: 
	~HSMOD.Sample.Inheritor~HSMOD.Sample.Super~HSMOD.Sample.SuperDuper~%Library.Persistent~%Library.SwizzleObject~%Library.RegisteredObject~%Library.Base~%Library.SystemBase~
	
	So it's a string delimited by "~", starting with the current class, going up as far as it goes along the primary
	inheritance path. We have built this into a $list. 
	
	We have to loop through this until both of the following are true: 
	a) we are sure we have a "description" OR we reach the end of the line 
	and 
	b) we reach the stratosphere of library classes and leave the world of module classes where annotations might be found
	
	Note that a subclass with no explicit comment block will have an empty Description property. 
	In other words, when you compile a subclass it doesn't inherit the comment block; presumably Documatic 
	recurses back through the primaries as well, when it's displaying the class description. 
	
	So we can't just look at the first primary superclass, we have to follow the trail up 
	if we're looking for the class description. This does not seem to be the same for class members, so the 
	code in the ClassMemberProxy class doesn't need to go deep in this direction. 
	*/
		
	// make a lookup array of the tags we have
	do ..InitializeTagNameArray(.tTagList, .tTagCount)
	
	// how many tags is the "full set"?
	set tTotalTagLimit = $listlength(..AcceptableTagList())
	
	// we'll need to hop around between namespaces if the superclasses are mapped in
	new $namespace
	
	set tPtr = 0
	while $listnext(tSuperClassList, tPtr, tLoopClassName)
	{
		// is it a module class ?
		kill tLoopClassProxy
		set $namespace = %HomeNamespace
		
		set tSuperclassNamespace = ..NamespaceForModuleClass(tLoopClassName, .tProxyID)
		if tSuperclassNamespace '= "" {
			
			set $namespace = tSuperclassNamespace
			set tLoopClassProxy = ..%OpenId(tProxyID,,.tSC)
			$$$ThrowOnError(tSC)
			
			// first, do we need to inherit the text comment (description)?  
			if (..CommentBlock = "") && (tLoopClassProxy.CommentBlock '= "") {
				set ..CommentBlock = tLoopClassProxy.CommentBlock
			}
			
			// now look at annotations ... assuming we don't already have them all
			if tTagCount = tTotalTagLimit {
				continue
			}
			
			do ..InheritTags(.tTagList, .tTagCount, tLoopClassProxy)
			
			// can we quit out of the loop early? 
			if (tTagCount = tTotalTagLimit) && (..CommentBlock '= "") {
				quit
			}			
		}
		else {
			// it's a "library" class or something else that isn't in a module
			if ..CommentBlock '= "" {
				// we're done
				quit
			}
			else {
				set ..CommentBlock = $$$defClassKeyGet(tLoopClassName, $$$cCLASSdescription)
			}
		}		
	}
}

Storage Default
{
<Data name="ClassProxyDefaultData">
<Subscript>"ClassProxy"</Subscript>
<Value name="1">
<Value>ModuleName</Value>
</Value>
</Data>
<DefaultData>ClassProxyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
