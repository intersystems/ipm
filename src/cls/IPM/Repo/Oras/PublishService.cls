Include %IPM.Common

Class %IPM.Repo.Oras.PublishService Extends (%IPM.Repo.Oras.PackageService, %IPM.Repo.IPublishService)
{

Method PublishModule(pModule As %IPM.Repo.Remote.ModuleInfo) As %Status
{
	Set status = $$$OK
    Try {
		Set repo = pModule.Name
		Set tag = $$$Semver2Tag(pModule.VersionString)

		#; Use a temp directory
		Set tDir = $$$FileTempDir
		If tDir = ("-" _ -tDir) { // $zu(140,17) can return a negative number if it fails
			Throw ##class(%Exception.General).%New("Failed to create temporary directory. Error code: " _ -tDir)
		}
		Set tempDirectory = ##class(%File).NormalizeDirectory(tDir _ "/" _ repo _ "/" _ tag _ "/")

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
		Set metadata.IPMPlatformVersion = pModule.PlatformVersion
		Set metadata.IPMModuleV1XML = moduleXML
		Do metadata.%JSONExportToString(.metaDataString)

		#; Push file
		$$$ThrowOnError(..Push(..Location, repo, ..Namespace, tempDirectory, tag, metaDataString, ..Username, ..Password, ..Token, ..TokenAuthMethod))
	} catch ex {
		Set status = ex.AsStatus()
	}
	// Clean up temp directory whether successful or not
    If ($Data(tempDirectory) # 2) && ##class(%File).DirectoryExists(tempDirectory) {
        Set tSC = ##class(%IPM.Utils.File).RemoveDirectoryTree(tempDirectory)
		Set status = $$$ADDSC(status, tSC)
    }

    Return status
}

Method CheckUnpublishEnabled(packageName As %String, packageVersion As %String) As %Boolean
{
	// TODO improve
	Return 1
}

Method Unpublish(packageName As %String, packageVersion As %String) As %Status
{
	If packageVersion = "all" {
		Do ..DeleteModule(..Location, packageName, ..Namespace, ..Username, ..Password, ..Token, ..TokenAuthMethod)
	} Else {
		Do ..DeleteTagsPy(..Location, packageName, ..Namespace, packageVersion, ..Username, ..Password, ..Token, ..TokenAuthMethod)
	}
	Return $$$OK
}

/// Pushes the files as an artifact with the given name and tag(s) as versions
/// Existing tags will be overwritten
/// Params:
/// 	package - string name of package to push to, e.g. test-artifact
/// 	tags    - comma separated strings of tags, e.g. "1.0.0,latest"
ClassMethod Push(registry As %String, package As %String, namespace As %String, path As %String, tags As %String, metadata As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String)
{
	#; Remove the tag from the package name if it exists and add it to tags
	Set repo = $piece(package, ":", 1)
	Set tag = $$$Semver2Tag($piece(package, ":", 2))
	If tag '= "" { Set tags = tags _ "," _ tag }
	If tags = "" {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Must specify version."))
	}

	#; Remove whitespace from tags
	Set tags = $zstrip(tags,"*W")

	Try {
		Do ..PushPy(registry, repo, namespace, tags, path, metadata, username, password, token, tokenAuthMethod)
	} Catch sc {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Unable to push: " _ sc.DisplayString()))
	}
    Return $$$OK
}

/// Publishes/pushes the package using ORAS
ClassMethod PushPy(registry As %String, package As %String, namespace As %String, tags As %String, directoryPath As %String, metadata As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String) [ Language = python ]
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
ClassMethod DeleteTagsPy(registry As %String, package As %String, namespace As %String, tags As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String) [ Language = python ]
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
ClassMethod DeleteModule(registry As %String, package As %String, namespace As %String, username As %String, password As %String, token As %String, tokenAuthMethod As %String)
{
	set target = ##class(%IPM.Repo.Oras.PackageService).GetAPITarget(registry, package, namespace)
	set client = ##class(%IPM.Repo.Oras.PackageService).GetClient(registry, username, password, token, tokenAuthMethod)
	try {
		set tags = client."get_tags"(target)
		do ..DeleteTagsPy(registry, package, namespace, tags, username, password, token, tokenAuthMethod)
	} Catch sc {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to delete: " _ sc.DisplayString()))
	}
}

}
