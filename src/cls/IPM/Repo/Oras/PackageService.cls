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
    set request = ..GetHttpRequest(..Location)
    set request.Timeout = 5
    if $$$ISERR(request.Get(..PathPrefix _ "v2/")) {
        quit 0
    }
    set statusCode = request.HttpResponse.StatusCode
    quit (200 <= statusCode) && (statusCode < 300)
}

Method GetModule(
	pModuleReference As %IPM.Storage.ModuleInfo,
	Output AsArchive As %Boolean = 0) As %Stream.Object
{
    set tag = $$$Semver2Tag(pModuleReference.VersionString)
    if (pModuleReference.Deployed) {
        set tag = tag _ $$$OrasTagPlatformSeparator _ pModuleReference.PlatformVersion
    }
    set status = ..Pull(..Location, pModuleReference.Name, tag, ..Namespace, ..Username, ..Password, ..Token, ..TokenAuthMethod, .stream)
    $$$ThrowOnError(status)
    #; module is pulled as a .tgz file
    set AsArchive = 1
    return stream
}

Method GetModuleManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
    set name = pModuleReference.Name _ ":" _ $$$Semver2Tag(pModuleReference.VersionString)
    return ..GetModuleXML(..Location, name, ..Namespace, ..Username, ..Password, ..Token, ..TokenAuthMethod)
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
        set $listbuild(version, platformVersion) = $listfromstring(tag, $$$OrasTagPlatformSeparator)
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

