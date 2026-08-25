/// Just a Serial Object of ModuleInfo so that it can be persisted in other objects.
/// Adds the platform compatibility information repositories report for deployed modules.
Class %IPM.Storage.ModuleInfo Extends (%SerialObject, %IPM.General.ModuleInfo) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleInfo";

Property PlatformVersions As list Of %String(%JSONFIELDNAME = "platform_versions");

/// Returns true if this module is installable on the given platform. Only a deployed module
/// with a non-empty platform list restricts anything; an empty entry in that list means the
/// artifact is not platform-specific, so it is compatible with everything.
Method IsCompatibleWithPlatform(platformVersion As %String) As %Boolean
{
    set platformVersions = ..PlatformVersionList()
    if '..Deployed || (platformVersions = "") {
        return 1
    }
    return ($listfind(platformVersions, "") > 0) || ($listfind(platformVersions, platformVersion) > 0)
}

/// Returns PlatformVersions as a comma-separated string, e.g. "2024.1, 2025.1", or "" if empty.
Method FormatPlatformVersions() As %String
{
    return $listtostring(..PlatformVersionList(), ", ")
}

/// Returns PlatformVersions as a $list, so it can be inspected with $listfind/$listtostring.
Method PlatformVersionList() As %List [ Private ]
{
    set result = ""
    for i=1:1:..PlatformVersions.Count() {
        set result = result _ $listbuild(..PlatformVersions.GetAt(i))
    }
    return result
}

Storage Default
{
<Data name="ModuleInfoState">
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>Version</Value>
</Value>
<Value name="3">
<Value>VersionString</Value>
</Value>
<Value name="4">
<Value>Description</Value>
</Value>
<Value name="5">
<Value>Repository</Value>
</Value>
<Value name="6">
<Value>AllVersions</Value>
</Value>
<Value name="7">
<Value>Origin</Value>
</Value>
<Value name="8">
<Value>Deployed</Value>
</Value>
<Value name="9">
<Value>PlatformVersion</Value>
</Value>
<Value name="10">
<Value>PlatformVersions</Value>
</Value>
<Value name="11">
<Value>DisplayName</Value>
</Value>
</Data>
<State>ModuleInfoState</State>
<StreamLocation>^IPM.Storage.ModuleInfoS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
