Class %IPM.Repo.Oras.PublishService Extends (%IPM.Repo.Oras.PackageService, %IPM.Repo.IPublishService)
{

Method PublishModule(pModule As %IPM.Repo.Remote.ModuleInfo) As %Boolean
{
    Set repo = pModule.Name
    Set tag = pModule.VersionString

    #; Use a temp directory
    Set tempFile = ""
    Set tempDirectory = ##class(%File).NormalizeDirectory($$$FileTempDir _ "/" _ repo _ "/" _ tag _ "/")

    #; Empty temp directory first
    If ##class(%File).DirectoryExists(tempDirectory) {
        Set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tempDirectory)
        $$$ThrowOnError(tSC)
    }

    #; Create temp directory
    Set tCreated = ##class(%File).CreateDirectoryChain(tempDirectory,.tReturnValue)
    If 'tCreated {
		$$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Error creating directory %1: %2", tempDirectory, tReturnValue)))
    }

    #; Create tgz file in temp directory
    Set tFileBinStream = ##class(%Stream.FileBinary).%New()
    Set tFileBinStream.Filename = ##class(%File).TempFilename("tgz", tempDirectory, .return)
    Do tFileBinStream.CopyFromAndSave(pModule.Payload)

    #; Convert module.xml into string
    Set moduleXML = ""
    While (pModule.Manifest.AtEnd = 0) {
        Set moduleXML = moduleXML _ pModule.Manifest.ReadLine(, .status)
        $$$ThrowOnError(status)
    }

	#; Set metadata
	Set metadata = ##class(%IPM.Repo.Oras.ArtifactMetadata).%New()
	Set metadata.ImageTitle = pModule.Name
	Set metadata.ImageDescription = pModule.Description
	Set metadata.ImageVersion = pModule.VersionString
	Set metadata.ImageSource = pModule.Repository
	Set metadata.ImageCreated = $zdt($now(),3,2)
	Set metadata.IPMAllVersions = pModule.AllVersions
	Set metadata.IPMOrigin = pModule.Origin
	Set metadata.IPMDeployed = pModule.Deployed
	Set metadata.IPMModuleV1XML = moduleXML
	Do metadata.%JSONExportToString(.metaDataString)

    #; Push file
	Set status = ..Push(..Location, repo, ..Namespace, tempDirectory, tag, metaDataString, ..Username, ..Password, ..Token, ..TokenBasicAuth)
	$$$ThrowOnError(status)

    Return 1
}

Method CheckUnpublishEnabled(packageName As %String, packageVersion As %String) As %Boolean
{
	// TODO improve
	Return 1
}

Method Unpublish(packageName As %String, packageVersion As %String) As %Status
{
	If packageVersion = "all" {
		Do ..DeleteModule(..Location, packageName, ..Namespace, ..Username, ..Password, ..Token, ..TokenBasicAuth)
	} Else {
		Do ..DeleteTagsPy(..Location, packageName, ..Namespace, packageVersion, ..Username, ..Password, ..Token, ..TokenBasicAuth)
	}
	Return $$$OK
}

/// Pushes the files as an artifact with the given name and tag(s) as versions
/// Existing tags will be overwritten
/// Params:
/// 	repository - string name of repository to push to, e.g. test-artifact
/// 	tags       - comma separated strings of tags, e.g. "1.0.0,latest"
ClassMethod Push(registry As %String, repository As %String, namespace As %String, path As %String, tags As %String, metadata As %String, username As %String, password As %String, token As %String, tokenBasicAuth As %Boolean)
{
	#; Remove the tag from the repository name if it exists and add it to tags
	Set repo = $piece(repository, ":", 1)
	Set tag = $piece(repository, ":", 2)
	If tag '= "" { Set tags = tags _ "," _ tag }
	If tags = "" {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Must specify version."))
	}

	#; Remove whitespace from tags
	Set tags = $zstrip(tags,"*W")

	Try {
		Do ..PushPy(registry, repo, namespace, tags, path, metadata, username, password, token, tokenBasicAuth)
	} Catch sc {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Unable to push: " _ sc.DisplayString()))
	}
    Return $$$OK
}

/// Publishes/pushes the package using ORAS
ClassMethod PushPy(registry As %String, repository As %String, namespace As %String, tags As %String, directoryPath As %String, metadata As %String, username As %String, password As %String, token As %String, tokenBasicAuth As %Boolean) [ Language = python ]
{
	import iris
	import os, sys
	import json

	# Get all files in the directory and fully specify path
	files = os.listdir(directoryPath)
	result = map(lambda x: directoryPath + x, files)
	file_paths = list(result)

	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenBasicAuth)

	# Push once for each tag
	for tag in tags.split(","):
		if tag == "":
			continue

		# Annotations are manifest.xml and other metadata
		manifest_annotations = json.loads(metadata)

        # Suppress console output
		sys.stdout = open(os.devnull, "w")

		target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace) + ":" + tag

		try:
			res = client.push(files=file_paths, target=target, disable_path_validation=True, manifest_annotations=manifest_annotations)
		except Exception as e:
			print("Error: ", repr(e))
			raise e

		# Reenable console output
		sys.stdout = sys.__stdout__
}

/// Deletes the specified tags from the module
ClassMethod DeleteTagsPy(registry As %String, repository As %String, namespace As %String, tags As %String, username As %String, password As %String, token As %String, tokenBasicAuth As %Boolean) [ Language = python ]
{
	import iris

	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace)
	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token, tokenBasicAuth)

	# remove whitespace and convert to a list
	if isinstance(tags, str):
		tags = tags.replace(" ","").split(",")
	for tag in tags:
		client.delete_tag(target,tag)
}

/// Deletes the module by deleting all tags
ClassMethod DeleteModule(registry As %String, repository As %String, namespace As %String, username As %String, password As %String, token As %String, tokenBasicAuth As %Boolean)
{
	set target = ##class(%IPM.Repo.Oras.PackageService).GetAPITarget(registry, repository, namespace)
	set client = ##class(%IPM.Repo.Oras.PackageService).GetClient(registry, username, password, token, tokenBasicAuth)
	try {
		set tags = client."get_tags"(target)
		do ..DeleteTagsPy(registry, repository, namespace, tags, username, password, token, tokenBasicAuth)
	} Catch sc {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to delete: " _ sc.DisplayString()))
	}
}

}
