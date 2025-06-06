Include %IPM.Common

Class %IPM.Repo.Oras.PackageService Extends %IPM.Repo.Http.PackageService
{

/// The base URL for this repo, e.g. https://irepo.intersystems.com
/// The API endpoint is will be located at <Location>/v2/
Property Location As %IPM.DataType.RepoLocation;

/// Optional extension for where packages get published to and pulled from
/// i.e. the API endpoint for a given module will be at <Location>/v2/<Namespace>/<Module>
Property Namespace As %IPM.DataType.OrasNamespace;

/// Prefix for ORAS API calls
Property PathPrefix As %String(MAXLEN = "");

Parameter ALLOWPREFIXINLOCATION = 0;

// ** PACKAGE SERVICE FUNCTIONS **

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
	Set request = ..GetHttpRequest(..Location)
	Set request.Timeout = 5
	If $$$ISERR(request.Get(..PathPrefix _ "v2/")) {
		Quit 0
	}
	Set statusCode = request.HttpResponse.StatusCode
	Quit (200 <= statusCode) && (statusCode < 300)
}

Method GetModule(pModuleReference As %IPM.Storage.ModuleInfo, Output AsArchive As %Boolean = 0) As %Stream.Object
{
	Set version = $$$Semver2Tag(pModuleReference.VersionString)
	If (pModuleReference.Deployed) {
		Set version = version _ $$$OrasTagPlatformSeparator _ pModuleReference.PlatformVersion
	}
	Set name = pModuleReference.Name _ ":" _ version
	Set status = ..Pull(..Location, name, ..Namespace, ..Username, ..Password, ..Token, ..TokenAuthMethod, .stream)
	$$$ThrowOnError(status)
	#; module is pulled as a .tgz file
	Set AsArchive = 1
	Return stream
}

Method GetModuleManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
	Set name = pModuleReference.Name _ ":" _ $$$Semver2Tag(pModuleReference.VersionString)
	Return ..GetModuleXMLPy(..Location, name, ..Namespace, ..Username, ..Password, ..Token, ..TokenAuthMethod)
}

Method HasModule(pModuleReference As %IPM.Storage.ModuleInfo) As %Boolean
{
	Set name = pModuleReference.Name _ ":" _ $$$Semver2Tag(pModuleReference.VersionString)
	
	#; Get ORAS client
	Set client = ..GetClient(..Location, ..Username, ..Password, ..Token, ..TokenAuthMethod)

	Return ..HasModulePy(..Location, name, ..Namespace, client)
}

/// Given a list of ORAS tags, aggregate the platform versions by package version
/// e.g. $lb("1.0.0__2024.1, "1.0.0__2024.2", "2.0.0__2023.1", "3.0.0") -> aggregatedPlatformVersion
/// where aggregatedPlatformVersion("1.0.0") = $lb("2024.1","2024.2") 
///       aggregatedPlatformVersion("2.0.0") = $lb("2023.1")
///       aggregatedPlatformVersion("3.0.0") = $lb("")
/// The returned list represents the correct order of the package versions, where latest versions are first
/// e.g., $lb("1.0.0", "2.0.0", "3.0.0") -> $lb("3.0.0", "2.0.0", "1.0.0")
ClassMethod AggregatePlatformVersions(tagsList As %List, Output aggregatedPlatformVersion As %String) As %List
{
	Set ptr = 0
	While $ListNext(tagsList, ptr, tag) {
		// aggregate
		Set $ListBuild(version, platformVersion) = $ListFromString(tag, $$$OrasTagPlatformSeparator)
		Set value = $Get(aggregatedPlatformVersion(version))
		Set aggregatedPlatformVersion(version) = value _ $ListBuild(platformVersion) 
	}

	Set version = "", versionList = ""
	For {
		Set version = $Order(aggregatedPlatformVersion(version))
		If version = "" {
			Quit
		}
		Set versionList = versionList _ $ListBuild(version)
	}
	
	Set pyList = ##class(%SYS.Python).ToList(versionList)
	Set sortedTags = ##class(%IPM.Utils.EmbeddedPython).SortVersions(pyList, 1)
	Return ##class(%IPM.Utils.EmbeddedPython).FromPythonList(sortedTags)
}

