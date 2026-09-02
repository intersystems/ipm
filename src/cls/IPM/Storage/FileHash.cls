Class %IPM.Storage.FileHash Extends %Persistent
{

Property ModuleName As %String(MAXLEN = 255) [ Required ];

/// Path relative to the module root, normalized: forward slashes, no leading slash, no double slashes.
/// Callers must normalize via %IPM.Utils.File:NormalizePath before storing or looking up.
Property RelativePath As %String(MAXLEN = "") [ Required ];

/// SHA-1 of RelativePath (hex), maintained by RelativePathSet. Subscripting ModulePathIndex on
/// this fixed-width value instead of the path itself keeps the index reference well inside the
/// global subscript limit, which a long path plus a long module name can otherwise exceed.
/// Hashing also makes the index case-sensitive, which the default SQLUPPER collation is not:
/// paths differing only in case are distinct files on Linux and must not collide.
Property PathHash As %String(MAXLEN = 40) [ Required ];

/// SHA-1 content hash (hex).
Property Hash As %String(MAXLEN = 64) [ Required ];

/// Set when a sync tried to apply this path and failed. A failed sync commits no hashes, so Hash
/// still describes the last successfully-synced content while the namespace holds whatever the
/// failed attempt left behind. This flag keeps the path in the change set until a sync commits it,
/// so reverting the file to the baseline content doesn't make it invisible to change detection.
Property SyncFailed As %Boolean [ InitialExpression = 0 ];

/// Set when a sync applied this path but did not run its tests — a plain <code>sync</code> over a
/// file owned by a test resource that runs in the "test" phase. The new hash is committed, so this
/// flag keeps the path in the change set until a sync with -test runs its tests.
Property TestPending As %Boolean [ InitialExpression = 0 ];

Index ModulePathIndex On (ModuleName, PathHash) [ Unique ];

Index ModuleNameIndex On ModuleName;

ForeignKey ModuleNameFK(ModuleName) References %IPM.Storage.Module(Name) [ OnDelete = cascade ];

/// Keep PathHash in sync with the path so callers never set it themselves.
Method RelativePathSet(value As %String) As %Status
{
    set i%RelativePath = value
    set i%PathHash = ..HashPath(value)
    quit $$$OK
}

/// SHA-1 of a relative path as 40 hex characters, for use as the ModulePathIndex subscript.
/// Case-sensitive: the caller-supplied path is hashed verbatim.
ClassMethod HashPath(relPath As %String) As %String
{
    quit ##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHA1Hash(relPath))
}

/// Open the row for a module/path pair, hashing the path into the index subscript.
/// Wraps ModulePathIndexOpen so callers keep passing relative paths.
/// Returns "" with sc = $$$OK when no row exists yet: an unstamped file is the normal case for
/// every caller, so only a genuine failure (e.g. a concurrency conflict) comes back as an error.
ClassMethod OpenByPath(
    moduleName As %String,
    relPath As %String,
    Output sc As %Status) As %IPM.Storage.FileHash
{
    set instance = ..ModulePathIndexOpen(moduleName, ..HashPath(relPath), , .sc)
    if $$$ISERR(sc) && $system.Status.Equals(sc, $$$ERRORCODE($$$KeyValueNotFoundOpen)) {
        set sc = $$$OK
    }
    quit instance
}

/// Returns 1 if a row exists for this module/path pair.
ClassMethod ExistsByPath(
    moduleName As %String,
    relPath As %String) As %Boolean
{
    quit ..ModulePathIndexExists(moduleName, ..HashPath(relPath))
}

/// Collect the deduplicated set of directories sync should walk for a module.
/// Each sync-supporting resource processor declares its owned directory via GetSyncDirectory();
/// this gathers them into scanDirs(relDir)="" and removes parent/child overlaps. Shared by
/// StampModule and the sync pipeline so both walk exactly the same directory set.
ClassMethod CollectScanDirs(module As %IPM.Storage.Module, Output scanDirs)
{
    kill scanDirs
    set orderedResourceList = module.GetOrderedResourceList()
    set key = ""
    for {
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""
        if '$isobject(resource.Processor) || 'resource.Processor.SupportsSync() {
            continue
        }
        set syncDir = resource.Processor.GetSyncDirectory()
        if syncDir '= "" {
            set scanDirs(syncDir) = ""
        }
    }
    do ..DeduplicateScanDirs(.scanDirs)
}

