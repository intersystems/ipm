Class %IPM.Storage.ModuleSetting.Parameter Extends %IPM.Storage.ModuleSetting
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModSet.Param";

/// Name of the parameter (may contain "." to indicate a subscript in the array passed to lifecycle phases)
Property Name As %String(XMLPROJECTION = "ATTRIBUTE");

/// Value of the parameter (may be empty)
Property Value As %String(XMLPROJECTION = "CONTENT");

/// Optional; if specified, parameter default only applies when the lifecycle class is the one in question.
Property LifecycleClass As %String(XMLPROJECTION = "ATTRIBUTE");

Storage Default
{
<Data name="ParameterState">
<Subscript>"Parameter"</Subscript>
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>Value</Value>
</Value>
<Value name="3">
<Value>LifecycleClass</Value>
</Value>
</Data>
<State>ParameterState</State>
<Type>%Storage.Serial</Type>
}

}
