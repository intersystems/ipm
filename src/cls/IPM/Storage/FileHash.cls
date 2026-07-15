Include %IPM.Common

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

/// Record the current mtime+size for each tracked file without reading file content (no hash).
/// This "stamp" establishes a baseline so subsequent sync calls can detect changes via ComputeChanges.
/// Called after a successful dev-mode %Compile (after %Reload) so all resources, including
/// unit test classes compiled during %Compile, are present on disk and in ^oddDEF.
ClassMethod StampModule(module As %IPM.Storage.Module, ByRef trackedPaths) As %Status
{
    set sc = $$$OK
    try {
        set root = ##class(%File).NormalizeDirectory(module.Root)
        set relPath = ""
        for {
            set relPath = $order(trackedPaths(relPath))
            quit:relPath=""

            set fullPath = ##class(%File).NormalizeFilename(relPath, root)
            if '##class(%File).Exists(fullPath) {
                continue
            }

            set normalizedRelPath = ..NormalizePath(relPath)
            set existing = ..ModulePathIndexOpen(module.Name, normalizedRelPath, , .openSC)
            if $isobject(existing) {
                set instance = existing
            } else {
                set instance = ..%New()
                set instance.ModuleName = module.Name
                set instance.RelativePath = normalizedRelPath
            }

            set instance.FileSize = ##class(%File).GetFileSize(fullPath)
            set instance.FileTimestamp = ..GetFileTimestamp(fullPath)
            $$$ThrowOnError(instance.%Save())
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
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

            set currentSize = ##class(%File).GetFileSize(fullPath)
            set currentTimestamp = ..GetFileTimestamp(fullPath)

            set existing = ..ModulePathIndexOpen(module.Name, normalizedRelPath, , .openSC)
            if '$isobject(existing) {
                // No baseline row — file is newly tracked (added since the last sync/stamp).
                // Report it as modified so it gets loaded; no prior hash to compare against.
                set modified(normalizedRelPath) = ##class(%File).SHA1Hash(fullPath, 1)
                continue
            }

            // Fast path: size+mtime match means unchanged
            if (existing.FileSize = currentSize) && (existing.FileTimestamp = currentTimestamp) {
                continue
            }

            // Size or mtime differ — read hash to confirm real change
            set newHash = ##class(%File).SHA1Hash(fullPath, 1)
            if (existing.Hash '= "") && (newHash = existing.Hash) {
                // Hash matches stored — content unchanged despite mtime/size difference; update fast-path
                set existing.FileTimestamp = currentTimestamp
                set existing.FileSize = currentSize
                $$$ThrowOnError(existing.%Save())
            } else {
                // Content changed (or no prior hash to confirm otherwise)
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
