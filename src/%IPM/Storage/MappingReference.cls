Class %IPM.Storage.MappingReference Extends (%Persistent, %XML.Adaptor, %IPM.Utils.ComparisonAdaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.MappingReference";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Name As %String(MAXLEN = 2048, XMLPROJECTION = "attribute") [ Required ];

/// Name index is unique per namespace.
Index ResourceName On (Name, Source);

Relationship Module As %IPM.Storage.Module(XMLPROJECTION = "NONE") [ Cardinality = parent, Inverse = Mappings ];

/// Namespace from which it is mapped or copied
Property Source As %String(XMLPROJECTION = "ATTRIBUTE");

/// If set to true, this source code is not shipped in application packaging.
/// (Of course, it must be included in module packaging.)
Property Deploy As %Boolean(XMLPROJECTION = "ATTRIBUTE");

Storage Default
{
<Data name="MappingReferenceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Source</Value>
</Value>
<Value name="4">
<Value>Deploy</Value>
</Value>
</Data>
<DataLocation>{%%PARENT}("Mappings")</DataLocation>
<DefaultData>MappingReferenceDefaultData</DefaultData>
<IdLocation>^IPM.Storage.MappingReferenceC("Mappings")</IdLocation>
<IndexLocation>^IPM.Storage.MappingReferenceI</IndexLocation>
<StreamLocation>^IPM.Storage.MappingReferenceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
