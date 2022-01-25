Class %ZPM.Repo.Filesystem.PackageService Extends (%RegisteredObject, %ZPM.Repo.IPackageService)
{

Property Root As %String [ Private, ReadOnly ];

Method %OnNew(pRoot As %String) As %Status [ Private, ServerOnly = 1 ]
{
	Set i%Root = pRoot
	Quit $$$OK
}

Method ListModules(pSearchCriteria As %ZPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%ZPM.Storage.ModuleInfo")
{
	Set tList = ##class(%Library.ListOfObjects).%New()
	Set tQuery = "select Name,VersionString from %ZPM_Repo_Filesystem.Cache_OrderedMatches(?,?,?,?) m"
	Set tArgs($i(tArgs)) = ..Root
	Quit ##class(%ZPM.Repo.Utils).moduleSqlToList(tQuery,.pSearchCriteria,.tArgs)
}

Method HasModule(pModuleReference As %ZPM.Storage.ModuleInfo) As %Boolean
{
	Quit ##class(%ZPM.Repo.Filesystem.Cache).RootNameVersionExists(..Root,pModuleReference.Name,pModuleReference.VersionString)
}

Method GetModuleManifest(pModuleReference As %ZPM.Storage.ModuleInfo) As %Stream.Object
{
	Set tModule = ##class(%ZPM.Repo.Filesystem.Cache).RootNameVersionOpen(..Root,pModuleReference.Name,pModuleReference.VersionString,,.tStatus)
	$$$ThrowOnError(tStatus)
	Quit tModule.Manifest
}

Method GetModule(pModuleReference As %ZPM.Storage.ModuleInfo, Output AsArchive As %Boolean = 1) As %Stream.Object
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

Method GetModuleDirectory(pModuleReference As %ZPM.Storage.ModuleInfo) As %String
{
	// Get the module ...
	Set tModule = ##class(%ZPM.Repo.Filesystem.Cache).RootNameVersionOpen(..Root,pModuleReference.Name,pModuleReference.VersionString,,.tStatus)
	$$$ThrowOnError(tStatus)
	
	Quit ##class(%File).NormalizeDirectory(tModule.Root_tModule.SubDirectory)
}

/// Returns 1 if the service supports a particular method.
ClassMethod Supports(pMethod As %String) As %Boolean
{
	// Returns 1 as no need to check for application stuff
	Quit 1
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
	Quit ##class(%File).DirectoryExists(..Root)
}

}
