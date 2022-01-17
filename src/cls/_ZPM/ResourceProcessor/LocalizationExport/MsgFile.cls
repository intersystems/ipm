/// Registered object representation of a localized error message document
Class %ZPM.ResourceProcessor.LocalizationExport.MsgFile Extends (%RegisteredObject, %XML.Adaptor)
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager/ErrorMessages";

Property Language As %String(XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = {$$$DefaultLanguage}, Required ];

Property Domains As array Of %ZPM.ResourceProcessor.LocalizationExport.MsgDomain(XMLKEYNAME = "Domain", XMLNAME = "MsgDomain", XMLPROJECTION = "ELEMENT");

}
