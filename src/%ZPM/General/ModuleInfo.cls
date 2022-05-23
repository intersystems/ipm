/// Most basic information that EVERY module must have.
Class %ZPM.General.ModuleInfo Extends (%XML.Adaptor, %ZPM.JSON.Adaptor) [ Abstract, StorageStrategy = "" ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Parameter XMLIGNOREINVALIDTAG = 1;

Parameter XMLIGNOREINVALIDATTRIBUTE = 1;

Property Name As %ZPM.DataType.ModuleName(%JSONFIELDNAME = "name") [ Required ];

Property Description As %String(%JSONFIELDNAME = "description", MAXLEN = 1000);

Property Version As %ZPM.General.SemanticVersion(%JSONINCLUDE = "NONE", XMLPROJECTION = "NONE") [ Required ];

Property VersionString As %String(%JSONFIELDNAME = "version", MAXLEN = 100, XMLNAME = "Version") [ Required ];

Property AllVersions As %String(%JSONINCLUDE = "NONE", MAXLEN = "", XMLPROJECTION = "NONE") [ Transient ];

/// The repository from which this module was loaded.
/// Is "" if the module was loaded using the load command (i.e. directly from a file and not from a repository).
Property Repository As %String(MAXLEN = "", XMLPROJECTION = "NONE");

Method VersionStringSet(tValue) As %Status
{
	Set i%VersionString = tValue
	Set ..Version = ##class(%ZPM.General.SemanticVersion).FromString(tValue)
	Quit $$$OK
}

Method VersionStringGet() As %String
{
	Quit ..Version.ToString()
}

}