/// Stamp all tracked files for a module.
/// Collects scan directories from each resource processor via GetSyncDirectory(), deduplicates,
/// walks only those directories, then stamps every compilable file found there (no namespace
/// check — see the note at the stamping loop below). Also stamps module.xml from the module root.
ClassMethod StampModule(module As %IPM.Storage.Module) As %Status
{
    set sc = $$$OK
    try {
        set root = ##class(%File).NormalizeDirectory(module.Root)

        // Collect and deduplicate scan directories from resource processors.
        do ..CollectScanDirs(module, .scanDirs)

        // Walk each declared directory.
        kill allFiles, allHashes
        $$$ThrowOnError(..WalkAndHashDirs(root, .scanDirs, .allFiles, .allHashes))

        // module.xml is always tracked — hash it directly from root.
        set moduleXmlPath = root _ "module.xml"
        if ##class(%File).Exists(moduleXmlPath) {
            set moduleXmlHash = $$$lcase(##class(%File).SHA1Hash(moduleXmlPath, 1))
            if moduleXmlHash '= "" {
                $$$ThrowOnError(..StampOneFileWithHash(module.Name, "module.xml", moduleXmlHash))
            }
        }

        // Stamp all compilable files found in scan dirs.
        // Targeted walks only visit declared resource directories, so every compilable file
        // found here belongs to the module and should be tracked. No namespace presence check
        // needed — directory-based resources (e.g. test dirs) use paths that RelPathToDocName
        // can't resolve to the correct class name, so a namespace check would wrongly skip them.
        set relPath = ""
        for {
            set relPath = $order(allFiles(relPath))
            quit:relPath=""
            set ext = $$$lcase($piece(relPath, ".", *))
            if ",cls,inc,mac,int,xml,rtn," '[ (","_ext_",") {
                continue
            }
            set hash = $get(allHashes(relPath))
            if hash = "" {
                continue
            }
            set stampSC = ..StampOneFileWithHash(module.Name, relPath, hash)
            if $$$ISERR(stampSC) {
                write !, "WARNING: could not stamp ", relPath, ": ", $system.Status.GetOneErrorText(stampSC)
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Stamp (or update) the FileHash row for a single file using a pre-computed hash.
ClassMethod StampOneFileWithHash(moduleName As %String, relPath As %String, hash As %String) As %Status
{
    if hash = "" {
        quit $$$ERROR($$$GeneralError, "Empty hash for: " _ relPath)
    }
    set existing = ..OpenByPath(moduleName, relPath, .openSC)
    if $$$ISERR(openSC) {
        quit openSC
    }
    if $isobject(existing) {
        set instance = existing
    } else {
        set instance = ..%New()
        set instance.ModuleName = moduleName
        set instance.RelativePath = relPath
    }
    set instance.Hash = hash
    quit instance.%Save()
}

/// Derive a server document name from a module-root-relative path.
/// Returns "" for paths that don't map to a compilable document.
/// Examples:
///   "src/cls/Foo/Bar.cls"  -> "Foo.Bar.CLS"
///   "src/SyncFlat/Flat.cls" -> "SyncFlat.Flat.CLS"
///   "src/inc/MyInc.inc"   -> "MyInc.INC"
///   "preload/cls/Foo/Bar.cls" -> "Foo.Bar.CLS"
ClassMethod RelPathToDocName(relPath As %String) As %String
{
    set parts = $length(relPath, "/")
    set ext = $$$lcase($piece(relPath, ".", *))
    if ",cls,inc,mac,int," '[ (","_ext_",") {
        quit ""
    }
    // Skip leading path segments that are conventional prefix directories.
    // Stop at the first segment that isn't one of these well-known prefixes.
    set startSeg = 1
    for i = 1:1:parts {
        set seg = $piece(relPath, "/", i)
        if ",src,preload,cls,inc,mac,int," [ (","_$$$lcase(seg)_",") {
            set startSeg = i + 1
        } else {
            quit
        }
    }
    if startSeg > parts {
        quit ""
    }
    // Segments startSeg through (parts-1) are package/directory components.
    // Segment parts is "ClassName.ext" — strip the extension for the final component.
    set name = ""
    for i = startSeg:1:(parts - 1) {
        set name = name _ $select(name="":"", 1:".") _ $piece(relPath, "/", i)
    }
    set lastName = $piece($piece(relPath, "/", parts), ".", 1, *-1)
    set name = name _ $select(name="":"", 1:".") _ lastName
    quit name _ "." _ $$$UPPER(ext)
}

/// Compute which files changed on disk vs stored baseline.
/// Pass 1: compilable files present in the namespace, from the pre-walked file set.
/// Pass 2: manifest-derived paths (from reverseIndex) for files not yet compiled
/// or non-compilable tracked files.
/// Pass 3: rows flagged by a previous failed sync, forced in regardless of their hash.
/// Pass 4: rows synced by an earlier sync that did not run their tests, forced in when this sync
/// will run tests (runTests) so those tests finally run.
/// Pass 5: iterate stored rows to detect deletions.
/// allFiles(relPath)=fullPath is the full pre-walked module root (all extensions).
/// allHashes(relPath)=sha1hex are pre-computed hashes from the same walk.
/// module.xml is deliberately excluded from every pass — it is owned by the pipeline's
/// SyncCheckModuleXml/SyncCommitModuleXml, never routed as a normal file.
/// Returns modified(relPath)=newHash and deleted(relPath)="" arrays, plus retried(relPath)="" and
/// testPending(relPath)="" for the subsets of modified that Pass 3 and Pass 4 forced in (for the
/// caller's reporting only).
ClassMethod ComputeChanges(module As %IPM.Storage.Module, Output modified, Output deleted, ByRef reverseIndex, ByRef allFiles, ByRef allHashes, Output retried, runTests As %Boolean = 0, Output testPending) As %Status
{
    set sc = $$$OK
    kill modified, deleted, retried, testPending
    try {
        set moduleName = module.Name
        kill seen

        // Pass 1: compilable files present in the namespace. RelPathToDocName returns "" for
        // non-compilable extensions, so iterating allFiles and skipping empty docNames suffices.
        set relPath = ""
        for {
            set relPath = $order(allFiles(relPath))
            quit:relPath=""
            set docName = ..RelPathToDocName(relPath)
            if docName = "" {
                continue
            }
            set docExt = $$$lcase($piece(docName, ".", *))
            if docExt = "cls" {
                set className = $piece(docName, ".", 1, *-1)
                if '$$$comClassDefined(className) {
                    continue
                }
            } else {
                if '##class(%RoutineMgr).Exists(docName) {
                    continue
                }
            }
            do ..CompareOneFile(moduleName, relPath, $get(allHashes(relPath)), .modified, .seen)
        }

        // Pass 2: check manifest-derived paths for files Pass 1 missed (uncompiled new files,
        // non-compilable tracked files). Top-level $order over reverseIndex yields relPaths only;
        // the per-path "Processor"/"Resource" subnodes are children and are skipped.
        set relPath = ""
        for {
            set relPath = $order(reverseIndex(relPath))
            quit:relPath=""
            if '$data(allFiles(relPath)) {
                continue
            }
            do ..CompareOneFile(moduleName, relPath, $get(allHashes(relPath)), .modified, .seen)
        }

        // Pass 3: rows a previous sync failed on. Their baseline hash is still the last
        // successfully-synced content, so a file reverted to that content compares as unchanged
        // above while the namespace holds whatever the failed attempt left behind. Force these in
        // until a sync commits them; paths gone from disk are left to the delete pass below.
        set result = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT RelativePath FROM %IPM_Storage.FileHash WHERE ModuleName = ? AND SyncFailed = 1",
            moduleName)
        while result.%Next() {
            set failedRelPath = result.%Get("RelativePath")
            if failedRelPath = "module.xml" {
                continue
            }
            if '$data(allFiles(failedRelPath)) {
                continue
            }
            if $data(modified(failedRelPath)) {
                continue
            }
            set modified(failedRelPath) = $get(allHashes(failedRelPath))
            set retried(failedRelPath) = ""
        }

        // Pass 4: rows an earlier sync applied without running their tests. Their hashes are
        // committed, so no pass above reports them. Forced in only when this sync runs tests, since
        // only then does the flag get cleared.
        if runTests {
            set result = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT RelativePath FROM %IPM_Storage.FileHash WHERE ModuleName = ? AND TestPending = 1",
                moduleName)
            while result.%Next() {
                set pendingRelPath = result.%Get("RelativePath")
                if pendingRelPath = "module.xml" {
                    continue
                }
                if '$data(allFiles(pendingRelPath)) {
                    continue
                }
                if $data(modified(pendingRelPath)) {
                    continue
                }
                set modified(pendingRelPath) = $get(allHashes(pendingRelPath))
                set testPending(pendingRelPath) = ""
            }
        }

        // Pass 5: iterate all stored rows — file not in allFiles → deleted. module.xml is always a
        // stored row but is not part of the walked file set, so it is skipped.
        set result = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT RelativePath FROM %IPM_Storage.FileHash WHERE ModuleName = ?",
            moduleName)
        while result.%Next() {
            set storedRelPath = result.%Get("RelativePath")
            if storedRelPath = "module.xml" {
                continue
            }
            if '$data(allFiles(storedRelPath)) {
                set deleted(storedRelPath) = ""
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Compare a file's pre-computed hash against stored baseline. No filesystem I/O.
/// Mutates the caller's by-ref arrays: sets modified(relPath)=newHash when the file is new or
/// changed, and marks seen(relPath) so a later pass won't re-compare the same path.
ClassMethod CompareOneFile(moduleName As %String, relPath As %String, newHash As %String, ByRef modified, ByRef seen) [ Private ]
{
    if $data(seen(relPath)) {
        quit
    }
    set seen(relPath) = ""
    if newHash = "" {
        set modified(relPath) = ""
        quit
    }
    // An open failure is reported as modified rather than skipped: re-syncing a file that was
    // already current is harmless, whereas skipping it would silently drop a real edit.
    set existing = ..OpenByPath(moduleName, relPath, .openSC)
    if $$$ISERR(openSC) || '$isobject(existing) {
        set modified(relPath) = newHash
        quit
    }
    if existing.Hash '= newHash {
        set modified(relPath) = newHash
    }
}

