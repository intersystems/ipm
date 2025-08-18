/// Storage class for update steps to run on a primary mirror member only
Class %IPM.Storage.UpdateStep.PrimaryOnly Extends %IPM.Storage.UpdateStep.Base
{

/// HostName where the update step was last ran
Property HostName As %String(MAXLEN = 255) [ InitialExpression = {##class(%SYS.System).GetNodeName()}, Required ];

/// InstanceName where the update step was last ran
Property InstanceName As %String(MAXLEN = 255) [ InitialExpression = {##class(%SYS.System).GetInstanceName()}, Required ];

Index UpdateClassMethodIdx On (ClassName, MethodName) [ Unique ];

Method %OnNew(
	className As %String = "",
	methodName As %String = "") As %Status
{
    set ..ClassName = className
    set ..MethodName = methodName

    return $$$OK
}

/// Returns %IPM.Storage.UpdateStep.PrimaryOnly object corresponding to unique index in storage table
/// If object does not exist, this will return an empty object
ClassMethod GetUpdateStep(
	className As %String,
	methodName As %String) As %IPM.Storage.UpdateStep.PrimaryOnly
{
    do ..UpdateClassMethodIdxExists(className, methodName, .stepId)
    return ..%OpenId(stepId)
}

Storage Default
{
<Data name="PrimaryOnlyDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ClassName</Value>
</Value>
<Value name="3">
<Value>InstanceName</Value>
</Value>
<Value name="4">
<Value>TimeStampStart</Value>
</Value>
<Value name="5">
<Value>TimeStampEnd</Value>
</Value>
<Value name="6">
<Value>Status</Value>
</Value>
<Value name="7">
<Value>HomeModule</Value>
</Value>
<Value name="8">
<Value>HostName</Value>
</Value>
<Value name="9">
<Value>MethodName</Value>
</Value>
</Data>
<DataLocation>^%IPM.Storage.UpC3A.PrimaryOnlyD</DataLocation>
<DefaultData>PrimaryOnlyDefaultData</DefaultData>
<IdLocation>^%IPM.Storage.UpC3A.PrimaryOnlyD</IdLocation>
<IndexLocation>^%IPM.Storage.UpC3A.PrimaryOnlyI</IndexLocation>
<StreamLocation>^%IPM.Storage.UpC3A.PrimaryOnlyS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
