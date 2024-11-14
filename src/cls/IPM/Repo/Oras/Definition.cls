Class %IPM.Repo.Oras.Definition Extends %IPM.Repo.Http.Definition
{

Parameter DISPLAYNAME As STRING = "ORAS";

Parameter MONIKER As STRING = "oras";

Property Namespace As %String;

XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<commands>
<command name="repo">
<group name="ORAS repository">

<modifier name="oras" aliases="o" description="Create/update an ORAS server repository" />
<modifier name="namespace" aliases="ns" value="true" description="For ORAS repositories, specifies the registry namespace, i.e. the fully specified path to a package is &lt;url>/&lt;namespace>/&lt;package>.
	Note, this is not the IRIS namespace, but a namespace in the sense of a (sub)directory in the registry's storage system. For example, if in a custom managed registry, the base url is 'registry.company.com',
	and the package is 'objectscript-example', but it will be stored at 'registry.company.com/packages/ipm/objectscript-example', then the namespace will be 'packages/ipm'." />
</group>
</command>
</commands>
}

/// Returns a REST client to interact with this server.
Method GetPackageService() As %IPM.Repo.IPackageService
{
	Set tClient = ##class(%IPM.Repo.Oras.PackageService).%New()
	Set tClient.Location = ..URL
	Set tClient.Namespace = ..Namespace
	Set tClient.Username = ..Username
	Set tClient.Password = ..Password
    Set tClient.Token = ..Token
	Set tClient.TokenBasicAuth = ..TokenBasicAuth
	Quit tClient
}

/// Returns a REST client to publish modules/applications to this server.
Method GetPublishService() As %IPM.Repo.IPublishService
{
	Set tClient = ##class(%IPM.Repo.Oras.PublishService).%New()
	Set tClient.Location = ..URL
	Set tClient.Namespace = ..Namespace
	Set tClient.Username = ..Username
	Set tClient.Password = ..Password
    Set tClient.Token = ..Token
	Quit tClient
}

/// Outputs information about this server to the current device.
/// Subclasses may override to show additional information.
Method Display()
{
	Do ##super()

	If (..Namespace '= "") {
		Write !,$c(9),"Namespace: ",$c(9),$c(9),..Namespace
	}
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %IPM.Repo.Definition, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tUrl = $Get(pModifiers("url"), pInstance.URL)
		If (..URLExists(tUrl, .tId)) && (tId '= pInstance.%Id())  {
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to add new ORAS server with non-unique URL."))
		}
		If (pInteractive && (tUrl = "")) {
			Set tPrompt = ..#URLPromptString
			Set tResponse = ##class(%Library.Prompt).GetString(tPrompt, .tUrl)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError, "Operation cancelled."))
			}
		}
		If $Data(pModifiers("username"), tUsername) {
			Set pInstance.Username = tUsername
		}
		If $Data(pModifiers("password"), tPassword) {
			Set pInstance.Password = tPassword
		}
		If $Data(pModifiers("token"), tToken) {
			Set pInstance.Token = tToken
		}
		If $Data(pModifiers("publish"), tPublish) {
			Set pInstance.DeploymentEnabled = tPublish
		}
		If tUrl'="" {
			Set pInstance.URL = tUrl
		}
		If (pInstance.DeploymentEnabled = 1) {
			Set tServer = ##class(%IPM.Repo.Oras.Definition).DeploymentServerOpen(1)
			If $Isobject(tServer),tServer.URL'=pInstance.URL {
				Set tServer.DeploymentEnabled = 0
				$$$ThrowOnError(tServer.%Save())
			}
		}
		If $Data(pModifiers("namespace"), tNamespace) {
			Set pInstance.Namespace = tNamespace
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Query PublishingServer() As %SQLQuery
{
	SELECT 
		CASE 
			WHEN DeploymentEnabled = 1 THEN 1
			WHEN Token IS NOT NULL THEN 2
			WHEN Username IS NOT NULL AND Password IS NOT NULL THEN 3
			ELSE 999 
		END PublishOrder,
		ID, Name, URL
	FROM %IPM_Repo_Oras.Definition 
	WHERE Enabled = 1
}

Method GetPublishingManager(ByRef status)
{
	Return ##class(%IPM.Repo.Oras.PublishManager).%Get(.status)
}

Storage Default
{
<Data name="OrasRepoDefinitionDefaultData">
<Subscript>"OrasRepoDefinition"</Subscript>
<Value name="1">
<Value>URL</Value>
</Value>
<Value name="2">
<Value>Username</Value>
</Value>
<Value name="3">
<Value>Password</Value>
</Value>
<Value name="4">
<Value>Token</Value>
</Value>
<Value name="5">
<Value>DeploymentEnabled</Value>
</Value>
<Value name="6">
<Value>Namespace</Value>
</Value>
</Data>
<DefaultData>OrasRepoDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
