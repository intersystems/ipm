Include (%IPM.Common, %occReference)

Class %IPM.Storage.FileHash Extends %Persistent
{

Property ModuleName As %String(MAXLEN = 255) [ Required ];

/// Path relative to the module root, normalized: forward slashes, no leading slash, no double slashes.
/// Used as the lookup key in ModulePathIndex — callers must normalize via NormalizePath before querying.
Property RelativePath As %String(MAXLEN = 512) [ Required ];

/// SHA-1 content hash (hex).
Property Hash As %String(MAXLEN = 64) [ Required ];

Index ModulePathIndex On (ModuleName, RelativePath) [ Unique ];

Index ModuleNameIndex On ModuleName;

ForeignKey ModuleNameFK(ModuleName) References %IPM.Storage.Module(Name) [ OnDelete = cascade ];

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
                write !, "Warning: could not stamp ", relPath, ": ", $system.Status.GetOneErrorText(stampSC)
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
    set existing = ..ModulePathIndexOpen(moduleName, relPath, , .openSC)
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
        if ",src,cls,inc,mac,int," [ (","_$$$lcase(seg)_",") {
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
/// Pass 3: iterate stored rows to detect deletions.
/// allFiles(relPath)=fullPath is the full pre-walked module root (all extensions).
/// allHashes(relPath)=sha1hex are pre-computed hashes from the same walk.
/// module.xml is deliberately excluded from all three passes — it is owned by the pipeline's
/// SyncCheckModuleXml/SyncCommitModuleXml, never routed as a normal file.
/// Returns modified(relPath)=newHash and deleted(relPath)="" arrays.
ClassMethod ComputeChanges(module As %IPM.Storage.Module, Output modified, Output deleted, ByRef reverseIndex, ByRef allFiles, ByRef allHashes) As %Status
{
    set sc = $$$OK
    kill modified, deleted
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

        // Pass 3: iterate all stored rows — file not in allFiles → deleted. module.xml is skipped:
        // it is always a stored row but is not part of the walked file set, so it would otherwise
        // be misreported as deleted every sync.
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
    set existing = ..ModulePathIndexOpen(moduleName, relPath, , .openSC)
    if '$isobject(existing) {
        set modified(relPath) = newHash
        quit
    }
    if existing.Hash '= newHash {
        set modified(relPath) = newHash
    }
}

/// After a successful sync, commit new hashes for modified files and optionally remove deleted rows.
ClassMethod CommitChanges(module As %IPM.Storage.Module, ByRef modified, ByRef deleted, processDeletes As %Boolean = 0) As %Status
{
    set sc = $$$OK
    try {
        set relPath = ""
        for {
            set relPath = $order(modified(relPath), 1, newHash)
            quit:relPath=""

            set existing = ..ModulePathIndexOpen(module.Name, relPath, , .openSC)
            if $isobject(existing) {
                set instance = existing
            } else {
                set instance = ..%New()
                set instance.ModuleName = module.Name
                set instance.RelativePath = relPath
            }

            set instance.Hash = newHash
            $$$ThrowOnError(instance.%Save())
        }

        if processDeletes {
            set relPath = ""
            for {
                set relPath = $order(deleted(relPath))
                quit:relPath=""

                set existing = ..ModulePathIndexOpen(module.Name, relPath, , .openSC)
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

/// Normalize a relative path: forward slashes, collapse //, strip leading slash.
ClassMethod NormalizePath(path As %String) As %String
{
    set path = $translate(path, "\", "/")
    while path [ "//" {
        set path = $replace(path, "//", "/")
    }
    while $extract(path) = "/" {
        set path = $extract(path, 2, *)
    }
    quit path
}

/// Walk each directory in scanDirs(relDir)="" under moduleRoot and hash all files.
/// Returns files(relPath)=fullPath and hashes(relPath)=sha1hex (lowercase).
/// Uses a single Python os.walk call across all directories for speed; falls back to SQL BFS.
ClassMethod WalkAndHashDirs(moduleRoot As %String, ByRef scanDirs, Output files, Output hashes) As %Status
{
    set sc = $$$OK
    kill files, hashes
    try {
        set moduleRoot = ##class(%File).NormalizeDirectory(moduleRoot)

        // Collect existing absolute directories to walk.
        kill absDirList
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

        // Single Python call across all directories — avoids per-dir interpreter overhead.
        set dirsJson = "["
        for i = 1:1:dirCount {
            if i > 1 { set dirsJson = dirsJson _ "," }
            set dirsJson = dirsJson _ """" _ $replace(absDirList(i), "\", "\\") _ """"
        }
        set dirsJson = dirsJson _ "]"

        set walkSC = ..WalkAndHashFilesPython(dirsJson, moduleRoot, .files, .hashes)
        if $$$ISERR(walkSC) {
            // SQL fallback: walk each directory individually.
            kill files, hashes
            for i = 1:1:dirCount {
                kill dirFiles, dirHashes
                $$$ThrowOnError(..WalkAndHashFilesSQL(absDirList(i), moduleRoot, .dirFiles, .dirHashes))
                merge files = dirFiles
                merge hashes = dirHashes
            }
        }
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
            set keptPrefix = ..NormalizePath(keptDir _ "/")
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

ClassMethod WalkAndHashFilesPython(dirsJson As %String, relativeToRoot As %String, Output files, Output hashes) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        set relativeToRoot = ##class(%File).NormalizeDirectory(relativeToRoot)
        set jsonStr = ..WalkAndHashFilesPythonImpl(dirsJson, relativeToRoot)
        set result = ##class(%DynamicArray).%FromJSON(jsonStr)
        set count = result.%Size()
        for i = 0:1:(count - 1) {
            set entry = result.%Get(i)
            set relPath = entry.%Get("rel")
            set files(relPath) = entry.%Get("full")
            set hashes(relPath) = entry.%Get("hash")
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

ClassMethod WalkAndHashFilesPythonImpl(dirsJson As %String, relativeToRoot As %String) As %String [ Language = python ]
{
import os
import json
import hashlib
import concurrent.futures

SKIP_DIRS = {'.git', '__pycache__', 'node_modules'}

dirs = json.loads(dirsJson)
root_len = len(relativeToRoot.rstrip(os.sep)) + 1

# Walk all directories, collecting all files.
file_list = []
for d in dirs:
    for dirpath, dirnames, filenames in os.walk(d):
        dirnames[:] = [x for x in dirnames if x not in SKIP_DIRS]
        for fname in filenames:
            full_path = os.path.join(dirpath, fname)
            rel_path = full_path[root_len:].replace('\\', '/')
            if rel_path:
                file_list.append((rel_path, full_path))

def hash_file(full_path):
    try:
        h = hashlib.sha1()
        with open(full_path, 'rb') as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()
    except (OSError, PermissionError):
        return ""

# Hash all files in parallel — SHA1 releases the GIL, so threads overlap I/O wait.
with concurrent.futures.ThreadPoolExecutor(max_workers=24) as executor:
    hash_results = list(executor.map(hash_file, [f for _, f in file_list]))

return json.dumps([
    {"rel": rel, "full": full, "hash": h}
    for (rel, full), h in zip(file_list, hash_results)
])
}

/// SQL-based BFS fallback that walks and hashes without Python.
ClassMethod WalkAndHashFilesSQL(dir As %String, relativeToRoot As %String, Output files, Output hashes) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        set dir = ##class(%File).NormalizeDirectory(dir)
        set relativeToRoot = ##class(%File).NormalizeDirectory(relativeToRoot)
        kill walkQueue
        set walkHead = 1, walkTail = 1
        set walkQueue(walkTail) = dir
        for {
            quit:(walkHead > walkTail)
            set walkDir = walkQueue(walkHead)
            set walkHead = walkHead + 1

            set rs = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT Name, Type FROM %Library.File_FileSet(?, ?, ?, ?)",
                walkDir, "*", "", 0)
            while rs.%Next() {
                set entryType = rs.%Get("Type")
                set entryPath = rs.%Get("Name")
                if entryType = "D" {
                    set childDirName = ##class(%File).GetFilename(entryPath)
                    if ",.git,__pycache__,node_modules," [ (","_childDirName_",") {
                        continue
                    }
                    set walkTail = walkTail + 1
                    set walkQueue(walkTail) = ##class(%File).NormalizeDirectory(entryPath)
                    continue
                }
                set relPath = ..NormalizePath($extract(entryPath, $length(relativeToRoot) + 1, *))
                if relPath '= "" {
                    set files(relPath) = entryPath
                    set hashes(relPath) = $$$lcase(##class(%File).SHA1Hash(entryPath, 1))
                }
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
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
</Data>
<DataLocation>^IPM.Storage.FileHashD</DataLocation>
<DefaultData>FileHashDefaultData</DefaultData>
<IdLocation>^IPM.Storage.FileHashD</IdLocation>
<IndexLocation>^IPM.Storage.FileHashI</IndexLocation>
<StreamLocation>^IPM.Storage.FileHashS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
