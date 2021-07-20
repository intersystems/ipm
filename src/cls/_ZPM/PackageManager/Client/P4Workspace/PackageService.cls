Class %ZPM.PackageManager.Client.P4Workspace.PackageService Extends %ZPM.PackageManager.Client.Filesystem.PackageService
{

Property P4Workspace As %ZPM.PackageManager.Client.P4Workspace;

Property FileSpec As %String [ ReadOnly ];

Property Available As %Boolean [ Private ];

Method %OnNew(pRoot As %String, pFileSpec As %String) As %Status [ Private, ServerOnly = 1 ]
{
	Set i%Root = pRoot
	Set i%FileSpec = $Case(pFileSpec,"":"#head",:pFileSpec)
	Quit $$$OK
}

ClassMethod CreateForWorkspace(pWorkspace As %ZPM.PackageManager.Client.P4Workspace) As %ZPM.PackageManager.Client.P4Workspace.PackageService
{
	If (pWorkspace.Root = "") {
		Quit $$$NULLOREF
	}
	Set tInstance = ..%New(pWorkspace.Root,pWorkspace.FileSpec)
	Set tInstance.P4Workspace = pWorkspace
	Quit tInstance
}

Method GetModuleDirectory(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %String
{
	// Get the module ...
	Set tModule = ##class(%ZPM.PackageManager.Client.Filesystem.Cache).RootNameVersionOpen(..Root,pModuleReference.Name,pModuleReference.VersionString,,.tStatus)
	$$$ThrowOnError(tStatus)
	
	// Trailing dots are needed for Perforce sync to work
	Set tDepotPath = ..Root_tModule.SubDirectory_"..."
	
	If ..PerforceIsAvailable() {
		// ... do a p4 sync ...
		Set tSC = ##class(%Studio.SourceControl.ISC).RunCmd("p4 sync "_tDepotPath_..FileSpec,0)
		If $$$ISERR(tSC) {
			Set tErrorText = $System.Status.GetErrorText(tSC)
			If (tErrorText [ "no such file(s)") { // Indicating that the module is not yet checked in.
				Set tSC = $$$OK
			} ElseIf (tErrorText [ "file(s) up-to-date") {
				Set tSC = $$$OK
			} Else {
				$$$ThrowStatus(tSC)
			}
		}
	
		// ... find the workspace path ...
		Set tSrcPath = ..GetLocalPathFromDepotPath(tDepotPath)
		
	} ElseIf $IsObject(..P4Workspace) {
		$$$ThrowOnError(..P4Workspace.ClientSpec.GetLocalPathForDepot(tDepotPath,.tSrcPath))
	}
	
	// Remove trailing dots
	Set tSrcPath = ##class(%Library.File).GetDirectory(tSrcPath)
	If (tSrcPath = "") {
		$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Filesystem path for module %1 not found.",pModuleReference.Name_" "_pModuleReference.VersionString)))
	}
	
	Quit tSrcPath
}

ClassMethod GetLocalPathFromDepotPath(pDepotPath As %String) As %String
{
	Set json = ..GetP4WhereOutput(pDepotPath)
	Return json.%Get("local_path")
}

ClassMethod GetDepotPathFromLocalPath(pLocalPath As %String) As %String
{
	Set json = ..GetP4WhereOutput(pLocalPath)
	Return json.%Get("depot_path")
}

ClassMethod GetP4WhereOutput(pPath As %String) As %Library.DynamicObject [ Internal ]
{
	Set sc = ##class(%Studio.SourceControl.ISC).P4Cmd("where "_pPath, .output)
	$$$ThrowOnError(sc)
	
	#dim result As %Library.DynamicObject
	Set result = {}
	For i=1:1:$Get(output) {
		// Skip if unmapped (this can occur due to custom workspace mappings)
		If $Data(output(i, "unmap"))#2 {
			Continue
		}
		// Found a match that is unmapped. Use this rather than subsequent workspace
		// mappings because this is an exact match to the provided path.
		Do result.%Set("local_path", $Get(output(i, "path")))
		Do result.%Set("depot_path", $Get(output(i, "depotFile")))
		Do result.%Set("client_path", $Get(output(i, "clientFile")))
		Quit
	}
	Return result
}

Method GetModule(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference, Output AsArchive As %Boolean = 1) As %Stream.Object
{
  Set AsArchive = 1
	// Get the path (includes syncing)...
	Set tSrcPath = ..GetModuleDirectory(pModuleReference)
	
	// ... and tgz it.
	Set tTempFileName = ##class(%File).TempFilename("tgz")
	$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Archive).Create(tSrcPath,tTempFileName))
	
	Set tFileBinStream = ##class(%Stream.FileBinary).%New()
	$$$ThrowOnError(tFileBinStream.LinkToFile(tTempFileName))
	
	Quit tFileBinStream
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
/// Always returns true, although also checks to see whether Perforce or the local filesystem should be used.
Method IsAvailable() As %Boolean
{
	#dim %SourceControl As %Studio.Extension.Base
	New %SourceControl
	
	// Optimization: check once per instance.
	// (checking may be slow.)
	If (..Available '= "") {
		Quit 1
	}
	
	Set ..Available = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC).GetPerforceAvailable()
	
	// Always available; ..Available used internally to toggle use of Perforce/not.
	Quit 1
}

Method PerforceIsAvailable() As %Boolean
{
	If (..Available = "") {
		// Check Perforce status.
		Do ..IsAvailable()
	}
	Quit ..Available
}

/// Attempts to determine if <var>pSC</var> occurred due to Perforce becoming unavailable.
/// Returns $$$OK if Perforce was available previously and no longer is, and <var>pSC</var> otherwise.
Method HandlePerforceError(pSC As %Status) As %Status
{
	Set tWasAvailable = ..PerforceIsAvailable()
	If 'tWasAvailable {
		// If we got a Perforce error and Perforce wasn't available to start with, it's a fatal error.
		Quit pSC
	}
	
	// Clear status and re-check Perforce availability.
	Set ..Available = ""
	Do ..IsAvailable()
	If '..Available {
		// Perforce is no longer available.
		Quit $$$OK
	}
	
	// Perforce is still available - something else went wrong.
	Quit pSC
}

}
