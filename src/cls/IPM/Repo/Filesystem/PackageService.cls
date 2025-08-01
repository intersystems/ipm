Class %IPM.Repo.Filesystem.PackageService Extends (%RegisteredObject, %IPM.Repo.IPackageService)
{

Property Root As %String [ Private, ReadOnly ];

Method %OnNew(pRoot As %String) As %Status [ Private, ServerOnly = 1 ]
{
    set i%Root = pRoot
    quit $$$OK
}

Method ListModules(pSearchCriteria As %IPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%IPM.Storage.ModuleInfo")
{
    set tList = ##class(%Library.ListOfObjects).%New()
    set tQuery = "select Name,VersionString from %IPM_Repo_Filesystem.Cache_OrderedMatches(?,?,?,?) m"
    set tArgs($increment(tArgs)) = ..Root
    quit ##class(%IPM.Repo.Utils).moduleSqlToList(tQuery,.pSearchCriteria,.tArgs)
}

Method HasModule(pModuleReference As %IPM.Storage.ModuleInfo) As %Boolean
{
    quit ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionExists(..Root,pModuleReference.Name,pModuleReference.VersionString)
}

Method GetModuleManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
    set tModule = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..Root,pModuleReference.Name,pModuleReference.VersionString,,.tStatus)
    $$$ThrowOnError(tStatus)
    quit tModule.Manifest
}

Method GetModule(
	pModuleReference As %IPM.Storage.ModuleInfo,
	Output AsArchive As %Boolean = 1) As %Stream.Object
{
    set AsArchive = 1
    // ... and tgz it!
    set tTempFileName = ##class(%File).TempFilename("tgz")
    set tSrcPath = ..GetModuleDirectory(pModuleReference)
    $$$ThrowOnError(##class(%IPM.General.Archive).Create(tSrcPath,tTempFileName))

    set tFileBinStream = ##class(%Stream.FileBinary).%New()
    $$$ThrowOnError(tFileBinStream.LinkToFile(tTempFileName))

    quit tFileBinStream
}

Method GetModuleDirectory(pModuleReference As %IPM.Storage.ModuleInfo) As %String
{
    // Get the module ...
    set tModule = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..Root,pModuleReference.Name,pModuleReference.VersionString,,.tStatus)
    $$$ThrowOnError(tStatus)

    quit ##class(%File).NormalizeDirectory(tModule.Root_tModule.SubDirectory)
}

/// Returns 1 if the service supports a particular method.
ClassMethod Supports(pMethod As %String) As %Boolean
{
    // Returns 1 as no need to check for application stuff
    quit 1
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
    quit ##class(%File).DirectoryExists(..Root)
}

}
