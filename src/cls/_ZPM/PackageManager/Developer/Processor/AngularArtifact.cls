/// Resource processor class to be used to obtain an artifact from an external repository via an HTTP request
/// and unpack that artifact into given directories. <br />
/// This is currently programmed to work exclusively with JFrog Artifactory but the core logic can be extended
/// to any other artifact repository if needed. <br />
Class %ZPM.PackageManager.Developer.Processor.AngularArtifact Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI).
Parameter DESCRIPTION As STRING = "Retrieves a build artifact of an Angular build from an external repository and unpacks it into the desired location(s).";

/// Comma-separated list of resource attribute names that this processor uses.
Parameter ATTRIBUTES As STRING = "SourceControlRepo,DeployDirectory,DevDirectory,Version,BranchName,ArtifactoryRepo";

/// Name of the UI artifact to be kitted, found as the name of the UI application repo, need to distinguish from ArtifactoryRepo.
Property SourceControlRepo As %String(MAXLEN = 128) [ Required ];

/// Path to which the artifact should be unpacked upon activation when in NON-developer mode; may contain expressions.
Property DeployDirectory As %String(MAXLEN = "") [ Required ];

/// Path to which the artifact should be unpacked upon activation when in developer mode; may contain expressions.
/// If not provided, <property>DeployDirectory</property> will be used.
Property DevDirectory As %String(MAXLEN = "");

/// Semantic version expression of the artifact to obtain. <br />
/// Unreleased version will have extra "-Snapshot" appended, e.g. 1.0.34-Snapshot. <br />
/// MAXLEN obtained from <class>%ZPM.PackageManager.Developer.Module</version>:<property>VersionString</property>
Property Version As %String(MAXLEN = 100) [ Required ];

/// Source branch where the artifact was built from.
Property BranchName As %String(MAXLEN = 128);

/// Name of the artifactory repo where UI artifacts live. (eg. healthshare-generic-dev-cambridge)
/// If not provided, this will fall back to the value in parameters.json as default.
Property ArtifactoryRepo As %String(MAXLEN = "");

