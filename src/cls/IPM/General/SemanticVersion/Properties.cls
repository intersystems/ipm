/// Properties class for Semantic Versioning
Class %IPM.General.SemanticVersion.Properties Extends (%RegisteredObject, %XML.Adaptor)
{

Property Major As %Integer(MINVAL = 0) [ Required ];

Property Minor As %Integer(MINVAL = 0) [ Required ];

Property Patch As %Integer(MINVAL = 0) [ Required ];

Property Prerelease As %IPM.DataType.RegExString(MAXLEN = 100, REGEX = "([0-9A-Za-z-])+(\.([0-9A-Za-z-])+)*");

Property Build As %IPM.DataType.RegExString(MAXLEN = 100, REGEX = "([0-9A-Za-z-])+(\.([0-9A-Za-z-])+)*");

}
