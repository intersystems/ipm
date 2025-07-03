Include %IPM.Common

Class %IPM.Repo.Oras.PublishService Extends (%IPM.Repo.Oras.PackageService, %IPM.Repo.IPublishService)
{

Method PublishModule(pModule As %IPM.Repo.Remote.ModuleInfo) As %Status
{
    set status = $$$OK
    try {
        set repo = pModule.Name
        set tag = $$$Semver2Tag(pModule.VersionString)

        #; Use a temp directory
        set tDir = $$$FileTempDir
        if tDir = ("-" _ -tDir) { // $zu(140,17) can return a negative number if it fails
            throw ##class(%Exception.General).%New("Failed to create temporary directory. Error code: " _ -tDir)
        }
        set tempDirectory = ##class(%File).NormalizeDirectory(tDir _ "/" _ repo _ "/" _ tag _ "/")

        #; Create temp directory
        set tCreated = ##class(%File).CreateDirectoryChain(tempDirectory,.tReturnValue)
        if 'tCreated {
            $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Error creating directory %1: %2", tempDirectory, tReturnValue)))
        }

        #; Create tgz file in temp directory
        set tFileBinStream = ##class(%Stream.FileBinary).%New()
        set tFileBinStream.Filename = ##class(%File).TempFilename("tgz", tempDirectory, .return)
        do tFileBinStream.CopyFromAndSave(pModule.Payload)

        #; Convert module.xml into string
        set moduleXML = ""
        while (pModule.Manifest.AtEnd = 0) {
            set moduleXML = moduleXML _ pModule.Manifest.ReadLine(, .status)
            $$$ThrowOnError(status)
        }

        #; Set metadata
        set metadata = ##class(%IPM.Repo.Oras.ArtifactMetadata).%New()
        set metadata.ImageTitle = pModule.Name
        set metadata.ImageDescription = pModule.Description
        set metadata.ImageVersion = pModule.VersionString
        set metadata.ImageSource = pModule.Repository
        set metadata.ImageCreated = $zdatetime($now(),3,2)
        set metadata.IPMAllVersions = pModule.AllVersions
        set metadata.IPMOrigin = pModule.Origin
        set metadata.IPMDeployed = pModule.Deployed
        set metadata.IPMPlatformVersion = pModule.PlatformVersion
        set metadata.IPMModuleV1XML = moduleXML
        do metadata.%JSONExportToString(.metaDataString)
        if (pModule.Deployed) {
            set tag = tag _ $$$OrasTagPlatformSeparator _ pModule.PlatformVersion
        }

        #; Push file
        $$$ThrowOnError(..Push(..Location, repo, ..Namespace, tempDirectory, tag, metaDataString, ..Username, ..Password, ..Token, ..TokenAuthMethod))
    } catch ex {
        set status = ex.AsStatus()
    }
    // Clean up temp directory whether successful or not
    if ($data(tempDirectory) # 2) && ##class(%File).DirectoryExists(tempDirectory) {
        set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tempDirectory)
        set status = $$$ADDSC(status, tSC)
    }

    return status
}

Method CheckUnpublishEnabled(
	packageName As %String,
	packageVersion As %String) As %Boolean
{
    // TODO improve
    return 1
}

Method Unpublish(
	packageName As %String,
	packageVersion As %String) As %Status
{
    if (packageVersion = "all") {
        do ..DeleteModule(..Location, packageName, ..Namespace, ..Username, ..Password, ..Token, ..TokenAuthMethod)
    } else {
        do ..DeleteTagsPy(..Location, packageName, ..Namespace, packageVersion, ..Username, ..Password, ..Token, ..TokenAuthMethod)
    }
    return $$$OK
}

/// Pushes the files as an artifact with the given name and tag(s) as versions
/// Existing tags will be overwritten
/// Params:
/// 	package - string name of package to push to, e.g. test-artifact
/// 	tags    - comma separated strings of tags, e.g. "1.0.0,latest"
ClassMethod Push(
	registry As %String,
	package As %String,
	namespace As %String,
	path As %String,
	tags As %String,
	metadata As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String)
{
    #; Remove the tag from the package name if it exists and add it to tags
    set repo = $piece(package, ":", 1)
    set tag = $$$Semver2Tag($piece(package, ":", 2))
    if (tag '= "") {
        set tags = tags _ "," _ tag
    }
    if (tags = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Must specify version."))
    }

    #; Remove whitespace from tags
    set tags = $zstrip(tags,"*W")

    try {
        do ..PushPy(registry, repo, namespace, tags, path, metadata, username, password, token, tokenAuthMethod)
    } catch e {
        if e.Name = "<OBJECT DISPATCH>" {
            set eStatus = e.AsStatus()
            set usrStatus = $$$ERROR($$$GeneralError,$$$OrasRequiresFlexiblePython)
            $$$ThrowStatus($$$EMBEDSC(usrStatus,eStatus))
        } else {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Unable to push: " _ e.DisplayString()))
        }
    }
    return $$$OK
}

/// Publishes/pushes the package using ORAS
ClassMethod PushPy(
	registry As %String,
	package As %String,
	namespace As %String,
	tags As %String,
	directoryPath As %String,
	metadata As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String) [ Language = python ]
{
    import iris
    import os, sys
    import json
    import re

    # Get all files in the directory and fully specify path
    file_paths = [os.path.join(directoryPath, f) for f in os.listdir(directoryPath)]
    client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenAuthMethod)
    regex = re.compile(r"^[a-zA-Z0-9_][a-zA-Z0-9._-]{0,127}$")

    # Push once for each tag
    for tag in tags.split(","):
        if not regex.search(tag):
            raise ValueError(f"Invalid OCI tag: {tag}")

        # Annotations are manifest.xml and other metadata
        manifest_annotations = json.loads(metadata)

        # TODO write a context manager for stdout/stderr redirection
        # Suppress console output
        sys.stdout = open(os.devnull, "w")

        try:
            target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace) + ":" + tag
            res = client.push(files=file_paths, target=target, disable_path_validation=True, manifest_annotations=manifest_annotations)
        except Exception as e:
            print("Error: ", repr(e), file=sys.stderr)
            sys.stdout = sys.__stdout__
            raise e

        # Reenable console output
        sys.stdout = sys.__stdout__
}

/// Deletes the specified tags from the module
ClassMethod DeleteTagsPy(
	registry As %String,
	package As %String,
	namespace As %String,
	tags As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String) [ Language = python ]
{
    import iris

    target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, package, namespace)
    client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenAuthMethod)

    # remove whitespace and convert to a list
    if isinstance(tags, str):
        tags = tags.replace(" ","").split(",")
    for tag in tags:
        client.delete_tag(target,tag)
}

/// Deletes the module by deleting all tags
ClassMethod DeleteModule(
	registry As %String,
	package As %String,
	namespace As %String,
	username As %String,
	password As %String,
	token As %String,
	tokenAuthMethod As %String)
{
    set target = ##class(%IPM.Repo.Oras.PackageService).GetAPITarget(registry, package, namespace)
    set client = ##class(%IPM.Repo.Oras.PackageService).GetClient(registry, username, password, token, tokenAuthMethod)
    try {
        set tags = client."get_tags"(target)
        do ..DeleteTagsPy(registry, package, namespace, tags, username, password, token, tokenAuthMethod)
    } catch sc {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to delete: " _ sc.DisplayString()))
    }
}

}
