Class %ZPM.PackageManager.Developer.Annotation.CosEntity.QueryMethodProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity.MemberWithArguments
{

Parameter XMLNAME = "QueryMethod";

Parameter AcceptableAnchorTags = "API.Overrideable,DoesNotInheritTags";

Parameter DictionaryKey = {$$$cCLASSmethod};

Parameter ParsedSpecKey = {$$$cMETHformalspecparsed};

/// does NOT accept the since/deprecated tags
Parameter CommonTags;

/// filter for implementation methods for custom queries (that is, queries of %Query type)
ClassMethod SkipProxy(pParentClassName As %Dictionary.Classname, pMemberName As %String) As %Boolean
{
	// query methods store the query name under the "stub member" subscript
	if $$$comMemberKeyGet(pParentClassName, ..#DictionaryKey, pMemberName, $$$cMETHstubmember) = "" {
		quit 1
	}
	quit 0
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
