/// Storage class for update steps that should be run on every instance
Class %IPM.Storage.UpdateStep.AnyMember Extends %IPM.Storage.UpdateStep.Base
{

/// Ensure it is not a % global so storage is namespace specific.
Parameter DEFAULTGLOBAL As STRING = "^IPM.UpdateStep.AnyMember";

Index UpdateClassMethodIdx On (ClassName, MethodName) [ Unique ];

/// ForeignKey pointing to the module which this update step belongs to
ForeignKey HomeModKey(HomeModule) References %IPM.Storage.Module() [ OnDelete = cascade ];

/// Returns object of this class corresponding to unique index in storage table
/// If object does not exist, this will return a new object with the ClassName and MethodName
/// properties set. <br />
/// @Argument className     The class name of the update step. <br />
/// @Argument methodName    The method name of the update step</param>
ClassMethod GetUpdateStep(
	className As %String,
	methodName As %String) As %IPM.Storage.UpdateStep.AnyMember
{
    if ..UpdateClassMethodIdxExists(className, methodName, .stepId) {
        set obj = ..%OpenId(stepId, , .sc)
        $$$ThrowOnError(sc)
    } else {
        set obj = ..%New()
        set obj.ClassName = className
        set obj.MethodName = methodName
    }
    return obj
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
</Data>
<DataLocation>^IPM.UpdateStep.AnyMemberD</DataLocation>
<DefaultData>AnyMemberDefaultData</DefaultData>
<IdLocation>^IPM.UpdateStep.AnyMemberD</IdLocation>
<IndexLocation>^IPM.UpdateStep.AnyMemberI</IndexLocation>
<StreamLocation>^IPM.UpdateStep.AnyMemberS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
