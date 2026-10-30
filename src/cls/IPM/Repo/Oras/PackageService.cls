Include %IPM.Common

Class %IPM.Repo.Oras.PackageService Extends %IPM.Repo.Http.PackageService
{

/// The base URL for this repo, e.g. https://irepo.intersystems.com
/// The API endpoint is will be located at <Location>/v2/
Property Location As %IPM.DataType.RepoLocation;

/// Optional extension for where packages get published to and pulled from
/// i.e. the API endpoint for a given module will be at <Location>/v2/<Namespace>/<Module>
Property Namespace As %IPM.DataType.OrasNamespace;

/// Module name for a registry repository path, i.e. the path without this service's namespace.
/// e.g. with namespace "packages", "packages/module-a" -> "module-a"
Method ModuleNameFromRepository(repository As %String) As %String
{
    set prefix = ..Namespace _ "/"
    if (..Namespace '= "") && ($extract(repository, 1, $length(prefix)) = prefix) {
        return $extract(repository, $length(prefix) + 1, *)
    }
    return repository
}

/// Prefix for ORAS API calls
Property PathPrefix As %String(MAXLEN = "");

/// Name of the repo definition this service was built from, for messages.
Property RepoName As %String(MAXLEN = "");

/// Result of ProbeCredentials once RegistryFailure has needed it, otherwise "".
Property CredentialsProbe As %String [ Private ];

Parameter ALLOWPREFIXINLOCATION = 0;

/// Splits url into a location with a scheme and no path, and a path prefix with no leading slash and a trailing slash.
/// e.g. "ghcr.io/myorg" gives "https://ghcr.io" and "myorg/"
ClassMethod SplitLocation(
	url As %String,
	Output location As %String,
	Output pathPrefix As %String)
{
    do ..ParseLocation(url, .components)
    set pathPrefix = components("path")
    if (pathPrefix '= "") && ($extract(pathPrefix, *) '= "/") {
        set pathPrefix = pathPrefix _ "/"
    }
    kill components("path")
    set location = ##class(%Net.URLParser).Compose(.components)
}

/// Splits the repo URL as SplitLocation does. The package service keeps the path in PathPrefix,
/// while the publish service's Location is the whole repo URL.
Method SplitRepoLocation(
	Output location As %String,
	Output pathPrefix As %String) [ Private ]
{
    do ..SplitLocation(..Location, .location, .pathPrefix)
    set pathPrefix = ..PathPrefix _ pathPrefix
}

/// Classifies failure, which came from an operation on module moduleName, and returns it.
/// A 401 or 403 with credentials configured probes them, at most once for this service.
Method RegistryFailure(
	failure As %IPM.Repo.Oras.HttpException,
	moduleName As %String) As %IPM.Repo.Oras.HttpException
{
    set probe = ""
    if ((failure.StatusCode = 401) || (failure.StatusCode = 403)) && ..HasCredentials() {
        if ..CredentialsProbe = "" {
            set ..CredentialsProbe = ..ProbeCredentials()
        }
        set probe = ..CredentialsProbe
    }
    do ..SplitRepoLocation(.location, .pathPrefix)
    set repoURL = $zstrip(location _ "/" _ pathPrefix, ">", "/")
    do failure.Classify(..RepoName, repoURL, moduleName, ..HasCredentials(), probe)
    return failure
}

/// Returns e classified by RegistryFailure if it is a failed registry response for module moduleName, otherwise e.
Method ClassifyException(
	e As %Exception.AbstractException,
	moduleName As %String) As %Exception.AbstractException
{
    set failure = ##class(%IPM.Repo.Oras.HttpException).FromException(e)
    if $isobject(failure) {
        return ..RegistryFailure(failure, moduleName)
    }
    return e
}

// ** PACKAGE SERVICE FUNCTIONS **

/// For run-time checks to ensure the service is available before attempting to invoke it.
/// Returns true if the registry is reachable.
/// Per the OCI Distribution Spec, GET /v2/ returning 401 means the registry is up but requires
/// authentication — this is not a failure. We check for WWW-Authenticate (required by RFC 7235 on
/// any proper 401) rather than Docker-Distribution-Api-Version, since many registries omit the latter.
Method IsAvailable() As %Boolean
{
    set request = ..GetHttpRequest(..Location)
    set request.Timeout = 5
    if $$$ISERR(request.Get(..PathPrefix _ "v2/")) {
        return 0
    }
    set statusCode = request.HttpResponse.StatusCode
    if (200 <= statusCode) && (statusCode < 300) {
        return 1
    }
    if statusCode = 401 {
        return (request.HttpResponse.GetHeader("WWW-AUTHENTICATE") '= "")
    }
    return 0
}

/// Returns true if the configured credentials are accepted by the registry.
/// Always returns true when no credentials are configured (anonymous access).
/// This is used for display (repo -list). Actual operations (pull, push,
/// list modules) delegate to the Python ORAS client via GetClient(), which handles the
/// full token exchange independently.
Method IsAuthenticated() As %Boolean
{
    return ..ProbeCredentials() = $$$OrasCredentialsAccepted
}

/// Returns whether the registry accepts the configured credentials: $$$OrasCredentialsAccepted, $$$OrasCredentialsRejected,
/// or $$$OrasCredentialsUnknown when the registry could not be asked or its answer does not say.
/// $$$OrasCredentialsAccepted when no credentials are configured.
Method ProbeCredentials() As %String
{
    if '..HasCredentials() {
        return $$$OrasCredentialsAccepted
    }
    // Probe GET /v2/ with credentials attached by GetHttpRequest().
    // Some registries accept credentials directly here and return 2xx.
    do ..SplitRepoLocation(.location, .pathPrefix)
    set request = ..GetHttpRequest(location)
    set request.Timeout = 5
    if $$$ISERR(request.Get(pathPrefix _ "v2/")) {
        return $$$OrasCredentialsUnknown
    }
    set statusCode = request.HttpResponse.StatusCode
    if (200 <= statusCode) && (statusCode < 300) {
        return $$$OrasCredentialsAccepted
    }
    if (statusCode '= 401) && (statusCode '= 403) {
        return $$$OrasCredentialsUnknown
    }
    set wwwAuth = request.HttpResponse.GetHeader("WWW-AUTHENTICATE")
    set scheme = $zconvert($piece(wwwAuth, " ", 1), "L")
    set sentBasic = ..HasBasicCredentials()
    // GetHttpRequest() sends any other token as a header
    set sentToken = (..Token '= "") && (..TokenAuthMethod '= "basic")
    // The registry refused credentials sent on /v2/ itself
    if sentToken || (sentBasic && (scheme = "basic")) {
        return $$$OrasCredentialsRejected
    }
    // A Bearer challenge means the registry uses a token endpoint for auth.
    // Parse the challenge and probe that endpoint to verify the credentials.
    if (scheme = "bearer") && sentBasic {
        return ..ProbeTokenEndpoint(wwwAuth)
    }
    return $$$OrasCredentialsUnknown
}

Method HasCredentials() As %Boolean
{
    return (..Username '= "") || (..Password '= "") || (..Token '= "")
}

/// Returns whether credentials are configured that are sent as Basic authentication: a username and password, or a "basic" token.
Method HasBasicCredentials() As %Boolean [ Private ]
{
    return ((..Username '= "") && (..Password '= "")) || ((..Token '= "") && (..TokenAuthMethod = "basic"))
}

/// Probes the Bearer token endpoint from a WWW-Authenticate challenge to check whether
/// the configured Basic credentials are accepted, returning the same values as ProbeCredentials.
/// We do not use the returned token, since a 2xx response is sufficient to confirm the credentials are valid.
/// We probe here rather than delegating to the Python ORAS client because oras-py has
/// no request timeout, so client.get_tags() can hang for a long time.
Method ProbeTokenEndpoint(wwwAuth As %String) As %String [ Private ]
{
    // Parse the token endpoint URL (realm) and optional service identifier from the challenge header.
    // Example: Bearer realm="https://ghcr.io/token",service="ghcr.io"
    set realmMatcher = ##class(%Regex.Matcher).%New("realm=""([^""]+)""", wwwAuth)
    if 'realmMatcher.Locate() {
        return $$$OrasCredentialsUnknown
    }
    set realm = realmMatcher.Group(1)
    set serviceMatcher = ##class(%Regex.Matcher).%New("service=""([^""]+)""", wwwAuth)
    set service = ""
    if serviceMatcher.Locate() {
        set service = serviceMatcher.Group(1)
    }
    // Build a request to the token endpoint (which may be on a different host than the registry)
    do ..ParseLocation(realm, .comp)
    set tokenRequest = ##class(%Net.HttpRequest).%New()
    set tokenRequest.Timeout = 5
    // A redirect could send the credentials elsewhere, including over plain http
    set tokenRequest.FollowRedirect = 0
    set tokenRequest.Server = comp("host")
    if ($data(comp("port")) # 2) && (comp("port") '= "") {
        set tokenRequest.Port = comp("port")
    }
    if $zconvert(comp("scheme"), "L") = "https" {
        set tokenRequest.Https = 1
        set tokenRequest.SSLConfiguration = ..GetSSLConfiguration(tokenRequest.Server)
    }
    // Attach credentials: username+password via Basic auth, or a "basic"-method token as a
    // pre-encoded Basic header (used by e.g. AWS ECR which issues a raw user:pass token string)
    if (..Username '= "") && (..Password '= "") {
        set tokenRequest.Username = ..Username
        set tokenRequest.Password = ..Password
    } elseif ..TokenAuthMethod = "basic" {
        do tokenRequest.SetHeader("Authorization", "Basic " _ ..Token)
    }
    set path = comp("path")
    // scope is omitted, since we are only probing whether the credentials are accepted, not
    // requesting access to a specific module. Registries that strictly require scope
    // may return 400, which reads as unknown.
    if service '= "" {
        set path = path _ "?service=" _ service
    }
    if $$$ISERR(tokenRequest.Get(path)) {
        return $$$OrasCredentialsUnknown
    }
    set statusCode = tokenRequest.HttpResponse.StatusCode
    // 2xx means the token endpoint accepted the credentials, and we don't need the token itself
    if (200 <= statusCode) && (statusCode < 300) {
        return $$$OrasCredentialsAccepted
    }
    if (statusCode = 401) || (statusCode = 403) {
        return $$$OrasCredentialsRejected
    }
    return $$$OrasCredentialsUnknown
}

Method GetModule(
	pModuleReference As %IPM.Storage.ModuleInfo,
	Output AsArchive As %Boolean = 0) As %Stream.Object
{
    set tag = ..TagForReference(pModuleReference)
    try {
        set status = ..Pull(..Location, pModuleReference.Name, tag, ..Namespace, ..Username, ..Password, ..Token, ..TokenAuthMethod, .stream)
    } catch e {
        throw ..ClassifyException(e, pModuleReference.Name)
    }
    $$$ThrowOnError(status)
    #; module is pulled as a .tgz file
    set AsArchive = 1
    return stream
}

Method GetModuleManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
    set name = pModuleReference.Name _ ":" _ ..TagForReference(pModuleReference)
    // GetModuleXML returns a string, but callers expect a stream per %IPM.Repo.IPackageService
    try {
        set moduleXML = ..GetModuleXML(..Location, name, ..Namespace, ..Username, ..Password, ..Token, ..TokenAuthMethod)
    } catch e {
        throw ..ClassifyException(e, pModuleReference.Name)
    }
    if (moduleXML = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No manifest found for '" _ name _ "' in registry " _ ..Location))
    }
    set stream = ##class(%Stream.GlobalCharacter).%New()
    $$$ThrowOnError(stream.Write(moduleXML))
    $$$ThrowOnError(stream.Rewind())
    return stream
}

/// Returns the registry tag holding the artifact for the given module reference.
/// A deployed module is tagged with a platform version suffix, since one version of it
/// is built separately for each supported platform.
ClassMethod TagForReference(moduleReference As %IPM.Storage.ModuleInfo) As %String [ Private ]
{
    set tag = $$$Semver2Tag(moduleReference.VersionString)
    if moduleReference.Deployed {
        if (moduleReference.PlatformVersion = "") {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot locate deployed module '" _ moduleReference.Name _ "' " _ moduleReference.VersionString _ " without a platform version."))
        }
        set tag = tag _ $$$OrasTagPlatformSeparator _ moduleReference.PlatformVersion
    }
    return tag
}

Method HasModule(pModuleReference As %IPM.Storage.ModuleInfo) As %Boolean
{
    set name = pModuleReference.Name _ ":" _ $$$Semver2Tag(pModuleReference.VersionString)

    #; Get ORAS client
    set client = ..GetClient(..Location, ..Username, ..Password, ..Token, ..TokenAuthMethod)

    return ..HasModuleHelper(..Location, name, ..Namespace, client)
}

/// Given a list of ORAS tags, aggregate the platform versions by package version
/// e.g. $lb("1.0.0__2024.1, "1.0.0__2024.2", "2.0.0__2023.1", "3.0.0") -> aggregatedPlatformVersion
/// where aggregatedPlatformVersion("1.0.0") = $lb("2024.1","2024.2")
///       aggregatedPlatformVersion("2.0.0") = $lb("2023.1")
///       aggregatedPlatformVersion("3.0.0") = $lb("")
/// The returned list represents the correct order of the package versions, where latest versions are first
/// e.g., $lb("1.0.0", "2.0.0", "3.0.0") -> $lb("3.0.0", "2.0.0", "1.0.0")
ClassMethod AggregatePlatformVersions(
	tagsList As %List,
	Output aggregatedPlatformVersion As %String) As %List
{
    set ptr = 0
    while $listnext(tagsList, ptr, tag) {
        // aggregate
        set parsed = $listfromstring(tag, $$$OrasTagPlatformSeparator)
        set version = $listget(parsed, 1)
        set platformVersion = $listget(parsed, 2, "")  // Default to empty string if no platform
        set value = $get(aggregatedPlatformVersion(version))
        set aggregatedPlatformVersion(version) = value _ $listbuild(platformVersion)
    }

    set version = "", versionList = ""
    for {
        set version = $order(aggregatedPlatformVersion(version))
        if (version = "") {
            quit
        }
        set versionList = versionList _ $listbuild(version)
    }

    set pyList = ##class(%SYS.Python).ToList(versionList)
    set sortedTags = ##class(%IPM.Utils.EmbeddedPython).SortVersions(pyList, 1)
    return ##class(%IPM.Utils.EmbeddedPython).FromPythonList(sortedTags)
}

/// Reorders versionsList so that versions with an artifact for currentPlatform come first, each
/// group keeping the newest-first order it arrived in. A caller that reports only the first version
/// therefore reports the newest installable one, falling back to the newest version overall when
/// the module has no artifact for this platform at all.
ClassMethod PreferCompatibleVersions(
	versionsList As %List,
	ByRef aggregatedPlatformVersion,
	currentPlatform As %String) As %List
{
    set compatible = "", incompatible = ""
    set ptr = 0
    while $listnext(versionsList, ptr, version) {
        set platformVersions = $get(aggregatedPlatformVersion(version))
        // An empty platform means the version is not platform-specific, so anything can use it.
        if ($listfind(platformVersions, "") > 0) || ($listfind(platformVersions, currentPlatform) > 0) {
            set compatible = compatible _ $listbuild(version)
        } else {
            set incompatible = incompatible _ $listbuild(version)
        }
    }
    return compatible _ incompatible
}

/// <var>moduleList</var> is a list of objects of type <class>%IPM.Storage.ModuleInfo</class> to which this method adds entries
/// <var>name</var> is the name of the package for which we are enumerating versions
/// A 401 or 403 from the registry adds nothing, unless the registry rejected the credentials, which throws.
Method ListModulesFromTagString(
	semverExpr As %IPM.General.SemanticVersionExpression,
	client As %SYS.Python,
	searchCriteria As %IPM.Repo.SearchCriteria,
	name As %String,
	ByRef moduleList As %ListOfObjects)
{
    try {
        do ..AddModulesFromTags(semverExpr, client, searchCriteria, name, .moduleList)
    } catch e {
        set e = ..ClassifyException(e, ..ModuleNameFromRepository(name))
        if 'e.%IsA("%IPM.Repo.Oras.HttpException") || ((e.StatusCode '= 401) && (e.StatusCode '= 403)) || e.CredentialsRejected {
            throw e
        }
    }
}

