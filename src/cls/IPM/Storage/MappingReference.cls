Class %IPM.Storage.MappingReference Extends (%Persistent, %XML.Adaptor, %IPM.Utils.ComparisonAdaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.MappingReference";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Name As %String(MAXLEN = 2048, XMLPROJECTION = "attribute") [ Required ];

/// Name index is unique per namespace.
Index ResourceName On (Name, Source);

Relationship Module As %IPM.Storage.Module(XMLPROJECTION = "NONE") [ Cardinality = parent, Inverse = Mappings, SqlFieldName = ModuleItem ];

/// Database from which it is mapped or copied
Property Source As %String(MAXLEN = 64, XMLPROJECTION = "ATTRIBUTE");

/// Resolved value after evaluating any permitted expressions in <property>Source</property>.
Property SourceResolved As %String(MAXLEN = 64, XMLPROJECTION = "NONE") [ SqlComputeCode = { Set {*} = ##class(%IPM.Utils.Module).%EvaluateSystemExpression({Source}) }, SqlComputed ];

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
<Value name="5">
<Value>SourceResolved</Value>
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
