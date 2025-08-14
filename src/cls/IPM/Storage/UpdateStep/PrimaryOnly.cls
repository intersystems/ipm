/// %IPM.Storage.UpdateStep.Base subclass with information specific to update steps to run on a primary mirror member only
Class %IPM.Storage.UpdateStep.PrimaryOnly Extends (%Persistent, %IPM.Storage.UpdateStep.Base)
{

/// HostName where the update step was last ran
Property HostName As %String(MAXLEN = 255) [ Required ];

/// InstanceName where the update step was last ran
Property InstanceName As %String(MAXLEN = 255) [ Required ];

Index UpdateClassMethodIdx On (ClassName, MethodName) [ Unique ];

/// Home module which this update step belongs to
Property HomeModule As %IPM.Storage.Module;

/// ForeignKey pointing to the module which this update step belonds to
ForeignKey HomeModKey(HomeModule) References %IPM.Storage.Module() [ OnDelete = cascade ];

/// Description
/// Relationship to module for which this update step belongs to
Method %OnNew(
	className As %String = "",
	methodName As %String = "") As %Status
{
    set ..ClassName = className
    set ..MethodName = methodName
    set ..HostName = ##class(%SYS.System).GetNodeName()
    set ..InstanceName = ##class(%SYS.System).GetInstanceName()

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
<Value>ForeignModule</Value>
</Value>
<Value name="6">
<Value>Status</Value>
</Value>
<Value name="7">
<Value>HostName</Value>
</Value>
<Value name="8">
<Value>MethodName</Value>
</Value>
<Value name="9">
<Value>TimeStampEnd</Value>
</Value>
<Value name="10">
<Value>HomeModule</Value>
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