/// Adds to moduleList as ListModulesFromTagString does, throwing every failure.
Method AddModulesFromTags(
	semverExpr As %IPM.General.SemanticVersionExpression,
	client As %SYS.Python,
	searchCriteria As %IPM.Repo.SearchCriteria,
	name As %String,
	ByRef moduleList As %ListOfObjects) [ Private ]
{
    set allTagsString = ..GetAllTags(..Location, name, "", client)
    set allVersionsList = ..AggregatePlatformVersions($listfromstring(allTagsString, ", "), .aggregatedPlatformVersion)
    // The tri-states of AllVersions that report a single version should report one this platform
    // can actually install. The empty state reports every version, so its order doesn't matter.
    if (searchCriteria.AllVersions '= "") {
        set allVersionsList = ..PreferCompatibleVersions(allVersionsList, .aggregatedPlatformVersion, $$$CurrentPlatformVersion)
    }
    set pointer = 0
    while $listnext(allVersionsList,pointer,moduleVersion) {
        // filter by version
        set tVersion = ##class(%IPM.General.SemanticVersion).FromString($$$Tag2Semver(moduleVersion))
        if 'tVersion.Satisfies(semverExpr) {
            continue
        }

        // Special case: if we provided an explicit build number, require it.
        if ##class(%IPM.General.SemanticVersion).IsValid(searchCriteria.VersionExpression,.specificVersion) && (specificVersion.Build '= "") && (specificVersion.Build '= tVersion.Build) {
            continue
        }

        // If there are multiple platform versions for a given package version, we only want to use the metadata of one of them
        set platformVersions = aggregatedPlatformVersion(moduleVersion)
        set platformVersion = $listget(platformVersions)
        set tag = moduleVersion
        if (platformVersion '= "") {
            set tag = tag _ $$$OrasTagPlatformSeparator _ platformVersion
        }

        // get metadata from annotations
        set metadata = ..GetPackageMetadata(..Location, name, tag, "", client)
        if (metadata = "") {
            // Tag exists in the tag list but manifest is unreachable — skip silently
            continue
        }
        set artifactMetadata = ##class(%IPM.Repo.Oras.ArtifactMetadata).%New()
        $$$ThrowOnError(artifactMetadata.%JSONImport(metadata))

        // Filter by module name if requested - check both Name and ExternalName
        if (searchCriteria.Name '= "") {
            // Extract the package name without namespace prefix for comparison
            // Package name from ORAS may be "namespace/modulename" or just "modulename"
            set packageNameWithoutNamespace = $piece(name, "/", *)

            // First check if package name already matches
            set packageNameMatches = ($$$lcase(packageNameWithoutNamespace) = $$$lcase(searchCriteria.Name))

            // If packageNameMatches is true, proceed without additional checks
            // Otherwise fetch module.xml to check namespaced Name and ExternalName
            if 'packageNameMatches {
                // Note: pass empty namespace since 'name' already includes the full path
                set moduleXMLText = ..GetModuleXML(..Location, name _ ":" _ tag, "", ..Username, ..Password, ..Token, ..TokenAuthMethod)

                if (moduleXMLText '= "") {
                    // Parse module.xml
                    try {
                        set moduleObj = ##class(%IPM.Utils.Module).GetModuleObjectFromString(moduleXMLText, .found)
                    } catch ex {
                        // if a single module.xml fails to parse, move onto the next one instead of failing completely
                        continue
                    }
                    if 'found {
                        continue
                    }

                    // Check if search name matches either Name or ExternalName (case-insensitive)
                    set matchesName = ($$$lcase(moduleObj.Name) = $$$lcase(searchCriteria.Name))
                    set matchesExternalName = ((moduleObj.ExternalName '= "") && ($$$lcase(moduleObj.ExternalName) = $$$lcase(searchCriteria.Name)))

                    // Only include if at least one matches
                    if 'matchesName && 'matchesExternalName {
                        continue
                    }
                } else {
                    // No module.xml available - skip this module
                    continue
                }
            }
        }

        // Determine packaging type from annotation; absent means source for backwards compatibility
        set modPackaging = $case(artifactMetadata.IPMPackaging, "database":"database", :"source")

        // Apply packaging filter if specified
        if (searchCriteria.Packaging '= "") && (modPackaging '= searchCriteria.Packaging) {
            continue
        }

        set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
        // `artifactMetadata.ImageTitle` can be different from `name`. E.g., when the module was simply "moved" from elsewhere under a different name.
        // Without the namespace, which the other methods of this service prefix
        set tModRef.Name = ..ModuleNameFromRepository(name)
        // `artifactMetadata.ImageVersion` can be different from `moduleVersion`. E.g., when the module was simply "moved" from elsewhere under a different tag
        set tModRef.VersionString = tVersion.ToString()
        set tModRef.Repository = artifactMetadata.ImageSource
        set tModRef.Description = artifactMetadata.ImageDescription
        set tModRef.Deployed = artifactMetadata.IPMDeployed
        // Skipped for AllVersions, which reports a single entry standing in for every version;
        // these platforms belong to just one of them.
        if (artifactMetadata.IPMDeployed '= "") && 'searchCriteria.AllVersions {
            set pvPtr = 0
            while $listnext(platformVersions, pvPtr, pv) {
                $$$ThrowOnError(tModRef.PlatformVersions.Insert(pv))
            }
        }
        if searchCriteria.AllVersions {
            // TODO: Convert these to semvers. This is just for display so OK not to for now.
            set tModRef.AllVersions = allTagsString
        }
        set tModRef.Origin = artifactMetadata.IPMOrigin
        do moduleList.Insert(tModRef)

        if (searchCriteria.AllVersions '= "") {
            // This is a tri-state.
            // 0: don't show them.
            // 1: do show them
            // empty: we're resolving dependencies so DON'T QUIT.
            quit
        }
    }
}