/// <var>moduleList</var> is a list of objects of type <class>%IPM.Storage.ModuleInfo</class> to which this method adds entries
/// <var>name</var> is the name of the package for which we are enumerating versions
Method ListModulesFromTagString(
	semverExpr As %IPM.General.SemanticVersionExpression,
	client As %SYS.Python,
	ByRef moduleList As %ListOfObjects,
	searchCriteria As %IPM.Repo.SearchCriteria,
	name As %String)
{
    set allTagsString = ..GetAllTags(..Location, name, "", client)
    set allVersionsList = ..AggregatePlatformVersions($listfromstring(allTagsString, ", "), .aggregatedPlatformVersion)
    set pointer = 0
    while $listnext(allVersionsList,pointer,moduleVersion) {
        #; filter by version
        set tVersion = ##class(%IPM.General.SemanticVersion).FromString($$$Tag2Semver(moduleVersion))
        if 'tVersion.Satisfies(semverExpr) {
            continue
        }

        #; Special case: if we provided an explicit build number, require it.
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

        #; get metadata from annotations
        set metadata = ..GetPackageMetadata(..Location, name, tag, "", client)
        set artifactMetadata = ##class(%IPM.Repo.Oras.ArtifactMetadata).%New()
        $$$ThrowOnError(artifactMetadata.%JSONImport(metadata))

        set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
        // `artifactMetadata.ImageTitle` can be different from `name`. E.g., when the module was simply "moved" from elsewhere under a different name.
        set tModRef.Name = name
        // `artifactMetadata.ImageVersion` can be different from `moduleVersion`. E.g., when the module was simply "moved" from elsewhere under a different tag
        set tModRef.VersionString = tVersion.ToString()
        set tModRef.Repository = artifactMetadata.ImageSource
        set tModRef.Description = artifactMetadata.ImageDescription
        set tModRef.Deployed = artifactMetadata.IPMDeployed
        if (artifactMetadata.IPMDeployed '= "") {
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

Method ListModules(pSearchCriteria As %IPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%IPM.Storage.ModuleInfo")
{
    #; Get ORAS client
    set client = ..GetClient(..Location, ..Username, ..Password, ..Token, ..TokenAuthMethod)

    #; Parse search criteria
    set name = $$$lcase(pSearchCriteria.Name)
    set tVersionExpression = pSearchCriteria.VersionExpression
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pSearchCriteria.VersionExpression, .tVersionExpression)
    $$$ThrowOnError(tSC)

    #; If namespace is defined, add it to the package URI being searched for
    if (name'="") && (..Namespace'="") {
        set name = ..AppendURIs(..Namespace, name)
    }

    #; Get all modules
    set tList = ##class(%Library.ListOfObjects).%New()

    #; get all versions
    // When no namespace is specified, we can only call "v2/_catalog" to get all the packages. In case of error, fail descriptively
    if (..Namespace = "") {
        set request = ..GetHttpRequest()
        #; Make GET request
        // response is a JSON structure like {"repositories":["package1", "package2", ...]}
        set tSC=request.Get(..PathPrefix _ "/v2/_catalog")
        $$$ThrowOnError(tSC)
        set response=request.HttpResponse
        if (response.StatusCode'=200) {
            // TODO improve error processing
            set msg = "Error: ORAS namespace is not set and the call to /v2/_catalog endpoint failed"
            set msg = msg _ $char(10,13) _ "Either set an ORAS namespace or ensure the ORAS server supports the /v2/_catalog endpoint"
            set msg = msg _ $char(10,13) _ "Response Code: "_response.StatusCode _ " - " _ response.Data.Read()
            $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
        }

        #; Handle results
        set json = ""
        while 'response.Data.AtEnd {
            set json = json _ response.Data.Read()
        }
        set data = ##class(%DynamicAbstractObject).%FromJSON(json)
        set iter = data.repositories.%GetIterator()
        // Iterate through each package
        // key is the index
        // package is the package name
        // type is always "string"
        while iter.%GetNext(.key, .package, .type) {
            if (package="") {
                continue
            }
            #; filter by module name if requested
            if (name'="") && (package'=name) {
                continue
            }
            #; collect all versions for this package in tList
            do ..ListModulesFromTagString(tVersionExpression, client, tList, pSearchCriteria, package)
        }
    } else {
        // TODO: Make this work properly for the case where name is empty (searching in a repo with a namespace)
        do ..ListModulesFromTagString(tVersionExpression, client, tList, pSearchCriteria, name)
    }
    return tList
}

// ** ORAS FUNCTIONS **

/// Returns an authenticated ORAS client
ClassMethod GetClient(
	registry As %String,
	username As %String = "",
	password As %String = "",
	token As %String = "",
	tokenAuthMethod As %String) As %SYS.Python
{
    try {
        set orasProvider = ##class(%SYS.Python).Import("oras.provider")

        set args = {}
        set args.hostname = registry
        #; assume everything not specified is using https
        set args.insecure = registry [ "http://"
        set client = orasProvider.Registry(args...)

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
        if e.Name = "<OBJECT DISPATCH>" {
            set eStatus = e.AsStatus()
            set usrStatus = $$$ERROR($$$GeneralError,$$$OrasRequiresFlexiblePython)
            $$$ThrowStatus($$$EMBEDSC(usrStatus,eStatus))
        } else {
            throw e
        }
    }
    return client
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
        set tag = ..GetLatestTag(registry, package,  namespace, username, password, token, tokenAuthMethod, 1)
    }

    try {
        #; Pull into temp directory
        set tempFile = ""
        set tempDirectory = $$$FileTempDir _ "/" _ package _ "/" _ tag

        #; Empty temp directory first
        if ##class(%File).DirectoryExists(tempDirectory) {
            set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tempDirectory)
            $$$ThrowOnError(tSC)
        }

        #; Pull the module using ORAS
        do ..PullOras(registry, package, tag, "", username, password, token, tokenAuthMethod, tempDirectory)

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
        if $$$ISOK(tSC) {
            set stream = tFileBinStream
        }

        #; Check hash and size against the manifest
        set hash = ##class(%SYSTEM.Encryption).SHAHashStream(256, stream, .sc)
        set hash = ##class(%xsd.hexBinary).LogicalToXSD(hash)

        set verified = ..VerifyModuleHashAndSize(registry, package _ ":" _ tag, "", username, password, token, tokenAuthMethod, hash, ##class(%Library.File).GetFileSize(tempFile))
        if 'verified {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Module size and/or hash failed validation!"))
        }
    } catch e {
        if e.Name = "<OBJECT DISPATCH>" {
            set eStatus = e.AsStatus()
            set usrStatus = $$$ERROR($$$GeneralError,$$$OrasRequiresFlexiblePython)
            set tSC = $$$EMBEDSC(usrStatus,eStatus)
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
    set res = client.pull(args...)
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

    try:
        manifest = client.get_manifest(target)
        annotations = manifest['annotations']
        return json.dumps(annotations)
    except Exception as ex:
        print("Exception: %s" % str(ex))

    # no module.xml found
    return ""
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
    try:
        tags = client.get_tags(target)
        # Return most recent version
        # If no tags exist, then module has been deleted
        return tags[-1] if tags else ""
    except:
        return ""
}

/// Returns comma separated string of all the tags for a given package
ClassMethod GetAllTags(
	registry As %String,
	package As %String,
	namespace As %String,
	client As %SYS.Python) As %String [ Language = python ]
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
    try:
        return bool(client.get_tags(target, 1))
    except:
        return False
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
