Include (%IPM.Common, %IPM.Formatting)

/// Resource processor class to be used to obtain an artifact from an external repository via an HTTP request
/// and unpack that artifact into given directories. <br />
/// This is currently programmed to work exclusively with JFrog Artifactory but the core logic can be extended
/// to any other artifact repository if needed. <br />
Class %IPM.ResourceProcessor.ArtifactoryTarball Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI).
Parameter DESCRIPTION As STRING = "Retrieves a build artifact from an external repository and unpacks it into the desired location(s).";

/// Comma-separated list of resource attribute names that this processor uses.
Parameter ATTRIBUTES As STRING = "InstallDirectory,Filter,Server,Port";

/// Path to which the artifact should be unpacked upon activation; may contain expressions.
Property InstallDirectory As %String(MAXLEN = "") [ Aliases = {Target,Dest}, Required ];

/// As JSON, the contents of the filter to be used in the items.find() query in JFrog Artifactory
/// For more details on specific values, visit <a href="https://jfrog.com/help/r/jfrog-artifactory-documentation/artifactory-query-language" target="_blank">JFrog AQL Documentation</a>
/// Without credentials, the filter may only use <code>repo</code>, <code>name</code>, <code>path</code>,
/// <code>type</code> and <code>@property</code> keys, with <code>$eq</code> (or <code>$match</code> for name and path), and must set a name or a property.
Property Filter As %String(MAXLEN = "");

/// Artifactory host name. The ARTI_SERVER environment variable takes precedence.
Property Server As %String(MAXLEN = "");

/// Artifactory port; defaults to 443. The ARTI_PORT environment variable takes precedence.
Property Port As %String(MAXLEN = "");

Method OnAfterPhase(
	phase As %String,
	ByRef params) As %Status
{
    #dim ex As %Exception.AbstractException
    set sc = $$$OK
    try {
        if (phase = "Activate") {
            set verbose  = $get(params("Verbose"),0)
            // If install directory exists, use that
            // Else, download from artifactory
            set downloadDirectory = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
            if '##class(%File).DirectoryExists(downloadDirectory) {
                if (verbose) {
                    write !, "No artifact found in "_downloadDirectory_", will now download it from artifactory."
                }
                do ..DownloadArtifact(.params)
            } else {
                if (verbose) {
                    write !, "Artifact found in "_downloadDirectory_". Will use that instead of downloading a new one."
                }
            }
            // Check that an artifact was downloaded in DownloadArtifact(). If so, copy contents over to the final destination
            if ##class(%File).DirectoryExists(downloadDirectory) {
                // copy everything from /<module root>/<resource name>/ into the final destination
                // overwrite existing files if there are any in destination dir
                if (verbose) {
                    write !, "Going to copy extracted contents from "_downloadDirectory_" to "_..InstallDirectory
                    if ##class(%File).DirectoryExists(..InstallDirectory) {
                        write !, $$$FormattedLine($$$Yellow, "WARNING: "_..InstallDirectory_" has contents which will be overwritten by this action.")
                    }
                }
                // Copy contents over with pDeleteBeforeCopy = 1
                if '##class(%File).CopyDir(downloadDirectory, ..InstallDirectory, 1, , 1) {
                    $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to copy to directory: "_..InstallDirectory))
                }
                if (verbose) {
                    write !, "Copy Succeeded."
                }
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

