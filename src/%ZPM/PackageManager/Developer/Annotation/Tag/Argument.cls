/// tag for @Argument, used to document method arguments
Class %ZPM.PackageManager.Developer.Annotation.Tag.Argument Extends %ZPM.PackageManager.Developer.Annotation.Tag.Multiline
{

/// this tag serves only to carry documentation for the argument. Therefore we display its Documentation property 
/// as if it were the full content of the element, and we change the name to masquerade as the documentation. 
Parameter XMLNAME = "ArgumentComment";

Parameter MultiLineProperty = "Documentation";

Property Documentation As %String(MAXLEN = 2000, XMLPROJECTION = "content");

/// used during processing; when processing is done this tag object will be in the annotations collection 
/// of the argument proxy object, at which point this property is redundant. 
Property ArgumentName As %String(XMLPROJECTION = "none");

Method HandleExtraContent(ByRef pCommentBlock As %Library.RawString, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity) [ Private ]
{
	set tArgName = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).PopWhitespacePiece(.pCommentBlock)
	set ..ArgumentName = tArgName
	do ##super(.pCommentBlock, pContextObject) // process the rest of the line & remainder of commentary if any
}

Storage Default
{
<Data name="ArgumentDefaultData">
<Subscript>"Argument"</Subscript>
<Value name="1">
<Value>Documentation</Value>
</Value>
<Value name="2">
<Value>ArgumentName</Value>
</Value>
</Data>
<DefaultData>ArgumentDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