/// Lists the modules available in this repository that satisfy the search criteria
/// Note: for ORAS repositories only, the internal name and external name can be used interchangeably
Method ListModules(pSearchCriteria As %IPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%IPM.Storage.ModuleInfo")
{
    // Get ORAS client
    set client = ..GetClient(..Location, ..Username, ..Password, ..Token, ..TokenAuthMethod)

    // Parse search criteria
    set tVersionExpression = pSearchCriteria.VersionExpression
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pSearchCriteria.VersionExpression, .tVersionExpression)
    $$$ThrowOnError(tSC)

    // Collect list of modules
    set tList = ##class(%Library.ListOfObjects).%New()

    // Use /v2/_catalog to enumerate all packages, then filter appropriately
    // Note: not every registry supports this endpoint, but without it, searching becomes much harder without using registry-specific endpoints
    set request = ..GetHttpRequest()
    // Make GET request
    // response is a JSON structure like {"repositories":["package1", "package2", ...]}
    set tSC=request.Get(..PathPrefix _ "/v2/_catalog")
    $$$ThrowOnError(tSC)
    set response=request.HttpResponse
    if (response.StatusCode=200) {
        // Handle results
        set data = ##class(%DynamicAbstractObject).%FromJSON(response.Data)
        set iter = data.repositories.%GetIterator()
        // Iterate through each package
        // key is the index
        // package is the package name
        // type is always "string"
        while iter.%GetNext(.key, .package, .type) {
            if (package="") {
                continue
            }

            // If namespace is configured, only consider packages in that namespace
            if (..Namespace '= "") {
                set namespacePrefix = ..Namespace _ "/"
                // Skip packages not in this namespace
                if ($extract(package, 1, $length(namespacePrefix)) '= namespacePrefix) {
                    continue
                }
            }

            // collect all versions for this package in tList
            do ..ListModulesFromTagString(tVersionExpression, client, pSearchCriteria, package, .tList)
        }
    }
    // Endpoint failed, but if the name is specified, still try to find it
    if tList.Count()=0 {
        set name = pSearchCriteria.Name
        if (name '= "") {
            if ..Namespace '= "" {
                set name = ..AppendURIs(..Namespace, name)
            }
            do ..ListModulesFromTagString(tVersionExpression, client, pSearchCriteria, name, .tList)
        } elseif response.StatusCode '= 200 {
            if (response.StatusCode = 401) || (response.StatusCode = 403) {
                set failure = ##class(%IPM.Repo.Oras.HttpException).%New("RegistryHttpError", response.StatusCode)
                set failure.StatusCode = response.StatusCode
                set failure.Reason = response.ReasonPhrase
                do ..SplitRepoLocation(.location, .pathPrefix)
                set failure.URL = location _ "/" _ pathPrefix _ "v2/_catalog"
                if ..RegistryFailure(failure, "_catalog").CredentialsRejected {
                    throw failure
                }
            }
            if response.StatusCode = 401 {
                set msg = "Registry requires authorization for catalog listing or does not support it."
            } else {
                set msg = "Call to /v2/_catalog endpoint failed. This registry may not support it."
                set msg = msg _ $char(10,13) _ "Response Code: "_response.StatusCode _ " - " _ response.ReasonPhrase
            }
            $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
        }
    }
    return tList
}

