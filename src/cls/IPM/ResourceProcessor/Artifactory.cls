Include (%IPM.Common, %IPM.Formatting)

/// Resource processor class to be used to obtain an artifact from an external repository via an HTTP request
/// and unpack that artifact into given directories. <br />
/// This is currently programmed to work exclusively with JFrog Artifactory but the core logic can be extended
/// to any other artifact repository if needed. <br />
Class %IPM.ResourceProcessor.Artifactory Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI).
Parameter DESCRIPTION As STRING = "Retrieves a build artifact from an external repository and unpacks it into the desired location(s).";

/// Comma-separated list of resource attribute names that this processor uses.
Parameter ATTRIBUTES As STRING = "InstallDirectory,Filter";

/// Path to which the artifact should be unpacked upon activation; may contain expressions.
Property InstallDirectory As %String(MAXLEN = "") [ Aliases = {Target,Dest}, Required ];

/// As JSON, the contents of the filter to be used in the items.find() query in JFrog Artifactory
/// For more details on specific values, visit <a href="https://jfrog.com/help/r/jfrog-artifactory-documentation/artifactory-query-language" target="_blank">JFrog AQL Documentation</a>
Property Filter As %String(MAXLEN = "");

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
            // If artifact fails to download in dev mode then the directory won't exist but execution won't error either
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
        // Copy contents over to package directory with pDeleteBeforeCopy = 1
        do ##class(%File).CopyDir(downloadDirectory, exportPath, 1, , 1)
        set itemHandled = 1
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
    set port = $system.Util.GetEnviron("ARTI_PORT")
    set aqlURL = $system.Util.GetEnviron("ARTI_AQL_URL")
    set username = $system.Util.GetEnviron("ARTI_USERNAME")
    set password = $system.Util.GetEnviron("ARTI_PASSWORD")
    set bearerToken = $system.Util.GetEnviron("ARTI_TOKEN")

    if ((server = "") || (port = "") || (aqlURL = "") || ((bearerToken = "") && ((username = "") || (password = "")))) {
        if (developerMode) {
            write !, $$$FormattedLine($$$Yellow, "WARNING: Not all of server, port, aql url, and a bearer token or username and password were provided, skipping downloading artifact.")
            quit
        }
        $$$ThrowStatus($$$ERROR($$$GeneralError,"All of server, port, aql url, and a bearer token or username and password must be provided to download an artifact"))
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

    set artifactPath = ..GetArtifactPath(server, port, aqlURL, username, password, bearerToken, ..Filter, verbose)
    set artifactName = ..RetrieveArtifact(server, port, artifactPath, PMTempDir, verbose)

    // Unpack artifact in temp location (so that if anything goes wrong, the true destination does not get affected)
    // and copy artifact to destination
    do ..UnTar(artifactName, PMTempDir, downloadDirectory, verbose)
}

/// Return the path of the valid artifact
/// Errors if no valid artifact is found
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
    // Token auth gets priority over baisc auth
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
        write !, "Start retrieving artifact at https://"_artifactServer_":"_artifactPort_"/"_artifactPath
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
        if '##class(%File).CreateDirectoryChain(downloadDirectory) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to create destination directory: "_downloadDirectory))
        }
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

/// Utility method to untar a tgz file into a designated (or not) temporary dir, and copy to a destination dir(or back to source dir).
/// artifactName: the source tgz file name
/// sourceFileDir: the directory of pSourceFilePath (passed to save the effort of parsing again based on Windows/Unix)
/// copyToDir: the destination directory for extracted contents to be copied to
ClassMethod UnTar(
	artifactName As %String,
	sourceFileDir As %String,
	copyToDir As %String,
	verbose As %Boolean = 0) [ Internal ]
{
    // if there is no artifact name, then it means there is nothing to be untarred
    if (artifactName = "") {
        if (verbose) {
            write !, "No artifact name provided, skipping untaring."
        }
        return
    }
    // normalize
    set sourceFileDir = ##class(%File).NormalizeDirectory(sourceFileDir)
    set artifactPath = ##class(%File).NormalizeFilename(artifactName, sourceFileDir)

    // make sure pSourceFilePath and sourceFileDir exist
    if '##class(%File).DirectoryExists(sourceFileDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Directory does not exist: "_sourceFileDir))
    }
    if '##class(%File).Exists(artifactPath) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "File does not exist: "_artifactPath))
    }

    // prepare arguments for $ZF(-100) method call
    // /LOGCMD used to log the actually triggered command into messages.log
    set keywords = "/SHELL"_$select(verbose:"/LOGCMD",1:"")

    /* Note that it seems cygwin version tar has trouble recognizing windows path passed in directly, e.g.
     * tar -C windows/path -(v)xzf windows/path/to/file will fail,
     * but cd command works fine with cd windows/path and will automatically cd into a mapped equivalent linux path like /cygdrive/c/ for C:\ (verified on cygwin)
     * so change the strategy to concatenate cd and tar commands:
     * full command to be called via $ZF(-100): cd pSourFileDir && tar -(v)xzf filename
     * default behavior is to overwrite existing files if you untar again
     * tar arguments explained, order sensitive
     * Note: we cannot do switch above into two separate $ZF(-100) calls because each time $ZF ends, pwd gets reverted to the one in previous stack
     * sourceFileDir: target dir to extract to, in our use case, it's where the source tgz file lives before extracting
     * "-(v)xzf": extract with option flags, having "v" as the last one will cause issue so put it as the first
     * pSourceFilePath: the actualy tgz file path
     */
    set args = ""
    set args($increment(args)) = sourceFileDir
    set args($increment(args)) = "&&"
    set args($increment(args)) = "tar"
    set args($increment(args)) = "-"_$select(verbose:"v",1:"")_"xzf"
    set args($increment(args)) = artifactName


    if (verbose) {
        set fullCommand = "cd"
        // write full command if verbose
        set key = ""
        while 1 {
            set key = $order(args(key),1,value)
            if (key = "") {
                quit
            }
            set fullCommand = fullCommand_" "_value
        }
        write !, "Lauching System Command: "_fullCommand
        write !, "Command and return code will be logged in messages.log"
        write !
    }

    set errorCode = $zf(-100, keywords, "cd", .args)
    // errorCode = 0 means the command gets launched successfully, other integers means getting error(e.g 1 means syntax error)
    if (errorCode '= 0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to finish system command due to error code: "_errorCode))
    }

    if (verbose) {
        write !, "Command launched successfully."
    }
    // After extracting, a new directory /package under sourceFileDir will be created holding the extracted files, so make sure to get to correct level
    set extractedDir = ##class(%File).NormalizeDirectory(sourceFileDir_$$$SLASH_"package")

    if '##class(%File).DirectoryExists(extractedDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Extracted directory does not exist: "_extractedDir))
    }

    // copy everything in /source/package into the final destination
    // overwrite existing files if there are any in destination dir
    if (verbose) {
        write !, "Going to copy extracted contents from "_extractedDir_" to "_copyToDir
    }

    // Copy contents over with pDeleteBeforeCopy = 1
    if '##class(%File).CopyDir(extractedDir, copyToDir, 1, , 1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to copy to directory: "_copyToDir))
    }

    if (verbose) {
        write !, "Copy Succeeded."
    }
}

}
