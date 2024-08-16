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
	Set metadata."org-opencontainers-image-title" = pModule.Name
	Set metadata."org-opencontainers-image-description" = pModule.Description
	Set metadata."org-opencontainers-image-version" = pModule.VersionString
	Set metadata."org-opencontainers-image-source" = pModule.Repository
	Set metadata."org-opencontainers-image-created" = $zdt($now(),3,2)
	Set metadata."com-intersystems-ipm-allVersions" = pModule.AllVersions
	Set metadata."com-intersystems-ipm-origin" = pModule.Origin
	Set metadata."com-intersystems-ipm-deployed" = pModule.Deployed
	Set metadata."com-intersystems-ipm-module-v1+xml" = moduleXML
	Do metadata.%JSONExportToString(.metaDataString)

    #; Push file
	Set client = ##class(%IPM.Repo.Oras.PackageService).GetClient(..Location, ..Username, ..Password, ..Token)
	Set status = ..Push(..Location, repo, ..Namespace, tempDirectory, tag, metaDataString, client)
	$$$ThrowOnError(status)
	
	#; Sign the package
	Do ..SignPackage(..Location, repo, ..Namespace, tag, tFileBinStream.Filename, client)

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
		Do ..DeleteModule(..Location, packageName, ..Namespace, ..Username, ..Password, ..Token)
	} Else {
		Do ..DeleteTagsPy(..Location, packageName, ..Namespace, packageVersion, ..Username, ..Password, ..Token)
	}
	Return $$$OK
}

/// Pushes the files as an artifact with the given name and tag(s) as versions
/// Existing tags will be overwritten
/// Params:
/// 	repository - string name of repository to push to, e.g. test-artifact
/// 	tags       - comma separated strings of tags, e.g. "1.0.0,latest"
ClassMethod Push(registry As %String, repository As %String, namespace As %String, path As %String, tags As %String, metadata As %String, client)
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
		Do ..PushPy(registry, repo, namespace, tags, path, metadata, client)
	} Catch sc {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Unable to push: " _ sc.DisplayString()))
	}
    Return $$$OK
}

/// Publishes/pushes the package using ORAS
ClassMethod PushPy(registry As %String, repository As %String, namespace As %String, tags As %String, directoryPath As %String, metadata As %String, client) [ Language = python ]
{
	import iris
	import os
	import sys
	import json

	# Get all files in the directory and fully specify path
	files = os.listdir(directoryPath)
	result = map(lambda x: directoryPath + x, files)
	file_paths = list(result)

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
ClassMethod DeleteTagsPy(registry As %String, repository As %String, namespace As %String, tags As %String, username As %String, password As %String, token As %String) [ Language = python ]
{
	import iris

	target = iris.cls("%IPM.Repo.Oras.PackageService").GetAPITarget(registry, repository, namespace)
	client = iris.cls("%IPM.Repo.Oras.PackageService").GetClient(registry, username, password, token)

	# remove whitespace and convert to a list
	if isinstance(tags, str):
		tags = tags.replace(" ","").split(",")
	for tag in tags:
		client.delete_tag(target,tag)
}

/// Deletes the module by deleting all tags
ClassMethod DeleteModule(registry As %String, repository As %String, namespace As %String, username As %String, password As %String, token As %String)
{
	Set target = ##class(%IPM.Repo.Oras.PackageService).GetAPITarget(registry, repository, namespace)
	Set client = ##class(%IPM.Repo.Oras.PackageService).GetClient(registry, username, password, token)
	Try {
		Set tags = client."get_tags"(target)
		Do ..DeleteTagsPy(registry, repository, namespace, tags, username, password, token)
	} Catch sc {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to delete: " _ sc.DisplayString()))
	}
}

ClassMethod SignPackage(registry, repository, namespace, tag, filePath, client)
{
	#; Generate signature
	Set signature = ..SignFileWithCert(filePath)

	#; Save signature in temp directory
    Set tFileStream = ##class(%Stream.FileCharacter).%New()
    Set tFileStream.Filename = ##class(%File).TempFilename("signature", $$$FileTempDir, .return)
    Do tFileStream.Write(signature)
	Do tFileStream.%Save()

	#; Attach to repo
	Set target = ##class(%IPM.Repo.Oras.PackageService).GetAPITarget(registry, repository, namespace)
	Do ..Attach(target, tag, tFileStream.Filename, client)
}

/// Signs the given file with the given private key (and certificate)
/// Returns string of the signed file and certificate intended for IPM use only
/// Params:
/// 	certKeyFile - a PEM file with a certificate and private key
ClassMethod SignFileWithCert(filePath, certKeyFile = "/tmp/cert_and_key.pem") [ Language = python ]
{
	from cryptography.hazmat.primitives import serialization, hashes
	from cryptography.hazmat.primitives.asymmetric import padding

	with open(certKeyFile, "rb") as cert_file:
		cert_contents = cert_file.read()
		private_key = serialization.load_pem_private_key(
			cert_contents,
			password=None,
		)
	with open(certKeyFile, "r") as cert_file:
		cert_contents = cert_file.read()
		start = cert_contents.find('-----BEGIN CERTIFICATE-----\n')
		end = cert_contents.find('\n-----END CERTIFICATE-----')
		certificate = cert_contents[start + len('-----BEGIN CERTIFICATE-----\n'):end]
	public_key = private_key.public_key()

	# read contents of file and sign
	with open(filePath, "rb") as package_file:
		contents = package_file.read()

	signature = private_key.sign(
		contents,
		padding.PSS(
			mgf=padding.MGF1(hashes.SHA256()),
			salt_length=padding.PSS.MAX_LENGTH
		),
		hashes.SHA256()
	)
	
	#; write out contents of the signed package and certificate (containing the public key)
	output = 'signature:\n'
	output += signature.hex()
	output += '\ncertificate:\n'
	output += certificate
	return output
}

ClassMethod Attach(target, tag, filePath, client) [ Language = python ]
{
	import oras
	import os
	import sys

	# attach module.xml
	try:
		manifest = client.get_manifest(target + ":" + tag)
		subject = oras.oci.Subject.from_manifest(manifest)
		
		# todo figure out how to make a tagless attachment
		module_xml_target = target + ":" + tag + "-signature"

        # Suppress console output
		sys.stdout = open(os.devnull, "w")

		client.push(files=[filePath], target=module_xml_target, subject=subject, disable_path_validation=True)
		
		# Reenable console output
		sys.stdout = sys.__stdout__
	except Exception as e:
		print("Error: ", repr(e))
		raise e
}

}
