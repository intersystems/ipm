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

        // Build cache without auto-detect - user specifies depth explicitly or it defaults to 0 (unlimited)
        $$$ThrowOnError(pInstance.BuildCache(1,1,0))
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

/// When Depth property changes, cache needs full rebuild
/// (different depth means different set of files included)
Trigger DepthChanged [ Event = UPDATE, Foreach = row/object ]
{
    new oldDepth, newDepth
    if ({Depth*C}) {
        set oldDepth = {Depth*O}
        set newDepth = {Depth}

        // Skip if we're already in the middle of BuildCache (e.g., auto-detecting depth)
        // This prevents infinite recursion when BuildCache sets the depth
        if $get(^||IPMBuildingCache) {
            quit
        }

        // Depth changed - rebuild cache
        set oref = ..%Open({ID})
        if $isobject(oref) {
            do oref.BuildCache(1, 0)  // Full rebuild, non-verbose
        }
    }
}

/// Build the cache of modules found in the filesystem repository.
/// pPurge - if 1, deletes existing cache entries before rebuilding
Method BuildCache(
	pPurge As %Boolean = 0,
	pVerbose As %Integer = 0,
	pAutoDetectDepth As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel

    // Set flag to prevent DepthChanged trigger from recursively calling BuildCache
    set ^||IPMBuildingCache = 1

    try {
        set tLogManager = ##class(%IPM.General.LogManager).%Get(.tSC)
        $$$ThrowOnError(tSC)

        // Instantiate at this level for the performance benefit
        set tXSLTProvider = ##class(%IPM.Repo.XSLTProvider).%Get(.tSC)
        $$$ThrowOnError(tSC)

        tstart

        // Track visited cache entries (for cleanup of stale entries)
        kill tVisitedIds

        if (pPurge) && (..%Id() '= "") {
            set tLockManager = ##class(%IPM.Utils.LockManager).%New()
            $$$ThrowOnError(tLockManager.LockClassId($classname(),..%Id()))
            #dim tResult As %SQL.StatementResult
            set tResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %IPM_Repo_Filesystem.Cache where Root = ?",..Root)
            if (tResult.%SQLCODE < 0) {
                set tSC = $$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message)
                quit
            }
        }

        // Force save so that root foreign key for items will exist.
        set tSC = ..%Save()
        if $$$ISERR(tSC) {
            quit
        }

        // Scan root directory recursively, up to ..Depth levels down, for module.xml files.
        // Try Python scanner first (much faster), fall back to SQL-based scanner if unavailable
        set tSC = ..ScanDirectoryPython(..Root,.tFilenameList,..Depth,$select(pVerbose>1:1,1:0),.tMaxDepth)
        if $$$ISERR(tSC) {
            write:pVerbose !,"Python scanner not available, using SQL-based scanner. ", $system.Status.GetErrorText(tSC)
            set tSC = ..ScanDirectory(..Root,.tFilenameList,,..Depth,$select(pVerbose>1:1,1:0),.tMaxDepth)
        }
        if $$$ISERR(tSC) {
            quit
        }

        if (pAutoDetectDepth) && (tMaxDepth > 0) {
            set ..Depth = tMaxDepth
            set tSC = ..%Save()
            if $$$ISERR(tSC) {
                quit
            }
        }

        // Ensure that we're looking at valid MODULE documents (as opposed to classes named Module, which the package manager has!)
        set tAggSC = $$$OK
        set tKey = ""
        for {
            set tKey = $order(tFilenameList(tKey),1,tFile)
            quit:(tKey="")

            set tSubDirectory = tFilenameList(tKey,"sub")
            set tAggSC = $$$ADDSC(tAggSC,..AddCacheItem(tFile,tSubDirectory,.tName,.tVersionString,.tCacheId))

            // Track this cache entry as visited (still exists on filesystem)
            if tCacheId '= "" {
                set tVisitedIds(tCacheId) = 1
            }

            write:pVerbose !,tName," ",tVersionString," @ ",##class(%File).NormalizeDirectory(..Root_tSubDirectory)
        }
        $$$ThrowOnError(tAggSC)

        // Cleanup stale entries (files deleted from filesystem)
        if 'pPurge {
            set tSC = ..CleanupStaleEntries(.tVisitedIds, pVerbose)
            $$$ThrowOnError(tSC)
        }

        // set cache rebuild timestamp using UTC
        set ..CacheLastRebuilt = $zdatetime($ztimestamp,3)
        $$$ThrowOnError(..%Save())
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) { trollback 1 }

    // Done building cache so clear the flag
    set ^||IPMBuildingCache = 0

    quit tSC
}

