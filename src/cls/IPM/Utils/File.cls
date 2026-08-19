/// Wraps a set of more robust file operations
Class %IPM.Utils.File
{

/// Ceiling on how far <method>WalkDirectoriesSQL</method> will descend, well past any real source tree.
Parameter MAXWALKDEPTH = 64;

/// Create this directory and all the parent directories if they do not exist. This differs from
/// <method>CreateDirectory</method> as that method only creates one new directory where as
/// this will create the entire chain of directories. Returns true if it succeeds and false otherwise.
/// Pass <var>return</var> by reference to obtain the low level return value in case of errors
ClassMethod CreateDirectoryChain(pName As %String) As %Status
{
    set tSC = $$$OK
    if '##class(%Library.File).CreateDirectoryChain(pName,.tReturn) {
        set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",pName,$zutil(209,$select(tReturn<0:-tReturn,1:tReturn))))
    }
    quit tSC
}

ClassMethod RemoveDirectoryTree(pRoot As %String) As %Status
{
    new %objlasterror
    set tSC = $$$OK
    set tBadSC = $$$ERROR($$$GeneralError,$$$FormatText("Error removing directory %1",pRoot))
    try {
        if $$$isUNIX {
            kill %objlasterror
            if '##class(%Library.File).RemoveDirectoryTree(pRoot) {
                set tLastErr = $get(%objlasterror)
                set tSC = $$$EMBEDSC(tBadSC,tLastErr)
            }
        } elseif $$$isWINDOWS {
            // Handle long directories
            // Based on https://superuser.com/a/620474/227743
            // On InterSystems IRIS, TempFilename() creates the temp file; append "dir" to ensure uniqueness.
            set tTempFileName = ##class(%Library.File).TempFilename()
            set tEmptyDir = ##class(%Library.File).NormalizeDirectory(tTempFileName_"dir")
            try {
                if '##class(%Library.File).CreateDirectory(tEmptyDir,.tReturn) {
                    set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",tEmptyDir,$zutil(209,tReturn)))
                    $$$ThrowStatus(tSC)
                }
                set pRoot = ##class(%Library.File).NormalizeDirectory(pRoot)
                set stdout=""
                set tCmd = $listbuild("ROBOCOPY",tEmptyDir,pRoot,"/MIR")
                set tSC = ##class(%IPM.Utils.Module).RunCommand(, tCmd,.stdout,,.retCode)
                if $$$ISERR(tSC) && ($get(retCode)<8) {
                    set tSC=$$$OK
                }
            } catch e {
                set tSC = e.AsStatus()
            }

            // Cleanup code - call even if RunCommandViaZF fails; no need to check results.
            do ##class(%Library.File).RemoveDirectory(pRoot)
            do ##class(%Library.File).RemoveDirectory(tEmptyDir)
            do ##class(%Library.File).Delete(tTempFileName)
        }
    } catch e {
        set tSC = $$$EMBEDSC(tBadSC,e.AsStatus())
    }
    quit tSC
}

/// Copy a file <var>pSource</var> to file <var>pDest</var>. <br />
/// Parameter <var>pDeleteBeforeCopy</var> may be used to specify that if the target file already exists then it should be deleted before being overwritten
/// with the source file. The default is 0 or false.
ClassMethod CopyFile(
	pSource As %String,
	pDest As %String,
	pDeleteBeforeCopy As %Boolean = 0) As %Status
{
    new %objlasterror
    set tSC = $$$OK
    if '##class(%Library.File).CopyFile(pSource,pDest,pDeleteBeforeCopy,.tOSErr) {
        set tInnerSC = $get(%objlasterror,$$$OK)
        set tOSMessage = $zutil(209,tOSErr)
        set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying file %1 to %2: %3",pSource,pDest,tOSMessage))
        if $$$ISERR(tInnerSC) {
            // Also embed the root-cause error from %objlasterror if present (e.g., if pDeleteBeforeCopy was 1 and there was an error deleting the file)
            set tSC = $$$EMBEDSC(tSC,tInnerSC)
        }
    }
    quit tSC
}

