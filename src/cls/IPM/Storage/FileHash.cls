Include (%IPM.Common, %occReference)

Class %IPM.Storage.FileHash Extends %Persistent
{

Property ModuleName As %String(MAXLEN = 255) [ Required ];

/// Path relative to the module root, normalized: forward slashes, no leading slash, no double slashes.
/// Used as the lookup key in ModulePathIndex — callers must normalize via NormalizePath before querying.
Property RelativePath As %String(MAXLEN = 512) [ Required ];

/// SHA-1 content hash (hex). Empty string means the row was stamped with mtime/size only and
/// no hash was computed yet. On the next sync, any mtime/size mismatch will compute a fresh hash.
Property Hash As %String(MAXLEN = 64) [ InitialExpression = "" ];

/// Last-modified timestamp as returned by ##class(%File).GetFileDateModified — $H format.
/// Used as a fast-path: if mtime and FileSize both match, assume content is unchanged.
Property FileTimestamp As %String(MAXLEN = 64);

/// File size in bytes. Combined with FileTimestamp forms the fast-path unchanged check.
/// Both fields are needed: size alone misses same-size edits; mtime alone is unreliable on copies.
Property FileSize As %Integer;

Index ModulePathIndex On (ModuleName, RelativePath) [ Unique ];

Index ModuleNameIndex On ModuleName;

ForeignKey ModuleNameFK(ModuleName) References %IPM.Storage.Module(Name) [ OnDelete = cascade ];

/// Stamp actual file paths for this module by combining two passes:
/// Pass 1 covers convention-derived paths that exist on disk (standard layouts).
/// Pass 2 walks the module root for compilable files not found at their derived location.
ClassMethod StampModule(module As %IPM.Storage.Module, ByRef trackedPaths) As %Status
{
    set sc = $$$OK
    try {
        set root = ##class(%File).NormalizeDirectory(module.Root)

        // Pass 1: stamp all convention-derived paths that exist on disk.
        set relPath = ""
        for {
            set relPath = $order(trackedPaths(relPath))
            quit:relPath=""

            set fullPath = ##class(%File).NormalizeFilename(relPath, root)
            if '##class(%File).Exists(fullPath) {
                continue
            }
            $$$ThrowOnError(..StampOneFile(module.Name, root, fullPath))
        }

        // Pass 2: walk the module root for compilable files not already in trackedPaths.
        // Catches non-standard layouts where OnItemRelativePath produced a path that doesn't
        // match the actual file location on disk.
        // Uses a manual BFS queue because File_FileSet's recursive flag only returns
        // immediate children — it does not descend through multiple directory levels in one call.
        kill walkQueue
        set walkHead = 1, walkTail = 1
        set walkQueue(walkTail) = root
        for {
            quit:(walkHead > walkTail)
            set walkDir = walkQueue(walkHead)
            set walkHead = walkHead + 1

            set walkResult = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT Name, Type FROM %Library.File_FileSet(?, ?, ?, ?)",
                walkDir, "*", "", 0)
            while walkResult.%Next() {
                set entryType = walkResult.%Get("Type")
                set entryPath = walkResult.%Get("Name")
                if entryType = "D" {
                    set walkTail = walkTail + 1
                    set walkQueue(walkTail) = ##class(%File).NormalizeDirectory(entryPath)
                    continue
                }
                set ext = $$$lcase($piece(entryPath, ".", *))
                if ",cls,inc,mac,int," '[ (","_ext_",") {
                    continue
                }
                set normalizedRelPath = ..NormalizePath($extract(entryPath, $length(root) + 1, *))
                if $data(trackedPaths(normalizedRelPath)) {
                    continue
                }
                set docName = ..RelPathToDocName(normalizedRelPath)
                if docName = "" {
                    continue
                }
                set docExt = $$$lcase($piece(docName, ".", *))
                if docExt = "cls" {
                    if '$$$comClassDefined($piece(docName, ".", 1, *-1)) {
                        continue
                    }
                } else {
                    if '##class(%RoutineMgr).Exists(docName) {
                        continue
                    }
                }
                $$$ThrowOnError(..StampOneFile(module.Name, root, entryPath))
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Stamp (or update) the FileHash row for a single file. Computes hash at stamp time.
ClassMethod StampOneFile(moduleName As %String, root As %String, fullPath As %String) As %Status
{
    set normalizedRelPath = ..NormalizePath($extract(fullPath, $length(root) + 1, *))
    set existing = ..ModulePathIndexOpen(moduleName, normalizedRelPath, , .openSC)
    if $isobject(existing) {
        set instance = existing
    } else {
        set instance = ..%New()
        set instance.ModuleName = moduleName
        set instance.RelativePath = normalizedRelPath
    }
    set instance.Hash = ##class(%File).SHA1Hash(fullPath, 1)
    set instance.FileSize = ##class(%File).GetFileSize(fullPath)
    set instance.FileTimestamp = ..GetFileTimestamp(fullPath)
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

/// Compute which tracked files changed on disk vs stored baseline.
/// Returns modified(relPath)=newHash and deleted(relPath)="" arrays.
ClassMethod ComputeChanges(module As %IPM.Storage.Module, ByRef trackedPaths, Output modified, Output deleted) As %Status
{
    set sc = $$$OK
    kill modified, deleted
    try {
        set root = ##class(%File).NormalizeDirectory(module.Root)

        set relPath = ""
        for {
            set relPath = $order(trackedPaths(relPath))
            quit:relPath=""

            set normalizedRelPath = ..NormalizePath(relPath)
            set fullPath = ##class(%File).NormalizeFilename(relPath, root)

            if '##class(%File).Exists(fullPath) {
                if ..ModulePathIndexExists(module.Name, normalizedRelPath) {
                    set deleted(normalizedRelPath) = ""
                }
                continue
            }

            set existing = ..ModulePathIndexOpen(module.Name, normalizedRelPath, , .openSC)
            if '$isobject(existing) {
                // No baseline row — file joined trackedPaths after initial load (e.g. added via
                // OnSyncResolveFiles). Stamp it silently so it doesn't trigger a spurious
                // "modified" on every sync until someone edits it.
                do ..StampOneFile(module.Name, root, fullPath)
                continue
            }

            // Hash-only comparison. Avoids mtime unreliability on bind mounts.
            set newHash = ##class(%File).SHA1Hash(fullPath, 1)
            if existing.Hash '= newHash {
                set modified(normalizedRelPath) = newHash
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
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
            set instance.FileSize = ##class(%File).GetFileSize(fullPath)
            set instance.FileTimestamp = ..GetFileTimestamp(fullPath)
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
/// Same structure as the trackedPaths array used by GetTrackedPaths and ComputeChanges.
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

/// Get the last-modified timestamp of a file in $H format (as returned by GetFileDateModified).
ClassMethod GetFileTimestamp(fullPath As %String) As %String
{
    quit ##class(%File).GetFileDateModified(fullPath)
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
<Value>FileTimestamp</Value>
</Value>
<Value name="6">
<Value>FileSize</Value>
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