Method OnExportItem(
	fullExportPath As %String,
	itemName As %String,
	ByRef itemParams,
	ByRef params,
	Output itemHandled As %Boolean = 0) As %Status
{
    set sc = $$$OK
    try {
        do ..DownloadArtifact(.params)
        set downloadDirectory = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
        set exportPath = params("ModuleExportPath")
        set verbose  = $get(params("Verbose"),0)
        if (verbose) {
            write !, "Going to copy extracted contents from "_downloadDirectory_" to "_exportPath
        }
        // Copy contents over to package directory with pDeleteBeforeCopy = 1
        if '##class(%File).CopyDir(downloadDirectory, exportPath, 1, , 1) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to copy to directory: "_exportPath))
        }
        set itemHandled = 1
        if (verbose) {
            write !, "Copy Succeeded."
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Wrapper method to invoked shared functionality of retreiving an artifact then untarring the contents
/// into a directory defined by /<module root>/<resource name>/
Method DownloadArtifact(ByRef params) [ Internal, Private ]
{
    set developerMode = $get(params("DeveloperMode"), ..ResourceReference.Module.DeveloperMode)
    set verbose  = $get(params("Verbose"),0)
    set downloadDirectory = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)

    set server = $system.Util.GetEnviron("ARTI_SERVER")
    if (server = "") {
        set server = ..Server
    }
    set port = $system.Util.GetEnviron("ARTI_PORT")
    if (port = "") {
        set port = ..Port
    }
    set aqlURL = $system.Util.GetEnviron("ARTI_AQL_URL")
    if (aqlURL = "") {
        set aqlURL = "/artifactory/api/search/aql"
    }
    set username = $system.Util.GetEnviron("ARTI_USERNAME")
    set password = $system.Util.GetEnviron("ARTI_PASSWORD")
    set bearerToken = $system.Util.GetEnviron("ARTI_TOKEN")
    set hasCredentials = (bearerToken '= "") || ((username '= "") && (password '= ""))

    if (server = "") {
        if (developerMode) {
            write !, $$$FormattedLine($$$Yellow, "WARNING: No Artifactory server was provided (Server attribute or ARTI_SERVER), skipping downloading artifact.")
            quit
        }
        $$$ThrowStatus($$$ERROR($$$GeneralError,"An Artifactory server (Server attribute or ARTI_SERVER) must be provided to download an artifact"))
    }
    if (verbose) {
        write !, "Start retrieving artifact..."
    }

    set tempFile = ##class(%File).TempFilename(,,.errorCode)
    if (errorCode < 0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to create temporary directory, system error code: "_errorCode))
    }
    // In Windows: C:\Windows\TEMP\GZGWGAs0
    // In Unix: /tmp/filJeBjAr
    set OSTempDir = $piece(tempFile,$$$SLASH,1,*-1)

    // create a subdir for the resource identified by its Name, e.g.: /tmp/ui/hs-app-hub/package/
    // SubDirectoryName does normalization as well
    set PMTempDir = ##class(%File).SubDirectoryName(OSTempDir, ..ResourceReference.Name, 1)

    if (hasCredentials) {
        set artifactPath = ..GetArtifactPath(server, port, aqlURL, username, password, bearerToken, ..Filter, verbose)
        set artifactName = ..RetrieveArtifact(server, port, artifactPath, PMTempDir, verbose)
    } else {
        try {
            set artifactPath = ..GetArtifactPathAnonymous(server, port, ..Filter, verbose)
            set artifactName = ..RetrieveArtifact(server, port, artifactPath, PMTempDir, verbose)
        } catch ex {
            if ('developerMode) {
                throw ex
            }
            write !, $$$FormattedLine($$$Yellow, "WARNING: Anonymous download failed, skipping downloading artifact: "_ex.DisplayString())
            return
        }
    }

    // Unpack artifact in temp location (so that if anything goes wrong, the true destination does not get affected)
    // and copy artifact to destination
    set artifactTarPath = ##class(%File).NormalizeFilename(artifactName, PMTempDir)
    if (verbose) {
        write !, "Going to extract contents from "_artifactTarPath_" to "_downloadDirectory
    }
    $$$ThrowOnError(##class(%IPM.General.Archive).Extract(artifactTarPath, downloadDirectory))
    if (verbose) {
        write !, "Extract Succeeded."
    }
}

/// Returns the path of a valid artifact.<br />
/// Errors if no valid artifact is found.<br />
/// @Argument   artifactServer  Server name where the artifact is located.<br />
/// @Argument   artifactPort    Port to use when connecting to artifactServer.<br />
/// @Argument   aqlURL          URL endpoint for aql search within JFrog Artifactory.<br />
/// @Argument   username        Username used for server authentication.<br />
/// @Argument   password        Password used for server authentication.<br />
/// @Argument   bearerToken     Token to use in place of username/password auth.<br />
/// @Argument   filter          JSON (as %String) to use inside the filtering body in the aql call.<br />
/// @Argument   verbose         Set to 1 to provide verbose output.<br />
ClassMethod GetArtifactPath(
	artifactServer As %String,
	artifactPort As %String,
	aqlURL As %String,
	username As %String,
	password As %String,
	bearerToken As %String,
	filter As %String,
	verbose As %Boolean = 0) As %String [ Internal ]
{
    set httpRequest = ##class(%Net.HttpRequest).%New()
    set httpRequest.Https = 1
    set httpRequest.SSLConfiguration = ##class(%IPM.Utils.Module).CreateAndGetSSLConfig()
    set httpRequest.Server = artifactServer
    set httpRequest.Port = artifactPort
    // Token auth gets priority over basic auth
    if (bearerToken '= "") {
        do httpRequest.SetHeader("Authorization", "Bearer "_bearerToken)
        if (verbose) {
            write !, "Using token auth in HTTP request"
        }
    } else {
        set httpRequest.Username = username
        set httpRequest.Password = password
        if (verbose) {
            write !, "Using basic auth in HTTP request"
        }
    }

    set body = "items.find("_filter_").sort({""$desc"": [""updated""]})"
    if (verbose) {
        // {}.%FromJSON(filter).%ToJSON() does not change the contents of the filter but does normalize its whitespace to make it easier for readability in verbose mode
        set body = "items.find("_{}.%FromJSON(filter).%ToJSON()_").sort({""$desc"": [""updated""]})"
        write !, "Going to POST with the following query to retrieve info of qualified artifacts: "
        write !, body
    }
    do httpRequest.EntityBody.Write(body)
    do httpRequest.ContentTypeSet("text/plain")
    $$$ThrowOnError(httpRequest.Send("POST", aqlURL))
    set responseData = httpRequest.HttpResponse.Data
    set responseDataStr = responseData.Read(,.readStatus)
    $$$ThrowOnError(readStatus)
    $$$ThrowOnError(responseData.Rewind())
    if (httpRequest.HttpResponse.StatusCode = 404) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Artifact not found at the designated location. It could be due to the fact that resource being removed or incorrect server, port or POST url."))
    } elseif (httpRequest.HttpResponse.StatusCode '= 200) {
        // Query syntax error will be a bad request and displayed here
        $$$ThrowStatus($$$ERROR($$$GeneralError, "The following error occurred while retrieving artifact info: " _ responseDataStr))
    }

    #dim jsonObj As %Library.DynamicAbstractObject
    set jsonObj = ##class(%Library.DynamicAbstractObject).%FromJSON(responseData)
    #dim results As %Library.DynamicArray
    set results = jsonObj.%Get("results")
    if (results.%Size() > 1) && (verbose) {
        write !, results.%Size()_" valid artifacts found matching the filtered criteria. Choosing the one most recently updated."
    }
    set resultArtifact = results.%Get(0, "")
    if (resultArtifact = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No valid artifact was found based on the query parameters"))
    }
    set artifactPath = "artifactory/"_resultArtifact.%Get("repo")_"/"_resultArtifact.%Get("path")_"/"_resultArtifact.%Get("name")
    if (verbose) {
        write !, "Valid artifact found at: "_artifactPath
    }

    return artifactPath
}

/// Returns the path of the most recently updated artifact matching the filter, without authenticating.<br />
/// Artifactory denies AQL to anonymous users, so this uses the artifact (name) or property search instead.<br />
/// Errors if no valid artifact is found.<br />
ClassMethod GetArtifactPathAnonymous(
	artifactServer As %String,
	artifactPort As %String,
	filter As %String,
	verbose As %Boolean = 0) As %String [ Internal ]
{
    set criteria = ..ParseAnonymousFilter(filter)

    set httpRequest = ##class(%Net.HttpRequest).%New()
    set httpRequest.Https = 1
    set httpRequest.SSLConfiguration = ##class(%IPM.Utils.Module).CreateAndGetSSLConfig()
    set httpRequest.Server = artifactServer
    set httpRequest.Port = artifactPort
    do httpRequest.SetHeader("X-Result-Detail", "info, properties")
    if (criteria.repo '= "") {
        do httpRequest.SetParam("repos", criteria.repo)
    }
    if (criteria.name '= "") {
        set searchURL = "/artifactory/api/search/artifact"
        do httpRequest.SetParam("name", criteria.name.value)
    } else {
        set searchURL = "/artifactory/api/search/prop"
        set iterator = criteria.properties.%GetIterator()
        while iterator.%GetNext(.key, .value) {
            do httpRequest.SetParam(key, value)
        }
    }
    if (verbose) {
        write !, "No credentials provided. Going to search anonymously: "_searchURL_httpRequest.ReturnParams()
    }
    $$$ThrowOnError(httpRequest.Get(searchURL))

    set responseData = httpRequest.HttpResponse.Data
    set responseDataStr = responseData.Read(,.readStatus)
    $$$ThrowOnError(readStatus)
    $$$ThrowOnError(responseData.Rewind())
    set statusCode = httpRequest.HttpResponse.StatusCode
    if (statusCode = 401) || (statusCode = 403) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Anonymous search was refused (HTTP %1); provide ARTI_TOKEN, or ARTI_USERNAME and ARTI_PASSWORD", statusCode)))
    } elseif (statusCode '= 200) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "The following error occurred while retrieving artifact info: " _ responseDataStr))
    }

    set results = ##class(%Library.DynamicAbstractObject).%FromJSON(responseData).%Get("results")
    if '$isobject(results) {
        set results = []
    }
    set artifactPath = ..SelectNewestArtifact(results, criteria)
    if (artifactPath = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No valid artifact was found based on the query parameters"))
    }
    if (verbose) {
        write !, "Valid artifact found at: "_artifactPath
    }

    return artifactPath
}

