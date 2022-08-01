/// tag for @ReturnValue, for documenting method return values
Class %ZPM.PackageManager.Developer.Annotation.Tag.ReturnValue Extends %ZPM.PackageManager.Developer.Annotation.Tag.Multiline
{

Parameter XMLNAME = "ReturnValueComment";

Parameter MultiLineProperty = "Documentation";

Property Documentation As %String(MAXLEN = 2000, XMLPROJECTION = "content");

Storage Default
{
<Data name="ReturnValueDefaultData">
<Subscript>"ReturnValue"</Subscript>
<Value name="1">
<Value>Documentation</Value>
</Value>
</Data>
<DefaultData>ReturnValueDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