/// <var>allTagsString</var> is as returned by <method>GetAllTagsPy</method> (comma + space separated)
/// <var>moduleList</var> is a list of objects of type <class>%IPM.Storage.ModuleInfo</class> to which this method adds entries
/// <var>name</var> is the name of the package for which we are enumerating versions
Method ListModulesFromTagString(allTagsString As %String, semverExpr As %IPM.General.SemanticVersionExpression, client As %SYS.Python, moduleList As %ListOfObjects, searchCriteria As %IPM.Repo.SearchCriteria, name As %String)
{
	Set allVersionsList = ..AggregatePlatformVersions($ListFromString(allTagsString, ", "), .aggregatedPlatformVersion)
	Set pointer = 0
	While $ListNext(allVersionsList,pointer,moduleVersion) {
		#; filter by version
		Set tVersion = ##class(%IPM.General.SemanticVersion).FromString($$$Tag2Semver(moduleVersion))
		If 'tVersion.Satisfies(semverExpr) { 
			Continue
		}

		#; Special case: if we provided an explicit build number, require it.
		If ##class(%IPM.General.SemanticVersion).IsValid(searchCriteria.VersionExpression,.specificVersion) && (specificVersion.Build '= "") && (specificVersion.Build '= tVersion.Build) {
			Continue
		}

		// If there are multiple platform versions for a given package version, we only want to use the metadata of one of them
		Set platformVersions = aggregatedPlatformVersion(moduleVersion)
		Set platformVersion = $ListGet(platformVersions)
		Set tag = moduleVersion
		If platformVersion '= "" {
			Set tag = tag _ $$$OrasTagPlatformSeparator _ platformVersion
		}

		#; get metadata from annotations
		Set metadata = ..GetPackageMetadataPy(..Location, name, "", tag, client)
		set artifactMetadata = ##class(%IPM.Repo.Oras.ArtifactMetadata).%New()
		$$$ThrowOnError(artifactMetadata.%JSONImport(metadata))

		Set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
		// `artifactMetadata.ImageTitle` can be different from `name`. E.g., when the module was simply "moved" from elsewhere under a different name.
		Set tModRef.Name = name
		// `artifactMetadata.ImageVersion` can be different from `moduleVersion`. E.g., when the module was simply "moved" from elsewhere under a different tag
		Set tModRef.VersionString = tVersion.ToString()
		Set tModRef.Repository = artifactMetadata.ImageSource
		Set tModRef.Description = artifactMetadata.ImageDescription
		Set tModRef.Deployed = artifactMetadata.IPMDeployed
		If artifactMetadata.IPMDeployed '= "" {
			Set pvPtr = 0
			While $ListNext(platformVersions, pvPtr, pv) {
				$$$ThrowOnError(tModRef.PlatformVersions.Insert(pv))
			}
		}
		If searchCriteria.AllVersions {
			// TODO: Convert these to semvers. This is just for display so OK not to for now.
			Set tModRef.AllVersions = allTagsString
		}
		Set tModRef.Origin = artifactMetadata.IPMOrigin
		Do moduleList.Insert(tModRef)

		If searchCriteria.AllVersions '= "" {
			// This is a tri-state.
			// 0: don't show them.
			// 1: do show them
			// empty: we're resolving dependencies so DON'T QUIT.
			Quit
		}
	}
}

