/// tag for @API.Deprecated
Class %ZPM.PackageManager.Developer.Annotation.Tag.API.Deprecated Extends (%ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag, %ZPM.PackageManager.Developer.Annotation.Tag.SupportsVersionValue)
{

Parameter XMLNAME = "API_Deprecated";

Method HandleExtraContent(ByRef pCommentBlock As %Library.RawString, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity) [ Private ]
{
	do ..HandleVersionContent(.pCommentBlock, pContextObject, ..ShortTagName())
}

Storage Default
{
<Data name="DeprecatedDefaultData">
<Subscript>"Deprecated"</Subscript>
<Value name="1">
<Value>VersionValue</Value>
</Value>
</Data>
<DefaultData>DeprecatedDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
