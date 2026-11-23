Include %IPM.Formatting

/// Wraps a set of more robust file operations
Class %IPM.Utils.File
{

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

/// Returns 1 if deleting dir would delete a directory IRIS or IPM needs to run, because dir is
/// one of those directories or an ancestor of one. Subdirectories, such as an application's own
/// directory under csp/, are not protected. Database directories are protected too, both configured
/// ones and any directory holding an IRIS.DAT.
ClassMethod IsProtectedDirectory(dir As %String) As %Boolean
{
    if ##class(%Library.File).Exists(##class(%Library.File).Construct(dir, "IRIS.DAT")) {
        return 1
    }
    set installDir = $system.Util.InstallDirectory()
    set mgrDir = ##class(%Library.File).ManagerDirectory()
    set cspDir = ##class(%Library.File).Construct(installDir, "csp")
    set libDir = ##class(%Library.File).Construct(installDir, "lib")
    set protectedDirs = $listbuild(
        installDir,
        $system.Util.DataDirectory(),
        mgrDir,
        $system.Util.BinaryDirectory(),
        libDir,
        cspDir,
        // The Management Portal and Interoperability UI
        ##class(%Library.File).Construct(cspDir, "sys"),
        ##class(%Library.File).Construct(cspDir, "broker"),
        ##class(%Library.File).Construct(cspDir, "enslib"),
        // Installed Python packages and the IRIS iris module
        ##class(%Library.File).Construct(mgrDir, "python"),
        ##class(%Library.File).Construct(libDir, "python"),
        // Holds IPM's own files
        ##class(%IPM.Repo.UniversalSettings).GetModuleRoot()) _ ..DatabaseDirectories()
    set dir = ..NormalizeForComparison(dir)
    set pointer = 0
    while $listnext(protectedDirs, pointer, protectedDir) {
        if $extract(..NormalizeForComparison(protectedDir), 1, $length(dir)) = dir {
            return 1
        }
    }
    return 0
}

/// Returns the directory of every database in the instance configuration, including those outside mgr/.
ClassMethod DatabaseDirectories() As %List [ Internal ]
{
    new $namespace
    set $namespace = "%SYS"
    set statement = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(statement.%PrepareClassQuery("Config.Databases", "List"))
    set rs = statement.%Execute("*")
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    set dirs = ""
    while rs.%Next(.sc) {
        $$$ThrowOnError(sc)
        set dirs = dirs _ $listbuild(rs.%Get("Directory"))
    }
    $$$ThrowOnError(sc)
    return dirs
}

/// Normalizes path as a directory so that a prefix match only matches whole path segments.
/// Lowercases on every platform because Windows and macOS file systems are case-insensitive by default.
/// On a case-sensitive file system a prefix match can then only match too much, which keeps files
/// rather than deleting them or writes an extra warning.
ClassMethod NormalizeForComparison(path As %String) As %String [ Private ]
{
    return $zconvert(##class(%Library.File).NormalizeDirectory(path), "L")
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
                do ..RunRobocopy($listbuild("ROBOCOPY",tEmptyDir,pRoot,"/MIR"), .stdout)
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
        // Clearing a target that contains the source deletes the source. Without clearing, only
        // copying into the source itself is unsafe.
        if pDeleteFirst && ..DirectoriesOverlap(pSource, pDest) {
            set message = $$$FormatText("Source %1 and target %2 are the same directory or one contains the other", pSource, pDest)
            $$$ThrowStatus($$$ERROR($$$GeneralError, message))
        }
        if 'pDeleteFirst && ..DirectoryContains(pSource, pDest) {
            set message = $$$FormatText("Target %2 is the source %1 or inside it", pSource, pDest)
            $$$ThrowStatus($$$ERROR($$$GeneralError, message))
        }
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
            if ('pVerbose) {
                set stdout = ""
            }
            do ..RunRobocopy($listbuild("ROBOCOPY", pSource,pDest,"/E"), .stdout)
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

/// Returns 1 if first and second are the same directory or one is inside the other.
ClassMethod DirectoriesOverlap(
	first As %String,
	second As %String) As %Boolean
{
    return ..DirectoryContains(first, second) || ..DirectoryContains(second, first)
}

/// Returns 1 if inner is the directory outer or inside it. Embedded Python compares device and inode,
/// so a symlink or bind mount that aliases the two is caught too. Without Python, or on a filesystem
/// that reports inode 0, only the normalized paths are compared.
ClassMethod DirectoryContains(
	outer As %String,
	inner As %String) As %Boolean
{
    try {
        return ..DirectoryContainsPython(outer, inner)
    } catch {
        set outer = ..NormalizeForComparison(outer)
        set inner = ..NormalizeForComparison(inner)
        return $extract(inner, 1, $length(outer)) = outer
    }
}

ClassMethod DirectoryContainsPython(
	outer As %String,
	inner As %String) As %Boolean [ Language = python ]
{
    import os

    def same(a, b):
        statA = os.stat(a)
        statB = os.stat(b)
        # An inode of 0 means the filesystem has no file IDs, so every file would compare equal.
        if statA.st_ino == 0 or statB.st_ino == 0:
            raise OSError("Filesystem does not report file IDs")
        return (statA.st_dev, statA.st_ino) == (statB.st_dev, statB.st_ino)

    if not os.path.isdir(outer):
        return False
    path = os.path.abspath(inner)
    while True:
        if os.path.exists(path) and same(outer, path):
            return True
        parent = os.path.dirname(path)
        if parent == path:
            return False
        path = parent
}

/// Runs <var>command</var>, a ROBOCOPY command $list, and throws if it fails. ROBOCOPY exits with
/// 0-7 on success and 8 or higher on failure. A command that never ran has no return code and fails.
ClassMethod RunRobocopy(
	command As %List,
	ByRef stdout)
{
    set sc = ##class(%IPM.Utils.Module).RunCommand(, command, .stdout, , .returnCode)
    if $$$ISERR(sc) && ($get(returnCode) '= "") && (returnCode < 8) {
        set sc = $$$OK
    }
    $$$ThrowOnError(sc)
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

/// Returns 1 if path is under installDir but not under dataDir. Copies there can fail, because the
/// install directory can be read-only, for example in containers with durable %SYS.
/// Returns 0 when the two directories are the same, because the install directory then holds the instance's
/// data and is writable.
/// <example>
/// // Returns 1
/// write ##class(%IPM.Utils.File).IsInInstallDirectoryOnly("/usr/irissys/csp/myapp/", "/usr/irissys/", "/durable/iris/")
/// // Returns 0
/// write ##class(%IPM.Utils.File).IsInInstallDirectoryOnly("/usr/irissys/csp/myapp/", "/usr/irissys/", "/usr/irissys/")
/// </example>
ClassMethod IsInInstallDirectoryOnly(
	path As %String,
	installDir As %String = {$system.Util.InstallDirectory()},
	dataDir As %String = {$system.Util.DataDirectory()}) As %Boolean
{
    set path = ..NormalizeForComparison(path)
    set dataDir = ..NormalizeForComparison(dataDir)
    set installDir = ..NormalizeForComparison(installDir)
    return ($extract(path, 1, $length(installDir)) = installDir) && ($extract(path, 1, $length(dataDir)) '= dataDir)
}

/// Writes a warning if target, a file or directory that resource is about to copy into, passes
/// IsInInstallDirectoryOnly.
ClassMethod WarnIfInInstallDirectory(
	target As %String,
	resource As %IPM.Storage.ResourceReference)
{
    if '..IsInInstallDirectoryOnly(target) {
        return
    }
    set message = "WARNING: "_resource.Module.Name_" resource "_resource.Name_" copies to "_target_", which is in the install directory and can be read-only."
    write !, $$$FormattedLine($$$Yellow, message)
}

}
