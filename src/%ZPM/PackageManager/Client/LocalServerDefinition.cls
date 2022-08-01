Class %ZPM.PackageManager.Client.LocalServerDefinition Extends %ZPM.PackageManager.Client.ServerDefinition
{

Parameter DISPLAYNAME As STRING = "Local Cache";

Parameter MONIKER As STRING = "local";

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {Set {*} = "Namespace-local module registry."}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

Index Singleton On IsLocalCache [ Unique ];

Property IsLocalCache As %Integer [ InitialExpression = 1, ReadOnly ];

/// Returns a client to interact with this server.
Method GetPackageService() As %ZPM.PackageManager.Core.IPackageService
{
	Quit ##class(%ZPM.PackageManager.Server.PackageService).%New()
}

/// Returns a client to publish modules/applications to this server.
Method GetPublishService() As %ZPM.PackageManager.Core.IPublishService
{
	Quit ##class(%ZPM.PackageManager.Server.PublishService).%New()
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %ZPM.PackageManager.Client.ServerDefinition, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
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
<Type>%Storage.Persistent</Type>
}

}
