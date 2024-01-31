/// Registered object representation of a domain in a localized error message document
Class %IPM.ResourceProcessor.LocalizationExport.MsgDomain Extends (%RegisteredObject, %XML.Adaptor)
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager/LocalizedMessages";

Property Messages As array Of %String(MAXLEN = "", XMLKEYNAME = "Id", XMLNAME = "Message", XMLPROJECTION = "ELEMENT");

}
