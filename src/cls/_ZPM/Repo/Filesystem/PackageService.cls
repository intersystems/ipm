Class %ZPM.Repo.Filesystem.PackageService Extends (%RegisteredObject, %ZPM.Repo.IPackageService, %ZPM.PackageManager.Core.ModuleInfo.QueryUtils)
{

Property Root As %String [ Private, ReadOnly ];

Method %OnNew(pRoot As %String) As %Status [ Private, ServerOnly = 1 ]
{
	Set i%Root = pRoot
	Quit $$$OK
}

Method ListModules(pSearchCriteria As %ZPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.ResolvedModuleReference")
{
	Set tList = ##class(%Library.ListOfObjects).%New()
	Set tQuery = "select Name,VersionString from %ZPM_Repo_Filesystem.Cache_OrderedMatches(?,?,?,?) m"
	Set tArgs($i(tArgs)) = ..Root
	Quit ..moduleSqlToList(tQuery,.pSearchCriteria,.tArgs)
}

Method HasModule(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Boolean
{
	Quit ##class(%ZPM.Repo.Filesystem.Cache).RootNameVersionExists(..Root,pModuleReference.Name,pModuleReference.VersionString)
}

Method GetModuleManifest(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Stream.Object
{
	Set tModule = ##class(%ZPM.Repo.Filesystem.Cache).RootNameVersionOpen(..Root,pModuleReference.Name,pModuleReference.VersionString,,.tStatus)
	$$$ThrowOnError(tStatus)
	Quit tModule.Manifest
}

Method GetModule(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference, Output AsArchive As %Boolean = 1) As %Stream.Object
{
  Set AsArchive = 1
	// ... and tgz it!
	Set tTempFileName = ##class(%File).TempFilename("tgz")
	Set tSrcPath = ..GetModuleDirectory(pModuleReference)
	$$$ThrowOnError(##class(%ZPM.General.Archive).Create(tSrcPath,tTempFileName))
	
	Set tFileBinStream = ##class(%Stream.FileBinary).%New()
	$$$ThrowOnError(tFileBinStream.LinkToFile(tTempFileName))
	
	Quit tFileBinStream
}

Method GetModuleDirectory(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %String
{
	// Get the module ...
	Set tModule = ##class(%ZPM.Repo.Filesystem.Cache).RootNameVersionOpen(..Root,pModuleReference.Name,pModuleReference.VersionString,,.tStatus)
	$$$ThrowOnError(tStatus)
	
	Quit ##class(%File).NormalizeDirectory(tModule.Root_tModule.SubDirectory)
}

Method GetApplication(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Stream.Object
{
	Quit $$$NULLOREF
}

Method GetApplicationManifest(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Stream.Object
{
	Quit $$$NULLOREF
}

Method HasApplication(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Boolean
{
	Quit 0
}

Method ListApplications(pSearchCriteria As %ZPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.ResolvedModuleReference")
{
	Quit ##class(%Library.ListOfObjects).%New()
}

/// Returns 1 if the service supports a particular method.
ClassMethod Supports(pMethod As %String) As %Boolean
{
	// Filesystem package service only supports module packaging for now.
	Quit '(pMethod [ "Application")
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
	Quit ##class(%File).DirectoryExists(..Root)
}

}