Method ListModules(pSearchCriteria As %IPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%IPM.Storage.ModuleInfo")
{
	#; Get ORAS client
	Set client = ..GetClient(..Location, ..Username, ..Password, ..Token, ..TokenAuthMethod)

	#; Parse search criteria
	Set name = $$$lcase(pSearchCriteria.Name)
	Set tVersionExpression = pSearchCriteria.VersionExpression
	Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pSearchCriteria.VersionExpression, .tVersionExpression)
	$$$ThrowOnError(tSC)
	
	#; If namespace is defined, add it to the package URI being searched for
	If name'="", ..Namespace'="" {
		Set name = ..AppendURIs(..Namespace, name)
	}

	#; Get all modules
	Set tList = ##class(%Library.ListOfObjects).%New()
			
	#; get all versions

	// When no namespace is specified, we can only call "v2/_catalog" to get all the packages. In case of error, fail descriptively
	If (..Namespace = "") {
		Set request = ..GetHttpRequest()
		#; Make GET request
		// response is a JSON structure like {"repositories":["package1", "package2", ...]}
		Set tSC=request.Get(..PathPrefix _ "/v2/_catalog")
		$$$ThrowOnError(tSC)
		Set response=request.HttpResponse
		If response.StatusCode'=200 {
			// TODO improve error processing
			Set msg = "Error: ORAS namespace is not set and the call to /v2/_catalog endpoint failed"
			Set msg = msg _ $Char(10,13) _ "Either set an ORAS namespace or ensure the ORAS server supports the /v2/_catalog endpoint"
			Set msg = msg _ $Char(10,13) _ "Response Code: "_response.StatusCode _ " - " _ response.Data.Read()
			$$$ThrowStatus($$$ERROR($$$GeneralError, msg))
		}

		#; Handle results
		Set json = ""
		While 'response.Data.AtEnd {
			Set json = json _ response.Data.Read()
		}
		Set data = ##class(%DynamicAbstractObject).%FromJSON(json)
		Set iter = data.repositories.%GetIterator()
		While iter.%GetNext(.key, .package, .type) {
			If (package="") { 
				Continue
			}
			#; filter by module name
			If (name'="") && (package'=name) {
				Continue
			}
			#; get all versions
			Set allTagsString = ..GetAllTagsPy(..Location, package, "", client)
			Do ..ListModulesFromTagString(allTagsString, tVersionExpression, client, tList, pSearchCriteria, package)
		}
		Return tList
	}

	// TODO: Make this work properly for the case where name is empty (searching in a repo with a namespace)
	Set allTagsString = ..GetAllTagsPy(..Location, name, "", client)
	Do ..ListModulesFromTagString(allTagsString, tVersionExpression, client, tList, pSearchCriteria, name)
	Return tList
}

// ** ORAS FUNCTIONS **