/// ** ORAS FUNCTIONS **
/// Returns an authenticated ORAS client
ClassMethod GetClient(
	registry As %String,
	username As %String = "",
	password As %String = "",
	token As %String = "",
	tokenAuthMethod As %String) As %SYS.Python
{
    try {
        set args = {}
        set args.hostname = registry
        #; assume everything not specified is using https
        set args.insecure = registry [ "http://"
        set client = ..OrasHelper().BasicAwareRegistry(args...)

        if username '= "", password '= "" {
            do client."set_basic_auth"(username, password)
        } elseif token '= "" {
            if tokenAuthMethod = "basic" {
                #; AWS tokens are essentially username:password in one string
                set client."_basic_auth" = token
                do client."reset_basic_auth"()
            } elseif tokenAuthMethod = "bearer" {
                #; Bearer token
                do client."set_token_auth"(token)
            } elseif tokenAuthMethod = "apiKey" {
                #; API key
                do client."set_header"("apikey", token)
            } else {
                $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Unknown token auth method: ""%1""", tokenAuthMethod)))
            }
        }
    } catch e {
        // The same permission failure has been seen as both <SYNTAX> and <PYTHON EXCEPTION>, so match on the details rather than the name
        set details = $zconvert(e.DisplayString(), "L")
        set pythonDir = ##class(%File).NormalizeDirectory("python", ##class(%File).ManagerDirectory())
        // Python reports the path as it appeared in sys.path, whose case can differ from the manager directory's
        if ((details [ "permissionerror") && (details [ $zconvert(pythonDir, "L"))) || ((details [ "modulenotfounderror") && ..IsOrasUnreadable(pythonDir)) {
            set eStatus = e.AsStatus()
            set usrStatus = $$$ERROR($$$GeneralError,$$$OrasPythonPackagesUnreadable)
            $$$ThrowStatus($$$EMBEDSC(usrStatus,eStatus))
        } elseif e.Name = "<OBJECT DISPATCH>" {
            set eStatus = e.AsStatus()
            set usrStatus = $$$ERROR($$$GeneralError,$$$OrasRequiresFlexiblePython)
            $$$ThrowStatus($$$EMBEDSC(usrStatus,eStatus))
        } else {
            throw e
        }
    }
    return client
}

/// Imports oras.provider, retrying once if it is not found.
/// A process that tried to import oras while it was unreadable keeps the result, so retrying lets a repaired installation work without a new process.
ClassMethod ImportOrasProvider() As %SYS.Python [ Internal, Language = python ]
{
    import importlib
    import sys

    try:
        return importlib.import_module("oras.provider")
    except ModuleNotFoundError:
        pass

    for name in [name for name in sys.modules if (name == "oras") or name.startswith("oras.")]:
        del sys.modules[name]
    # Python caches each directory's listing, including the empty one it got for an unreadable directory
    importlib.invalidate_caches()
    return importlib.import_module("oras.provider")
}

/// Returns a module with the Python IPM uses around oras-py:
/// BasicAwareRegistry, RegistryHttpError and registry_message.
/// Cached in sys.modules so RegistryHttpError stays one class across calls.
ClassMethod OrasHelper() As %SYS.Python [ Internal, Language = python ]
{
    import json
    import sys
    import types

    cached = sys.modules.get("_ipm_oras")
    if (cached is not None) and (cached.provider is sys.modules.get("oras.provider")):
        return cached

    import iris
    import requests

    provider = iris.cls("%IPM.Repo.Oras.PackageService").ImportOrasProvider()

    def clean(text):
        """Text from a registry on one line, without control characters."""
        return " ".join("".join(c if c.isprintable() else " " for c in str(text)).split())

    def registry_message(text):
        """The registry's message from an OCI {"errors": [...]} body or a top-level {"message": ...} body."""
        try:
            body = json.loads(text)
        except (TypeError, ValueError):
            return ""
        if not isinstance(body, dict):
            return ""
        errors = body.get("errors")
        if isinstance(errors, list):
            if errors and isinstance(errors[0], dict):
                return clean(errors[0].get("message") or "")
            return ""
        return clean(body.get("message") or "")

    class RegistryHttpError(Exception):
        """A failed registry response. str() is JSON for ObjectScript to parse."""

        def __init__(self, response):
            self.status = response.status_code
            self.reason = clean(response.reason or "")
            # Signed blob URLs carry credentials in the query
            self.url = (response.url or "").split("?", 1)[0]
            try:
                self.message = registry_message(response.text)
            except Exception:
                # A streamed response may already be closed
                self.message = ""
            super().__init__(json.dumps({"status": self.status, "reason": self.reason, "url": self.url, "message": self.message}))

    def failed(response):
        return (response is not None) and not (200 <= response.status_code < 300)

    raise_on_missing = object()

    class BasicAwareRegistry(provider.Registry):
        """Answers Basic challenges, which oras-py treats as a token URL, and raises RegistryHttpError from call()."""

        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.last_response = None
            self.session.hooks["response"].append(self._record_response)

        def _record_response(self, response, *args, **kwargs):
            self.last_response = response

        def authenticate_request(self, originalResponse):
            challenge = originalResponse.headers.get("Www-Authenticate", "")
            if not challenge.lower().startswith("basic"):
                return super().authenticate_request(originalResponse)
            already_sent = originalResponse.request.headers.get("Authorization", "").startswith("Basic ")
            if already_sent or not self._basic_auth:
                return False
            self.set_header("Authorization", "Basic %s" % self._basic_auth)
            return True

        def call(self, method_name, *args, if_missing=raise_on_missing, **kwargs):
            """Calls an oras-py method, raising RegistryHttpError when it fails on a registry response.
            Returns if_missing instead for a 404, if given."""
            try:
                return self._call(method_name, *args, **kwargs)
            except RegistryHttpError as ex:
                if (ex.status == 404) and (if_missing is not raise_on_missing):
                    return if_missing
                raise

        def _call(self, method_name, *args, **kwargs):
            self.last_response = None
            try:
                result = getattr(self, method_name)(*args, **kwargs)
            except RegistryHttpError:
                raise
            except Exception as ex:
                # A request that got no response, such as a refused connection, failed on its own account
                no_response = isinstance(ex, requests.RequestException) and (ex.response is None)
                if failed(self.last_response) and not no_response:
                    raise RegistryHttpError(self.last_response) from None
                raise
            # delete_tag returns False for a 404 on its HEAD request
            if (result is False) and failed(self.last_response):
                raise RegistryHttpError(self.last_response)
            return result

    module = types.ModuleType("_ipm_oras")
    module.provider = provider
    module.registry_message = registry_message
    module.RegistryHttpError = RegistryHttpError
    module.BasicAwareRegistry = BasicAwareRegistry
    sys.modules["_ipm_oras"] = module
    return module
}

/// Returns whether this process is denied access to the oras package in pythonDir.
/// Python reports that as oras or one of its modules not being found, rather than as a PermissionError.
ClassMethod IsOrasUnreadable(pythonDir As %String) As %Boolean [ Internal, Language = python ]
{
    import os

    orasDir = os.path.join(pythonDir, "oras")
    try:
        os.listdir(orasDir)
        with open(os.path.join(orasDir, "__init__.py"), "rb"):
            pass
    except PermissionError:
        return True
    except OSError:
        return False
    return False
}

/// Pulls the specified module to disk and returns the module in tgz form as %Stream.FileBinary
/// If no tag is specified, then the latest version will be pulled
ClassMethod Pull(
	registry As %String,
	package As %String,
	tag As %String,
	namespace As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String,
	Output stream As %Stream.FileBinary) As %Status
{
    set stream = ""
    set tSC = $$$OK

    if tag = "" {
        set tag = ..GetLatestTag(registry, package, namespace, username, password, token, tokenAuthMethod)
    }

    try {
        #; Pull into temp directory
        set tempFile = ""
        set tempDirectory = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.File).CreateTempDirectory() _ package _ "/" _ tag)

        #; Empty temp directory first
        if ##class(%File).DirectoryExists(tempDirectory) {
            set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tempDirectory)
            $$$ThrowOnError(tSC)
        }

        #; Pull the module using ORAS
        do ..PullOras(registry, package, tag, namespace, username, password, token, tokenAuthMethod, tempDirectory)

        #; Find only the tgz file
        set result=##class(%ResultSet).%New("%File:FileSet")
        do result.Execute(tempDirectory,"*.tgz")
        while result.Next() {
            set tempFile = result.GetDataByName("Name")
            quit
        }
        if (tempFile = "") {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "tgz file not found"))
        }

        #; Convert into stream
        set tFileBinStream = ##class(%Stream.FileBinary).%New()
        set tSC = tFileBinStream.LinkToFile(tempFile)
        $$$ThrowOnError(tSC)
        set stream = tFileBinStream

        // Check hash and size against the manifest
        set hash = ##class(%IPM.Utils.File).ComputeSHA256Hex(tempFile)

        set verified = ..VerifyModuleHashAndSize(registry, package _ ":" _ tag, namespace, username, password, token, tokenAuthMethod, hash, ##class(%Library.File).GetFileSize(tempFile))
        if 'verified {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Module size and/or hash failed validation!"))
        }
    } catch e {
        if e.Name = "<OBJECT DISPATCH>" {
            set eStatus = e.AsStatus()
            set usrStatus = $$$ERROR($$$GeneralError,$$$OrasRequiresFlexiblePython)
            set tSC = $$$EMBEDSC(usrStatus,eStatus)
        } elseif ##class(%IPM.Repo.Oras.HttpException).IsRegistryFailure(e) {
            // A status would lose what GetModule needs to classify the failure
            throw e
        } else {
            set tSC = e.AsStatus()
        }
    }
    quit tSC
}

