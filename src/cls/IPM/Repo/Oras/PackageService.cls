Include %IPM.Common

Class %IPM.Repo.Oras.PackageService Extends %IPM.Repo.Http.PackageService
{

/// The base URL for this repo, e.g. https://irepo.intersystems.com
/// The API endpoint is will be located at <Location>/v2/
Property Location As %String;

/// Optional extension for where packages get published to and pulled from
/// i.e. the API endpoint for a given module will be at <Location>/v2/<Namespace>/<Module>
Property Namespace As %String;

Property Username As %String(MAXLEN = "");

Property Password As %String(MAXLEN = "");

Property Token As %String(MAXLEN = "");

// ** PACKAGE SERVICE FUNCTIONS **

Method GetModule(pModuleReference As %IPM.Storage.ModuleInfo, Output AsArchive As %Boolean = 0) As %Stream.Object
{
	Set name = pModuleReference.Name _ ":" _ pModuleReference.VersionString
	Set status = ..Pull(..Location, name, ..Namespace, ..Username, ..Password, ..Token, .stream)
	If $$$ISERR(status) {
		$$$ThrowStatus(status)
	}
	#; module is pulled as a .tgz file
	Set AsArchive = 1
	Return stream
}

Method GetModuleManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
	Set name = pModuleReference.Name _ ":" _ pModuleReference.VersionString
	Return ..GetModuleXMLPy(..Location, name)
}

Method HasModule(pModuleReference As %IPM.Storage.ModuleInfo) As %Boolean
{
	Set name = pModuleReference.Name _ ":" _ pModuleReference.VersionString
	
	#; Get ORAS client
	Set client = ..GetClient(..Location, ..Username, ..Password, ..Token)

	Return ..HasModulePy(..Location, name, ..Namespace, client)
}

Method ListModules(pSearchCriteria As %IPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%IPM.Storage.ModuleInfo")
{
	#; Get ORAS client
	Set client = ..GetClient(..Location, ..Username, ..Password, ..Token)

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
	Set request = ..GetHttpRequest()
	
	#; Make GET request
	Set tSC=request.Get("/v2/_catalog")
	$$$ThrowOnError(tSC)
	Set response=request.HttpResponse
	If response.StatusCode'=200 {
		// todo improve error processing
		Set data = response.Data.Read()
		Write !, "Error! " _ response.StatusCode _ ": " _ response.ReasonPhrase
		Return ""
	}

	#; Handle results
	Set json = response.Data.ReadLine()
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
		Set allTagsList = $LISTFROMSTRING(allTagsString, ", ")
		Set pointer = 0
		While $ListNext(allTagsList,pointer,tag) {
			#; filter by version
			Set tVersion = ##class(%IPM.General.SemanticVersion).FromString(tag)
			If 'tVersion.Satisfies(tVersionExpression) { 
				Continue
			}

			#; get metadata from annotations
			Set metadata = ..GetPackageMetadataPy(..Location, package, "", tag, client)
			Set metadata = ##class(%DynamicAbstractObject).%FromJSON(metadata)

			Set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
			Set tModRef.Name = metadata."org.opencontainers.image.title"
			Set tModRef.Repository = metadata."org.opencontainers.image.source"
			Set tModRef.VersionString = metadata."org.opencontainers.image.version"
			Set tModRef.Description = metadata."org.opencontainers.image.description"
			Set tModRef.Deployed = metadata."com.intersystems.image.deployed"
			#; If $IsObject(item."platform_versions") {
			#;   Set tIterPVer = item."platform_versions".%GetIterator() 
			#;   While tIterPVer.%GetNext(.tPVerKey, .platformVersion) {
			#;     Do tModRef.PlatformVersions.Insert(platformVersion)
			#;   }
			#; }
			Set tModRef.AllVersions = allTagsString
			Set tModRef.Origin = metadata."com.intersystems.image.origin"
			Do tList.Insert(tModRef)
			
			#; If not all versions are requested, return the latest one
			If 'pSearchCriteria.AllVersions, name="" {
				Quit
			}
		}
	}
	Quit tList
}

// ** ORAS FUNCTIONS **

/// Returns an authenticated ORAS client
ClassMethod GetClient(registry, username = "", password = "", token = "")
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
		If registry [ "amazonaws" {
			#; AWS tokens are essentially username:password in one string
			Set client."_basic_auth" = token
			Do client."reset_basic_auth"()
		} Else {
			#; Bearer token
			Do client."set_token_auth"(token)
		}
	}
	Return client
}

