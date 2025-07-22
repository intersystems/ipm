Class %IPM.Storage.UpdateStep Extends %Persistent
{

Property ClassName As %Dictionary.Classname;

Property MethodName As %Dictionary.Identifier;

Property Mirrored As %Boolean;

Property TimeStampStart As %Library.DateTime;

Property TimeStampEnd As %Library.DateTime;

Property MirroredHostName As %String(MAXLEN = 255);

Property MirroredInstanceName As %String(MAXLEN = 255);

Index UpdateClassMethodIdx On (MethodName, ClassName, MirroredHostName, MirroredInstanceName) [ Unique ];

Property Status As %Status;

// Relationship ModuleHome As %IPM.Storage.Module [ Cardinality = many, Inverse = oneProp ];

Method %OnNew(
	className As %String = "",
	methodName As %String = "",
	mirrored As %Boolean = 1,
	mirroredHostName As %String = "",
	mirroredInstanceName As %String = "") As %Status
{
    set ..ClassName = className
    set ..MethodName = methodName
    set ..Mirrored = mirrored
    set uniqueInstanceName = ##class(%SYS.System).GetUniqueInstanceName()
    set ..MirroredHostName = $piece(uniqueInstanceName, ":", 1)
    set ..MirroredInstanceName = $piece(uniqueInstanceName, ":", 2)
    set ..Status = $$$OK

    return $$$OK
}

Storage Default
{
<Data name="UpdateStepDefaultData">
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
<Value>Mirrored</Value>
</Value>
<Value name="9">
<Value>TimeStampStart</Value>
</Value>
<Value name="10">
<Value>TimeStampEnd</Value>
</Value>
<Value name="11">
<Value>ModuleHome</Value>
</Value>
</Data>
<DataLocation>^%IPM.Storage.UpdateStepD</DataLocation>
<DefaultData>UpdateStepDefaultData</DefaultData>
<IdLocation>^%IPM.Storage.UpdateStepD</IdLocation>
<IndexLocation>^%IPM.Storage.UpdateStepI</IndexLocation>
<StreamLocation>^%IPM.Storage.UpdateStepS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