Method VersionSet(pValue As %String) As %Library.Status
{
	#dim versionObj As %ZPM.General.SemanticVersion
	Set sc = ##class(%ZPM.General.SemanticVersion).IsValid(pValue)
	Set i%Version = pValue
	Return sc
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	#dim ex As %Exception.AbstractException
	Set sc = $$$OK
	Try {
		If (pPhase = "Activate") {
			Set developerMode = $Get(pParams("DeveloperMode"), ..ResourceReference.Module.DeveloperMode)
			Set verbose  = $Get(pParams("Verbose"),0)
			
			Merge processorParams = pParams("AngularArtifact")
			Set force = $Get(processorParams("Force"),0)
			Set run = $Get(processorParams("Run"),0) || force
			
			If ('run) {
				If (verbose) {
					Write !, "Will skip downloading and kitting UI artifact because neither -DAngularArtifact.Run nor -DAngularArtifact.Force was provided."
				}
				Quit
			}
			Set destinationDirectory = ..DeployDirectory
			If developerMode && (..DevDirectory '= "") {
				Set destinationDirectory = ..DevDirectory
			}
			// Retrieve artifact
			If (verbose) {
				Write !, "Start retrieving UI artifact..."
			}
			Do ..OnGetUniqueName(.resourceName)
			Merge artifactory = pParams("Artifactory")
			Set useHttps = $Get(artifactory("UseHttps"), 0)
			Set server = $Get(artifactory("Server"))
			Set port = $Get(artifactory("Port"))
			Set artifactoryRepo = $Select((..ArtifactoryRepo '= ""):..ArtifactoryRepo, 1:$Get(artifactory("UI")))
			Set apiURL = $Get(artifactory("APIURL"))
			Set username = $Get(artifactory("Username"))
			Set password = $Get(artifactory("Password"))
			
			// The following variables need to be set for all or none
			If ((server = "") || (artifactoryRepo = "") || (apiURL = "") || (username = "") || (password = "")) {
				If (verbose) {
					Set errorText = "No information provided for server, port, artifactory repo, api url, username and password."
					$$$ThrowStatus($$$ERROR($$$GeneralError,errorText))
				}
			}
			
			Set tempFile = ##class(%Library.File).TempFilename(,,.errorCode)
			If (errorCode < 0) {
				$$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to create temporary directory, system error code: "_errorCode))
			}
			// In Windows: C:\Windows\TEMP\GZGWGAs0
			// In Unix: /tmp/filJeBjAr
			Set OSTempDir = $Piece(tempFile,$$$SLASH,1,*-1)
			
			// create a subdir for the resource identified by its SourceControlRepo, e.g.: C:\Windows\TEMP\hs-universal-login
			// SubDirectoryName does normalization as well
			Set PMTempDir = ##class(%Library.File).SubDirectoryName(OSTempDir, ..SourceControlRepo, 1)
			
			Set artifactPath = ..FindValidArtifact(useHttps, server, port, username, password, apiURL, artifactoryRepo, resourceName, ..SourceControlRepo, ..Version, ..BranchName, developerMode, verbose, force, .targetResultObj)			
			If (artifactPath = "") {
				Quit
			}
			Set artifactName = ..RetrieveArtifact(useHttps, server, port, artifactPath, PMTempDir, verbose)
			If (artifactName = "") {
				Quit
			}
						
			// Unpack artifact in temp location (so that if anything goes wrong, the true destination does not get affected)			
			// and copy artifact to destination
			Do ..UnTar(artifactName, PMTempDir, destinationDirectory, verbose)
			
			// only save the metadata after download and untar finish successfully
			Do ..SaveMetadata(resourceName, ..SourceControlRepo, ..Version, .targetResultObj, verbose)
		}
	} Catch ex {
		Set sc = ex.AsStatus()
	}
	Quit sc
}

/// Return the path of the valid artifact, and empty string if the algorithm finds either no qualified artifact or no new artifact
/// compared with what was stored before.
ClassMethod FindValidArtifact(pUseHttps As %Boolean, pArtifactServer As %String, pArtifactPort As %String, pUsername As %String, pPassword As %String, pAPIURL As %String, pArtifactoryRepo As %String, pResourceName As %String, pSourceControlRepo As %String, pVersion As %String, pBranchName As %String, pDeveloperMode As %Boolean = 0, pVerbose As %Boolean = 0, pForce As %Boolean = 0, Output pTargetResultObj As %Library.DynamicObject) As %String [ Internal ]
{
	Set httpRequest = ##class(%Net.HttpRequest).%New()
	Set httpRequest.Https = pUseHttps
	Set httpRequest.SSLConfiguration = ##class(%ZPM.PackageManager.Developer.Utils).CreateAndGetSSLConfig()
 	Set httpRequest.Server = pArtifactServer
 	Set httpRequest.Port = pArtifactPort
 	Set httpRequest.Username = pUsername
 	Set httpRequest.Password = pPassword
 	Set url = pAPIURL
 		
	// check whether the artifact had been downloaded before
	Set mostRecentUpdatedTimestamp = ""
	If (##class(%ZPM.PackageManager.Developer.AngularArtifact).UniqueIdentifierIdxExists(pResourceName, pSourceControlRepo, pVersion)) {
		If (pVerbose) {
			Write !, "Artifact download history found in local cache for: "_pSourceControlRepo_"-"_pVersion
			If (pForce) {
				Write !, "With force flag on, will force re-downloading the latest artifact!"
			}
		}
		If (pDeveloperMode) {
			If (pForce) {
				// delete existing record
				Set sc = ##class(%ZPM.PackageManager.Developer.AngularArtifact).UniqueIdentifierIdxDelete(pResourceName, pSourceControlRepo, pVersion)
				$$$ThrowOnError(sc)
			} Else {
				// find the most recent one built
				Set storage = ##class(%ZPM.PackageManager.Developer.AngularArtifact).UniqueIdentifierIdxOpen(pResourceName, pSourceControlRepo, pVersion,, .sc)
				$$$ThrowOnError(sc)
				Set mostRecentUpdatedTimestamp = storage.MostRecentUpdated
			}
		} Else {
			// no need to download anything
		 	If (pVerbose) {
			 	Write !, "Artifact had already been downloaded before, skip downloading."
			}
			Return ""
		}
	}
	
	/* AQL Query Body
 	 * DevMode: 
 	 * items.find(
 	 * 		{
	 *	   		"repo":<artifactoryRepo>,
	 *			"name":{"$match":"my-app-1.0.34*"},
	 *			"@commit.branch":{"$eq":<wip-branch>},
	 *			"updated":{"$gt" : "2020-08-18T16:49:59.257Z"}
	 *		}
	 * ).include("property")
 	 * 
 	 * Non-DevMode: 
 	 * items.find(
 	 *		{
	 *	 		"repo":<artifactoryRepo>,
	 *			"name":{"$match":"my-app-1.0.34*"},
	 *		}
	 * ).include("property")	
 	*/
 	Set aqlFindBody = {
	 	"repo":(pArtifactoryRepo),
	 	"name":{"$match":(pSourceControlRepo_"-"_pVersion_"*")}
	}
 	// "@commit.branch"
 	If (pBranchName '= "") {
	 	// $eq - equals
	 	Do aqlFindBody.%Set("@commit.branch", {"$eq":(pBranchName)})
	}
 	// "updated"
 	If (pDeveloperMode && (mostRecentUpdatedTimestamp '= "")) {
	 	// $gt - greater than
	 	Do aqlFindBody.%Set("updated", {"$gt":(mostRecentUpdatedTimestamp)})
	}
	
	Set body = "items.find("_aqlFindBody.%ToJSON()_").include(""property"")"
	
	If (pVerbose) {
		Write !, "Going to POST with the following query to retrieve info of qualified artifacts: "
		Write !, body
	}
 	Do httpRequest.EntityBody.Write(body)
 	Do httpRequest.ContentTypeSet("text/plain")
 	$$$ThrowOnError(httpRequest.Send("POST", url))
 	Set responseData = httpRequest.HttpResponse.Data
 	Set responseDataStr = responseData.Read(,.readStatus)
 	$$$ThrowOnError(readStatus)
 	$$$ThrowOnError(responseData.Rewind())
 	If (httpRequest.HttpResponse.StatusCode = 404) {
 		$$$ThrowStatus($$$ERROR($$$GeneralError, "Artifact not found at the designated location. It could be due to the fact that resource being removed or incorrect server, port or POST url."))
 	} ElseIf (httpRequest.HttpResponse.StatusCode '= 200) {
	 	// Query syntax error will be categorized as Bad Request (400) and displayed here
 		$$$ThrowStatus($$$ERROR($$$GeneralError, "The following error occurred while retrieving artifact info: " _ responseDataStr))
 	}
 	
 	#dim jsonObj As %Library.DynamicAbstractObject
 	Set jsonObj = ##class(%Library.DynamicAbstractObject).%FromJSON(responseData)
 	#dim results As %Library.DynamicArray
 	Set results = jsonObj.%Get("results")
 	
 	Set size = results.%Size()
 	If (size = 0) {
		If (mostRecentUpdatedTimestamp = "") {
			// Means no prior artifact so must throw an error
			Set errorMessage = "No valid artifact was found based on the query parameters"
			$$$ThrowStatus($$$ERROR($$$GeneralError,errorMessage))
		}
		Return ""
	}
	
	// ISC internal timestamp
	Set maxTimeStamp = 0
	// timestamp from API server
	#dim targetResultObj As %Library.DynamicObject
	Set targetResultObj = ""
	#dim iterator As %Iterator.Array
	Set iterator = results.%GetIterator()
	While iterator.%GetNext(,.value) {
		Set updated = value.%Get("updated")
		Set updatedISC = ##class(%ZPM.PackageManager.Developer.Utils).ConvertW3CToTimestampUTC(updated)
		// calculates time diff in miliseconds
		// DATEDIFF("ms", startTime, endTime) returns x where x > 0 means endTime is later than startTime with interval of x miliseconds(ms)
	 	If ($System.SQL.DATEDIFF("ms", maxTimeStamp, updatedISC) > 0) {
		 	Set maxTimeStamp = updatedISC
		 	// only retrieve the value blob when we detect a later timestamp
		 	Set targetResultObj = value
		}		
	}
	
	Set artifactoryRepo = targetResultObj.%Get("repo")
	Set path = targetResultObj.%Get("path")
	Set name = targetResultObj.%Get("name")
 	Set artifactPath = "artifactory/"_artifactoryRepo_"/"_path_"/"_name
 	If (pVerbose) {
	 	Write !, "Valid artifact found at: "_artifactPath
	}
	
	Set pTargetResultObj = targetResultObj
 	Return artifactPath
}

/// Retrieves the artifact based on the pArtifactPath provided.
/// pDestinationDirectory: Destination of directory for the artifact to be downloaded to
/// There is no need to return full path of the downloaded artifact tar/tgz but just the file name
/// Full path will be written to console if verbose is enabled.
ClassMethod RetrieveArtifact(pUseHttps As %Boolean, pArtifactServer As %String, pArtifactPort As %String, pArtifactPath As %String, pDestinationDirectory As %String, pVerbose As %Boolean = 0) As %String [ Internal ]
{
	If (pArtifactPath = "") {
		Return ""
	}
	Set httpRequest = ##class(%Net.HttpRequest).%New()
	Set httpRequest.Https = pUseHttps
	Set httpRequest.SSLConfiguration = ##class(%ZPM.PackageManager.Developer.Utils).CreateAndGetSSLConfig()
 	Set httpRequest.Server = pArtifactServer
 	Set httpRequest.Port = pArtifactPort
 	 	
 	If pVerbose {
 		Write !, "Start retrieving artifact at "_$Case(pUseHttps, 1: "https", : "http")_"://" _ pArtifactServer _ ":" _ $Case((pArtifactPort = ""), 1: "", : ":"_pArtifactPort) _ "/" _ pArtifactPath
 	}
 	$$$ThrowOnError(httpRequest.Get(pArtifactPath))
 	
 	Set responseData = httpRequest.HttpResponse.Data
 	Set responseDataStr = responseData.Read(,.readStatus)
 	$$$ThrowOnError(readStatus) 	
 	$$$ThrowOnError(responseData.Rewind())
 	If (httpRequest.HttpResponse.StatusCode = 404) {
 		$$$ThrowStatus($$$ERROR($$$GeneralError, "Artifact does not exist at: " _ pArtifactPath))
 	} ElseIf (httpRequest.HttpResponse.StatusCode '= 200) {
 		$$$ThrowStatus($$$ERROR($$$GeneralError, "The following error occurred while retrieving artifact: " _ responseDataStr))
 	}
 	
 	Set artifactName = httpRequest.HttpResponse.Headers("X-ARTIFACTORY-FILENAME")
 	If pVerbose {
 		write !, "Found: " _ artifactName
 	}
 	
 	// Create directory if it doesn't exist
 	If '##class(%Library.File).DirectoryExists(pDestinationDirectory) {
 		If '##class(%Library.File).CreateDirectoryChain(pDestinationDirectory) {
 			$$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to create destination directory: "_pDestinationDirectory))
 		}
 	}
 	
 	Set localPath = ##class(%Library.File).NormalizeFilename(artifactName, pDestinationDirectory)
 	If '##class(%Library.File).Exists(localPath) {
 		If pVerbose {
 			Write !, "Update found. Saving to " _ localPath
 		}
 		
 	    Set stream = ##class(%Library.FileBinaryStream).%New()
 	    Set stream.Filename = localPath
 	    $$$ThrowOnError(stream.CopyFrom(responseData))
 	    $$$ThrowOnError(stream.%Save())
 	}
 	
 	Return artifactName
}

