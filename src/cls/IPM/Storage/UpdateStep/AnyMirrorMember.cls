Class %IPM.Storage.UpdateStep.AnyMirrorMember Extends (%Persistent, %IPM.Storage.UpdateStep.Base)
{

/// Relationship to module for which this update step belongs to
Relationship ModuleHome As %IPM.Storage.Module [ Cardinality = one, Inverse = AnyMirrorMemberUpdateSteps, OnDelete = cascade ];

Index UpdateClassMethodIdx On (ClassName, MethodName) [ Unique ];

/// Returns %IPM.Storage.UpdateStep.AnyMirrorMember object corresponding to unique index in storage table
/// If object does not exist, this will return an empty object
ClassMethod GetUpdateStep(
	className As %String,
	methodName As %String) As %IPM.Storage.UpdateStep.AnyMirrorMember
{
    do ..UpdateClassMethodIdxExists(className, methodName, .stepId)
    return ..%OpenId(stepId)
}

Storage Default
{
<Data name="AnyMirrorMemberDefaultData">
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
<Value>TimeStampStart</Value>
</Value>
<Value name="5">
<Value>TimeStampEnd</Value>
</Value>
<Value name="6">
<Value>Status</Value>
</Value>
<Value name="7">
<Value>ModuleHome</Value>
</Value>
</Data>
<DataLocation>^%IPM.StoragC3A.AnyMirrorMeE8EED</DataLocation>
<DefaultData>AnyMirrorMemberDefaultData</DefaultData>
<IdLocation>^%IPM.StoragC3A.AnyMirrorMeE8EED</IdLocation>
<IndexLocation>^%IPM.StoragC3A.AnyMirrorMeE8EEI</IndexLocation>
<StreamLocation>^%IPM.StoragC3A.AnyMirrorMeE8EES</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
