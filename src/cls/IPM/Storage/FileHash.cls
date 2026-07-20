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

/// Stamp all tracked files for a module. Two passes:
/// Pass 1 walks the module root for compilable files (cls/inc/mac/int) present in the namespace.
/// Pass 2 calls OnSyncResolveFiles on each processor to stamp non-compilable tracked files (e.g. FileCopy).
/// Also stamps module.xml.
ClassMethod StampModule(module As %IPM.Storage.Module) As %Status
{
    set sc = $$$OK
    try {
        set root = ##class(%File).NormalizeDirectory(module.Root)

        // module.xml is always tracked.
        set moduleXmlPath = root _ "module.xml"
        if ##class(%File).Exists(moduleXmlPath) {
            $$$ThrowOnError(..StampOneFile(module.Name, root, moduleXmlPath))
        }

        // Single walk of the entire module root (uses Python os.walk for speed).
        kill allFiles
        $$$ThrowOnError(..WalkFilesRecursive(root, root, .allFiles))

        // Pass 1: filter for compilable files present in the namespace.
        set relPath = ""
        for {
            set relPath = $order(allFiles(relPath), 1, entryPath)
            quit:relPath=""
            set ext = $$$lcase($piece(relPath, ".", *))
            if ",cls,inc,mac,int," '[ (","_ext_",") {
                continue
            }
            set docName = ..RelPathToDocName(relPath)
            if docName = "" {
                continue
            }
            set docExt = $$$lcase($piece(docName, ".", *))
            if docExt = "cls" {
                set className = $piece(docName, ".", 1, *-1)
                if '$$$comClassDefined(className) && '$$$comClassDefined("%" _ className) {
                    continue
                }
            } else {
                if '##class(%RoutineMgr).Exists(docName) && '##class(%RoutineMgr).Exists("%" _ docName) {
                    continue
                }
            }
            set stampSC = ..StampOneFile(module.Name, root, entryPath)
            if $$$ISERR(stampSC) {
                write !, "Warning: could not stamp ", relPath, ": ", $system.Status.GetOneErrorText(stampSC)
            }
        }

        // Pass 2: stamp non-compilable tracked files via OnSyncResolveFiles on each processor.
        set orderedResourceList = module.GetOrderedResourceList()
        set key = ""
        for {
            set resource = orderedResourceList.GetNext(.key)
            quit:key=""
            if '$isobject(resource.Processor) {
                continue
            }
            kill syncOnlyPaths
            set childSC = resource.Processor.OnSyncResolveFiles(.syncOnlyPaths, .allFiles)
            if $$$ISERR(childSC) {
                continue
            }
            set relPath = ""
            for {
                set relPath = $order(syncOnlyPaths(relPath))
                quit:relPath=""
                set fullPath = ##class(%File).NormalizeFilename(relPath, root)
                if '##class(%File).Exists(fullPath) {
                    continue
                }
                set stampSC = ..StampOneFile(module.Name, root, fullPath)
                if $$$ISERR(stampSC) {
                    write !, "Warning: could not stamp ", relPath, ": ", $system.Status.GetOneErrorText(stampSC)
                }
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Stamp (or update) the FileHash row for a single file. Computes hash at stamp time.
/// Returns an error if the file cannot be hashed (locked/permission denied).
ClassMethod StampOneFile(moduleName As %String, root As %String, fullPath As %String) As %Status
{
    set normalizedRelPath = ..NormalizePath($extract(fullPath, $length(root) + 1, *))
    set hash = ##class(%File).SHA1Hash(fullPath, 1)
    if hash = "" {
        quit $$$ERROR($$$GeneralError, "Could not compute hash for: " _ fullPath)
    }
    set existing = ..ModulePathIndexOpen(moduleName, normalizedRelPath, , .openSC)
    if $isobject(existing) {
        set instance = existing
    } else {
        set instance = ..%New()
        set instance.ModuleName = moduleName
        set instance.RelativePath = normalizedRelPath
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
/// Pass 1: filter pre-walked BFS data for compilable files present in the namespace.
/// Pass 2: check manifest-derived paths (from reverseIndex) for files not yet compiled
/// or non-compilable tracked files — avoids re-calling ResolveChildren/OnSyncResolveFiles.
/// Pass 3: iterate stored rows to detect deletions.
/// allFiles(relPath)=fullPath is the full pre-walked module root (all extensions).
/// bfsFiles(relPath)=fullPath is the compilable subset (cls,inc,mac,int).
/// Returns modified(relPath)=newHash and deleted(relPath)="" arrays.
ClassMethod ComputeChanges(module As %IPM.Storage.Module, Output modified, Output deleted, ByRef manifestPaths, ByRef bfsFiles, ByRef allFiles) As %Status
{
    set sc = $$$OK
    kill modified, deleted
    try {
        set root = ##class(%File).NormalizeDirectory(module.Root)
        kill seen

        // module.xml
        set moduleXmlPath = root _ "module.xml"
        if ##class(%File).Exists(moduleXmlPath) {
            do ..CheckOneFile(module.Name, root, moduleXmlPath, .modified, .seen)
        }

        // Pass 1: filter pre-walked compilable files by namespace presence.
        set relPath = ""
        for {
            set relPath = $order(bfsFiles(relPath), 1, entryPath)
            quit:relPath=""
            set docName = ..RelPathToDocName(relPath)
            if docName = "" {
                continue
            }
            set docExt = $$$lcase($piece(docName, ".", *))
            if docExt = "cls" {
                set className = $piece(docName, ".", 1, *-1)
                if '$$$comClassDefined(className) && '$$$comClassDefined("%" _ className) {
                    continue
                }
            } else {
                if '##class(%RoutineMgr).Exists(docName) && '##class(%RoutineMgr).Exists("%" _ docName) {
                    continue
                }
            }
            do ..CheckOneFile(module.Name, root, entryPath, .modified, .seen)
        }

        // Pass 2: check manifest-derived paths for files BFS missed (uncompiled new files,
        // non-compilable tracked files). Use allFiles for existence check (O(1) $data)
        // instead of filesystem calls.
        set relPath = ""
        for {
            set relPath = $order(manifestPaths(relPath))
            quit:relPath=""
            if '$data(allFiles(relPath)) {
                continue
            }
            do ..CheckOneFile(module.Name, root, allFiles(relPath), .modified, .seen)
        }

        // Pass 3: iterate all stored rows — file not in allFiles → deleted.
        set result = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT RelativePath FROM %IPM_Storage.FileHash WHERE ModuleName = ?",
            module.Name)
        while result.%Next() {
            set storedRelPath = result.%Get("RelativePath")
            if '$data(allFiles(storedRelPath)) {
                set deleted(storedRelPath) = ""
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Check a single file against its stored baseline. If no row or hash differs, add to modified.
/// If hash cannot be computed (locked/permission denied), reports as modified with "" hash and warns.
ClassMethod CheckOneFile(moduleName As %String, root As %String, fullPath As %String, ByRef modified, ByRef seen) [ Private ]
{
    set normalizedRelPath = ..NormalizePath($extract(fullPath, $length(root) + 1, *))
    if $data(seen(normalizedRelPath)) {
        quit
    }
    set seen(normalizedRelPath) = ""
    set newHash = ##class(%File).SHA1Hash(fullPath, 1)
    if newHash = "" {
        write !, "Warning: could not hash ", normalizedRelPath, " (file may be locked)"
        set modified(normalizedRelPath) = ""
        quit
    }
    set existing = ..ModulePathIndexOpen(moduleName, normalizedRelPath, , .openSC)
    if '$isobject(existing) {
        set modified(normalizedRelPath) = newHash
        quit
    }
    if existing.Hash '= newHash {
        set modified(normalizedRelPath) = newHash
    }
}

