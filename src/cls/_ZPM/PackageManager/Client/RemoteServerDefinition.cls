Class %ZPM.PackageManager.Client.RemoteServerDefinition Extends %ZPM.PackageManager.Client.ServerDefinition
{

Parameter DISPLAYNAME As STRING = "Remote Repository";

Parameter MONIKER As STRING = "registry";

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {Set {*} = {URL}}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

Index URL On URL [ Unique ];

Property URL As %String(MAXLEN = 2048) [ Required ];

Parameter URLPromptString = {$$$Text("Registry URL:","ZPM")};

Property Username As %String(MAXLEN = "");

Property Password As %String(MAXLEN = "");

Property DeploymentEnabled As %Integer(MAXVAL = 1, MINVAL = 0) [ InitialExpression = 0 ];

Index DeploymentServer On DeploymentEnabled [ Unique ];

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

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to 
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	Set tStatus = $$$OK
	Quit tStatus
}

/// Returns a REST client to interact with this server.
Method GetPackageService() As %ZPM.PackageManager.Core.IPackageService
{
	Set tClient = ##class(%ZPM.PackageManager.Client.REST.PackageManagerClient).%New()
	Set tClient.Location = ..URL
	Set tClient.Username = ..Username
	Set tClient.Password = ..Password
	Quit tClient
}

/// Returns a REST client to publish modules/applications to this server.
Method GetPublishService() As %ZPM.PackageManager.Core.IPublishService
{
	Set tClient = ##class(%ZPM.PackageManager.Client.REST.PublishClient).%New()
	Set tClient.Location = ..URL
	Set tClient.Username = ..Username
	Set tClient.Password = ..Password
	Quit tClient
}

/// Outputs information about this server to the current device.
/// Subclasses may override to show additional information.
Method Display()
{
	Do ##super() 
	Write !,$c(9),"DeploymentEnabled?",$c(9),$$$YesNo(..DeploymentEnabled)
	If (..Username '= "") {
		Write !,$c(9),"Username: ",$c(9),..Username
	}
	If (..Password '= "") {
		Write !,$c(9),"Password: ",$c(9),$Case(..Password,"":"<unset>",:"<set>")
	}
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %ZPM.PackageManager.Client.ServerDefinition, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tUrl = $Get(pModifiers("url"), pInstance.URL)
		If (pInteractive && (tUrl = "")) {
			Set tPrompt = ..#URLPromptString
			Set tResponse = ##class(%Library.Prompt).GetString(tPrompt, .tUrl)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError, "Operation cancelled."))
			}
		}
		Set pInstance.URL = tUrl
		
		If $Data(pModifiers("username"),tUsername) {
			Set pInstance.Username = tUsername
		}
		If $Data(pModifiers("password"),tPassword) {
			Set pInstance.Password = tPassword
		}
		If $Data(pModifiers("url"),tURL) {
			Set pInstance.URL = tURL
		}
		If $Data(pModifiers("deployment"),tDeployment){
			do ..RemoveDeploymentEnable()
			Set pInstance.DeploymentEnabled = 1
		} 
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// remove DeploymentEnable Flag from all REPO
ClassMethod RemoveDeploymentEnable() As %Status
{
	Set tSC = $$$OK
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,"UPDATE %ZPM_PackageManager_Client.RemoteServerDefinition set DeploymentEnabled = NULL")
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	Return tSC
}

Method GetSortOrder() As %Integer [ Private ]
{
	// TODO: Allow this to be changed dynamically.
	Quit 2 + $Case(..%Id(),"":1,:..%Id())
}

Storage Default
{
<Data name="RemoteServerDefinitionDefaultData">
<Subscript>"RemoteServerDefinition"</Subscript>
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
<Value>DeploymentEnabled</Value>
</Value>
</Data>
<DefaultData>RemoteServerDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
