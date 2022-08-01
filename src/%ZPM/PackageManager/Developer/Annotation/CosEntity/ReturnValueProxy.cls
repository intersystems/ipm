Class %ZPM.PackageManager.Developer.Annotation.CosEntity.ReturnValueProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity
{

Parameter XMLNAME = "ReturnValue";

Parameter AcceptableAnchorTags = "ReturnValue";

Property DataType As %Dictionary.Classname(XMLPROJECTION = "attribute");

Relationship ParentMethod As %ZPM.PackageManager.Developer.Annotation.CosEntity.MethodProxy [ Cardinality = one, Inverse = ReturnValue, OnDelete = cascade ];

Index ReturnValueProxyExtentIndex [ Extent ];

ClassMethod GetOwnerClassProxyID(pID As %Integer) As %Integer
{
	set tParentMethodID = ..ParentMethodGetStored(pID)
	quit ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.MethodProxy).GetOwnerClassProxyID(tParentMethodID)
}

Method GetFriendlyIdentifier() As %String
{
	quit ..ParentMethod.GetFriendlyIdentifier() _ ", return value"
}

Storage Default
{
<Data name="ReturnValueProxyDefaultData">
<Subscript>"ReturnValueProxy"</Subscript>
<Value name="1">
<Value>DataType</Value>
</Value>
<Value name="2">
<Value>ParentMethod</Value>
</Value>
</Data>
<DefaultData>ReturnValueProxyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
