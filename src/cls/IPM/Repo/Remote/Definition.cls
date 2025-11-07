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
    set tClient = ##class(%IPM.Repo.Remote.PackageService).%New()
    set tClient.Location = ..URL
    set tClient.Username = ..Username
    set tClient.Password = ..Password
    set tClient.Token = ..Token
    set tClient.TokenAuthMethod = ..TokenAuthMethod
    quit tClient
}

/// Returns a REST client to publish modules/applications to this server.
Method GetPublishService() As %IPM.Repo.IPublishService
{
    set tClient = ##class(%IPM.Repo.Remote.PublishService).%New()
    set tClient.Location = ..URL
    set tClient.Username = ..Username
    set tClient.Password = ..Password
    set tClient.Token = ..Token
    set tClient.TokenAuthMethod = ..TokenAuthMethod
    quit tClient
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(
	pInstance As %IPM.Repo.Definition,
	pInteractive As %Boolean = 1,
	ByRef pModifiers,
	ByRef pData) As %Status
{
    set tSC = $$$OK
    try {
        set tUrl = $get(pModifiers("url"), pInstance.URL)
        if (..URLExists(tUrl, .tId)) && (tId '= pInstance.%Id())  {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to add new remote server with non-unique URL."))
        }
        if (pInteractive && (tUrl = "")) {
            set tPrompt = ..#URLPromptString
            set tResponse = ##class(%Library.Prompt).GetString(tPrompt, .tUrl)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Operation cancelled."))
            }
        }

        if ( $$$lcase(tUrl) '= $$$lcase(pInstance.URL) ) {
            // when repo URL changing - clear all existing credentials
            set pInstance.Username = ""
            set pInstance.Password = ""
            set pInstance.Token = ""
        }

        if $data(pModifiers("username"), tUsername) {
            set pInstance.Username = tUsername
        }
        if $data(pModifiers("password"), tPassword) {
            set pInstance.Password = tPassword
        }
        if $data(pModifiers("token"), tToken) {
            set pInstance.Token = tToken
        }

        if $data(pModifiers("publish"), tPublish) {
            set pInstance.DeploymentEnabled = tPublish
        }
        if tUrl'="" {
            set pInstance.URL = tUrl
        }
        if (pInstance.DeploymentEnabled = 1) {
            set tServer = ##class(%IPM.Repo.Remote.Definition).DeploymentServerOpen(1)
            if $isobject(tServer),tServer.URL'=pInstance.URL {
                set tServer.DeploymentEnabled = 0
                $$$ThrowOnError(tServer.%Save())
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
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
    return ##class(%IPM.Repo.Remote.PublishManager).%Get(.status)
}

Method GetValuesForLockFile()
{
    set values = ##super()
    set values.type = "remote"
    return values
}

/// Sets values to a repo object as defined by a lock file
/// This method neither creates nor saves the new repo object, just sets the values
/// This allows for a bit more abstraction to allow classes to call superclasses to set some values
Method SetValuesFromLockFile(repoValues As %DynamicObject)
{
    do ##super(.repoValues)
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
