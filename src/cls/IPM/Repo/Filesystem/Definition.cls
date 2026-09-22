Class %IPM.Repo.Filesystem.Definition Extends %IPM.Repo.Definition
{

Parameter DISPLAYNAME As STRING = "Filesystem";

Parameter MONIKER As STRING = "filesystem";

Parameter MONIKERALIAS As STRING = "f,fs";

Index RootIndex On Root [ Unique ];

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {set {*} = {Root}_$case({Depth},0:"*",:$replace($justify(" ",{Depth}*2),"  ",$select($$$isWINDOWS:"*\",1:"*/"))_"module.xml")}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

/// Root folder on the server filesystem
Property Root As %String(MAXLEN = 260) [ Required ];

/// How many levels of depth to search for module.xml files; 0 indicates unlimited.
Property Depth As %Integer [ InitialExpression = 0, Required ];

/// Timestamp of last cache rebuild for this repository
Property CacheLastRebuilt As %TimeStamp;

/// Prompt to use for Root in interactive configuration of this repository type
Parameter RootPromptString = {$$$Text("Root File Path:","ZPM")};

XData Commands
{
<commands>
<command name="repo">
<group name="Filesystem repository">

<modifier name="filesystem" aliases="f,fs" description="Create/update a filesystem repository" />
<modifier name="depth" aliases="d" value="true" description="For filesystem repositories, specifies the depth (number of folders underneath the root) to search for files named module.xml" />
<modifier name="path" aliases="p" value="true" description="For filesystem repositories, specifies the path to the root directory" />
<modifier name="rebuild-cache" aliases="rebuild" description="Rebuilds the cache for the specified filesystem repository." />

<example description="Create a repository pointing to the filesystem with name LocalFiles, accepting snapshots, looking for files named module.xml up to 2 directories deep in C:\MyWorkspace\RootModuleDir\">
repo -name LocalFiles -snapshots 1 -fs -depth 2 -path C:\MyWorkspace\RootModuleDir\
</example>

</group>
</command>
</commands>
}

Method RootSet(%val) As %Status
{
    if (%val '= "") {
        set %val = ##class(%File).NormalizeDirectory(%val)
    }
    set i%Root = %val
    quit $$$OK
}

/// Returns a client to interact with this server.
Method GetPackageService() As %IPM.Repo.IPackageService
{
    return ##class(%IPM.Repo.Filesystem.PackageService).%New(..Root)
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(
	pInstance As %IPM.Repo.Definition,
	pInteractive As %Boolean = 1,
	ByRef pModifiers,
	ByRef pData) As %Status
{
    set tSC = $$$OK
    try {
        set tPath = $get(pModifiers("path"),pInstance.Root)
        if (pInteractive && (tPath = "")) {
            set tPrompt = ..#RootPromptString
            set tResponse = ##class(%Library.Prompt).GetString(tPrompt,.tPath)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }

            if ##class(%IPM.Repo.Filesystem.Definition).RootIndexExists(tPath) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Root '%1' is already configured for another repository.",tPath)))
            }
        }
        set pInstance.Root = tPath

        if $data(pModifiers("depth"),tDepth) {
            set pInstance.Depth = tDepth
        }

        if ##class(%File).DirectoryExists(pInstance.Root) {
            $$$ThrowOnError(pInstance.BuildCache(1,1))
        } else {
            // Still configure the repository, since the root may be a share that mounts later, but
            // warn that nothing resolves from it until the cache is built. Configure() does the save.
            set tMessage = "Root '"_pInstance.Root_"' does not exist. No modules will resolve from this repository until it does and the cache is rebuilt."
            do ##class(%IPM.General.LogManager).Warning(tMessage,1)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns a client to publish modules/applications to this server.
Method GetPublishService() As %IPM.Repo.IPublishService
{
    // TODO: Implement? (Does it make sense to allow publishing to the local filesystem? What does that even mean?)
    quit $$$NULLOREF
}

Method GetSortOrder() As %Integer [ Private ]
{
    quit 2
}

/// Clears the cache if the root is changed.
Trigger RootChanged [ Event = UPDATE, Foreach = row/object ]
{
    new tOldRoot
    if ({Root*C}) {
        set tOldRoot = {Root*O}
        &sql(delete from %IPM_Repo_Filesystem.Cache where Root = :tOldRoot)
        if (SQLCODE < 0) {
            set %ok = 0
        }
    }
}

/// Build the cache of modules found in the filesystem repository.
/// pPurge - if 1, re-parses every manifest instead of skipping the ones whose content is unchanged
Method BuildCache(
	pPurge As %Boolean = 0,
	pVerbose As %Integer = 0) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel

    try {
        set tLogManager = ##class(%IPM.General.LogManager).%Get(.tSC)
        $$$ThrowOnError(tSC)

        // Instantiate at this level for the performance benefit
        set tXSLTProvider = ##class(%IPM.Repo.XSLTProvider).%Get(.tSC)
        $$$ThrowOnError(tSC)

        // Refuse to rebuild against a root we cannot see. The walk would report no files, every
        // existing entry would look deleted, and the repository would be silently emptied. An
        // unmounted share or an interrupted source control sync looks exactly like this.
        if '##class(%File).DirectoryExists(..Root) {
            set tSC = $$$ERROR($$$GeneralError,"Filesystem repository root does not exist: "_..Root)
            quit
        }

        tstart

        // Serialize against other rebuilds of this repository. Two concurrent rebuilds each compute
        // their own visited set, so whichever finished last would delete the other's new entries.
        // A repository with no ID yet is not visible to any other process.
        if (..%Id() '= "") {
            set tLockManager = ##class(%IPM.Utils.LockManager).%New()
            $$$ThrowOnError(tLockManager.LockClassId($classname(),..%Id()))

            if (pPurge) {
                // Blank the hashes rather than deleting the rows: every entry then mismatches and is
                // re-parsed in place, so a concurrent reader never sees an emptied repository.
                #dim tResult As %SQL.StatementResult
                set tResult = ##class(%SQL.Statement).%ExecDirect(,"update %IPM_Repo_Filesystem.Cache set ContentHash = '' where Root = ?",..Root)
                if (tResult.%SQLCODE < 0) {
                    set tSC = $$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message)
                    quit
                }
            }
        }

        // Force save so that root foreign key for items will exist.
        set tSC = ..%Save()
        if $$$ISERR(tSC) {
            quit
        }

        // Read the rows already cached for this root up front, so an unchanged module.xml costs one
        // hash comparison instead of an object instantiation.
        $$$ThrowOnError(..LoadExistingEntries(.tExisting))

        // Scan root directory recursively, up to ..Depth levels down, for module.xml files,
        // hashing each one so unchanged manifests can be skipped without re-parsing.
        set tDirList(1) = ..Root
        set tSC = ##class(%IPM.Utils.File).WalkDirectories(.tDirList,..Root,..Depth,"module.xml",1,.tFilenameList,.tHashList)
        if $$$ISERR(tSC) {
            quit
        }

        // Track visited cache entries (for cleanup of stale entries)
        kill tVisitedIds

        // Ensure that we're looking at valid MODULE documents (as opposed to classes named Module, which the package manager has!)
        set tAggSC = $$$OK
        set tRelPath = ""
        for {
            set tRelPath = $order(tFilenameList(tRelPath),1,tFile)
            quit:(tRelPath="")

            // Keys are relative to the root and always end in "module.xml"; dropping that and the
            // separator before it leaves the module's subdirectory ("" for a module.xml in the root).
            set tSubDirectory = $extract(tRelPath,1,*-$length("module.xml")-1)
            set tAggSC = $$$ADDSC(tAggSC,..AddCacheItem(tFile,tSubDirectory,$get(tHashList(tRelPath)),.tName,.tVersionString,.tCacheId,.tExisting))

            // Track this cache entry as visited (still exists on filesystem)
            if tCacheId '= "" {
                set tVisitedIds(tCacheId) = 1
            }

            write:pVerbose !,tName," ",tVersionString," @ ",##class(%File).NormalizeDirectory(..Root_tSubDirectory)
        }
        $$$ThrowOnError(tAggSC)

        // Cleanup stale entries (files deleted from filesystem)
        set tSC = ..CleanupStaleEntries(.tVisitedIds, pVerbose)
        $$$ThrowOnError(tSC)

        // set cache rebuild timestamp using UTC
        set ..CacheLastRebuilt = $zdatetime($ztimestamp,3)
        $$$ThrowOnError(..%Save())
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) { trollback 1 }

    quit tSC
}

/// Read the cache rows already stored for this root, keyed by SubDirectoryHash so a long subdirectory
/// cannot overflow a local array subscript.
/// <var>existing</var>(hash) = $listbuild(id, contentHash, name, versionString)
Method LoadExistingEntries(Output existing) As %Status [ Private ]
{
    set sc = $$$OK
    kill existing
    try {
        #dim result As %SQL.StatementResult
        set result = ##class(%SQL.Statement).%ExecDirect(,"SELECT ID, SubDirectory, SubDirectoryHash, ContentHash, Name, VersionString FROM %IPM_Repo_Filesystem.Cache WHERE Root = ?",..Root)
        if (result.%SQLCODE < 0) {
            $$$ThrowStatus($$$ERROR($$$SQLCode,result.%SQLCODE,result.%Message))
        }
        while result.%Next(.fetchSC) {
            $$$ThrowOnError(fetchSC)
            set hash = result.%Get("SubDirectoryHash")
            // Rows carried over from a release without SubDirectoryHash have an empty stored value.
            // Compute it from SubDirectory so the preload finds them correctly.
            if hash = "" {
                set hash = ##class(%IPM.Repo.Filesystem.Cache).PathHash(result.%Get("SubDirectory"))
            }
            set existing(hash) = $listbuild(result.%Get("ID"),result.%Get("ContentHash"),result.%Get("Name"),result.%Get("VersionString"))
        }
        $$$ThrowOnError(fetchSC)
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Parse a module.xml file and return parsed metadata
ClassMethod ParseModuleFile(
	filePath As %String,
	Output name As %String,
	Output versionString As %String)
{
    set name = ""
    set versionString = ""

    // Validate file is a valid Studio document export
    $$$ThrowOnError($system.OBJ.Load(filePath, "-d", , .loadedList, 1))

    if ($length(loadedList, ",") > 1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "File contains multiple documents"))
    }

    set ext = $zconvert($piece($get(loadedList), ".", *), "U")
    if (ext '= "ZPM") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "File is not a ZPM module"))
    }

    // Parse module info (skip full manifest if metadata-only)
    $$$ThrowOnError(..GetModuleStreamFromFile(filePath, .stream, .name, .versionString, 1))
}

/// Refresh a cache entry by re-parsing its module.xml file.
/// Called when the content hash indicates the file has changed since it was last cached.
/// Re-parses filePath into cacheObj and saves it, deferring the full manifest until
/// GetModuleManifest() asks for it.
/// A re-parse can change Name and VersionString. Callers must re-check that the entry still describes
/// the module they looked it up by, as RootNameVersionOpenValidated does.
/// Returns 0 if the re-parsed Name and Version already belong to another entry under this root.
ClassMethod RefreshCacheEntry(
	cacheObj As %IPM.Repo.Filesystem.Cache,
	filePath As %String,
	newHash As %String) As %Boolean
{
    // Parse the module file (metadata only, re-validate since file changed)
    do ..ParseModuleFile(filePath, .name, .versionString)

    // Update the cache entry
    set cacheObj.Name = name
    set cacheObj.VersionString = versionString
    set cacheObj.ContentHash = newHash
    // Drop the manifest along with the flag, so a reader that trusts the stream over ManifestLoaded
    // can't get superseded bytes.
    do cacheObj.Manifest.Clear()
    set cacheObj.ManifestLoaded = 0
    set cacheObj.LastModified = $zdatetime($ztimestamp, 3)

    set sc = cacheObj.%Save()
    if $$$ISERR(sc) {
        // A duplicate Name and Version means another directory already claims this module, which
        // HandleSaveError reports as a warning; anything else is a real failure and throws.
        $$$ThrowOnError(cacheObj.HandleSaveError(sc))
        return 0
    }
    return 1
}

/// Adds a module to the cache.
/// pContentHash is the SHA-1 of pModuleFileName as computed by the directory walk; an entry whose
/// stored hash still matches is reused as-is, without re-parsing or re-validating the manifest.
/// pExisting is the array from <method>LoadExistingEntries</method> and is required: without it an
/// already-cached directory takes the insert path and fails the CacheItemIndex unique key.
Method AddCacheItem(
	pModuleFileName As %String,
	pSubDirectory As %String,
	pContentHash As %String,
	Output pName As %String,
	Output pVersionString As %String,
	Output pCacheId As %String = "",
	ByRef pExisting) As %Status
{
    set tSC = $$$OK
    set pName = ""
    set pVersionString = ""
    set pCacheId = ""
    try {
        // The walk reports an empty hash for a file it could not read. Hash it here rather than
        // treating the module as changed on every rebuild.
        if (pContentHash = "") {
            set pContentHash = $$$lcase(##class(%File).SHA1Hash(pModuleFileName, 1))
            // Still empty means unreadable. An empty hash matches the empty hash of a previous failed
            // attempt, so the entry would look unchanged and be served indefinitely without this.
            if (pContentHash = "") {
                do ##class(%IPM.General.LogManager).Warning("Could not read "_pModuleFileName_"; keeping the cached entry for it.",1)
            }
        }

        set tRow = $get(pExisting(##class(%IPM.Repo.Filesystem.Cache).PathHash(pSubDirectory)))
        if (tRow '= "") {
            set $listbuild(tRowId,tRowHash,tRowName,tRowVersion) = tRow

            if (tRowHash = pContentHash) {
                // File unchanged, so reuse the cached values without opening the object or parsing.
                set pName = tRowName
                set pVersionString = tRowVersion
                set pCacheId = tRowId
                return $$$OK
            }

            set tCacheItem = ##class(%IPM.Repo.Filesystem.Cache).%OpenId(tRowId,,.tSC)
            $$$ThrowOnError(tSC)
        } else {
            // New cache entry - need to create, parse and validate
            set tCacheItem = ##class(%IPM.Repo.Filesystem.Cache).%New()
            set tCacheItem.Root = ..Root
            set tCacheItem.SubDirectory = pSubDirectory
        }

        // Parse the module file (metadata only, validate since file is new or changed)
        try {
            do ..ParseModuleFile(pModuleFileName, .pName, .pVersionString)
        } catch ex {
            // Wasn't a valid file or failed to parse. Log as warning and continue
            do ##class(%IPM.General.LogManager).Warning("Failed to parse module manifest in "_pModuleFileName_": "_$system.Status.GetErrorText(ex.AsStatus()),1)

            // Report an already-cached entry as still present. The file exists, it is only momentarily
            // unparseable, say mid-save or with unresolved merge markers. Leaving it out of the
            // caller's visited set would have CleanupStaleEntries evict a healthy entry.
            if (tRow '= "") {
                set pName = tRowName
                set pVersionString = tRowVersion
                set pCacheId = tRowId
            }
            return $$$OK
        }

        // Update cache item
        set tCacheItem.Name = pName
        set tCacheItem.VersionString = pVersionString
        set tCacheItem.ContentHash = pContentHash
        // Drop the manifest along with the flag, as in RefreshCacheEntry.
        do tCacheItem.Manifest.Clear()
        set tCacheItem.ManifestLoaded = 0
        set tCacheItem.LastModified = $zdatetime($ztimestamp,3)
        set tSaveSC = tCacheItem.%Save()
        if $$$ISERR(tSaveSC) {
            set tSC = tCacheItem.HandleSaveError(tSaveSC)
        }

        // Return cache ID for tracking
        set pCacheId = tCacheItem.%Id()
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Delete cache entries for files that no longer exist on filesystem
Method CleanupStaleEntries(
	ByRef visitedIds,
	verbose As %Integer = 0) As %Status
{
    set sc = $$$OK
    try {
        // Query all cache entries for this root
        set stmt = ##class(%SQL.Statement).%New()
        set sc = stmt.%Prepare("SELECT ID, Name, VersionString, SubDirectory FROM %IPM_Repo_Filesystem.Cache WHERE Root = ?")
        $$$ThrowOnError(sc)

        set result = stmt.%Execute(..Root)
        if (result.%SQLCODE < 0) {
            set sc = $$$ERROR($$$SQLCode,result.%SQLCODE,result.%Message)
            quit
        }

        // Collect before deleting, so no row is removed from under the open cursor.
        set stale = 0
        while result.%Next(.fetchSC) {
            $$$ThrowOnError(fetchSC)
            set cacheId = result.%Get("ID")
            if '$data(visitedIds(cacheId)) {
                set stale($increment(stale)) = $listbuild(cacheId,result.%Get("Name"),result.%Get("VersionString"),result.%Get("SubDirectory"))
            }
        }
        $$$ThrowOnError(fetchSC)

        set deletedCount = 0
        for i = 1:1:stale {
            set cacheId = $listget(stale(i),1)
            set name = $listget(stale(i),2)
            set version = $listget(stale(i),3)
            set subDir = $listget(stale(i),4)

            write:verbose !,"Removing stale cache entry: ",name," ",version," (file deleted from ",..Root,subDir,")"

            set delSC = ##class(%IPM.Repo.Filesystem.Cache).%DeleteId(cacheId)
            if $$$ISERR(delSC) {
                set sc = $$$ADDSC(sc, delSC)
            } else {
                set deletedCount = deletedCount + 1
            }
        }

        if (deletedCount > 0) && verbose {
            write !,"Cleaned up ",deletedCount," stale cache entries"
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Extracts the full <Module> XML section into the Manifest stream and sets ManifestLoaded.
/// Deferred until a caller actually needs the manifest, so list, search and version resolution
/// never pay for it.
ClassMethod LoadManifestForCacheEntry(
	cacheObj As %IPM.Repo.Filesystem.Cache,
	filePath As %String) As %Status
{
    set sc = $$$OK
    try {
        // Extract full manifest using GetModuleStreamFromFile (not metadata-only)
        $$$ThrowOnError(..GetModuleStreamFromFile(filePath, .stream, .name, .version, 0))

        // Update cache entry with manifest
        do cacheObj.Manifest.Clear()
        do cacheObj.Manifest.CopyFrom(stream)
        set cacheObj.ManifestLoaded = 1
        set cacheObj.LastModified = $zdatetime($ztimestamp, 3)
        $$$ThrowOnError(cacheObj.%Save())
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

ClassMethod GetModuleStreamFromFile(
	pFilename As %String,
	Output pStream As %Stream.GlobalCharacter,
	Output pName As %String,
	Output pVersion As %String,
	pMetadataOnly As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set pStream = ""
    set pName = ""
    set pVersion = ""
    try {
        // The source stream should contain a Studio document export of a module manifest.
        set tSourceStream = ##class(%Stream.FileCharacter).%New()
        set tSC = tSourceStream.LinkToFile(pFilename)
        $$$ThrowOnError(tSC)

        set tMetaStream = ##class(%Stream.GlobalCharacter).%New()

        // Extract <Module> section of document (skip if metadata-only)
        if 'pMetadataOnly {
            // Two transforms mean two passes, so buffer the source in memory to avoid re-reading the
            // file. A metadata-only call makes one pass and reads the file directly.
            set tInputStream = ##class(%Stream.GlobalCharacter).%New()
            set tSC = tInputStream.CopyFrom(tSourceStream)
            $$$ThrowOnError(tSC)
            do tInputStream.Rewind()

            set pStream = ##class(%Stream.GlobalCharacter).%New()
            set tCompiledTransform = ##class(%IPM.Repo.XSLTProvider).GetCompiledTransformForXData($classname(),"ModuleDocumentTransform")
            set tSC = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(tInputStream,tCompiledTransform,.pStream)
            $$$ThrowOnError(tSC)

            do tInputStream.Rewind()
        } else {
            set tInputStream = tSourceStream
        }

        // Extract Name and Version
        set tCompiledTransform = ##class(%IPM.Repo.XSLTProvider).GetCompiledTransformForXData($classname(),"MetadataExtractionTransform")
        set tSC = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(tInputStream,tCompiledTransform,.tMetaStream)
        $$$ThrowOnError(tSC)

        set tMetaStream.LineTerminator = $select($$$isWINDOWS:$char(13,10),$$$isUNIX:$char(10))
        set pName = $zconvert(tMetaStream.ReadLine(), "L")
        set pVersion = tMetaStream.ReadLine()
    } catch e {
        set tOuterSC = $$$ERROR($$$GeneralError,$$$FormatText("Error loading module from file '%1'",pFilename))
        set tSC = $system.Status.EmbedStatus(tOuterSC,e.AsStatus())
    }
    quit tSC
}

/// Extracts entire <Module> section from a Studio document export
XData ModuleDocumentTransform
{
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output indent="yes"/>
 <xsl:template match="/Export/Document/Module">
 <Module>
 <xsl:copy-of select="node()"/>
 </Module>
 </xsl:template>
</xsl:stylesheet>
}

/// Extracts Name and Version from a Studio document export and prints them one per line.
XData MetadataExtractionTransform
{
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="text"/>
 <xsl:strip-space elements="*"/>
 <xsl:template match="/Export/Document/Module">
  <xsl:value-of select="Name" />
  <!-- this prints a newline. -->
  <xsl:text>&#10;</xsl:text>
  <xsl:value-of select="Version" />
 </xsl:template>
</xsl:stylesheet>
}

XData LockFileMapping
{
<Mapping xmlns="http://www.intersystems.com/jsonmapping">
  <Property Name="LockFileType" FieldName="type" />
  <Property Name="OverriddenSortOrder" FieldName="overriddenSortOrder" />
  <Property Name="ReadOnly" FieldName="readOnly" />
  <Property Name="Root" FieldName="root" />
  <Property Name="Depth" FieldName="depth" />
</Mapping>
}

Storage Default
{
<Data name="FilesystemRepoDefinitionDefaultData">
<Subscript>"FilesystemRepoDefinition"</Subscript>
<Value name="1">
<Value>Root</Value>
</Value>
<Value name="2">
<Value>Depth</Value>
</Value>
<Value name="3">
<Value>CacheLastRebuilt</Value>
</Value>
</Data>
<DefaultData>FilesystemRepoDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