/// Pulls the package using ORAS
ClassMethod PullOras(
	registry As %String,
	package As %String,
	tag As %String,
	namespace As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String,
	path As %String)
{
    set target = ..GetAPITarget(registry, package, namespace) _ ":" _ tag
    set client = ..GetClient(registry, username, password, token, tokenAuthMethod)

    #; set up for python call
    set args = {}
    set args.target = target
    set args.outdir = path
    set res = client.call("pull", args...)
}

/// Returns the contents of the module.xml for the given package
ClassMethod GetModuleXML(
	registry As %String,
	packageAndTag As %String,
	namespace As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String) As %String [ Language = python ]
{
    import iris

    target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, packageAndTag, namespace)
    client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenAuthMethod)

    manifest = client.call("get_manifest", target, if_missing={})
    # the module.xml text is in the annotations
    module_xml = manifest.get('annotations', {}).get('com.intersystems.ipm.module.v1+xml')
    # remove extraneous whitespace
    return module_xml.strip() if module_xml else ""
}

ClassMethod GetPackageMetadata(
	registry As %String,
	package As %String,
	tag As %String,
	namespace As %String,
	client As %String) As %String [ Language = python ]
{
    import iris
    import json

    target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace) + ":" + tag

    manifest = client.call("get_manifest", target)
    return json.dumps(manifest.get('annotations', {}))
}