/// After a successful sync, commit new hashes for modified files and optionally remove deleted rows.
ClassMethod CommitChanges(module As %IPM.Storage.Module, ByRef modified, ByRef deleted, processDeletes As %Boolean = 0) As %Status
{
    set sc = $$$OK
    try {
        set root = ##class(%File).NormalizeDirectory(module.Root)

        set relPath = ""
        for {
            set relPath = $order(modified(relPath), 1, newHash)
            quit:relPath=""

            set fullPath = ##class(%File).NormalizeFilename(relPath, root)
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
    quit result.%Next()
}

/// Populate paths(normalizedRelPath)="" for all stored baseline rows for this module.
ClassMethod GetStoredPaths(moduleName As %String, Output paths)
{
    kill paths
    set result = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT RelativePath FROM %IPM_Storage.FileHash WHERE ModuleName = ?",
        moduleName)
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

/// Walk all files under dir using Python os.walk() for performance.
/// Returns files(normalizedRelPath) = fullPath, relative to relativeToRoot.
/// extensionFilter is comma-separated (e.g. "cls,inc,mac,int") or "" for all files.
/// Falls back to SQL-based BFS if Python is unavailable.
ClassMethod WalkFilesRecursive(dir As %String, relativeToRoot As %String, Output files, extensionFilter As %String = "") As %Status
{
    set sc = ..WalkFilesRecursivePython(dir, relativeToRoot, .files, extensionFilter)
    if $$$ISERR(sc) {
        set sc = ..WalkFilesRecursiveSQL(dir, relativeToRoot, .files, extensionFilter)
    }
    quit sc
}

/// Python implementation of recursive file walk using os.walk().
/// ~10x faster than SQL-based FileSet iteration.
ClassMethod WalkFilesRecursivePython(dir As %String, relativeToRoot As %String, Output files, extensionFilter As %String = "") As %Status
{
    set sc = $$$OK
    try {
        set dir = ##class(%File).NormalizeDirectory(dir)
        set relativeToRoot = ##class(%File).NormalizeDirectory(relativeToRoot)
        set jsonStr = ..WalkFilesRecursivePythonImpl(dir, relativeToRoot, extensionFilter)
        set result = ##class(%DynamicArray).%FromJSON(jsonStr)
        set count = result.%Size()
        for i = 0:1:(count - 1) {
            set entry = result.%Get(i)
            set relPath = entry.%Get("rel")
            set fullPath = entry.%Get("full")
            set files(relPath) = fullPath
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

ClassMethod WalkFilesRecursivePythonImpl(dir As %String, relativeToRoot As %String, extensionFilter As %String = "") As %String [ Language = python ]
{
import os
import json

SKIP_DIRS = {'.git', '__pycache__', 'node_modules'}

results = []
ext_filter = set()
if extensionFilter:
    ext_filter = set(extensionFilter.lower().split(','))

root_len = len(relativeToRoot.rstrip(os.sep)) + 1

for dirpath, dirnames, filenames in os.walk(dir):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
    for fname in filenames:
        if ext_filter:
            ext = fname.rsplit('.', 1)[-1].lower() if '.' in fname else ''
            if ext not in ext_filter:
                continue
        full_path = os.path.join(dirpath, fname)
        rel_path = full_path[root_len:].replace('\\', '/')
        if rel_path:
            results.append({"rel": rel_path, "full": full_path})

return json.dumps(results)
}

/// SQL-based BFS fallback for environments without Python.
ClassMethod WalkFilesRecursiveSQL(dir As %String, relativeToRoot As %String, Output files, extensionFilter As %String = "") As %Status
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
                    set walkTail = walkTail + 1
                    set walkQueue(walkTail) = ##class(%File).NormalizeDirectory(entryPath)
                    continue
                }
                if extensionFilter '= "" {
                    set ext = $$$lcase($piece(entryPath, ".", *))
                    if (","_extensionFilter_",") '[ (","_ext_",") {
                        continue
                    }
                }
                set relPath = ..NormalizePath($extract(entryPath, $length(relativeToRoot) + 1, *))
                if relPath '= "" {
                    set files(relPath) = entryPath
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