/// Converts an AQL filter into the criteria used by <method>GetArtifactPathAnonymous</method>, e.g.
/// <example>
/// {"repo": "generic-local", "name": {"$match": "my-ui-1.2.*"}, "@commit.branch": "main"}
/// </example>
/// becomes
/// <example>
/// {"repo": "generic-local", "name": {"value": "my-ui-1.2.*", "isPattern": 1}, "properties": {"commit.branch": "main"}}
/// </example>
/// Errors if the filter uses anything that only AQL can evaluate.
ClassMethod ParseAnonymousFilter(filter As %String) As %DynamicObject [ Internal ]
{
    set criteria = {"repo": "", "properties": {}}
    set filterObject = $select(filter = "": {}, 1: {}.%FromJSON(filter))
    set iterator = filterObject.%GetIterator()
    while iterator.%GetNext(.key, .condition) {
        if (key = "repo") {
            set criteria.repo = ..ParseCondition(key, condition, 0)
        } elseif (key = "name") || (key = "path") {
            set value = ..ParseCondition(key, condition, 1, .isPattern)
            do criteria.%Set(key, {"value": (value), "isPattern": (isPattern)})
        } elseif (key = "type") {
            if (..ParseCondition(key, condition, 0) '= "file") {
                do ..ThrowUnsupportedFilter(key)
            }
        } elseif ($extract(key) = "@") {
            do criteria.properties.%Set($extract(key, 2, *), ..ParseCondition(key, condition, 0))
        } else {
            do ..ThrowUnsupportedFilter(key)
        }
    }
    if (criteria.name = "") && (criteria.properties.%Size() = 0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Without credentials, the filter must specify a name or a @property"))
    }
    return criteria
}

