Class %IPM.Repo.Http.Definition Extends %IPM.Repo.Definition [ Abstract ]
{

Parameter MONIKER As String = "http";

Property URL As %String(MAXLEN = 2048) [ Required ];

Index URL On URL [ Unique ];

Parameter URLPromptString = {$$$Text("Registry URL:","ZPM")};

Property Username As %String(MAXLEN = "");

Property Password As %String(MAXLEN = "");

Property Token As %String(MAXLEN = "");

Property DeploymentEnabled As %Boolean [ InitialExpression = 0 ];

Index DeploymentServer On DeploymentEnabled [ Unique ];

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {Set {*} = {URL}}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<commands>
<command name="repo">
<group name="HTTP(s) repository">

<modifier name="url" value="true" description="For HTTP(s) repositories, specifies the URL for package retrieval web services." />
<modifier name="publish-url" value="true" description="For HTTP(s) repositories, specifies the URL for package publishing web services."/>
<modifier name="username" aliases="user" value="true" description="For HTTP(s) repositories, specifies the username to use when connecting." />
<modifier name="password" aliases="pass" value="true" description="For HTTP(s) repositories, specifies the password to use when connecting." />
<modifier name="token" value="true" description="For HTTP(s) repositories, specifies the key to use when connecting." />
<modifier name="sslconfig" aliases="ssl" value="true" description="For HTTP(s) repositories, specifies the SSL configuration name to use when connecting." />
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

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to 
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	Set tStatus = $$$OK
	Quit tStatus
}

/// Outputs information about this server to the current device.
/// Subclasses may override to show additional information.
Method Display()
{
	Do ##super()

	Write !,$c(9),"Deployment Enabled? ",$c(9),$Case(..DeploymentEnabled,1:"Yes",:"No")

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

Method GetSortOrder() As %Integer [ Private ]
{
	// TODO: Allow this to be changed dynamically.
	Quit 2 + $Case(..%Id(),"":1,:..%Id())
}

Query PublishingServer() As %SQLQuery
{
	--TODO: dynamically handle subclasses
	SELECT 
		CASE 
			WHEN DeploymentEnabled = 1 THEN 1
			WHEN Token IS NOT NULL THEN 2
			WHEN Username IS NOT NULL AND Password IS NOT NULL THEN 3
			ELSE 999 
		END PublishOrder,
		ID, Name, URL, 1 AS Type
	FROM %IPM_Repo_Remote.Definition 
	WHERE Enabled = 1
	UNION
	SELECT 
		CASE 
			WHEN DeploymentEnabled = 1 THEN 1
			WHEN Token IS NOT NULL THEN 2
			WHEN Username IS NOT NULL AND Password IS NOT NULL THEN 3
			ELSE 999 
		END PublishOrder,
		ID, Name, URL, 2 AS Type
	FROM %IPM_Repo_Oras.Definition 
	WHERE Enabled = 1
	ORDER BY PublishOrder, ID
}

Storage Default
{
<Data name="HttpRepoDefinitionDefaultData">
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
</Data>
<DefaultData>HttpRepoDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
