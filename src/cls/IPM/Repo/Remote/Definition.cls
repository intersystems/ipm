Class %IPM.Repo.Remote.Definition Extends %IPM.Repo.Http.Definition
{

Parameter DISPLAYNAME As STRING = "Remote Repository";

Parameter MONIKER As STRING = "registry";

Parameter MONIKERALIAS As STRING = "remote";

XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<commands>
<command name="repo">
<group name="Remote repository">

<modifier name="remote" aliases="r" description="Create/update a remote server repository" />
<modifier name="reset-defaults" value="false" description="Reset to default repository" />

<example description="Switch to test registery">
repo -r -n registry -url https://test.pm.community.intersystems.com/registry/ -user "test" -pass "test"
</example>

<example description="Reset to default registry (pm.community.intersystems.com) and it is equivalent to a command">
repo -r -n registry -reset-defaults
</example>
<example description=" ">
repo -r -n registry -url https://pm.community.intersystems.com/ -user "" -pass ""
</example>

</group>
</command>
</commands>
}

/// Returns a REST client to interact with this server.
Method GetPackageService() As %IPM.Repo.IPackageService
{
	Set tClient = ##class(%IPM.Repo.Remote.PackageService).%New()
	Set tClient.Location = ..URL
	Set tClient.Username = ..Username
	Set tClient.Password = ..Password
	Set tClient.Token = ..Token
	Set tClient.TokenBasicAuth = ..TokenBasicAuth
	Quit tClient
}

/// Returns a REST client to publish modules/applications to this server.
Method GetPublishService() As %IPM.Repo.IPublishService
{
	Set tClient = ##class(%IPM.Repo.Remote.PublishService).%New()
	Set tClient.Location = ..URL
	Set tClient.Username = ..Username
	Set tClient.Password = ..Password
	Set tClient.Token = ..Token
	Quit tClient
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %IPM.Repo.Definition, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tUrl = $Get(pModifiers("url"), pInstance.URL)
		If (..URLExists(tUrl, .tId)) && (tId '= pInstance.%Id())  {
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to add new remote server with non-unique URL."))
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
			Set tServer = ##class(%IPM.Repo.Remote.Definition).DeploymentServerOpen(1)
			If $Isobject(tServer),tServer.URL'=pInstance.URL {
				Set tServer.DeploymentEnabled = 0
				$$$ThrowOnError(tServer.%Save())
			}
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
	FROM %IPM_Repo_Remote.Definition 
	WHERE Enabled = 1
}

Method GetPublishingManager(ByRef status)
{
	Return ##class(%IPM.Repo.Remote.PublishManager).%Get(.status)
}

Storage Default
{
<Data name="RemoteRepoDefinitionDefaultData">
<Subscript>"RemoteRepoDefinition"</Subscript>
<Value name="2">
<Value>Username</Value>
</Value>
<Value name="3">
<Value>Password</Value>
</Value>
<Value name="4">
<Value>URL</Value>
</Value>
<Value name="5">
<Value>Token</Value>
</Value>
<Value name="6">
<Value>DeploymentEnabled</Value>
</Value>
</Data>
<DefaultData>RemoteRepoDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
