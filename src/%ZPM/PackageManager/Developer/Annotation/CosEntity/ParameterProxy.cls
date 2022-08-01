/// proxy for class parameters (NOT method arguments)
Class %ZPM.PackageManager.Developer.Annotation.CosEntity.ParameterProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassMemberProxy
{

Parameter XMLNAME = "Parameter";

Parameter AcceptableAnchorTags = "API.Overrideable,API.Parameter,DoesNotInheritTags";

Property ParameterValue As %String(MAXLEN = "");

Parameter DictionaryKey = {$$$cCLASSparameter};

Index ParameterProxyExtentIndex [ Extent ];

Method HandleExtraProperties()
{
	set ..ParameterValue = $$$defMemberKeyGet(..ParentClassName, $$$cCLASSparameter, ..Name, $$$cPARAMdefault)
}

Storage Default
{
<Data name="ParameterProxyDefaultData">
<Subscript>"ParameterProxy"</Subscript>
<Value name="1">
<Value>ParameterValue</Value>
</Value>
</Data>
<DefaultData>ParameterProxyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
