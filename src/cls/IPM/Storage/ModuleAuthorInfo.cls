Class %IPM.Storage.ModuleAuthorInfo Extends (%SerialObject, %XML.Adaptor, %IPM.Utils.ComparisonAdaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleAuthorInfo";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Parameter XMLIGNOREINVALIDTAG = 1;

Parameter XMLIGNOREINVALIDATTRIBUTE = 1;

Property Person As %String(MAXLEN = 255);

Property Organization As %String(MAXLEN = 255);

Property CopyrightDate As %String(MAXLEN = 255);

Property License As %String(MAXLEN = 1000);

Property Notes As %String(MAXLEN = "");

Storage Default
{
<Data name="ModuleAuthorInfoState">
<Value name="1">
<Value>Person</Value>
</Value>
<Value name="2">
<Value>Organization</Value>
</Value>
<Value name="3">
<Value>CopyrightDate</Value>
</Value>
<Value name="4">
<Value>License</Value>
</Value>
<Value name="5">
<Value>Notes</Value>
</Value>
</Data>
<State>ModuleAuthorInfoState</State>
<StreamLocation>^IPM.Storage.ModuleAuthorInfoS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
