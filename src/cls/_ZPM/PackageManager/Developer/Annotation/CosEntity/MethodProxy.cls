Class %ZPM.PackageManager.Developer.Annotation.CosEntity.MethodProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity.MemberWithArguments
{

Parameter XMLNAME = "Method";

Parameter AcceptableAnchorTags = "API.Overrideable,API.Method,DoesNotInheritTags";

Parameter DictionaryKey = {$$$cCLASSmethod};

Parameter ParsedSpecKey = {$$$cMETHformalspecparsed};

/// there will never be more than one return value, but we use a many-to-one relationship for simpler manipulation
Relationship ReturnValue As %ZPM.PackageManager.Developer.Annotation.CosEntity.ReturnValueProxy(XMLPROJECTION = "element", XMLTYPECONSTRAINT = "choice") [ Cardinality = many, Inverse = ParentMethod ];

Property ClassMethod As %Boolean(XMLPROJECTION = "attribute");

Index MethodProxyExtentIndex [ Extent ];

/// exclude implementation methods for custom queries (that is, queries of %Query type)
ClassMethod SkipProxy(pParentClassName As %Dictionary.Classname, pMemberName As %String) As %Boolean
{
	if $$$comMemberKeyGet(pParentClassName, ..#DictionaryKey, pMemberName, $$$cMETHstubmember) '= "" {
		quit 1
	}
	quit 0
}

Method HandleExtraProperties()
{
	set tIsClassMethod = $$$defMemberKeyGet(..ParentClassName, $$$cCLASSmethod, ..Name, $$$cMETHclassmethod)
	set ..ClassMethod = ''$get(tIsClassMethod,0)
	
	// get the return value
	set tReturnType = $$$comMemberKeyGet(..ParentClassName, $$$cCLASSmethod, ..Name, $$$cMETHreturntype)
	if tReturnType '= "" {	
		#dim tReturnValueObj as %ZPM.PackageManager.Developer.Annotation.CosEntity.ReturnValueProxy
		set tReturnValueObj = ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.ReturnValueProxy).%New()
		set tReturnValueObj.DataType = tReturnType
		set tReturnValueObj.ParentMethod = $this
	}
	
	do ##super()
}

/// when we find an Argument or ReturnValue tag in a method, we farm those out to the sub-objects. Otherwise 
/// we handle as usual. 
Method AssignTag(pNewTag As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag) As %Status
{
	if pNewTag.%IsA("%ZPM.PackageManager.Developer.Annotation.Tag.ReturnValue") {		
		#dim tRVObject as %ZPM.PackageManager.Developer.Annotation.CosEntity.ReturnValue
		set tRVObject = ..ReturnValue.GetAt(1)
		if '$isobject(tRVObject) {
			quit $$$ERROR($$$GeneralError, "No return value found for method " _ ..Name _ " in class " _ ..ParentClassName _ "; can't use @ReturnValue tag")
		}
		quit tRVObject.AssignTag(pNewTag)		
	}
	
	// default case for tags other than ReturnValue, including Arguments
	quit ##super(pNewTag)
}

Method ValidateTags()
{
	do ##super()
	
	set tRetValCount = 0
	set tKey = ""
	while 1 {
		set tRetValObject = ..ReturnValue.GetNext(.tKey)
		if tKey = "" {
			quit
		}
		set tRetValCount = tRetValCount + 1
		if tRetValCount > 1 {
			$$$ThrowOnError(..StoreWarning("A method can't have more than one return value"))
		}
	}
}

Method SpecialMemberInheritance(pSuperMember As %ZPM.PackageManager.Developer.Annotation.CosEntity.MethodProxy)
{
	do ##super(pSuperMember) // handle arguments etc. 
	
	// handle return value; slightly simpler than the argument case because we assume there is only one
	#dim tRetValProxy as ReturnValueProxy
	set tTagCountLimit = $listlength(##class(ReturnValueProxy).AcceptableTagList())
	
	set tKey = ""
	if ..ReturnValue.Count() = 1 {
		set tRetValProxy = ..ReturnValue.GetNext(.tKey)
		do tRetValProxy.InitializeTagNameArray(.tTagNameArray, .tTagCount)
		if tTagCount = tTagCountLimit {
			quit 
		}
		set tSuperRetval = pSuperMember.ReturnValue.GetAt(1)
		do tRetValProxy.InheritTags(.tTagNameArray, .tTagCount, tSuperRetval)
	}
}

Method SupplyMissingTags()
{
	do ##super()
	
	#dim tRetValProxy as ReturnValueProxy
	set tKey = ""
	if ..ReturnValue.Count() = 1 {
		set tRetValProxy = ..ReturnValue.GetNext(.tKey)
		do tRetValProxy.SupplyMissingTags()
	}
}

Storage Default
{
<Data name="MethodProxyDefaultData">
<Subscript>"MethodProxy"</Subscript>
<Value name="1">
<Value>ClassMethod</Value>
</Value>
</Data>
<DefaultData>MethodProxyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
