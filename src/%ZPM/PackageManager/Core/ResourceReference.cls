Class %ZPM.PackageManager.Core.ResourceReference Extends (%XML.Adaptor, %ZPM.PackageManager.Core.ComparisonAdaptor) [ Abstract ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

// Property Name As %ZPM.PackageManager.Developer.ResourceName(XMLPROJECTION = "attribute") [ Required ];

Property Name As %String(MAXLEN = 255, XMLPROJECTION = "attribute") [ Required ];

}
