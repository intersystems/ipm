Class %IPM.Repo.Http.Definition Extends %IPM.Repo.Definition [ Abstract ]
{

Parameter MONIKER As String = "http";

/// The maximum number of tabs to display for padding purposes.
/// Override this in subclasses to provide more padding.
Parameter MaxDisplayTabCount As INTEGER = 4;

Property URL As %IPM.DataType.RepoLocation [ Required ];

Index URL On URL [ Unique ];

Parameter URLPromptString = {$$$Text("Registry URL:","ZPM")};

Property Username As %String(MAXLEN = "");

Property Password As %String(MAXLEN = "");

Property Token As %String(MAXLEN = "");

Property TokenAuthMethod As %String(VALUELIST = "-apiKey-bearer-basic") [ InitialExpression = "apiKey" ];

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
<modifier name="token-auth-method" value="true" description="Enum of { basic, bearer, apiKey }. Defaults to apiKey. If set to 'basic', token will be included as 'Authorization: Basic &lt;token&gt;'. If set to 'bearer', token will be included as 'Authorization: Bearer &lt;token&gt;'. If set to 'apiKey', token will be included as 'apiKey: &lt;token&gt;'" />
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

	Write !,$c(9),"Default Deployment Registry? ",..Padding(3),$Case(..DeploymentEnabled,1:"Yes",:"No")

	If (..Username '= "") {
		Write !,$c(9),"Username: ",..Padding(1),..Username
	}
	If (..Password '= "") {
		Write !,$c(9),"Password: ",..Padding(1),$Case(..Password,"":"<unset>",:"<set>")
	}
	If (..Token '= "") {
		Write !,$c(9),"Token: ",..Padding(0),$Case(..Token,"":"<unset>",:"<set>")
	}
	If (..Token '= "") || (..Password '= "") || (..Username '= "") {
		Write !,$c(9),"Token Auth Method: ",..Padding(2),..TokenAuthMethod
	}
}

Method GetSortOrder() As %Integer [ Private ]
{
	// TODO: Allow this to be changed dynamically.
	Quit 2 + $Case(..%Id(),"":1,:..%Id())
}

Query PublishingServer() As %Query(ROWSPEC = "Name:%String,ID:%Integer,Url:%String,Class:%String") [ SqlProc ]
{
}

ClassMethod PublishingServerExecute(ByRef qHandle As %Binary) As %Status
{
	Set tSC = $$$OK
	Set rs = ##class(%Dictionary.ClassDefinitionQuery).SubclassOfFunc(..%ClassName(1))

	Try {
		While rs.%Next() {
			Set classname = rs.Name
			Set tRS = $ClassMethod(classname,"PublishingServerFunc")
			If (tRS.%SQLCODE = 0) && tRS.%Next() {
				#; Order by publish order and then name
				Set qHandle(tRS.PublishOrder _ "/" _ tRS.Name) = $LB(tRS.ID, tRS.URL, classname)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod PublishingServerFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = PublishingServerExecute ]
{
	Set orderName = $Order(qHandle($Get(qHandle)))
	If (orderName = "") {
		Set AtEnd = 1
	} Else {
		#; publish order is an integer while name is a string that could contain a "/"
		Set order = $PIECE(orderName, "/", 1)
		Set name = $PIECE(orderName, "/", 2, *)
		Set Row = $lb(name) _ qHandle(orderName)
		Set qHandle = orderName
	}
	Quit $$$OK
}

ClassMethod PublishingServerClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = PublishingServerFetch ]
{
	Quit $$$OK
}

Method GetPublishingManager(ByRef status) [ Abstract ]
{
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
<Value name="6">
<Value>TokenAuthMethod</Value>
</Value>
</Data>
<DefaultData>HttpRepoDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
