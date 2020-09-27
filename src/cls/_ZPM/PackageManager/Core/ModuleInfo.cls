Class %ZPM.PackageManager.Core.ModuleInfo Extends (%XML.Adaptor, %ZPM.JSON.Adaptor) [ Abstract, StorageStrategy = "" ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Parameter XMLIGNOREINVALIDTAG = 1;

Parameter XMLIGNOREINVALIDATTRIBUTE = 1;

Property Name As %String(%JSONFIELDNAME = "name", MAXLEN = 255) [ Required ];

Property Description As %String(%JSONFIELDNAME = "description", MAXLEN = 1000);

Property Version As %ZPM.PackageManager.Core.SemanticVersion(%JSONINCLUDE = "NONE", XMLPROJECTION = "NONE") [ Required ];

Property VersionString As %String(%JSONFIELDNAME = "version", MAXLEN = 100, XMLNAME = "Version") [ Required ];

Property Repo As %String(%JSONINCLUDE = "NONE", XMLPROJECTION = "NONE");

Method VersionStringSet(tValue) As %Status
{
	Set i%VersionString = tValue
	Set ..Version = ##class(%ZPM.PackageManager.Core.SemanticVersion).FromString(tValue)
	Quit $$$OK
}

Method VersionStringGet() As %String
{
	Quit ..Version.ToString()
}

}