ClassMethod CopyDir(
	pSource As %String,
	pDest As %String,
	pDeleteFirst As %Boolean = 1,
	pVerbose As %Boolean = 0) As %Status
{
    new %objlasterror
    set tSC = $$$OK
    set tBadSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying directory %1 to %2",pSource,pDest))
    try {
        if $$$isUNIX {
            kill %objlasterror
            if '##class(%Library.File).CopyDir(pSource,pDest,1,.tCreated,pDeleteFirst) {
                set tLastErr = $get(%objlasterror)
                set tSC = $$$EMBEDSC(tBadSC,tLastErr)
            }
        } elseif $$$isWINDOWS {
            if pDeleteFirst {
                set tSC = ..RemoveDirectoryTree(pDest)
                if $$$ISERR(tSC) {
                    quit
                }
            }
            set pSource = ##class(%Library.File).NormalizeDirectory(pSource)
            set pDest = ##class(%Library.File).NormalizeDirectory(pDest)
            set tCmd = $listbuild("ROBOCOPY", pSource,pDest,"/E")
            if ('pVerbose) {
                set stdout = ""
            }
            set tSC = ##class(%IPM.Utils.Module).RunCommand(, tCmd,.stdout,,.retCode)
            if $$$ISERR(tSC) && ($get(retCode)<8) {
                set tSC=$$$OK
            }
            if (pVerbose) {
                for i=1:1:$get(tLog) {
                    write tLog(i),!
                }
            }
        }
    } catch e {
        set tSC = $$$EMBEDSC(tBadSC,e.AsStatus())
    }
    quit tSC
}

