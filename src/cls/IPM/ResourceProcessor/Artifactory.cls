Include %IPM.Common

/// Resource processor class to be used to obtain an artifact from an external repository via an HTTP request
/// and unpack that artifact into given directories. <br />
/// This is currently programmed to work exclusively with JFrog Artifactory but the core logic can be extended
/// to any other artifact repository if needed. <br />
Class %IPM.ResourceProcessor.Artifactory Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI).
Parameter DESCRIPTION As STRING = "Retrieves a build artifact from an external repository and unpacks it into the desired location(s).";

/// Comma-separated list of resource attribute names that this processor uses.
Parameter ATTRIBUTES As STRING = "ArtifactName,DeployDirectory,DevDirectory,Version,BranchName,ArtifactoryRepo";

/// Name of the artifact.
Property ArtifactName As %String(MAXLEN = 128) [ Required ];

/// Path to which the artifact should be unpacked upon activation when in NON-developer mode; may contain expressions.
Property DeployDirectory As %String(MAXLEN = "") [ Required ];

/// Path to which the artifact should be unpacked upon activation when in developer mode; may contain expressions.
/// If not provided, <property>DeployDirectory</property> will be used.
Property DevDirectory As %String(MAXLEN = "");

/// Semantic version expression of the artifact to obtain. <br />
/// Unreleased version will have extra "-Snapshot" appended, e.g. 1.0.34-Snapshot. <br />
/// MAXLEN obtained from <class>%IPM.Storage.Module</version>:<property>VersionString</property>
Property Version As %String(MAXLEN = 100) [ Required ];

/// Source branch where the artifact was built from.
Property BranchName As %String(MAXLEN = 128);

/// Name of the artifactory repo where artifacts live.
/// If not provided, this will fall back to the value in parameters.json as default.
Property ArtifactoryRepo As %String(MAXLEN = "");

Method OnAfterPhase(
	phase As %String,
	ByRef params) As %Status
{
    #dim ex As %Exception.AbstractException
    set sc = $$$OK
    try {
        if (phase = "Package") {
            do ..DownloadArtifact(.params)
        }
        if (phase = "Activate") {
            set verbose  = $get(params("Verbose"),0)
            // If install directory exists, use that
            // Else, download from artifactory
            set installDirectory = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
            if '##class(%File).DirectoryExists(installDirectory) {
                if $get(params("Artifactory", "Run"), 0) {
                    if (verbose) {
                        write !, "No artifact found in "_installDirectory_" and -DArtifactory.Run set. Will now download it from artifactory."
                    }
                    do ..DownloadArtifact(.params)
                } else {
                    if (verbose) {
                        write !, "No artifact found in "_installDirectory_" and -DArtifactory.Run was NOT set, skipping copying contents."
                    }
                    quit
                }
            } else {
                if (verbose) {
                    write !, "Artifact found in "_installDirectory_". Will use that instead of downloading a new one."
                }
            }

            // Move the files from the root directory to deploy/dev directory
            set developerMode = $get(params("DeveloperMode"), ..ResourceReference.Module.DeveloperMode)
            set destinationDirectory = ..DeployDirectory
            if developerMode && (..DevDirectory '= "") {
                set destinationDirectory = ..DevDirectory
            }
            // copy everything from /<module root>/<resource name>/ into the final destination
            // overwrite existing files if there are any in destination dir
            if (verbose) {
                write !, "Going to copy extracted contents from "_installDirectory_" to "_destinationDirectory
            }
            // pOverlay = 1, pDeleteBeforeCopy = 1
            if '##class(%Library.File).CopyDir(installDirectory, destinationDirectory, 1, ,1) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to copy to directory: "_destinationDirectory))
            }
            if (verbose) {
                write !, "Copy Succeeded."
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

/// Wrapper method to invoked shared functionality of retreiving an artifact then untarring the contents
/// into a directory defined by /<module root>/<resource name>/
Method DownloadArtifact(ByRef params) [ Internal, Private ]
{
    set developerMode = $get(params("DeveloperMode"), ..ResourceReference.Module.DeveloperMode)
    set verbose  = $get(params("Verbose"),0)
    set destinationDirectory = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)

    if (verbose) {
        write !, "Start retrieving artifact..."
    }

    merge artifactory = params("Artifactory")
    set useHttps = $get(artifactory("UseHttps"), 0)
    set server = $get(artifactory("Server"))
    set port = $get(artifactory("Port"))
    set artifactoryRepo = $select((..ArtifactoryRepo '= ""):..ArtifactoryRepo, 1:$get(artifactory("UI")))
    set apiURL = $get(artifactory("APIURL"))
    set username = $get(artifactory("Username"))
    set password = $get(artifactory("Password"))

    // The following variables need to be set for all or none
    if ((server = "") || (artifactoryRepo = "") || (apiURL = "") || (username = "") || (password = "")) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"All of server, port, artifactory repo, api url, username, and password must be provided to download an artifact"))
    }

    set tempFile = ##class(%Library.File).TempFilename(,,.errorCode)
    if (errorCode < 0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to create temporary directory, system error code: "_errorCode))
    }
    // In Windows: C:\Windows\TEMP\GZGWGAs0
    // In Unix: /tmp/filJeBjAr
    set OSTempDir = $piece(tempFile,$$$SLASH,1,*-1)

    // create a subdir for the resource identified by its ArtifactName, e.g.: C:\Windows\TEMP\hs-universal-login
    // SubDirectoryName does normalization as well
    set PMTempDir = ##class(%Library.File).SubDirectoryName(OSTempDir, ..ArtifactName, 1)

    set artifactPath = ..GetArtifactPath(useHttps, server, port, username, password, apiURL, artifactoryRepo, ..ArtifactName, ..Version, ..BranchName, verbose)
    set artifactName = ..RetrieveArtifact(useHttps, server, port, artifactPath, PMTempDir, verbose)

    // Unpack artifact in temp location (so that if anything goes wrong, the true destination does not get affected)
    // and copy artifact to destination
    do ..UnTar(artifactName, PMTempDir, destinationDirectory, verbose)
}

