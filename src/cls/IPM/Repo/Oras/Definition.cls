Class %IPM.Repo.Oras.Definition Extends %IPM.Repo.Definition
{

Parameter DISPLAYNAME As STRING = "ORAS";

Parameter MONIKER As STRING = "oras";

Property URL As %String(MAXLEN = 2048) [ Required ];

Index ORASURL On URL [ Unique ];

Parameter URLPromptString = {$$$Text("ORAS Registry URL:","ZPM")};

Property Namespace As %String;

Property Username As %String(MAXLEN = "");

Property Password As %String(MAXLEN = "");

Property Token As %String(MAXLEN = "");

Property DeploymentEnabled As %Boolean [ InitialExpression = 0 ];

Index DeploymentServerOras On DeploymentEnabled [ Unique ];

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {Set {*} = {URL}}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<commands>
<command name="repo">
<group name="Oras repository">

<modifier name="namespace" aliases="ns" value="true" description="For ORAS repositories, specifies the registry namespace, i.e. the fully specified path to a package is &lt;url>/&lt;namespace>/&lt;package>.
	Note, this is not the IRIS namespace, but a namespace in the sense of a (sub)directory in the registry's storage system. For example, if in a custom managed registry, the base url is 'registry.company.com',
	and the package is 'objectscript-example', but it will be stored at 'registry.company.com/packages/ipm/objectscript-example', then the namespace will be 'packages/ipm'." />
</group>
</command>
</commands>
}

/// This callback method is invoked by the <METHOD>%Save</METHOD> method to 
/// provide notification that the object is being saved. It is called before 
/// any data is written to disk.
/// 
/// <P><VAR>insert</VAR> will be set to 1 if this object is being saved for the first time.
/// 
/// <P>If this method returns an error then the call to <METHOD>%Save</METHOD> will fail.
Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	// Leave DeploymentEnabled null to make unique index work right
	// (i.e., deployment can only be enabled for one remote server.)
	Set:..DeploymentEnabled=0 ..DeploymentEnabled=""
	Quit $$$OK
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

	Write !,$c(9),"Deployment Enabled? ",$c(9),$Case(..DeploymentEnabled,1:"Yes",:"No")
	
	If (..Namespace '= "") {
		Write !,$c(9),"Namespace: ",$c(9),$c(9),..Namespace
	}
	If (..Username '= "") {
		Write !,$c(9),"Username: ",$c(9),$c(9),..Username
	}
	If (..Password '= "") {
		Write !,$c(9),"Password: ",$c(9),$c(9),$Case(..Password,"":"<unset>",:"<set>")
	}
	If (..Token '= "") {
		Write !,$c(9),"Token: ",$c(9),$c(9),$c(9),$Case(..Token,"":"<unset>",:"<set>")
	}
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %IPM.Repo.Definition, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tUrl = $Get(pModifiers("url"), pInstance.URL)
		If (..ORASURLExists(tUrl, .tId)) && (tId '= pInstance.%Id())  {
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
			Set tServer = ##class(%IPM.Repo.Oras.Definition).DeploymentServerOrasOpen(1)
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

Method GetSortOrder() As %Integer [ Private ]
{
	// TODO: Allow this to be changed dynamically.
	Quit 2 + $Case(..%Id(),"":1,:..%Id())
}

Storage Default
{
<Data name="DefinitionDefaultData">
<Subscript>"Definition"</Subscript>
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
<DefaultData>DefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
