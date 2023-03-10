/// Tested in the SatisfiesCondition method of <class>%IPM.ResourceProcessor.Abstract</class>
Class %IPM.Storage.ModuleSetting.ProcessorDefault.Condition Extends (%SerialObject, %XML.Adaptor, %IPM.Utils.ComparisonAdaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModSet.RP.Cond";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

/// Name of other attribute to test
Property Attribute As %String(MAXLEN = 100, XMLPROJECTION = "attribute") [ Required ];

/// Comparison operator; if empty, "eq" is assumed (although not the InitialExpression for sake of XML re-export).
Property Operator As %String(VALUELIST = ",eq,neq,gt,lt,gte,lte,contains", XMLPROJECTION = "attribute");

/// Value to compare to - may be empty.
Property Value As %String(MAXLEN = "", XMLPROJECTION = "attribute");

Storage Default
{
<Data name="ConditionState">
<Value name="1">
<Value>Attribute</Value>
</Value>
<Value name="2">
<Value>Operator</Value>
</Value>
<Value name="3">
<Value>Value</Value>
</Value>
</Data>
<State>ConditionState</State>
<StreamLocation>^IPM.Storage.ModSet.RP.CondS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