/// Helper method to persist relevant metadata for future lookup
ClassMethod SaveMetadata(pResourceName As %String, pSourceControlRepo As %String, pVersion As %String, ByRef pTargetResultObj As %Library.DynamicObject, pVerbose As %Boolean = 0) [ Internal ]
{
	If ('$isobject(pTargetResultObj)) {
		If (pVerbose) {
			Write !, "Invalid object was passed in which was previously identified as the target result object."
		}
		Quit
	}
	#dim storage As %ZPM.PackageManager.Developer.AngularArtifact
	If ('##class(%ZPM.PackageManager.Developer.AngularArtifact).UniqueIdentifierIdxExists(pResourceName, pSourceControlRepo, pVersion)) {
	 	Set storage = ##class(%ZPM.PackageManager.Developer.AngularArtifact).%New()
	 	Set storage.ResourceName = pResourceName
	 	Set storage.SourceControlRepo = pSourceControlRepo
	 	Set storage.Version = pVersion	 	
	} Else {
		Set storage = ##class(%ZPM.PackageManager.Developer.AngularArtifact).UniqueIdentifierIdxOpen(pResourceName, pSourceControlRepo, pVersion,, .sc)
		$$$ThrowOnError(sc)
	}
	
 	Set storage.MostRecentUpdated = pTargetResultObj.%Get("updated")
 	
 	#dim properties As %Library.DynamicArray
 	Set properties = pTargetResultObj.%Get("properties")
 	#dim iterator As %Iterator.Array
 	Set iterator = properties.%GetIterator()
 	While iterator.%GetNext(,.element) {
	 	// each element is a dynamic object:
	 	// {"key":"build.number", "value":"1.0.92"}
	 	// {"key":"commit.branch", "value":"master"}
	 	Set key = element.%Get("key")
	 	Set value = element.%Get("value")
	 	If (key = "commit.branch") {
		 	Set storage.BranchName = value
		} ElseIf (key = "commit.hash") {
			Set storage.CommitHash = value
		}
	}
 	$$$ThrowOnError(storage.%Save())
 	If (pVerbose) {
	 	Write !, "Artifact metadata successfully added/updated."
	}
}