/// Determines the latest tag for a given package by
/// 1) listing all of the modules and their latest versions in the package
/// 2) returning the tag for the highest numbered version
ClassMethod GetLatestTag(
	registry As %String,
	package As %String,
	namespace As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String) As %String [ Language = python ]
{
    import iris
    target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace)
    client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenAuthMethod)
    tags = client.call("get_tags", target)
    # Return most recent version
    # If no tags exist, then module has been deleted
    return tags[-1] if tags else ""
}

/// Returns comma separated string of all the tags for a given package
ClassMethod GetAllTags(
	registry As %String,
	package As %String,
	namespace As %String,
	client As %SYS.Python) As %String [ Language = python ]
{
    import iris
    target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace)
    # a missing package has no tags
    tags = client.call("get_tags", target, if_missing=[])

    # flip list so higher versions are first
    tags = iris.cls("%IPM.Utils.EmbeddedPython").SortOCITags(tags, 1)

    # convert from list to comma separated string
    return ", ".join(str(x) for x in tags)
}

/// Returns whether the given package is in the registry
ClassMethod HasModuleHelper(
	registry As %String,
	packageAndTag As %String,
	namespace As %String,
	client As %SYS.Python) As %Boolean [ Language = python ]
{
    import iris
    # Attempt to get the tags of the specified package
    # If tags are not found, then the package does not exist
    target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, packageAndTag, namespace)

    # check if tags is [] through boolean coercion
    return bool(client.call("get_tags", target, 1, if_missing=[]))
}

