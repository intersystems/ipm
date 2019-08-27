Class %ZPM.PackageManager.Developer.APIDocumentation Extends (%SerialObject, %XML.Adaptor)
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Type As %String(VALUELIST = ",class,routine,include,other", XMLPROJECTION = "attribute");

Property SubType As %String(XMLPROJECTION = "attribute");

Property Name As %String(MAXLEN = 500, XMLPROJECTION = "attribute");

Property Public As %Boolean(XMLPROJECTION = "attribute") [ InitialExpression = 0 ];

Storage Default
{
<Data name="APIDocumentationState">
<Value name="1">
<Value>Type</Value>
</Value>
<Value name="2">
<Value>SubType</Value>
</Value>
<Value name="3">
<Value>Name</Value>
</Value>
<Value name="4">
<Value>Public</Value>
</Value>
</Data>
<State>APIDocumentationState</State>
<StreamLocation>^ZPM.PackageManager.APIDocumentS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
