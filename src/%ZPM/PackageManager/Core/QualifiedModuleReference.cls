/// Just a Resolved Module reference with a bit more information about which repository
/// the module is located in.
Class %ZPM.PackageManager.Core.QualifiedModuleReference Extends %ZPM.PackageManager.Core.ResolvedModuleReference
{

/// The name of the repository the module is in (The Name property in <class>%ZPM.PackageManager.Client.ServerDefinition</class>. <br />
Property ServerName As %String;

Method %OnNew(pServerName As %String = "", pResolvedReference As %ZPM.PackageManager.Core.ResolvedModuleReference = "") As %Status [ Private, ServerOnly = 1 ]
{
	If (pServerName '= "") {
		Set ..ServerName = pServerName
	}
	If (pResolvedReference '= "") {
		Set ..Name = pResolvedReference.Name
		Set ..Version = pResolvedReference.Version
	}
	Quit $$$OK
}

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
<Value>ServerName</Value>
</Value>
<Value name="5">
<Value>Repository</Value>
</Value>
<Value name="6">
<Value>Description</Value>
</Value>
<Value name="7">
<Value>Origin</Value>
</Value>
<Value name="8">
<Value>AllVersions</Value>
</Value>
</Data>
<Type>%Storage.Serial</Type>
}

}
