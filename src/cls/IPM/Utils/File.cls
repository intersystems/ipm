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
        set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",pName,$zutil(209,tReturn)))
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
            set pCmd = $listbuild("attrib","-r"_##class(%Library.File).NormalizeDirectory(pDirectory)_"*.*","/s")
            set stdout = ""
        } elseif $$$isUNIX {
            set pCmd = $listbuild("chmod","-R","775",##class(%Library.File).NormalizeDirectory(pDirectory))
        }
        set tSC = ##class(%IPM.Utils.Module).RunCommand(, pCmd,.stdout)
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

}
