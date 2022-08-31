/// Just a Serial Object of ModuleInfo so that it can be persisted in other objects.
Class %ZPM.PackageManager.Core.ResolvedModuleReference Extends (%SerialObject, %ZPM.PackageManager.Core.ModuleInfo) [ StorageStrategy = "" ]
{

Property PlatformVersions As list Of %String(%JSONFIELDNAME = "platform_versions");

Storage Default
{
<Data name="ResolvedModuleReferenceState">
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
</Data>
<State>ResolvedModuleReferenceState</State>
<StreamLocation>^ZPM.PackageManager9CFF.ResolvedMod1E11S</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
