Class %ZPM.PackageManager.Core.MappingReference Extends %XML.Adaptor [ Abstract ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Name As %String(MAXLEN = 2048, XMLPROJECTION = "attribute") [ Required ];

}
