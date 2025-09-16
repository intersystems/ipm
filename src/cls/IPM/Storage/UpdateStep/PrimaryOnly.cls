/// Storage class for update steps to run on a primary mirror member only
Class %IPM.Storage.UpdateStep.PrimaryOnly Extends %IPM.Storage.UpdateStep.Base
{

/// Ensure it is not a % global so storage is namespace specific.
Parameter DEFAULTGLOBAL As STRING = "^IPM.UpdateStep.PrimaryOnly";

/// HostName where the update step was last ran
Property HostName As %String(MAXLEN = 255) [ InitialExpression = {##class(%SYS.System).GetNodeName()}, Required ];

/// InstanceName where the update step was last ran
Property InstanceName As %String(MAXLEN = 255) [ InitialExpression = {##class(%SYS.System).GetInstanceName()}, Required ];

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
	methodName As %String) As %IPM.Storage.UpdateStep.PrimaryOnly
{
    if ..UpdateClassMethodIdxExists(className, methodName, .stepId) {
        set obj = ..%OpenId(stepId, , .sc)
        $$$ThrowOnError(sc)
    } else {
        set obj = ..%New(className, methodName)
    }
    return obj
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
<Value>HostName</Value>
</Value>
<Value name="4">
<Value>InstanceName</Value>
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
<Value>MethodName</Value>
</Value>
<Value name="9">
<Value>TimeStampStart</Value>
</Value>
</Data>
<DataLocation>^IPM.UpdateStep.PrimaryOnlyD</DataLocation>
<DefaultData>PrimaryOnlyDefaultData</DefaultData>
<IdLocation>^IPM.UpdateStep.PrimaryOnlyD</IdLocation>
<IndexLocation>^IPM.UpdateStep.PrimaryOnlyI</IndexLocation>
<StreamLocation>^IPM.UpdateStep.PrimaryOnlyS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
