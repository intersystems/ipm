/// Just a Resolved Module reference with a bit more information about which repository
/// the module is located in.
Class %ZPM.Storage.QualifiedModuleInfo Extends %ZPM.Storage.ModuleInfo
{

/// The name of the repository the module is in (The Name property in <class>%ZPM.Repo.Definition</class>. <br />
Property ServerName As %String;

Method %OnNew(pServerName As %String = "", pResolvedReference As %ZPM.Storage.ModuleInfo = "") As %Status [ Private, ServerOnly = 1 ]
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
<Data name="ModuleInfoState">
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>Description</Value>
</Value>
<Value name="3">
<Value>Version</Value>
</Value>
<Value name="4">
<Value>VersionString</Value>
</Value>
<Value name="5">
<Value>Repository</Value>
</Value>
<Value name="6">
<Value>ServerName</Value>
</Value>
</Data>
<Type>%Storage.Serial</Type>
}

}
