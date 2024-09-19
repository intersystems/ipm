Class IPM.General.History Extends %Persistent
{

Property Action As %String(VALUELIST = ",load,install,uninstall") [ Required ];

Property Package As %IPM.DataType.ModuleName [ Required ];

Property Version As %IPM.General.SemanticVersion [ Required ];

Property SourceName As %String(MAXLEN = 100);

Property SourceMoniker As %String(MAXLEN = 100);

Property SourceDetails As %String(MAXLEN = "");

Property TimeStamp As %TimeStamp [ Required ];

Property NameSpace As %String [ InitialExpression = {$NAMESPACE}, Required ];

Property UserName As %String [ InitialExpression = {$USERNAME}, Required ];

Property Success As %Status [ Required ];

Property Committed As %Boolean [ Required ];

Property CommandString As %String(MAXLEN = 8192) [ Required ];

Storage Default
{
<Data name="HistoryDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Package</Value>
</Value>
<Value name="3">
<Value>Action</Value>
</Value>
<Value name="4">
<Value>Version</Value>
</Value>
<Value name="5">
<Value>SourceName</Value>
</Value>
<Value name="6">
<Value>SourceMoniker</Value>
</Value>
<Value name="7">
<Value>SourceDetails</Value>
</Value>
<Value name="8">
<Value>TimeStamp</Value>
</Value>
<Value name="9">
<Value>NameSpace</Value>
</Value>
<Value name="10">
<Value>UserName</Value>
</Value>
<Value name="11">
<Value>Success</Value>
</Value>
<Value name="12">
<Value>Committed</Value>
</Value>
<Value name="13">
<Value>CommandString</Value>
</Value>
</Data>
<DataLocation>^IPM.General.HistoryD</DataLocation>
<DefaultData>HistoryDefaultData</DefaultData>
<IdLocation>^IPM.General.HistoryD</IdLocation>
<IndexLocation>^IPM.General.HistoryI</IndexLocation>
<StreamLocation>^IPM.General.HistoryS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
