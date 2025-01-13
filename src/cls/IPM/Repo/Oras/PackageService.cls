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
	Set name = pModuleReference.Name _ ":" _ $$$Semver2Tag(pModuleReference.VersionString)
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
	Set allTagsString = ..GetAllTagsPy(..Location, name, "", client)
	Set allTagsList = $LISTFROMSTRING(allTagsString, ", ")
	Set pointer = 0
	While $ListNext(allTagsList,pointer,tag) {
		#; filter by version
		Set tVersion = ##class(%IPM.General.SemanticVersion).FromString(tag)
		If 'tVersion.Satisfies(tVersionExpression) { 
			Continue
		}

		#; get metadata from annotations
		Set metadata = ..GetPackageMetadataPy(..Location, name, "", tag, client)
		set artifactMetadata = ##class(%IPM.Repo.Oras.ArtifactMetadata).%New()
		Do artifactMetadata.%JSONImport(metadata)

		Set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
		Set tModRef.Name = artifactMetadata.ImageTitle
		Set tModRef.Repository = artifactMetadata.ImageSource
		Set tModRef.VersionString = artifactMetadata.ImageVersion
		Set tModRef.Description = artifactMetadata.ImageDescription
		Set tModRef.Deployed = artifactMetadata.IPMDeployed
		#; If $IsObject(item."platform_versions") {
		#;   Set tIterPVer = item."platform_versions".%GetIterator() 
		#;   While tIterPVer.%GetNext(.tPVerKey, .platformVersion) {
		#;     Do tModRef.PlatformVersions.Insert(platformVersion)
		#;   }
		#; }
		Set tModRef.AllVersions = allTagsString
		Set tModRef.Origin = artifactMetadata.IPMOrigin
		Do tList.Insert(tModRef)
		
		#; If not all versions are requested, return the latest one
		If 'pSearchCriteria.AllVersions, name="" {
			Quit
		}
	}
	Quit tList
}

// ** ORAS FUNCTIONS **

/// Returns an authenticated ORAS client
ClassMethod GetClient(registry As %String, username As %String = "", password As %String = "", token As %String = "", tokenAuthMethod As %String) As %SYS.Python
{
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
		Set tSC = e.AsStatus()
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
		tags.reverse()
		
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