/// Returns the value of an AQL condition, which is either a plain value or a single
/// <code>$eq</code> (or, if allowMatch is set, <code>$match</code>) operator.
ClassMethod ParseCondition(
	key As %String,
	condition,
	allowMatch As %Boolean,
	Output isPattern As %Boolean) As %String [ Internal, Private ]
{
    set isPattern = 0
    if '$isobject(condition) {
        return condition
    }
    if 'condition.%IsA("%Library.DynamicObject") || (condition.%Size() '= 1) {
        do ..ThrowUnsupportedFilter(key)
    }
    set operator = condition.%GetIterator()
    do operator.%GetNext(.name, .value)
    if $isobject(value) {
        do ..ThrowUnsupportedFilter(key)
    }
    if (name = "$match") && allowMatch {
        set isPattern = 1
    } elseif (name '= "$eq") {
        do ..ThrowUnsupportedFilter(key)
    }
    return value
}

ClassMethod ThrowUnsupportedFilter(key As %String) [ Internal, Private ]
{
    $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Filter key %1 cannot be evaluated without credentials; provide ARTI_TOKEN, or ARTI_USERNAME and ARTI_PASSWORD, to use AQL", key)))
}

/// Returns the path (as in <method>GetArtifactPath</method>) of the most recently updated search result
/// that matches the criteria, or "" if none does. Results carry the <code>X-Result-Detail: info, properties</code> fields.
ClassMethod SelectNewestArtifact(
	results As %DynamicArray,
	criteria As %DynamicObject) As %String [ Internal ]
{
    set artifactPath = ""
    set newestUpdated = ""
    set iterator = results.%GetIterator()
    while iterator.%GetNext(, .result) {
        // e.g. /my-ui/-/my-ui-1.2.3.tgz
        set fullPath = result.path
        set name = $piece(fullPath, "/", *)
        set folder = $piece(fullPath, "/", 2, *-1)
        if (criteria.repo '= "") && (result.repo '= criteria.repo) {
            continue
        }
        if '..MatchesCondition(name, criteria.name) || '..MatchesCondition($select(folder = "": ".", 1: folder), criteria.path) {
            continue
        }
        if '..HasProperties(result.properties, criteria.properties) {
            continue
        }
        if (artifactPath = "") || (result.lastUpdated ] newestUpdated) {
            set newestUpdated = result.lastUpdated
            set artifactPath = "artifactory/"_result.repo_"/"_$select(folder = "": "", 1: folder_"/")_name
        }
    }
    return artifactPath
}