/// After a successful sync, commit new hashes for modified files and optionally remove deleted rows.
/// clearTestPending is set by a sync that ran tests: every path it committed has had its tests run,
/// so any pending-test flag from an earlier sync without -test is spent (see the TestPending property).
ClassMethod CommitChanges(module As %IPM.Storage.Module, ByRef modified, ByRef deleted, processDeletes As %Boolean = 0, clearTestPending As %Boolean = 0) As %Status
{
    set sc = $$$OK
    try {
        set relPath = ""
        for {
            set relPath = $order(modified(relPath), 1, newHash)
            quit:relPath=""

            set existing = ..OpenByPath(module.Name, relPath, .openSC)
            $$$ThrowOnError(openSC)
            if $isobject(existing) {
                set instance = existing
            } else {
                set instance = ..%New()
                set instance.ModuleName = module.Name
                set instance.RelativePath = relPath
            }

            set instance.Hash = newHash
            // This path is now synced, so any retry flag from an earlier failed attempt is spent.
            set instance.SyncFailed = 0
            if clearTestPending {
                set instance.TestPending = 0
            }
            $$$ThrowOnError(instance.%Save())
        }

        if processDeletes {
            set relPath = ""
            for {
                set relPath = $order(deleted(relPath))
                quit:relPath=""

                set existing = ..OpenByPath(module.Name, relPath, .openSC)
                $$$ThrowOnError(openSC)
                if $isobject(existing) {
                    $$$ThrowOnError(existing.%DeleteId(existing.%Id()))
                }
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// After a failed sync, flag the paths it was applying so the next sync forces them through again
/// even if their content now matches the baseline (see the SyncFailed property).
/// Paths with no baseline row need no flag: an absent row already reads as modified.
/// deleted is only flagged when processDeletes is set — otherwise the deletions were never
/// attempted, and an absent file is re-detected by ComputeChanges' delete pass anyway.
/// Called from an error handler, so failures here are returned for the caller to warn about rather
/// than thrown: they must not replace the error that caused the sync to fail.
ClassMethod MarkFailed(
    module As %IPM.Storage.Module,
    ByRef modified,
    ByRef deleted,
    processDeletes As %Boolean = 0) As %Status
{
    set sc = ..MarkPathSetFailed(module.Name, .modified)
    if processDeletes {
        set sc = $$$ADDSC(sc, ..MarkPathSetFailed(module.Name, .deleted))
    }
    quit sc
}

/// Set SyncFailed on every baselined path in one change-set array. See MarkFailed.
ClassMethod MarkPathSetFailed(
    moduleName As %String,
    ByRef paths) As %Status [ Private ]
{
    set sc = $$$OK
    set relPath = ""
    for {
        set relPath = $order(paths(relPath))
        quit:relPath=""

        set existing = ..OpenByPath(moduleName, relPath, .openSC)
        if $$$ISERR(openSC) {
            set sc = $$$ADDSC(sc, openSC)
            continue
        }
        if '$isobject(existing) {
            continue
        }
        if existing.SyncFailed {
            continue
        }
        set existing.SyncFailed = 1
        set saveSC = existing.%Save()
        if $$$ISERR(saveSC) {
            set sc = $$$ADDSC(sc, saveSC)
        }
    }
    quit sc
}

/// Flag paths a sync applied without running their tests, so the next sync with -test forces them
/// back into the change set even though their content matches the baseline (see the TestPending
/// property). Called after CommitChanges, which creates a row for everything it committed, so a
/// path with no row here was never synced and needs no flag.
/// Failures are returned rather than thrown: the files themselves are synced and reported by then,
/// and losing the marker is a missed test run, not a failed sync.
ClassMethod MarkTestPending(
    moduleName As %String,
    ByRef paths) As %Status
{
    set sc = $$$OK
    set relPath = ""
    for {
        set relPath = $order(paths(relPath))
        quit:relPath=""

        set existing = ..OpenByPath(moduleName, relPath, .openSC)
        if $$$ISERR(openSC) {
            set sc = $$$ADDSC(sc, openSC)
            continue
        }
        if '$isobject(existing) {
            continue
        }
        if existing.TestPending {
            continue
        }
        set existing.TestPending = 1
        set saveSC = existing.%Save()
        if $$$ISERR(saveSC) {
            set sc = $$$ADDSC(sc, saveSC)
        }
    }
    quit sc
}

/// Returns 1 if this module has any stored baseline rows.
ClassMethod HasBaseline(moduleName As %String) As %Boolean
{
    set result = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT TOP 1 1 FROM %IPM_Storage.FileHash WHERE ModuleName = ?",
        moduleName)
    if result.%SQLCODE < 0 {
        quit 0
    }
    quit result.%Next()
}

/// Populate paths(normalizedRelPath)="" for all stored baseline rows for this module.
ClassMethod GetStoredPaths(moduleName As %String, Output paths)
{
    kill paths
    set result = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT RelativePath FROM %IPM_Storage.FileHash WHERE ModuleName = ?",
        moduleName)
    if result.%SQLCODE < 0 {
        quit
    }
    while result.%Next() {
        set paths(result.%Get("RelativePath")) = ""
    }
}

