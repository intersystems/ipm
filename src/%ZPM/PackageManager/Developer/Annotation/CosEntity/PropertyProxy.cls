Class %ZPM.PackageManager.Developer.Annotation.CosEntity.PropertyProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassMemberProxy
{

Parameter XMLNAME = "Property";

Parameter AcceptableAnchorTags = "API.Overrideable,API.Property,DoesNotInheritTags";

Property DataType As %Dictionary.Classname;

Parameter DictionaryKey = {$$$cCLASSproperty};

Index PropertyProxyExtentIndex [ Extent ];

Method HandleExtraProperties()
{
	set ..DataType = $$$comMemberKeyGet(..ParentClassName, $$$cCLASSproperty, ..Name, $$$cPROPtype)
}

Storage Default
{
<Data name="PropertyProxyDefaultData">
<Subscript>"PropertyProxy"</Subscript>
<Value name="1">
<Value>DataType</Value>
</Value>
</Data>
<DefaultData>PropertyProxyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
