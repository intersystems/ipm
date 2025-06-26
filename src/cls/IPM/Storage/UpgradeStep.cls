Class %IPM.Storage.UpgradeStep Extends %Persistent
{

Property ClassName As %Dictionary.Classname;

Property MethodName As %Dictionary.Identifier;

Property TimeStamp As %Library.DateTime;

Property MirroredHostName As %String(MAXLEN = 255);

Property MirroredInstanceName As %String(MAXLEN = 255);

Index UpgradeClassMethodIdx On (MethodName, ClassName) [ Unique ];

Property Status As %Status;

// Relationship ModuleHome As %IPM.Storage.Module [ Cardinality = one, Inverse = manyProp ];

Method %OnNew(
	className As %String = "",
	methodName As %String = "",
	timestamp As %Library.DateTime) As %Status
{
    Set ..ClassName = className
    Set ..MethodName = methodName
    // TODO: Should default to current time be determined here or the method which instantiates the new object?
    If '##class(%Library.DateTime).IsValid(timestamp) {
        Set timestamp = $zdt($h,3)
    }
    Set ..TimeStamp = timestamp
    Set ..MirroredHostName = ""
    Set ..MirroredInstanceName = ##class(%SYS.System).GetUniqueInstanceName()
    Set ..Status = $$$OK

    Return $$$OK
}

Storage Default
{
<Data name="UpgradeStepDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ClassName</Value>
</Value>
<Value name="3">
<Value>MethodName</Value>
</Value>
<Value name="4">
<Value>TimeStamp</Value>
</Value>
<Value name="5">
<Value>MirroredHostName</Value>
</Value>
<Value name="6">
<Value>MirroredInstanceName</Value>
</Value>
<Value name="7">
<Value>Status</Value>
</Value>
<Value name="8">
<Value>Module</Value>
</Value>
<Value name="9">
<Value>ModuleHome</Value>
</Value>
</Data>
<DataLocation>^%IPM.Storage.UpgradeStepD</DataLocation>
<DefaultData>UpgradeStepDefaultData</DefaultData>
<IdLocation>^%IPM.Storage.UpgradeStepD</IdLocation>
<IndexLocation>^%IPM.Storage.UpgradeStepI</IndexLocation>
<StreamLocation>^%IPM.Storage.UpgradeStepS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
