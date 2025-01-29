Class %IPM.StudioDocument.ModuleStream Extends %IPM.StudioDocument.AbstractStream
{

Parameter DEFAULTGLOBAL = "^IPM.StudioDoc.ModuleStream";

Storage Default
{
<Data name="ModuleStreamDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Contents</Value>
</Value>
<Value name="4">
<Value>Hash</Value>
</Value>
<Value name="5">
<Value>LastModifiedTimestamp</Value>
</Value>
</Data>
<DataLocation>^IPM.StudioDoc.ModuleStreamD</DataLocation>
<DefaultData>ModuleStreamDefaultData</DefaultData>
<IdLocation>^IPM.StudioDoc.ModuleStreamD</IdLocation>
<IndexLocation>^IPM.StudioDoc.ModuleStreamI</IndexLocation>
<StreamLocation>^IPM.StudioDoc.ModuleStreamS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