/// Return the path of the valid artifact
/// Errors if no valid artifact is found
ClassMethod GetArtifactPath(
	useHttps As %Boolean,
	artifactServer As %String,
	artifactPort As %String,
	username As %String,
	password As %String,
	apiURL As %String,
	artifactoryRepo As %String,
	artifactName As %String,
	version As %String,
	branchName As %String,
	verbose As %Boolean = 0) As %String [ Internal ]
{
    set httpRequest = ##class(%Net.HttpRequest).%New()
    set httpRequest.Https = useHttps
    set httpRequest.SSLConfiguration = ##class(%IPM.Utils.Module).CreateAndGetSSLConfig()
    set httpRequest.Server = artifactServer
    set httpRequest.Port = artifactPort
    set httpRequest.Username = username
    set httpRequest.Password = password
    set url = apiURL

    /* AQL Query Body
        * items.find(
        *     {
        *          "repo":<artifactoryRepo>,
        *          "name":{"$match":"my-app-1.0.34*"},
        *          "@commit.branch":{"$eq":<wip-branch>}
        *      }
        * ).include("property")
    */
    set aqlFindBody = {
        "repo":(artifactoryRepo),
        "name":{"$match":(artifactName_"-"_version_"*")}
    }
    // "@commit.branch"
    if (branchName '= "") {
        // $eq - equals
        do aqlFindBody.%Set("@commit.branch", {"$eq":(branchName)})
    }

    set body = "items.find("_aqlFindBody.%ToJSON()_").include(""property"")"

    if (verbose) {
        write !, "Going to POST with the following query to retrieve info of qualified artifacts: "
        write !, body
    }
    do httpRequest.EntityBody.Write(body)
    do httpRequest.ContentTypeSet("text/plain")
    $$$ThrowOnError(httpRequest.Send("POST", url))
    set responseData = httpRequest.HttpResponse.Data
    set responseDataStr = responseData.Read(,.readStatus)
    $$$ThrowOnError(readStatus)
    $$$ThrowOnError(responseData.Rewind())
    if (httpRequest.HttpResponse.StatusCode = 404) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Artifact not found at the designated location. It could be due to the fact that resource being removed or incorrect server, port or POST url."))
    } elseif (httpRequest.HttpResponse.StatusCode '= 200) {
        // Query syntax error will be categorized as Bad Request (400) and displayed here
        $$$ThrowStatus($$$ERROR($$$GeneralError, "The following error occurred while retrieving artifact info: " _ responseDataStr))
    }

    #dim jsonObj As %Library.DynamicAbstractObject
    set jsonObj = ##class(%Library.DynamicAbstractObject).%FromJSON(responseData)
    #dim results As %Library.DynamicArray
    set results = jsonObj.%Get("results")

    if (results.%Size() = 0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No valid artifact was found based on the query parameters"))
    }

    // Get artifact by latest updated timestamp
    set maxTimeStamp = 0
    #dim targetResultObj As %Library.DynamicObject
    set targetResultObj = ""
    #dim iterator As %Iterator.Array
    set iterator = results.%GetIterator()
    while iterator.%GetNext(,.value) {
        set updated = value.%Get("updated")
        set updatedISC = ##class(%IPM.Utils.Module).ConvertW3CToTimestampUTC(updated)
        // If current timestamp is later than max seen, then this is the most up to date artifact so far and we should use that
        if ($system.SQL.DATEDIFF("ms", maxTimeStamp, updatedISC) > 0) {
            // only retrieve the value blob when we detect a later timestamp
            set targetResultObj = value
            set maxTimeStamp = updatedISC
        }
    }

    set artifactoryRepo = targetResultObj.%Get("repo")
    set path = targetResultObj.%Get("path")
    set name = targetResultObj.%Get("name")
    set artifactPath = "artifactory/"_artifactoryRepo_"/"_path_"/"_name
    if (verbose) {
        write !, "Valid artifact found at: "_artifactPath
    }

    return artifactPath
}

