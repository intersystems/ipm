Class %IPM.Repo.Oras.Definition Extends %IPM.Repo.Http.Definition
{

Parameter DISPLAYNAME As STRING = "ORAS";

Parameter MONIKER As STRING = "oras";

Property Namespace As %IPM.DataType.OrasNamespace;

XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<commands>
<command name="repo">
<group name="ORAS repository">

<modifier name="oras" aliases="o" description="Create/update an ORAS server repository" />
<modifier name="namespace" aliases="ns" value="true" description="For ORAS repositories, specifies the registry namespace, i.e. the fully specified path to a package is &lt;url>/&lt;namespace>/&lt;package>.
Note, this is not the IRIS namespace, but a namespace in the sense of a (sub)directory in the registry's storage system. For example, if in a custom managed registry, the base url is 'registry.company.com', and the package is 'objectscript-example', but it will be stored at 'registry.company.com/packages/ipm/objectscript-example', then the namespace will be 'packages/ipm'." />
</group>
</command>
</commands>
}

/// Returns a REST client to interact with this server.
Method GetPackageService() As %IPM.Repo.IPackageService
{
    set tClient = ##class(%IPM.Repo.Oras.PackageService).%New()
    // We want to preprend the prefix to the "GET"/"POST"/etc. requests
    // Otherwise, it will be overwritten
    do ##class(%Net.URLParser).Decompose(..URL,.comp)
    if $data(comp("path"), path) && (path '= "") {
        if $extract(path, *) '= "/" {
            set path = path _ "/"
        }
        set tClient.PathPrefix = path
    }
    kill comp("path")
    set tClient.Location = ##class(%Net.URLParser).Compose(.comp)
    set tClient.Namespace = ..Namespace
    set tClient.Username = ..Username
    set tClient.Password = ..Password
    set tClient.Token = ..Token
    set tClient.TokenAuthMethod = ..TokenAuthMethod
    quit tClient
}

/// Returns a REST client to publish modules/applications to this server.
Method GetPublishService() As %IPM.Repo.IPublishService
{
    set tClient = ##class(%IPM.Repo.Oras.PublishService).%New()
    set tClient.Location = ..URL
    set tClient.Namespace = ..Namespace
    set tClient.Username = ..Username
    set tClient.Password = ..Password
    set tClient.Token = ..Token
    set tClient.TokenAuthMethod = ..TokenAuthMethod
    quit tClient
}

/// Outputs information about this server to the current device.
/// Subclasses may override to show additional information.
Method Display()
{
    do ##super()
    if (..Namespace '= "") {
        write !,$char(9),"Namespace: ",..Padding(1),..Namespace
    }
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
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to add new ORAS server with non-unique URL."))
        }
        if (pInteractive && (tUrl = "")) {
            set tPrompt = ..#URLPromptString
            set tResponse = ##class(%Library.Prompt).GetString(tPrompt, .tUrl)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Operation cancelled."))
            }
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
        if $data(pModifiers("token-auth-method"), tokenAuthMethod) # 2 {
            set pInstance.TokenAuthMethod = tokenAuthMethod
        }
        if $data(pModifiers("publish"), tPublish) {
            set pInstance.DeploymentEnabled = tPublish
        }
        if tUrl'="" {
            set pInstance.URL = tUrl
        }
        if (pInstance.DeploymentEnabled = 1) {
            set tServer = ##class(%IPM.Repo.Oras.Definition).DeploymentServerOpen(1)
            if $isobject(tServer),tServer.URL'=pInstance.URL {
                set tServer.DeploymentEnabled = 0
                $$$ThrowOnError(tServer.%Save())
            }
        }
        if $data(pModifiers("namespace"), tNamespace) {
            set pInstance.Namespace = tNamespace
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
    FROM %IPM_Repo_Oras.Definition
    WHERE Enabled = 1
}

Method GetPublishingManager(ByRef status)
{
    return ##class(%IPM.Repo.Oras.PublishManager).%Get(.status)
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