// ** UTILITY FUNCTIONS **

/// Gets the URL for the API endpoint, i.e. returns target where <target>/v2/ is the endpoint
ClassMethod GetAPITarget(
	registry As %String,
	packageAndOptionalTag As %String,
	namespace As %String = "") As %String
{
    if (namespace '= "") {
        set packageAndOptionalTag = ..AppendURIs(namespace, packageAndOptionalTag)
    }
    set target = ..AppendURIs(registry, packageAndOptionalTag)
    return $replace($replace(target, "http://", ""), "https://", "")
}

/// Given two URIs, appends them such that the "/" are correctly placed in between
/// Removes the leading and trailing "/"
ClassMethod AppendURIs(
	uri1 As %String,
	uri2 As %String) As %String
{
    if ($extract(uri1, *) '= "/" ) && ($extract(uri2, 1) '= "/") {
        set uri1 = uri1 _ "/"
    }
    if ($extract(uri1, *) = "/" ) && ($extract(uri2, 1) = "/") {
        set uri1 = $extract(uri1, 1, *-1)
    }
    if ($extract(uri2, *) = "/" ) {
        set uri2 = $extract(uri2, 1, *-1)
    }
    return uri1 _ uri2
}

/// Returns whether the given SHA256 hash and file size matches the hash and size in the ORAS manifest for the module
ClassMethod VerifyModuleHashAndSize(
	registry As %String,
	packageAndTag As %String,
	namespace As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String,
	hash As %String,
	size As %String) As %Boolean [ Language = python ]
{
    import iris

    target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, packageAndTag, namespace)
    client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenAuthMethod)

    manifest = client.call("get_manifest", target)
    # parse the manifest
    for layer in manifest['layers']:
        if layer["mediaType"] != "application/vnd.oci.image.layer.v1.tar":
            continue
        # check size and hash
        manifest_size = layer["size"]
        manifest_hash = layer["digest"]
        expected_hash = f"sha256:{hash}".lower()
        return manifest_size == size and manifest_hash == expected_hash
    return False
}

}
