/// Just a Resolved Module reference with a bit more information about which repository
/// the module is located in.
Class %IPM.Storage.QualifiedModuleInfo Extends %IPM.Storage.ModuleInfo
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.QualifyModInfo";

/// The name of the repository the module is in (The Name property in <class>%IPM.Repo.Definition</class>. <br />
Property ServerName As %String;

Method %OnNew(pServerName As %String = "", pResolvedReference As %IPM.Storage.ModuleInfo = "") As %Status [ Private, ServerOnly = 1 ]
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
<Value name="7">
<Value>DisplayName</Value>
</Value>
<Value name="8">
<Value>DisplayNameInternal</Value>
</Value>
</Data>
<Type>%Storage.Serial</Type>
}

}
