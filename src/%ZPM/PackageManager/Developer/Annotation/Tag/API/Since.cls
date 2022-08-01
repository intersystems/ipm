/// tag for @API.Since
Class %ZPM.PackageManager.Developer.Annotation.Tag.API.Since Extends (%ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag, %ZPM.PackageManager.Developer.Annotation.Tag.SupportsVersionValue)
{

Parameter XMLNAME = "API_Since";

Method HandleExtraContent(ByRef pCommentBlock As %Library.RawString, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity) [ Private ]
{
	do ..HandleVersionContent(.pCommentBlock, pContextObject, ..ShortTagName())
}

Storage Default
{
<Data name="SinceDefaultData">
<Subscript>"Since"</Subscript>
<Value name="1">
<Value>VersionValue</Value>
</Value>
</Data>
<DefaultData>SinceDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