/// Parse a module.xml file and return parsed metadata
Method ParseModuleFile(
	filePath As %String,
	root As %String,
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
    kill stream, name, versionString
    $$$ThrowOnError(..GetModuleStreamFromFile(filePath, .stream, .name, .versionString, 1))
}

/// Refresh a cache entry by re-parsing its module.xml file
/// Updates the cache entry in-place with new manifest and mtime
Method RefreshCacheEntry(
	cacheObj As %IPM.Repo.Filesystem.Cache,
	filePath As %String,
	newMTime As %TimeStamp)
{
    // Parse the module file (metadata only, re-validate since file changed)
    kill stream, name, versionString
    do ..ParseModuleFile(filePath, cacheObj.Root, .name, .versionString)

    // Update the cache entry
    set cacheObj.Name = name
    set cacheObj.VersionString = versionString
    set cacheObj.FileMTime = newMTime
    set cacheObj.ManifestLoaded = 0  // Mark manifest as not loaded (lazy load on next access)
    set cacheObj.ValidationPassed = 1  // Mark validation passed
    set cacheObj.LastModified = $zdatetime($ztimestamp, 3)

    set sc = cacheObj.%Save()
    if $$$ISERR(sc) {
        set sc = cacheObj.HandleSaveError(sc)
        $$$ThrowOnError(sc)
    }
}

