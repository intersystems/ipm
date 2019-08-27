Class %ZPM.PackageManager.Core.ResourceReference Extends %XML.Adaptor [ Abstract ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Name As %String(MAXLEN = 255, XMLPROJECTION = "attribute") [ Required ];

}
