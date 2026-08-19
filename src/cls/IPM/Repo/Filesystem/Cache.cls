Include %occErrors

Class %IPM.Repo.Filesystem.Cache Extends (%Persistent, %IPM.General.ModuleInfo)
{

Parameter DEFAULTGLOBAL = "^IPM.Repo.Filesystem.Cache";

/// Uniqueness constraint only: one cache entry per directory under a given root.
Index CacheItemIndex On (Root, SubDirectoryHash) [ Unique ];

Property Root As %String(MAXLEN = 260) [ Required ];

ForeignKey RootFK(Root) References %IPM.Repo.Filesystem.Definition(RootIndex) [ OnDelete = cascade ];

Property SubDirectory As %String(MAXLEN = "");

/// SHA-1 of SubDirectory as uppercase hex, giving the unique index a fixed 40-character subscript.
/// SubDirectory itself cannot be one: a path can exceed the combined subscript budget, and %String's
/// SQLUPPER collation reports "mods/Foo" and "mods/foo" as the same key when they are two directories.
Property SubDirectoryHash As %String(MAXLEN = 40) [ Required, SqlComputeCode = {set {*} = ##class(%IPM.Repo.Filesystem.Cache).PathHash({SubDirectory})}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE, SubDirectory) ];

Property LastModified As %TimeStamp [ Required ];

/// SHA-1 content hash (lowercase hex) of the module.xml file this entry was built from.
/// Content, not modification time: mtime is unreliable across container bind mounts, where it can
/// be coarse, stale, or never propagate at all.
Property ContentHash As %String(MAXLEN = 40);

/// Indicates if full manifest has been populated (deferred loading optimization).
/// When 0: Only metadata (Name, Version) is cached; Manifest stream is empty.
/// When 1: Full <Module> XML has been loaded into Manifest property.
/// Use LoadManifestForCacheEntry() to populate on-demand when needed.
Property ManifestLoaded As %Boolean [ InitialExpression = 0 ];

/// Full module manifest
Property Manifest As %Stream.GlobalCharacter;

Index SemVer On (Name, Version) As %IPM.General.SemanticVersion.Index;

/// Property associated with the index to allow quick $Query'ing over SemVer order based on ID
Property SemVer As %String(MAXLEN = 512) [ SqlComputeCode = {set {*} = ##class(%IPM.Repo.Filesystem.Cache).SemVerNode({Name},{Version})}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

Index RootNameVersion On (Root, Name, VersionString) [ Unique ];

ClassMethod PathHash(subDirectory As %String) As %String [ CodeMode = expression ]
{
##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHA1Hash(subDirectory))
}

ClassMethod %OnBeforeBuildIndices(ByRef indexlist As %String(MAXLEN="") = "") As %Status [ Private, ServerOnly = 1 ]
{
    if (indexlist [ "SemVer") || (indexlist = "") {
        // Force recomputation of SemVer property if index needs to be rebuilt (i.e., because structure has changed)
        set tRes = ##class(%SQL.Statement).%ExecDirect(,"update %IPM_Repo_Filesystem.Cache set SemVer = ''")
        if tRes.%SQLCODE < 0 {
            quit $$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message)
        }
    }
    quit $$$OK
}

Query OrderedMatches(
	pRoot As %String = "",
	pName As %String = "",
	pVersionExpression As %String = "*",
	pParameters As %String = "") As %Query(ROWSPEC = "Name:%String,VersionString:%String,Version_Major:%String,Version_Minor:%String,Version_Patch:%String,Version_Prerelease:%String,Version_Build:%String") [ SqlProc ]
{
}

ClassMethod OrderedMatchesExecute(
	ByRef qHandle As %Binary,
	pRoot As %String = "",
	pName As %String = "",
	pVersionExpression As %String = "*",
	pParameters As %String = "") As %Status
{
    set tSC = ##class(%IPM.General.SemanticVersion.Find).MatchesExecute(.qHandle,$classname(),"SemVer",..SemVerIndexLocation(),pName,pVersionExpression,pParameters)
    set qHandle("root") = pRoot
    quit tSC
}

ClassMethod OrderedMatchesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = OrderedMatchesExecute ]
{
    quit ##class(%IPM.General.SemanticVersion.Find).MatchesClose(.qHandle)
}

ClassMethod OrderedMatchesFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = OrderedMatchesExecute ]
{
    for {
        set tSC = ##class(%IPM.General.SemanticVersion.Find).MatchesFetch(.qHandle,.tRow,.AtEnd)
        if AtEnd {
            quit
        }
        set tRoot = ..RootGetStored($listget(tRow))
        if (tRoot = qHandle("root")) {
            set Row = $listbuild(..NameGetStored($listget(tRow)),..VersionStringGetStored($listget(tRow)))_..VersionGetStored($listget(tRow))
            quit
        }
    }
    quit tSC
}

Method HandleSaveError(pSC As %Status) As %Status
{
    set tSC = pSC
    try {
        if $system.Status.Equals(pSC,$$$ERRORCODE($$$KeyNotUnique)) {
            $$$ThrowOnError($system.Status.DecomposeStatus(pSC,.tStatusInfo))

            // Which key?
            set tErrorParam = tStatusInfo(1,"param",1)
            set tClass = $piece(tErrorParam,":",1)
            set tKey = $piece(tErrorParam,":",2)
            if (tClass = $classname()) && (tKey = "RootNameVersion") {
                // Find the existing instance with matching RootNameVersion
                set tOtherInstance = ..RootNameVersionOpen(..Root,..Name,..VersionString,,.tSC)
                $$$ThrowOnError(tSC)

                // Log a descriptive error message
                set tDupeDir = ..Root_..SubDirectory
                set tUseDir = tOtherInstance.Root_tOtherInstance.SubDirectory
                set tMessage = ..Name_" "_..VersionString_" previously found in "_tUseDir_"; also found in "_tDupeDir_". The version in "_tUseDir_" will be used."
                do ##class(%IPM.General.LogManager).Warning(tMessage,1)

                // Treat this as a non-error
                set tSC = $$$OK
            }
        }
    } catch e {
        set tSC = $$$ADDSC(pSC,e.AsStatus())
    }
    quit tSC
}

/// Open a cache entry and validate it against the filesystem
/// If the cached entry is stale (ContentHash differs from the hash of the module.xml on disk),
/// re-parse the module.xml and update the cache entry
/// Returns the cache object (possibly refreshed) or throws error if not found
ClassMethod RootNameVersionOpenValidated(
	root As %String,
	name As %String,
	versionString As %String,
	concurrency As %Integer = -1,
	Output status As %Status) As %IPM.Repo.Filesystem.Cache
{
    set status = $$$OK
    set cacheObj = ""

    try {
        // Open the cache entry
        set cacheObj = ..RootNameVersionOpen(root, name, versionString, concurrency, .status)
        if $$$ISERR(status) {
            quit
        }

        set dirPath = ##class(%File).NormalizeFilename(cacheObj.SubDirectory, cacheObj.Root)
        set filePath = ##class(%File).NormalizeFilename("module.xml", dirPath)
        if '##class(%File).Exists(filePath) {
            // Report it but leave the row alone. The absence may be transient, such as a source
            // control sync in flight or an unmounted share. Pruning belongs to CleanupStaleEntries,
            // which only runs after a full walk has established the file is really gone.
            set cacheObj = ""
            set status = $$$ERROR($$$GeneralError, "module.xml not found in " _ dirPath)
            quit
        }

        // Compare the cached content hash with the file on disk. An entry written before
        // ContentHash existed holds an empty value, so this comparison also upgrades old rows on
        // their first validated open.
        set currentHash = $$$lcase(##class(%File).SHA1Hash(filePath, 1))
        if (cacheObj.ContentHash '= currentHash) {
            do ##class(%IPM.Repo.Filesystem.Definition).RefreshCacheEntry(cacheObj, filePath, currentHash)

            // The re-parse can change Name or Version, so the entry may no longer be the module that
            // was asked for. Returning it would install something other than what the caller resolved.
            // Re-check through the index rather than comparing properties, so the same key semantics
            // apply on both sides of the comparison as on the original lookup.
            if '..RootNameVersionExists(root, name, versionString, .stillId) || (stillId '= cacheObj.%Id()) {
                set message = filePath_" now describes "_cacheObj.Name_" "_cacheObj.VersionString_", not "_name_" "_versionString
                set cacheObj = ""
                set status = $$$ERROR($$$GeneralError, message)
                quit
            }
        }
    } catch ex {
        set status = ex.AsStatus()
        set cacheObj = ""
    }

    quit cacheObj
}

Storage Default
{
<Data name="CacheDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Root</Value>
</Value>
<Value name="3">
<Value>SubDirectory</Value>
</Value>
<Value name="4">
<Value>Name</Value>
</Value>
<Value name="5">
<Value>Version</Value>
</Value>
<Value name="6">
<Value>VersionString</Value>
</Value>
<Value name="7">
<Value>LastModified</Value>
</Value>
<Value name="8">
<Value>Manifest</Value>
</Value>
<Value name="9">
<Value>SemVer</Value>
</Value>
<Value name="10">
<Value>Description</Value>
</Value>
<Value name="11">
<Value>Repository</Value>
</Value>
<Value name="12">
<Value>AllVersions</Value>
</Value>
<Value name="13">
<Value>Origin</Value>
</Value>
<Value name="14">
<Value>Deployed</Value>
</Value>
<Value name="15">
<Value>PlatformVersion</Value>
</Value>
<Value name="16">
<Value>DisplayName</Value>
</Value>
<Value name="17">
<Value>ContentHash</Value>
</Value>
<Value name="18">
<Value>ManifestLoaded</Value>
</Value>
<Value name="19">
<Value>SubDirectoryHash</Value>
</Value>
</Data>
<DataLocation>^IPM.Repo.Filesystem.CacheD</DataLocation>
<DefaultData>CacheDefaultData</DefaultData>
<IdLocation>^IPM.Repo.Filesystem.CacheD</IdLocation>
<IndexLocation>^IPM.Repo.Filesystem.CacheI</IndexLocation>
<StreamLocation>^IPM.Repo.Filesystem.CacheS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
