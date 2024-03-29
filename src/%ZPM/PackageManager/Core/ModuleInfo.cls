/// Most basic information that EVERY module must have.
Class %ZPM.PackageManager.Core.ModuleInfo Extends (%XML.Adaptor, %ZPM.JSON.Adaptor) [ Abstract, StorageStrategy = "" ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Parameter XMLIGNOREINVALIDTAG = 1;

Parameter XMLIGNOREINVALIDATTRIBUTE = 1;

Property Name As %ZPM.PackageManager.Core.ModuleName(%JSONFIELDNAME = "name") [ Required ];

Property Description As %String(%JSONFIELDNAME = "description", MAXLEN = 1000);

Property Version As %ZPM.PackageManager.Core.SemanticVersion(%JSONINCLUDE = "NONE", XMLPROJECTION = "NONE") [ Required ];

Property AllVersions As %String;

Property Origin As %String;

Property VersionString As %String(%JSONFIELDNAME = "version", MAXLEN = 100, XMLNAME = "Version") [ Required ];

Property Deployed As %Boolean(%JSONFIELDNAME = "deployed", XMLNAME = "Deployed");

/// Version of IRIS for Deployed modules
Property PlatformVersion As %String(%JSONFIELDNAME = "platform_version", MAXLEN = 10, XMLNAME = "PlatformVersion");

/// The repository from which this module was loaded.
/// Is "" if the module was loaded using the load command (i.e. directly from a file and not from a repository).
Property Repository As %String(MAXLEN = "", XMLPROJECTION = "NONE");

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