/// Adds a module to the cache.
Method AddCacheItem(
	pModuleFileName As %String,
	pSubDirectory As %String,
	Output pName As %String,
	Output pVersionString As %String,
	Output pCacheId As %String = "") As %Status
{
    set tSC = $$$OK
    set pName = ""
    set pVersionString = ""
    set pCacheId = ""
    try {
        // Check if cache entry exists
        set tCurrentMTime = $zdatetime(##class(%Library.File).GetFileDateModified(pModuleFileName), 3)

        if ##class(%IPM.Repo.Filesystem.Cache).CacheItemIndexExists(..Root,pSubDirectory) {
            set tCacheItem = ##class(%IPM.Repo.Filesystem.Cache).CacheItemIndexOpen(..Root,pSubDirectory,,.tSC)
            $$$ThrowOnError(tSC)

            // Check if we can skip parsing entirely (file unchanged and previously validated)
            if (tCacheItem.FileMTime = tCurrentMTime) && tCacheItem.ValidationPassed {
                // File unchanged - reuse cached values without parsing or updating
                set pName = tCacheItem.Name
                set pVersionString = tCacheItem.VersionString
                set pCacheId = tCacheItem.%Id()
                return $$$OK
            }
        } else {
            // New cache entry - need to create, parse and validate
            set tCacheItem = ##class(%IPM.Repo.Filesystem.Cache).%New()
            set tCacheItem.Root = ..Root
            set tCacheItem.SubDirectory = pSubDirectory
        }

        // Parse the module file (metadata only, validate since file is new or changed)
        kill tStream, tName, tVersionString
        try {
            do ..ParseModuleFile(pModuleFileName, ..Root, .pName, .pVersionString)
        } catch ex {
            // Wasn't a valid file or failed to parse. Log as warning and continue
            set tSC = ex.AsStatus()
            do ##class(%IPM.General.LogManager).Warning("Failed to parse module manifest in "_pModuleFileName_": "_$system.Status.GetErrorText(tSC),1)
            return $$$OK
        }

        // Update cache item
        set tCacheItem.Name = pName
        set tCacheItem.VersionString = pVersionString
        set tCacheItem.FileMTime = tCurrentMTime
        set tCacheItem.ManifestLoaded = 0  // Manifest will be loaded on-demand
        set tCacheItem.ValidationPassed = 1  // Mark validation passed
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
        set deletedCount = 0

        while result.%Next() {
            set cacheId = result.%Get("ID")

            // If not visited during scan, delete it (file was removed)
            if '$data(visitedIds(cacheId)) {
                set name = result.%Get("Name")
                set version = result.%Get("VersionString")
                set subDir = result.%Get("SubDirectory")

                write:verbose !,"Removing stale cache entry: ",name," ",version," (file deleted from ",..Root,subDir,")"

                set delSC = ##class(%IPM.Repo.Filesystem.Cache).%DeleteId(cacheId)
                if $$$ISERR(delSC) {
                    set sc = $$$ADDSC(sc, delSC)
                } else {
                    set deletedCount = deletedCount + 1
                }
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

/// Load the full manifest for a cache entry on-demand
/// Used for lazy loading optimization - only extracts manifest when needed
Method LoadManifestForCacheEntry(
	cacheObj As %IPM.Repo.Filesystem.Cache,
	filePath As %String) As %Status
{
    set sc = $$$OK
    try {
        // Extract full manifest using GetModuleStreamFromFile (not metadata-only)
        kill stream, name, version
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

Method GetModuleStreamFromFile(
	pFilename As %String,
	Output pStream As %Stream.GlobalCharacter,
	Output pName As %String,
	Output pVersion As %String,
	pMetadataOnly As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set pName = ""
    set pVersion = ""
    try {
        // The source stream should contain a Studio document export of a module manifest.
        set tSourceStream = ##class(%Stream.FileCharacter).%New()
        set tSC = tSourceStream.LinkToFile(pFilename)
        $$$ThrowOnError(tSC)

        // Copy to in-memory stream for reuse (avoid file I/O on rewind)
        set tMemoryStream = ##class(%Stream.GlobalCharacter).%New()
        set tSC = tMemoryStream.CopyFrom(tSourceStream)
        $$$ThrowOnError(tSC)
        do tMemoryStream.Rewind()

        set tMetaStream = ##class(%Stream.GlobalCharacter).%New()

        // Extract <Module> section of document (skip if metadata-only)
        if 'pMetadataOnly {
            set pStream = ##class(%Stream.GlobalCharacter).%New()
            set tCompiledTransform = ##class(%IPM.Repo.XSLTProvider).GetCompiledTransformForXData($classname(),"ModuleDocumentTransform")
            set tSC = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(tMemoryStream,tCompiledTransform,.pStream)
            $$$ThrowOnError(tSC)

            // Rewind in-memory stream for next transform
            do tMemoryStream.Rewind()
        }

        // Extract Name and Version
        set tCompiledTransform = ##class(%IPM.Repo.XSLTProvider).GetCompiledTransformForXData($classname(),"MetadataExtractionTransform")
        set tSC = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(tMemoryStream,tCompiledTransform,.tMetaStream)
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

/// Fast directory scanning using embedded Python - returns dynamic object with results
/// Uses Python's os.walk() which is C-based and highly optimized
ClassMethod ScanDirectoryPythonImpl(
	root As %String,
	depth As %Integer = 0,
	verbose As %Boolean = 0) As %DynamicObject [ Language = python ]
{
import os
import iris

# Track results and max depth
results = []
max_depth = 0

try:
    for dirpath, dirnames, filenames in os.walk(root):
        # Calculate current depth before processing
        # Must compute each iteration because os.walk() provides absolute paths, not incremental navigation
        # We derive depth by: removing root prefix, stripping separators, then counting remaining separators + 1
        if dirpath == root or dirpath == root.rstrip(os.sep):
            current_depth = 0
        else:
            current_depth = dirpath[len(root):].lstrip(os.sep).count(os.sep) + 1

        # Depth limiting - stop descending if we've reached the limit
        if depth > 0 and current_depth >= depth:
            dirnames.clear()  # Don't descend further

        if 'module.xml' in filenames:
            # Skip if this directory exceeds the depth limit
            if depth > 0 and current_depth > depth:
                continue

            full_path = os.path.join(dirpath, 'module.xml')

            # Calculate relative directory from root
            if dirpath == root or dirpath == root.rstrip(os.sep):
                rel_dir = ''
            else:
                rel_dir = os.path.relpath(dirpath, root)
                # Convert backslashes to forward slashes for consistency
                rel_dir = rel_dir.replace('\\', '/')

            # Track max depth
            if rel_dir:
                file_depth = rel_dir.count('/') + 1
                if file_depth > max_depth:
                    max_depth = file_depth

            # Store result as dict
            results.append({'fullPath': full_path, 'relDir': rel_dir})

            if verbose:
                print(f"Found file: {full_path}")

    # Return plain dict
    return {
        'results': results,
        'maxDepth': max_depth
    }

except Exception as e:
    error_msg = f"Error scanning directory with Python: {str(e)}"
    print(error_msg)
    raise
}

/// Wrapper method that calls Python scanner and converts results to ObjectScript array
ClassMethod ScanDirectoryPython(
	root As %String,
	ByRef filenameList,
	depth As %Integer = 0,
	verbose As %Boolean = 0,
	Output maxDepth As %Integer = 0) As %Status
{
    set sc = $$$OK
    try {
        // Normalize root path
        set root = ##class(%File).NormalizeDirectory(root)

        // Call Python implementation
        set result = ..ScanDirectoryPythonImpl(root, depth, verbose)

        // Extract results and max depth from Python dict
        set resultsList = result."__getitem__"("results")
        set maxDepth = result."__getitem__"("maxDepth")

        // Convert Python list to ObjectScript array
        set filenameList = 0
        set listLen = resultsList."__len__"()
        for idx = 0:1:(listLen-1) {
            set item = resultsList."__getitem__"(idx)
            set fullPath = item."__getitem__"("fullPath")
            set relDir = item."__getitem__"("relDir")

            set filenameList($increment(filenameList)) = fullPath
            set filenameList(filenameList, "sub") = relDir
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

ClassMethod ScanDirectory(
	pRoot As %String,
	ByRef pFilenameList,
	pSub As %String = "",
	pDepth As %Integer = "",
	pVerbose As %Boolean = 0,
	Output pMaxDepth As %Integer = 0) As %Status [ Internal ]
{
    set tSC = $$$OK
    try {
        set pRoot = ##class(%File).NormalizeDirectory(pRoot)
        set tDirArray($increment(tDirArray)) = ""

        set i = 0
        do {
            set i = i + 1
            if (pDepth > 0) && ($length(tDirArray(i),"/") > pDepth) {
                continue
            }

            set tStmt = ##class(%SQL.Statement).%New()
            set tSC = tStmt.%PrepareClassQuery("%Library.File","FileSet")
            if $$$ISERR(tSC) {
                quit
            }

            set tFullDir = ##class(%File).NormalizeDirectory(pRoot_tDirArray(i))
            set tRes = tStmt.%Execute(tFullDir,"module.xml",,1)
            while tRes.%Next() {
                if (tRes.%Get("Type") = "D") {
                    write:pVerbose !,"Scanning directory: ",tRes.%Get("ItemName")
                    set tDirArray($increment(tDirArray)) = tDirArray(i)_$case(tDirArray(i),"":"",:"/")_tRes.%Get("ItemName")
                } else {
                    write:pVerbose !,"Found file: ",tRes.%Get("Name")
                    set pFilenameList($increment(pFilenameList)) = tRes.%Get("Name")
                    set pFilenameList(pFilenameList,"sub") = tDirArray(i)
                    if (pDepth > pMaxDepth) {
                        set pMaxDepth = $length(tDirArray(i),"/")
                    }
                }
            }
        } while (i < tDirArray)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
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
