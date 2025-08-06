Class %IPM.Storage.UpdateStep.AnyMember Extends (%Persistent, %IPM.Storage.UpdateStep.Base)
{

Index UpdateClassMethodIdx On (ClassName, MethodName) [ Unique ];

Relationship ModuleHome As %IPM.Storage.Module [ Cardinality = one, Inverse = AnyMemberUpdateSteps, OnDelete = cascade ];

/// Returns %IPM.Storage.UpdateStep.AnyMember object corresponding to unique index in storage table
/// If object does not exist, this will return an empty object
ClassMethod GetUpdateStep(
	className As %String,
	methodName As %String) As %IPM.Storage.UpdateStep.AnyMember
{
    do ..UpdateClassMethodIdxExists(className, methodName, .stepId)
    return ..%OpenId(stepId)
}

Storage Default
{
<Data name="AnyMemberDefaultData">
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
<Value>HostName</Value>
</Value>
<Value name="5">
<Value>InstanceName</Value>
</Value>
<Value name="6">
<Value>TimeStampStart</Value>
</Value>
<Value name="7">
<Value>TimeStampEnd</Value>
</Value>
<Value name="8">
<Value>Status</Value>
</Value>
<Value name="9">
<Value>ModuleHome</Value>
</Value>
</Data>
<DataLocation>^%IPM.Storage.UpdaC3A.AnyMemberD</DataLocation>
<DefaultData>AnyMemberDefaultData</DefaultData>
<IdLocation>^%IPM.Storage.UpdaC3A.AnyMemberD</IdLocation>
<IndexLocation>^%IPM.Storage.UpdaC3A.AnyMemberI</IndexLocation>
<StreamLocation>^%IPM.Storage.UpdaC3A.AnyMemberS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