/// Utility method to untar a tgz file into a designated(or not) temporary dir, and copy to a destination dir(or back to source dir).
/// pArtifactName the source tgz file name
/// pSourceFileDir: the directory of pSourceFilePath (passed to save the effort of parsing again based on Windows/Unix)
/// pCopyToDir: the destination directory for extracted contents to be copied to
ClassMethod UnTar(pArtifactName As %String, pSourceFileDir As %String, pCopyToDir As %String, pVerbose As %Boolean = 0) [ Internal ]
{
	// if there is no artifact name, then it means artifact already exists and nothing new was downloaded, and skil untaring as well
	If (pArtifactName = "") {
		If (pVerbose) {
			Write !, "Artifact had been downloaded and extracted, skip untaring."
		}
		Return
	}
	// normalize
	Set pSourceFileDir = ##class(%Library.File).NormalizeDirectory(pSourceFileDir)
	Set artifactPath = ##class(%Library.File).NormalizeFilename(pArtifactName, pSourceFileDir)
	
	// make sure pSourceFilePath and pSourceFileDir exist
	If '##class(%Library.File).Exists(artifactPath) {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "File does not exist: "_artifactPath))
	}
	
	If '##class(%Library.File).DirectoryExists(pSourceFileDir) {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Directory does not exist: "_pSourceFileDir))
	}
	
	// prepare arguments for $ZF(-100) method call
	// /LOGCMD used to log the actually triggered command into messages.log
	Set keywords = "/SHELL"_$Select(pVerbose:"/LOGCMD",1:"")
	
	/* Note that it seems cygwin version tar has trouble recognizing windows path passed in directly, e.g.
	 * tar -C windows/path -(v)xzf windows/path/to/file will fail,
	 * but cd command works fine with cd windows/path and will automatically cd into a mapped equivalent linux path like /cygdrive/c/ for C:\ (verified on cygwin)
	 * so change the strategy to concatenate cd and tar commands:
	 * full command to be called via $ZF(-100): cd pSourFileDir && tar -(v)xzf filename
	 * default behavior is to overwrite existing files if you untar again
	 * tar arguments explained, order sensitive
	 * Note: we cannot do switch above into two separate $ZF(-100) calls because each time $ZF ends, pwd gets reverted to the one in previous stack
	 * pSourceFileDir: target dir to extract to, in our use case, it's where the source tgz file lives before extracting
	 * "-(v)xzf": extract with option flags, having "v" as the last one will cause issue so put it as the first
	 * pSourceFilePath: the actualy tgz file path
	 */
	Set args = ""
	Set args($increment(args)) = pSourceFileDir
	Set args($increment(args)) = "&&"
	Set args($increment(args)) = "tar"
	Set args($increment(args)) = "-"_$Select(pVerbose:"v",1:"")_"xzf"
	Set args($increment(args)) = pArtifactName
	
	
	If (pVerbose) {
		Set fullCommand = "cd"
		// write full command if pVerbose
		Set key = ""
		While 1 {
			Set key = $Order(args(key),1,value)
			If (key = "") {
				Quit
			}
			Set fullCommand = fullCommand_" "_value
		}
		Write !, "Lauching System Command: "_fullCommand
		Write !, "Command and return code will be logged in messages.log"
		Write !
	}
	
	Set errorCode = $ZF(-100, keywords, "cd", .args)
	// errorCode = 0 means the command gets launched successfully, other integers means getting error(e.g 1 means syntax error)
	If (errorCode '= 0) {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Unable to finish system command due to error code: "_errorCode))
	}
	
	If (pVerbose) {
		Write !, "Command launched successfully."
	}
	// After extracting, a new directory /package under pSourceFileDir will be created holding the extracted files, so make sure to get to correct level
	Set extractedDir = ##class(%Library.File).NormalizeDirectory(pSourceFileDir_$$$SLASH_"package")

	If '##class(%Library.File).DirectoryExists(extractedDir) {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Extracted directory does not exist: "_extractedDir))
	}
	
	// copy everything in /source/package into the final destination
	// overwrite existing files if there are any in destination dir
	If (pVerbose) {
		Write !, "Going to copy extracted contents from "_extractedDir_" to "_pCopyToDir
	}
	
	// pOverlay = 1, pDeleteBeforeCopy = 1
	If '##class(%Library.File).CopyDir(extractedDir, pCopyToDir, 1, ,1) {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to copy to directory: "_pCopyToDir))
	}

	If (pVerbose) {
		Write !, "Copy Succeeded."
	}
}

/// Returns a unique name for this resource.
Method OnGetUniqueName(Output pUniqueName)
{
	Set pUniqueName = ..ResourceReference.Name
}

}
