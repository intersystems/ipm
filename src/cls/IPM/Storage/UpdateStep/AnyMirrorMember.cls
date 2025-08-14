Class %IPM.Storage.UpdateStep.AnyMirrorMember Extends (%Persistent, %IPM.Storage.UpdateStep.Base)
{

Index UpdateClassMethodIdx On (ClassName, MethodName) [ Unique ];

/// Home module which this update step belongs to
Property HomeModule As %IPM.Storage.Module;

/// ForeignKey pointing to the module which this update step belonds to
ForeignKey HomeModKey(HomeModule) References %IPM.Storage.Module() [ OnDelete = cascade ];

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
<Value name="8">
<Value>HomeModule</Value>
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