ClassMethod MatchesCondition(
	value As %String,
	condition As %DynamicObject) As %Boolean [ Internal, Private ]
{
    if (condition = "") {
        return 1
    }
    if 'condition.isPattern {
        return (value = condition.value)
    }
    return ..WildcardMatch(value, condition.value)
}

ClassMethod HasProperties(
	actual As %DynamicObject,
	expected As %DynamicObject) As %Boolean [ Internal, Private ]
{
    set iterator = expected.%GetIterator()
    while iterator.%GetNext(.key, .expectedValue) {
        set values = $select($isobject(actual): actual.%Get(key), 1: "")
        if '$isobject(values) {
            return 0
        }
        set found = 0
        set valueIterator = values.%GetIterator()
        while 'found && valueIterator.%GetNext(, .value) {
            set found = (value = expectedValue)
        }
        if 'found {
            return 0
        }
    }
    return 1
}

/// Matches an AQL <code>$match</code> pattern, where * is any run of characters and ? is any one character.
ClassMethod WildcardMatch(
	value As %String,
	pattern As %String) As %Boolean [ Internal ]
{
    set regex = ""
    for i = 1:1:$length(pattern) {
        set char = $extract(pattern, i)
        if (char = "*") {
            set regex = regex_".*"
        } elseif (char = "?") {
            set regex = regex_"."
        } elseif (char?1AN) {
            set regex = regex_char
        } else {
            set regex = regex_"\"_char
        }
    }
    return $match(value, regex)
}

/// Retrieves the artifact based on the artifactPath provided
/// Full path will be written to console if verbose is enabled.
/// Returns the file name of the artifact downloaded
ClassMethod RetrieveArtifact(
	artifactServer As %String,
	artifactPort As %String,
	artifactPath As %String,
	downloadDirectory As %String,
	verbose As %Boolean = 0) As %String [ Internal ]
{
    set httpRequest = ##class(%Net.HttpRequest).%New()
    set httpRequest.Https = 1
    set httpRequest.SSLConfiguration = ##class(%IPM.Utils.Module).CreateAndGetSSLConfig()
    set httpRequest.Server = artifactServer
    set httpRequest.Port = artifactPort

    if verbose {
        write !, "Start retrieving artifact at https://"_artifactServer_$select(artifactPort = "": "", 1: ":"_artifactPort)_"/"_artifactPath
    }
    $$$ThrowOnError(httpRequest.Get(artifactPath))

    set responseData = httpRequest.HttpResponse.Data
    set responseDataStr = responseData.Read(,.readStatus)
    $$$ThrowOnError(readStatus)
    $$$ThrowOnError(responseData.Rewind())
    if (httpRequest.HttpResponse.StatusCode = 404) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Artifact does not exist at: " _ artifactPath))
    } elseif (httpRequest.HttpResponse.StatusCode '= 200) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "The following error occurred while retrieving artifact: " _ responseDataStr))
    }

    set artifactName = httpRequest.HttpResponse.Headers("X-ARTIFACTORY-FILENAME")
    if verbose {
        write !, "Found: " _ artifactName
    }

    // Create directory if it doesn't exist
    if '##class(%File).DirectoryExists(downloadDirectory) {
        $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(downloadDirectory))
    }

    set localPath = ##class(%File).NormalizeFilename(artifactName, downloadDirectory)
    if '##class(%File).Exists(localPath) {
        if verbose {
            write !, "Saving to " _ localPath
        }

        set stream = ##class(%FileBinaryStream).%New()
        set stream.Filename = localPath
        $$$ThrowOnError(stream.CopyFromAndSave(responseData))
    }

    return artifactName
}

}
