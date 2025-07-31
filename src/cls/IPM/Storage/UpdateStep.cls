Class %IPM.Storage.UpdateStep Extends %Persistent
{

Property ClassName As %Dictionary.Classname [ Required ];

Property MethodName As %Dictionary.Identifier [ Required ];

Property HostName As %String(MAXLEN = 255) [ Required ];

Property InstanceName As %String(MAXLEN = 255) [ Required ];

Index UpdateClassMethodIdx On (ClassName, MethodName, HostName, InstanceName) [ Unique ];

Property Mirrored As %Boolean;

Property TimeStampStart As %Library.DateTime;

Property TimeStampEnd As %Library.DateTime;

Property Status As %Status;

Relationship ModuleHome As %IPM.Storage.Module [ Cardinality = one, Inverse = UpdateSteps, OnDelete = cascade ];

Method %OnNew(
	className As %String = "",
	methodName As %String = "",
	mirrored As %Boolean = 1,
	hostName As %String = "",
	instanceName As %String = "") As %Status
{
    set ..ClassName = className
    set ..MethodName = methodName
    set ..Mirrored = mirrored
    if hostName = "" {
        set ..HostName = ##class(%SYS.System).GetNodeName()
    }
    if instanceName = "" {
        set ..InstanceName = ##class(%SYS.System).GetInstanceName()
    }
    set ..Status = $$$OK

    return $$$OK
}

/// Returns %IPM.Storage.UpdateStep object corresponding to unique index in storage table
/// If object does not exist, this will return an empty object
ClassMethod GetUpdateStep(
	className As %String,
	methodName As %String,
	hostName As %String,
	instanceName As %String) As %IPM.Storage.UpdateStep
{
    do ..UpdateClassMethodIdxExists(className, methodName, hostName, instanceName, .stepId)
    return ..%OpenId(stepId)
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
<Value>HostName</Value>
</Value>
<Value name="6">
<Value>InstanceName</Value>
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
