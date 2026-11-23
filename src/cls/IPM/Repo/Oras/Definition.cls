Class %IPM.Repo.Oras.Definition Extends %IPM.Repo.Http.Definition
{

Parameter DISPLAYNAME As STRING = "ORAS";

Parameter MONIKER As STRING = "oras";

Property Namespace As %IPM.DataType.OrasNamespace;

Parameter TRUSTSERVERSUPPORTED As BOOLEAN = 1;

/// https URL of a Docker Content Trust (Notary) server, e.g. https://notary.example.com:4443.
/// When set, every package retrieved from this repository must be signed for its tag on that server.
Property TrustServer As %IPM.DataType.RepoLocation;

/// Covers the namespace as well as the URL, so repos on one registry can use different namespaces.
Method RepoKey() As %List
{
    return ..ComputeRepoKey(..URL, ..Namespace)
}

Method NamespaceGet() As %IPM.DataType.OrasNamespace
{
    return ##class(%IPM.DataType.OrasNamespace).Normalize(i%Namespace)
}

XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<commands>
<command name="repo">
<group name="ORAS repository">

<modifier name="oras" aliases="o" description="Create/update an ORAS server repository" />
<modifier name="namespace" aliases="ns" value="true" description="For ORAS repositories, specifies the registry namespace, i.e. the fully specified path to a package is &lt;url>/&lt;namespace>/&lt;package>.
Note, this is not the IRIS namespace, but a namespace in the sense of a (sub)directory in the registry's storage system. For example, if in a custom managed registry, the base url is 'registry.company.com', and the package is 'objectscript-example', but it will be stored at 'registry.company.com/packages/ipm/objectscript-example', then the namespace will be 'packages/ipm'." />
<modifier name="trust-server" value="true" description="For ORAS repositories, specifies the https URL of a Docker Content Trust (Notary) server, e.g. https://notary.example.com:4443. Packages from this repository are then only offered and installed when the trust server has a valid signature for their tag in the targets/releases or targets role. Verification runs the notary executable (see the NotaryExecutable setting). An empty value turns verification off." />
</group>
</command>
</commands>
}

/// Returns a REST client to interact with this server.
Method GetPackageService() As %IPM.Repo.IPackageService
{
    set tClient = ##class(%IPM.Repo.Oras.PackageService).%New()
    set tClient.Location = ##class(%IPM.DataType.RepoLocation).Canonicalize(..URL)
    set tClient.RepoName = ..Name
    set tClient.Namespace = ..Namespace
    set tClient.Username = ..Username
    set tClient.Password = ..Password
    set tClient.Token = ..Token
    set tClient.TokenAuthMethod = ..TokenAuthMethod
    set tClient.TrustServer = ..TrustServer
    quit tClient
}

/// Returns a REST client to publish modules/applications to this server.
Method GetPublishService() As %IPM.Repo.IPublishService
{
    set tClient = ##class(%IPM.Repo.Oras.PublishService).%New()
    set tClient.Location = ##class(%IPM.DataType.RepoLocation).Canonicalize(..URL)
    set tClient.RepoName = ..Name
    set tClient.Namespace = ..Namespace
    set tClient.Username = ..Username
    set tClient.Password = ..Password
    set tClient.Token = ..Token
    set tClient.TokenAuthMethod = ..TokenAuthMethod
    // The publish service inherits the package service's retrieval methods, which must check signatures too
    set tClient.TrustServer = ..TrustServer
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
    if (..TrustServer '= "") {
        write !,$char(9),"Trust server: ",..Padding(1),..TrustServer
    }
    if (..Username '= "") || (..Password '= "") || (..Token '= "") {
        set packageService = ..GetPackageService()
        try {
            set authenticated = (packageService.IsAvailable() && packageService.IsAuthenticated())
        } catch e {
            if e.%IsA("%Exception.SystemException") {
                throw e
            }
            // The base class shows the error under Available?
            set authenticated = 0
        }
        write !,$char(9),"Authenticated?",..Padding(1),$$$YesNo(authenticated)
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
        // Checked before anything below saves another repo
        if $data(pModifiers("trust-server"), trustServer) {
            set trustServer = ..NormalizeTrustServer(trustServer)
        }
        set tUrl = $get(pModifiers("url"), pInstance.URL)
        if (pInteractive && (tUrl = "")) {
            set tPrompt = ..#URLPromptString
            set tResponse = ##class(%Library.Prompt).GetString(tPrompt, .tUrl)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Operation cancelled."))
            }
        }
        set namespace = ##class(%IPM.DataType.OrasNamespace).Normalize($get(pModifiers("namespace"), pInstance.Namespace))
        // A repo saved with a path or a duplicate URL stays configurable, e.g. with -disable, until its URL or namespace changes
        if $data(pModifiers("url")) || $data(pModifiers("namespace")) || (pInstance.%Id() = "") {
            do ##class(%IPM.Repo.Oras.PackageService).CheckNoPath(tUrl, namespace)
            do ..CheckRepoKeyUnique(pInstance, ..ComputeRepoKey(tUrl, namespace), "URL and namespace")
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
            if $isobject(tServer),tServer.%Id()'=pInstance.%Id() {
                set tServer.DeploymentEnabled = 0
                $$$ThrowOnError(tServer.%Save())
            }
        }
        if $data(pModifiers("namespace"), tNamespace) {
            set pInstance.Namespace = tNamespace
        }
        if $data(pModifiers("trust-server")) {
            set pInstance.TrustServer = trustServer
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns trustServer canonicalized, or "" for "". Throws unless it is an https URL, as docker requires,
/// since the first check of a repository trusts the root key the server presents.
/// e.g. "HTTPS://Notary.example.com:443/" gives "https://notary.example.com"
ClassMethod NormalizeTrustServer(trustServer As %String) As %String
{
    if (trustServer = "") {
        return ""
    }
    if (trustServer '[ "://") || ($zconvert($piece(trustServer, "://"), "L") '= "https") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Trust server '%1' must be an https:// URL.", trustServer)))
    }
    set canonical = ##class(%IPM.DataType.RepoLocation).Canonicalize(trustServer)
    if $$$ISERR(##class(%IPM.DataType.RepoLocation).IsValid(canonical)) || ($piece(canonical, "/", 3) = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Trust server '%1' is not a valid URL.", trustServer)))
    }
    return canonical
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

XData LockFileMapping
{
<Mapping xmlns="http://www.intersystems.com/jsonmapping">
  <Property Name="LockFileType" FieldName="type" />
  <Property Name="OverriddenSortOrder" FieldName="overriddenSortOrder" />
  <Property Name="ReadOnly" FieldName="readOnly" />
  <Property Name="URL" FieldName="url" />
  <Property Name="Namespace" FieldName="orasNamespace" />
  <Property Name="TrustServer" FieldName="trustServer" />
</Mapping>
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
<Value name="7">
<Value>TrustServer</Value>
</Value>
</Data>
<DefaultData>OrasRepoDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