ClassMethod MakeDirectoryWriteable(
	pDirectory As %String,
	Output pCmd,
	Output pOutputLog,
	Output pErrLog) As %Status
{
    set tSC = $$$OK
    set pCmd = ""
    try {
        kill pOutputLog
        kill pErrLog
        if $$$isWINDOWS {
            set pCmd = $listbuild("attrib", "-r", ##class(%Library.File).NormalizeDirectory(pDirectory)_"*.*", "/s")
            set stdout = ""
        } elseif $$$isUNIX {
            set pCmd = $listbuild("chmod", "-R", "775", ##class(%Library.File).NormalizeDirectory(pDirectory))
        }
        set tSC = ##class(%IPM.Utils.Module).RunCommand(, pCmd, .stdout)
        $$$ThrowOnError(tSC)
        if ($get(pErrLog(1))'="") {
            set error = pErrLog(1)
            throw ##class(%Exception.General).%New(error)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod SetReadOnly(
	pFileOrDirectoryName As %String,
	pLeaveExisting As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        if '##class(%Library.File).SetReadOnly(pFileOrDirectoryName,.pLeaveExisting,.tReturn) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error making '%1' read-only: %2",pFileOrDirectoryName,$zutil(209,tReturn)))
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod SetWriteable(
	pFileName As %String,
	pWriteable As %Boolean = 1) As %Status
{
    set tSC = $$$OK
    try {
        if '##class(%Library.File).SetWriteable(pFileName,.pWriteable,.tReturn) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error making '%1' writeable: %2",pFileName,$zutil(209,tReturn)))
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod FindFiles(
	pPath As %String,
	pWildcards As %String = "",
	Output pList) As %Integer
{
    kill pList
    set pList = 0
    set fileSetRS = ##class(%File).FileSetFunc(##class(%File).NormalizeDirectory(pPath), pWildcards, , 1)
    while fileSetRS.%Next() {
        if (fileSetRS.Type = "D") {
            do ..FindFiles(fileSetRS.Name, pWildcards, .tList)
            for i=1:1:tList {
                set pList($increment(pList)) = tList(i)
            }
        } else {
            set pList($increment(pList)) = $listbuild(fileSetRS.ItemName, fileSetRS.Name)
        }
    }

    return pList
}

/// Check if file exists but case insensitive
ClassMethod Exists(
	ByRef pFilename,
	Output pReturn) As %Boolean
{
    if ##class(%File).Exists(pFilename) {
        return 1
    }
    set tDirectory = ##class(%File).ParentDirectoryName(pFilename)
    if '##class(%File).DirectoryExists(tDirectory) {
        return 0
    }
    set tName = $piece(pFilename, tDirectory, 2, *)
    set tFileName = $piece(tName, ".", 1, * - 1)
    set tFileExt = $piece(tName, ".", *)
    for tExt = $$$LOWER(tFileExt), $$$UPPER(tFileExt) {
        if ##class(%File).Exists(tDirectory _ tFileName _ "." _ tExt) {
            set pFilename = tDirectory _ tFileName _ "." _ tExt
            return 1
        }
    }
    set tNameLower = $$$LOWER(tName)
    set rs = ##class(%File).FileSetFunc(tDirectory, "*", , 0)
    while rs.%Next() {
        set tItemNameLower = $$$LOWER(rs.ItemName)
        if tItemNameLower = tNameLower {
            set pFilename = tDirectory _ rs.ItemName
            return 1
        }
    }
    return 0
}

/// Normalize a relative path: forward slashes, collapse //, drop "." segments, strip leading slash.
///
/// Dot collapsing is what makes <SourcesRoot>.</SourcesRoot> work. Such a module composes resource
/// paths as SourcesRoot_"/"_Directory, so a file arrives as "./cls/Foo.cls" while the directory walk
/// keys it as "cls/Foo.cls". Both forms reduce to one here so the sync reverse index matches.
ClassMethod NormalizePath(path As %String) As %String
{
    set path = $translate(path, "\", "/")
    while path [ "//" {
        set path = $replace(path, "//", "/")
    }
    while path [ "/./" {
        set path = $replace(path, "/./", "/")
    }
    while $extract(path) = "/" {
        set path = $extract(path, 2, *)
    }
    // A leading "./" has no slash in front of it, so the loop above misses it. Repeats for "./.".
    while $extract(path, 1, 2) = "./" {
        set path = $extract(path, 3, *)
    }
    // A bare "." is the module root, not a file.
    if path = "." {
        set path = ""
    }
    quit path
}

/// Walk one or more directories and report the files found, optionally with content hashes.
/// Shared by sync's change detection and the filesystem repository cache scan.
/// <var>dirs</var>(n) = absolute directory to walk; callers pass only directories that exist.
/// <var>relativeTo</var> is the root that result keys are made relative to.
/// <var>maxDepth</var> limits how far below each walked directory to descend; 0 is unlimited.
/// A file exactly <var>maxDepth</var> levels down is kept; anything deeper is not visited.
/// <var>filenameFilter</var>, when non-empty, keeps only files with that name (e.g. "module.xml"),
/// compared case-insensitively on Windows and case-sensitively elsewhere, matching the filesystem.
/// <var>files</var>(relPath) = fullPath, and <var>hashes</var>(relPath) = lowercase SHA-1 hex
/// (empty when <var>computeHashes</var> is 0). Keys are normalized: forward slashes, no leading slash.
/// <var>maxDepthFound</var> reports the greatest depth at which a kept file was found, for depth auto-detection.
/// Directories named .git, __pycache__ or node_modules are never descended into.
ClassMethod WalkDirectories(
	ByRef dirs,
	relativeTo As %String,
	maxDepth As %Integer = 0,
	filenameFilter As %String = "",
	computeHashes As %Boolean = 1,
	Output files,
	Output hashes,
	Output maxDepthFound As %Integer) As %Status
{
    set sc = $$$OK
    kill files, hashes
    set maxDepthFound = 0
    try {
        set relativeTo = ##class(%Library.File).NormalizeDirectory(relativeTo)

        set dirCount = 0
        set key = ""
        for {
            set key = $order(dirs(key),1,dir)
            quit:key=""
            set dirCount = dirCount + 1
            set dirList(dirCount) = ##class(%Library.File).NormalizeDirectory(dir)
        }
        quit:dirCount=0

        // A single Python call across all directories avoids per-directory interpreter overhead.
        set dirsJson = "["
        for i = 1:1:dirCount {
            set dirsJson = dirsJson _ $select(i>1:",",1:"") _ """" _ $replace(dirList(i), "\", "\\") _ """"
        }
        set dirsJson = dirsJson _ "]"

        set pythonSC = ..WalkDirectoriesPython(dirsJson, relativeTo, maxDepth, filenameFilter, computeHashes, .files, .hashes, .maxDepthFound)
        if $$$ISOK(pythonSC) {
            quit
        }

        // Fall back to a SQL-driven breadth-first walk, one directory at a time.
        // Warn, because the fallback is far slower and otherwise indistinguishable from a slow disk.
        set warning = "Python directory walk failed, falling back to a slower SQL walk: "_$system.Status.GetOneErrorText(pythonSC)
        do ##class(%IPM.General.LogManager).Warning(warning,1)

        kill files, hashes
        set maxDepthFound = 0
        for i = 1:1:dirCount {
            $$$ThrowOnError(..WalkDirectoriesSQL(dirList(i), relativeTo, maxDepth, filenameFilter, computeHashes, .files, .hashes, .maxDepthFound))
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

ClassMethod WalkDirectoriesPython(
	dirsJson As %String,
	relativeTo As %String,
	maxDepth As %Integer,
	filenameFilter As %String,
	computeHashes As %Boolean,
	Output files,
	Output hashes,
	Output maxDepthFound As %Integer) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        set result = ##class(%DynamicObject).%FromJSON(..WalkDirectoriesPythonImpl(dirsJson, relativeTo, maxDepth, filenameFilter, computeHashes))
        set maxDepthFound = result.maxDepth
        set entries = result.files
        for i = 0:1:(entries.%Size() - 1) {
            set entry = entries.%Get(i)
            set relPath = entry.%Get("rel")
            set files(relPath) = entry.%Get("full")
            set hashes(relPath) = entry.%Get("hash")
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// os.walk() is C-based and far faster than a SQL FileSet walk; hashing runs on a thread pool
/// because SHA-1 releases the GIL, so threads overlap I/O wait.
ClassMethod WalkDirectoriesPythonImpl(
	dirsJson As %String,
	relativeTo As %String,
	maxDepth As %Integer,
	filenameFilter As %String,
	computeHashes As %Boolean) As %String [ Language = python, Private ]
{
import os
import json
import hashlib
import concurrent.futures

SKIP_DIRS = {'.git', '__pycache__', 'node_modules'}

dirs = json.loads(dirsJson)
max_depth = int(maxDepth)
compute_hashes = int(computeHashes)
root_len = len(relativeTo.rstrip(os.sep)) + 1

# Windows filenames are case-insensitive, so "Module.xml" must match a "module.xml" filter there.
# Elsewhere those are two distinct files, so the comparison stays exact.
fold_case = os.name == 'nt'
name_filter = filenameFilter.lower() if fold_case else filenameFilter

file_list = []
max_depth_found = 0

for d in dirs:
    dir_len = len(d.rstrip(os.sep))
    for dirpath, dirnames, filenames in os.walk(d):
        dirnames[:] = [x for x in dirnames if x not in SKIP_DIRS]

        # Depth of dirpath below the walked directory; 0 for the directory itself. Recomputed each
        # iteration because os.walk() yields absolute paths rather than incremental navigation.
        rel_dir = dirpath[dir_len:].lstrip(os.sep)
        current_depth = rel_dir.count(os.sep) + 1 if rel_dir else 0

        # Stop descending once the cap is reached; files at exactly the cap are still kept.
        if max_depth > 0 and current_depth >= max_depth:
            dirnames[:] = []

        for fname in filenames:
            if name_filter and (fname.lower() if fold_case else fname) != name_filter:
                continue
            full_path = os.path.join(dirpath, fname)
            rel_path = full_path[root_len:].replace('\\', '/')
            if not rel_path:
                continue
            file_list.append((rel_path, full_path))
            if current_depth > max_depth_found:
                max_depth_found = current_depth

def hash_file(full_path):
    try:
        h = hashlib.sha1()
        with open(full_path, 'rb') as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()
    except (OSError, PermissionError):
        return ""

if compute_hashes:
    with concurrent.futures.ThreadPoolExecutor(max_workers=24) as executor:
        hash_results = list(executor.map(hash_file, [f for _, f in file_list]))
else:
    hash_results = [""] * len(file_list)

return json.dumps({
    "maxDepth": max_depth_found,
    "files": [
        {"rel": rel, "full": full, "hash": h}
        for (rel, full), h in zip(file_list, hash_results)
    ]
})
}

/// Breadth-first walk of a single directory using %Library.File_FileSet, for use when embedded
/// Python is unavailable. Adds to the caller's files/hashes/maxDepthFound rather than resetting them.
ClassMethod WalkDirectoriesSQL(
	dir As %String,
	relativeTo As %String,
	maxDepth As %Integer,
	filenameFilter As %String,
	computeHashes As %Boolean,
	ByRef files,
	ByRef hashes,
	ByRef maxDepthFound As %Integer) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        // Windows matches filenames case-insensitively; other platforms do not. See WalkDirectories.
        set foldCase = $$$isWINDOWS
        set nameFilter = $select(foldCase:$$$lcase(filenameFilter),1:filenameFilter)

        set walkHead = 1, walkTail = 1
        set walkQueue(1) = ##class(%Library.File).NormalizeDirectory(dir)
        set walkQueue(1,"depth") = 0
        for {
            quit:walkHead>walkTail
            set walkDir = walkQueue(walkHead)
            set walkDepth = walkQueue(walkHead,"depth")
            set walkHead = walkHead + 1

            // FileSet cannot tell a symlink from a directory, so an unlimited walk through a symlink
            // loop would descend forever, each pass yielding a longer but distinct path. The ceiling is
            // set far above any real source tree, so a legitimate walk never reaches it.
            if (walkDepth > ..#MAXWALKDEPTH) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Directory walk exceeded "_..#MAXWALKDEPTH_" levels below "_dir_"; check for a symbolic link cycle"))
            }

            set rs = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT Name, Type FROM %Library.File_FileSet(?, ?, ?, ?)",
                walkDir, "*", "", 0)
            if rs.%SQLCODE < 0 {
                $$$ThrowStatus($$$ERROR($$$SQLCode,rs.%SQLCODE,rs.%Message))
            }
            while rs.%Next() {
                set entryPath = rs.%Get("Name")
                if rs.%Get("Type") = "D" {
                    if (maxDepth > 0) && ((walkDepth + 1) > maxDepth) {
                        continue
                    }
                    if ",.git,__pycache__,node_modules," [ (","_##class(%Library.File).GetFilename(entryPath)_",") {
                        continue
                    }
                    set walkTail = walkTail + 1
                    set walkQueue(walkTail) = ##class(%Library.File).NormalizeDirectory(entryPath)
                    set walkQueue(walkTail,"depth") = walkDepth + 1
                    continue
                }
                if (nameFilter '= "") {
                    set entryName = ##class(%Library.File).GetFilename(entryPath)
                    if $select(foldCase:$$$lcase(entryName),1:entryName) '= nameFilter {
                        continue
                    }
                }
                set relPath = ..NormalizePath($extract(entryPath, $length(relativeTo) + 1, *))
                if (relPath = "") {
                    continue
                }
                set files(relPath) = entryPath
                set hashes(relPath) = $select(computeHashes:$$$lcase(##class(%Library.File).SHA1Hash(entryPath, 1)),1:"")
                if (walkDepth > maxDepthFound) {
                    set maxDepthFound = walkDepth
                }
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Creates a new temporary directory and returns its normalized path.
/// baseDirectory optionally specifies the parent; defaults to the OS temp directory.
/// $zu(140,17) returns a negative integer error code on failure (e.g., -28 = no space left on device).
ClassMethod CreateTempDirectory(baseDirectory As %String = "") As %String
{
    set dir = $select(baseDirectory = "": $zutil(140,17), 1: $zutil(140,17,baseDirectory))
    if dir = ("-" _ -dir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to create temporary directory: " _ $zutil(209,-dir)))
    }
    return ##class(%File).NormalizeDirectory(dir)
}

}