/// Canonical form of a server document name for use as an array subscript: the name as given, with
/// the extension upper-cased.
///
/// Document names reach the sync pipeline from two sources that disagree on case:
/// <method>RelPathToDocName</method> produces "Foo.Bar.CLS", while a resource's ResolveChildren
/// yields the Studio-style "Foo.Bar.cls". An exact-match subscript lookup between the two always
/// misses, so both sides route through this method.
ClassMethod CanonicalDocName(docName As %String) As %String
{
    if docName = "" {
        quit ""
    }
    set ext = $piece(docName, ".", *)
    if ext = docName {
        quit docName
    }
    quit $piece(docName, ".", 1, *-1) _ "." _ $$$UPPER(ext)
}

/// Walk each directory in scanDirs(relDir)="" under moduleRoot and hash all files.
/// Returns files(relPath)=fullPath and hashes(relPath)=sha1hex (lowercase), keyed relative to
/// moduleRoot. Resolves the module-relative scan dirs to absolute existing directories and defers
/// the walk itself to %IPM.Utils.File, which the filesystem repository cache scan shares.
ClassMethod WalkAndHashDirs(moduleRoot As %String, ByRef scanDirs, Output files, Output hashes) As %Status
{
    set sc = $$$OK
    kill files, hashes
    try {
        set moduleRoot = ##class(%File).NormalizeDirectory(moduleRoot)

        // Collect existing absolute directories to walk.
        set dirCount = 0
        set relDir = ""
        for {
            set relDir = $order(scanDirs(relDir))
            quit:relDir=""
            set absDir = ##class(%File).NormalizeDirectory(moduleRoot _ relDir)
            if ##class(%File).DirectoryExists(absDir) {
                set dirCount = dirCount + 1
                set absDirList(dirCount) = absDir
            }
        }
        quit:dirCount=0

        // No depth cap and no filename filter: sync tracks every file under a declared directory.
        set sc = ##class(%IPM.Utils.File).WalkDirectories(.absDirList, moduleRoot, 0, "", 1, .files, .hashes)
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Remove entries from scanDirs that are already covered by a shorter prefix.
/// Sorts alphabetically; skips any entry that starts with a previously-kept entry + "/".
ClassMethod DeduplicateScanDirs(ByRef scanDirs)
{
    kill kept
    set relDir = ""
    for {
        set relDir = $order(scanDirs(relDir))
        quit:relDir=""
        set covered = 0
        set keptDir = ""
        for {
            set keptDir = $order(kept(keptDir))
            quit:keptDir=""
            set keptPrefix = ##class(%IPM.Utils.File).NormalizePath(keptDir _ "/")
            if $extract(relDir, 1, $length(keptPrefix)) = keptPrefix {
                set covered = 1
                quit
            }
        }
        if 'covered {
            set kept(relDir) = ""
        }
    }
    kill scanDirs
    merge scanDirs = kept
}

Storage Default
{
<Data name="FileHashDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ModuleName</Value>
</Value>
<Value name="3">
<Value>RelativePath</Value>
</Value>
<Value name="4">
<Value>Hash</Value>
</Value>
<Value name="5">
<Value>PathHash</Value>
</Value>
<Value name="6">
<Value>SyncFailed</Value>
</Value>
<Value name="7">
<Value>TestPending</Value>
</Value>
</Data>
<DataLocation>^IPM.Storage.FileHashD</DataLocation>
<DefaultData>FileHashDefaultData</DefaultData>
<IdLocation>^IPM.Storage.FileHashD</IdLocation>
<IndexLocation>^IPM.Storage.FileHashI</IndexLocation>
<StreamLocation>^IPM.Storage.FileHashS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