/// Pulls the specified module to disk and returns the module in tgz form as %Stream.FileBinary
/// If no tag is specified, then the latest version will be pulled
ClassMethod Pull(registry, repository, namespace, username, password, token, ByRef stream) As %Status
{
	Set stream = ""
	Set tSC = $$$OK

	Set repoAndTag = ..GetRepoVersionPy(registry, repository, 1)
	Set repo = $piece(repoAndTag, ",", 1)
	Set tag = $piece(repoAndTag, ",", 2)

	Try {
		#; Pull into temp directory
		Set tempFile = ""
		Set tempDirectory = "/tmp/" _ repo _ "/" _ tag

		#; Empty temp directory first
		If ##class(%File).DirectoryExists(tempDirectory) {
			Set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tempDirectory)
			$$$ThrowOnError(tSC)
		}

		#; Pull the module using ORAS
		Do ..PullOras(registry, repository, "", username, password, token, tempDirectory)

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

		Set verified = ..VerifyModuleHashAndSizePy(registry, repository, "", username, password, token, hash, ##class(%Library.File).GetFileSize(tempFile))
		If 'verified {
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Module size and/or hash failed validation!"))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Pulls the package using ORAS
ClassMethod PullOras(registry, repository, namespace, username, password, token, path)
{
	Set repoTag = ..GetRepoVersionPy(registry, repository, 1)
	Set repo = $PIECE(repoTag, ",", 1)
	Set tag = $PIECE(repoTag, ",", 2)

	Set target = ..GetAPITarget(registry, repo, namespace) _ ":" _ tag
	Set client = ..GetClient(registry, username, password, token)
	
	#; set up for python call
	Set args = {}
	Set args.target = target
	Set args.outdir = path
	Set res = client.pull(args...)
}

/// Returns the contents of the module.xml for the given repository
ClassMethod GetModuleXMLPy(registry, repository, namespace, username, password, token) [ Language = python ]
{
	import iris

	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace)
	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token)

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

ClassMethod GetPackageMetadataPy(registry, repository, namespace, tag, client) [ Language = python ]
{
	import iris
	import json

	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace) + ":" + tag
	
	try:
		manifest = client.get_manifest(target)
		annotations = manifest['annotations']
		return json.dumps(annotations)
	except Exception as ex:
		print("Exception: %s" % str(ex))

	# no module.xml found
	return ""
}

/// Given a repository name, either parses out the tag or determines the latest tag
/// Params:
/// 	repository : is either in the form <repo>:<tag> or <repo>
/// 			     in the latter case, returns latest tag
/// 	asString   : 0 => returns as python tuple of (repo, tag)
/// 			     1 => returns as string of "<repo>,<tag>"
ClassMethod GetRepoVersionPy(registry, repository, asString = 0) [ Language = python ]
{
	import iris
	
	if ":" in repository:
		repo, tag = repository.split(":", 1)
	else:
		repo = repository
		tag = iris.cls("%IPM.Repo.Oras.PackageService").GetLatestTagPy(registry, repo, "", "", "", "")
	if asString:
		return repo + "," + tag
	else:
		return (repo, tag)
}

/// Lists all of the modules and their latest versions in the repository
/// Returns the tag for the highest numbered version
ClassMethod GetLatestTagPy(registry, repository, namespace, username, password, token) [ Language = python ]
{
	import iris
	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace)
	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token)
	tags = client.get_tags(target)

	# Return most recent version
	# If no tags exist, then module has been deleted
	if not tags:
		return ""
	else:
		return tags[-1]
}

/// Returns comma separated string of all the tags for a given repository
ClassMethod GetAllTagsPy(registry, repository, namespace, client) [ Language = python ]
{
	import iris
	try:
		target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace)
		tags = client.get_tags(target)

		# flip list so higher versions are first
		tags.reverse()
		
		# convert from list to comma separated string
		tags = ", ".join(str(x) for x in tags)
	except e:
		print("Error: ", repr(e))
	return tags
}

/// Returns whether the given repository is in the registry
ClassMethod HasModulePy(registry, repository, namespace, client) As %Boolean [ Language = python ]
{
	import iris
	# Attempt to get the tags of the specified repository
	# If tags are not found, then the repository does not exist
	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace)

	tags = client.get_tags(target, 1)
	# check if tags is [] through boolean coercion
	return not not tags
}

// ** UTILITY FUNCTIONS **

/// Gets the URL for the API endpoint, i.e. returns target where <target>/v2/ is the endpoint
ClassMethod GetAPITarget(registry, repository, namespace = "") [ Language = python ]
{
	import iris
	
	if namespace != "":
		repository = iris.cls("%IPM.Repo.Oras.PackageService").AppendURIs(namespace, repository)
	target = iris.cls("%IPM.Repo.Oras.PackageService").AppendURIs(registry, repository)

	# remove http(s) from target url
	return target.replace("http://","").replace("https://","")
}

/// Given two URIs, appends them such that the "/" are correctly placed in between
/// Removes the leading and trailing "/"
ClassMethod AppendURIs(uriOne As %String, uriTwo As %String) [ Language = python ]
{
	if uriOne[-1] != "/" and uriTwo[0] != "/":
		uriOne = uriOne + "/"
	if uriOne[-1] == "/" and uriTwo[0] == "/":
		uriOne = uriOne[:-1]
	if uriTwo[-1] == "/":
		uriTwo = uriTwo[:-1]
	return uriOne + uriTwo
}

/// Returns whether the given SHA256 hash and file size matches the hash and size in the ORAS manifest for the module
ClassMethod VerifyModuleHashAndSizePy(registry, repository, namespace, username, password, token, hash, size) As %Boolean [ Language = python ]
{
	import iris

	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace)
	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token)
	
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
