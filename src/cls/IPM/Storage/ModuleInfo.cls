/// Serializable representation of a module available in a repository, including platform compatibility information for deployed modules.
/// Can be embedded in other persistent objects.
Class %IPM.Storage.ModuleInfo Extends (%SerialObject, %IPM.General.ModuleInfo) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleInfo";

Property PlatformVersions As list Of %String(%JSONFIELDNAME = "platform_versions");

/// Returns true if this module is installable on the given platform.
/// Non-deployed modules and deployed modules with no platform list are always compatible.
/// Deployed modules with a platform list are compatible only if platformVersion appears in the list.
Method IsCompatibleWithPlatform(platformVersion As %String) As %Boolean
{
    if '..Deployed || (..PlatformVersions.Count() = 0) {
        return 1
    }
    return ..PlatformVersions.Find(platformVersion) > 0
}

/// Returns PlatformVersions as a comma-separated string, e.g. "2024.1, 2025.1".
/// Returns "" when the list is empty.
Method FormatPlatformVersions() As %String
{
    set result = ""
    for i=1:1:..PlatformVersions.Count() {
        set result = result _ $select(i > 1: ", ", 1: "") _ ..PlatformVersions.GetAt(i)
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