/// Returns an authenticated ORAS client
ClassMethod GetClient(registry As %String, username As %String = "", password As %String = "", token As %String = "", tokenAuthMethod As %String) As %SYS.Python
{
	Try {
		Set orasProvider = ##class(%SYS.Python).Import("oras.provider")
		
		Set args = {}
		Set args.hostname = registry
		#; assume everything not specified is using https
		Set args.insecure = registry [ "http://"
		Set client = orasProvider.Registry(args...)

		If username '= "", password '= "" {
			Do client."set_basic_auth"(username, password)
		} Elseif token '= "" {
			If tokenAuthMethod = "basic" {
				#; AWS tokens are essentially username:password in one string
				Set client."_basic_auth" = token
				Do client."reset_basic_auth"()
			} ElseIf tokenAuthMethod = "bearer" {
				#; Bearer token
				Do client."set_token_auth"(token)
			} ElseIf tokenAuthMethod = "apiKey" {
				#; API key
				Do client."set_header"("apikey", token)
			} Else {
				$$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Unknown token auth method: ""%1""", tokenAuthMethod)))
			}
		}
	} Catch e {
		If e.Name = "<OBJECT DISPATCH>" {
			Set eStatus = e.AsStatus()
			Set usrStatus = $$$ERROR($$$GeneralError,$$$OrasRequiresFlexiblePython)
			$$$ThrowStatus($$$EMBEDSC(usrStatus,eStatus))
		} Else {
			Throw e
		}
	}
	Return client
}

/// Pulls the specified module to disk and returns the module in tgz form as %Stream.FileBinary
/// If no tag is specified, then the latest version will be pulled
ClassMethod Pull(registry As %String, package As %String, namespace As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String, Output stream As %Stream.FileBinary) As %Status
{
	Set stream = ""
	Set tSC = $$$OK

	Set pkgAndTag = ..GetPackageVersionPy(registry, package,  namespace, username, password, token, tokenAuthMethod, 1)
	Set pkg = $piece(pkgAndTag, ",", 1)
	Set tag = $piece(pkgAndTag, ",", 2)

	Try {
		#; Pull into temp directory
		Set tempFile = ""
		Set tempDirectory = $$$FileTempDir _ "/" _ pkg _ "/" _ tag

		#; Empty temp directory first
		If ##class(%File).DirectoryExists(tempDirectory) {
			Set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tempDirectory)
			$$$ThrowOnError(tSC)
		}

		#; Pull the module using ORAS
		Do ..PullOras(registry, package, "", username, password, token, tokenAuthMethod, tempDirectory)

		#; Find only the tgz file
		Set result=##class(%ResultSet).%New("%File:FileSet")
		Do result.Execute(tempDirectory,"*.tgz")
		While result.Next() {
			Set tempFile = result.GetDataByName("Name")
			Quit
		}
		If tempFile = "" {
			$$$ThrowStatus($$$ERROR($$$GeneralError, "tgz file not found"))
		}

		#; Convert into stream
		Set tFileBinStream = ##class(%Stream.FileBinary).%New()
		Set tSC = tFileBinStream.LinkToFile(tempFile)
		If $$$ISOK(tSC) {
			Set stream = tFileBinStream
		}

		#; Check hash and size against the manifest
		Set hash = ##class(%SYSTEM.Encryption).SHAHashStream(256, stream, .sc)
		Set hash = ##class(%xsd.hexBinary).LogicalToXSD(hash)

		Set verified = ..VerifyModuleHashAndSizePy(registry, package, "", username, password, token, tokenAuthMethod, hash, ##class(%Library.File).GetFileSize(tempFile))
		If 'verified {
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Module size and/or hash failed validation!"))
		}
	} Catch e {
		If e.Name = "<OBJECT DISPATCH>" {
			Set eStatus = e.AsStatus()
			Set usrStatus = $$$ERROR($$$GeneralError,$$$OrasRequiresFlexiblePython)
			Set tSC = $$$EMBEDSC(usrStatus,eStatus)
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

/// Pulls the package using ORAS
ClassMethod PullOras(registry As %String, package As %String, namespace As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String, path As %String)
{
	Set pkgTag = ..GetPackageVersionPy(registry, package, namespace, username, password, token, tokenAuthMethod, 1)
	Set pkg = $PIECE(pkgTag, ",", 1)
	Set tag = $$$Semver2Tag($PIECE(pkgTag, ",", 2))

	Set target = ..GetAPITarget(registry, pkg, namespace) _ ":" _ tag
	Set client = ..GetClient(registry, username, password, token, tokenAuthMethod)
	
	#; set up for python call
	Set args = {}
	Set args.target = target
	Set args.outdir = path
	Set res = client.pull(args...)
}

/// Returns the contents of the module.xml for the given package
ClassMethod GetModuleXMLPy(registry As %String, package As %String, namespace As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String) As %String [ Language = python ]
{
	import iris

	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace)
	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenAuthMethod)

	# loop through the annotations to find the module.xml text
	manifest=""
	try:
		manifest = client.get_manifest(target)
		for key in manifest['annotations']:
			if key == "com.intersystems.ipm.module.v1+xml":
				moduleXML = manifest['annotations'][key]
				# remove whitespace
				return "".join(moduleXML.split())
	except Exception as ex:
		print("Exception: %s" % str(ex))

	# no module.xml found
	return ""
}

ClassMethod GetPackageMetadataPy(registry As %String, package As %String, namespace As %String, tag As %String, client As %String) As %String [ Language = python ]
{
	import iris
	import json

	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace) + ":" + tag
	
	try:
		manifest = client.get_manifest(target)
		annotations = manifest['annotations']
		return json.dumps(annotations)
	except Exception as ex:
		print("Exception: %s" % str(ex))

	# no module.xml found
	return ""
}

/// Given a package name, either parses out the tag or determines the latest tag
/// Params:
/// 	package : is either in the form <package>:<tag> or <package>
/// 			     in the latter case, returns semver corresponding to the latest tag
/// 	asString   : 0 => returns as python tuple of (package, semver)
/// 			     1 => returns as string of "<package>,<semver>"
ClassMethod GetPackageVersionPy(registry As %String, package As %String, namespace As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String, asString As %Boolean = 0) [ Language = python ]
{
	import iris
	
	if ":" in package:
		pkg, tag = package.split(":", 1)
	else:
		pkg = package
		tag = iris.cls("%IPM.Repo.Oras.PackageService").GetLatestTagPy(registry, pkg,  namespace, username, password, token, tokenAuthMethod, asString )
	
	semver = tag.replace("_", "+")
	if asString:
		return pkg + "," + semver
	else:
		return (pkg, semver)
}

/// Lists all of the modules and their latest versions in the package
/// Returns the tag for the highest numbered version
ClassMethod GetLatestTagPy(registry As %String, package As %String, namespace As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String) As %String [ Language = python ]
{
	import iris
	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace)
	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenAuthMethod)
	try:
		tags = client.get_tags(target)
		# Return most recent version
		# If no tags exist, then module has been deleted
		return tags[-1] if tags else ""
	except:
		return ""
}

/// Returns comma separated string of all the tags for a given package
ClassMethod GetAllTagsPy(registry As %String, package As %String, namespace As %String, client As %SYS.Python) As %String [ Language = python ]
{
	import iris
	try:
		target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace)
		tags = client.get_tags(target)

		# flip list so higher versions are first
		tags = iris.cls("%IPM.Utils.EmbeddedPython").SortOCITags(tags, 1)
		
		# convert from list to comma separated string
		return ", ".join(str(x) for x in tags)
	except ValueError:
	    # ValueError indicates the package is missing and has no tags. Fail silently with no tags returned
		return ""
	except Exception as e:
		print("Error: ", repr(e))
		return ""
}

/// Returns whether the given package is in the registry
ClassMethod HasModulePy(registry As %String, package As %String, namespace As %String, client As %SYS.Python) As %Boolean [ Language = python ]
{
	import iris
	# Attempt to get the tags of the specified package
	# If tags are not found, then the package does not exist
	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace)

	# check if tags is [] through boolean coercion
	try:
		return bool(client.get_tags(target, 1))
	except:
		return False
}

// ** UTILITY FUNCTIONS **

/// Gets the URL for the API endpoint, i.e. returns target where <target>/v2/ is the endpoint
ClassMethod GetAPITarget(registry As %String, package As %String, namespace As %String = "") As %String
{
	If namespace '= "" {
		Set package = ..AppendURIs(namespace, package)
	}
	Set target = ..AppendURIs(registry, package)
	Return $Replace($Replace(target, "http://", ""), "https://", "")
}

/// Given two URIs, appends them such that the "/" are correctly placed in between
/// Removes the leading and trailing "/"
ClassMethod AppendURIs(uri1 As %String, uri2 As %String) As %String
{
	If ($Extract(uri1, *) '= "/" ) && ($Extract(uri2, 1) '= "/") {
		Set uri1 = uri1 _ "/"
	}
	If ($Extract(uri1, *) = "/" ) && ($Extract(uri2, 1) = "/") {
		Set uri1 = $Extract(uri1, 1, *-1)
	}
	If ($Extract(uri2, *) = "/" ) {
		Set uri2 = $Extract(uri2, 1, *-1)
	}
	Return uri1 _ uri2
}

/// Returns whether the given SHA256 hash and file size matches the hash and size in the ORAS manifest for the module
ClassMethod VerifyModuleHashAndSizePy(registry As %String, package As %String, namespace As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String, hash As %String, size As %String) As %Boolean [ Language = python ]
{
	import iris

	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace)
	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenAuthMethod)
	
	try:
		manifest = client.get_manifest(target)
		# parse the manifest
		for layer in manifest['layers']:
			if layer["mediaType"] != "application/vnd.oci.image.layer.v1.tar":
				continue
			# check size and hash
			manifest_size = layer["size"]
			manifest_hash = layer["digest"]
			hash = ("sha256:" + hash).lower()
			return manifest_size == size and manifest_hash == hash
	except Exception as ex:
		print("Exception: %s" % str(ex))
	return False
}

}
