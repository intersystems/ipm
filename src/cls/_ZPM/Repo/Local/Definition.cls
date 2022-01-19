Class %ZPM.Repo.Local.Definition Extends %ZPM.Repo.Definition
{

Parameter DISPLAYNAME As STRING = "Local Cache";

Parameter MONIKER As STRING = "local";

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {Set {*} = "Namespace-local module registry."}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

Index Singleton On IsLocalCache [ Unique ];

Property IsLocalCache As %Integer [ InitialExpression = 1, ReadOnly ];

/// Returns a client to interact with this server.
Method GetPackageService() As %ZPM.Repo.IPackageService
{
	Quit $$$NULLOREF
}

/// Returns a client to publish modules/applications to this server.
Method GetPublishService() As %ZPM.Repo.IPublishService
{
	Quit $$$NULLOREF
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %ZPM.Repo.Definition, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
{
	// Intentional no-op.
	Quit $$$OK
}

Method GetSortOrder() As %Integer [ Private ]
{
	Quit 1
}

Storage Default
{
<Data name="DefinitionDefaultData1">
<Subscript>"Definition"</Subscript>
<Value name="1">
<Value>IsLocalCache</Value>
</Value>
</Data>
<DefaultData>DefinitionDefaultData1</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
