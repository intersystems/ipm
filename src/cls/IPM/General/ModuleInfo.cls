/// Most basic information that EVERY module must have.
Class %IPM.General.ModuleInfo Extends (%XML.Adaptor, %IPM.JSON.Adaptor) [ Abstract, StorageStrategy = "" ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Parameter XMLIGNOREINVALIDTAG = 1;

Parameter XMLIGNOREINVALIDATTRIBUTE = 1;

/// lowercase storage name of the module
Property Name As %IPM.DataType.ModuleName(%JSONINCLUDE = "NONE", XMLPROJECTION = "NONE") [ Required ];

Property Description As %String(%JSONFIELDNAME = "description", MAXLEN = 1000);

Property Version As %IPM.General.SemanticVersion(%JSONINCLUDE = "NONE", XMLPROJECTION = "NONE") [ Required ];

Property AllVersions As %String(%JSONINCLUDE = "NONE", MAXLEN = "", XMLPROJECTION = "NONE") [ Transient ];

Property Origin As %String;

Property VersionString As %String(%JSONFIELDNAME = "version", MAXLEN = 100, XMLNAME = "Version") [ Required ];

Property Deployed As %Boolean(%JSONFIELDNAME = "deployed", XMLNAME = "Deployed");

/// Version of IRIS for Deployed modules
Property PlatformVersion As %String(%JSONFIELDNAME = "platform_version", MAXLEN = 10, XMLNAME = "PlatformVersion");

/// The repository from which this module was loaded.
/// Is "" if the module was loaded using the load command (i.e. directly from a file and not from a repository).
Property Repository As %String(MAXLEN = "", XMLPROJECTION = "NONE");

/// Case-sensitive display name of the module as it appears in the module manifest
Property DisplayName As %IPM.DataType.ModuleName(%JSONFIELDNAME = "name", XMLNAME = "Name");

Method NameSet(val As %String) As %Status
{
    set i%Name = $$$lcase(val)
    set i%DisplayName = val
    return $$$OK
}

Method DisplayNameSet(val As %String) As %Status
{
    if (i%Name '= "") {
        if (i%Name '= $$$lcase(val)) {
            return $$$ERROR($$$GeneralError, "DisplayName needs to be case sensitive form of module name: "_i%Name)
        }
    }
    set i%DisplayName = val
    set i%Name = $$$lcase(val)
    return $$$OK
}

Method VersionStringSet(tValue) As %Status
{
    set i%VersionString = tValue
    set ..Version = ##class(%IPM.General.SemanticVersion).FromString(tValue)
    quit $$$OK
}

Method VersionStringGet() As %String
{
    quit ..Version.ToString()
}

}
