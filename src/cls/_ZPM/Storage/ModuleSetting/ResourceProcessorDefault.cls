Class %ZPM.Storage.ModuleSetting.ResourceProcessorDefault Extends %ZPM.Storage.ModuleSetting
{

/// Resource processor class to which this default setting applies
Property Class As %Dictionary.Classname(XMLPROJECTION = "ATTRIBUTE") [ Required ];

/// Default attributes to apply to the resources with the specified ProcessorClass
Property Attributes As array Of %String(MAXLEN = "", XMLKEYNAME = "Name", XMLNAME = "Attribute", XMLPROJECTION = "ELEMENT");

/// Conditions under which the default settings apply
Property Conditions As list Of %ZPM.Storage.ModuleSetting.ResourceProcessorDefault.Condition(XMLNAME = "Condition", XMLPROJECTION = "ELEMENT");

Storage Default
{
<Data name="ResourceProcessorDefaultState">
<Subscript>"ResourceProcessorDefault"</Subscript>
<Value name="1">
<Value>Class</Value>
</Value>
<Value name="2">
<Value>Attributes</Value>
</Value>
<Value name="3">
<Value>Conditions</Value>
</Value>
</Data>
<State>ResourceProcessorDefaultState</State>
<Type>%Storage.Serial</Type>
}

}