/// Retrieves the artifact based on the artifactPath provided
/// Full path will be written to console if verbose is enabled.
/// Returns the file name of the artifact downloaded
ClassMethod RetrieveArtifact(
	useHttps As %Boolean,
	artifactServer As %String,
	artifactPort As %String,
	artifactPath As %String,
	destinationDirectory As %String,
	verbose As %Boolean = 0) As %String [ Internal ]
{
    set httpRequest = ##class(%Net.HttpRequest).%New()
    set httpRequest.Https = useHttps
    set httpRequest.SSLConfiguration = ##class(%IPM.Utils.Module).CreateAndGetSSLConfig()
    set httpRequest.Server = artifactServer
    set httpRequest.Port = artifactPort

    if verbose {
        write !, "Start retrieving artifact at "_$case(useHttps, 1: "https", : "http")_"://" _ artifactServer _ ":" _ $case((artifactPort = ""), 1: "", : ":"_artifactPort) _ "/" _ artifactPath
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
    if '##class(%Library.File).DirectoryExists(destinationDirectory) {
        if '##class(%Library.File).CreateDirectoryChain(destinationDirectory) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to create destination directory: "_destinationDirectory))
        }
    }

    set localPath = ##class(%Library.File).NormalizeFilename(artifactName, destinationDirectory)
    if '##class(%Library.File).Exists(localPath) {
        if verbose {
            write !, "Update found. Saving to " _ localPath
        }

        set stream = ##class(%Library.FileBinaryStream).%New()
        set stream.Filename = localPath
        $$$ThrowOnError(stream.CopyFrom(responseData))
        $$$ThrowOnError(stream.%Save())
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
    set sourceFileDir = ##class(%Library.File).NormalizeDirectory(sourceFileDir)
    set artifactPath = ##class(%Library.File).NormalizeFilename(artifactName, sourceFileDir)

    // make sure pSourceFilePath and sourceFileDir exist
    if '##class(%Library.File).DirectoryExists(sourceFileDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Directory does not exist: "_sourceFileDir))
    }
    if '##class(%Library.File).Exists(artifactPath) {
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
    set extractedDir = ##class(%Library.File).NormalizeDirectory(sourceFileDir_$$$SLASH_"package")

    if '##class(%Library.File).DirectoryExists(extractedDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Extracted directory does not exist: "_extractedDir))
    }

    // copy everything in /source/package into the final destination
    // overwrite existing files if there are any in destination dir
    if (verbose) {
        write !, "Going to copy extracted contents from "_extractedDir_" to "_copyToDir
    }

    // pOverlay = 1, pDeleteBeforeCopy = 1
    if '##class(%Library.File).CopyDir(extractedDir, copyToDir, 1, ,1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to copy to directory: "_copyToDir))
    }

    if (verbose) {
        write !, "Copy Succeeded."
    }
}

}
