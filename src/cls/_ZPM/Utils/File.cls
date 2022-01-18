/// Wraps a set of more robust file operations
Class %ZPM.Utils.File
{

/// Create this directory and all the parent directories if they do not exist. This differs from
/// <method>CreateDirectory</method> as that method only creates one new directory where as
/// this will create the entire chain of directories. Returns true if it succeeds and false otherwise.
/// Pass <var>return</var> by reference to obtain the low level return value in case of errors
ClassMethod CreateDirectoryChain(pName As %String) As %Status
{
	Set tSC = $$$OK
	If '##class(%Library.File).CreateDirectoryChain(pName,.tReturn) {
		Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",pName,$zu(209,tReturn)))
	}
	Quit tSC
}

ClassMethod RemoveDirectoryTree(pRoot As %String) As %Status
{
	New %objlasterror
	Set tSC = $$$OK
	Set tBadSC = $$$ERROR($$$GeneralError,$$$FormatText("Error removing directory %1",pRoot))
	Try {
		If $$$isUNIX {
			Kill %objlasterror
			If '##class(%Library.File).RemoveDirectoryTree(pRoot) {
				Set tLastErr = $Get(%objlasterror)
				Set tSC = $$$EMBEDSC(tBadSC,tLastErr)
			}
		} ElseIf $$$isWINDOWS {
			// Handle long directories
			// Based on https://superuser.com/a/620474/227743
			// On InterSystems IRIS, TempFilename() creates the temp file; append "dir" to ensure uniqueness.
			Set tTempFileName = ##class(%Library.File).TempFilename()
			Set tEmptyDir = ##class(%Library.File).NormalizeDirectory(tTempFileName_"dir")
			Try {
				If '##class(%Library.File).CreateDirectory(tEmptyDir,.tReturn) {
					Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",tEmptyDir,$zu(209,tReturn)))
					$$$ThrowStatus(tSC)
				}
				Set pRoot = ##class(%Library.File).NormalizeDirectory(pRoot)
				
				Set tCmd = "ROBOCOPY "_tEmptyDir_" "_pRoot_" /MIR"
				Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).RunCommandViaZF(tCmd,.tLog,.tErr)
			} Catch e {
				Set tSC = e.AsStatus()
			}
			
			// Cleanup code - call even if RunCommandViaZF fails; no need to check results.
			Do ##class(%Library.File).RemoveDirectory(pRoot)
			Do ##class(%Library.File).RemoveDirectory(tEmptyDir)
			Do ##class(%Library.File).Delete(tTempFileName)
		}
	} Catch e {
		Set tSC = $$$EMBEDSC(tBadSC,e.AsStatus())
	}
	Quit tSC
}

/// Copy a file <var>pSource</var> to file <var>pDest</var>. <br />
/// Parameter <var>pDeleteBeforeCopy</var> may be used to specify that if the target file already exists then it should be deleted before being overwritten 
/// with the source file. The default is 0 or false.
ClassMethod CopyFile(pSource As %String, pDest As %String, pDeleteBeforeCopy As %Boolean = 0) As %Status
{
	New %objlasterror
	Set tSC = $$$OK
	If '##class(%Library.File).CopyFile(pSource,pDest,pDeleteBeforeCopy,.tOSErr) {
		Set tInnerSC = $Get(%objlasterror,$$$OK)
		Set tOSMessage = $zu(209,tOSErr)
		Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying file %1 to %2: %3",pSource,pDest,tOSMessage))
		If $$$ISERR(tInnerSC) {
			// Also embed the root-cause error from %objlasterror if present (e.g., if pDeleteBeforeCopy was 1 and there was an error deleting the file)
			Set tSC = $$$EMBEDSC(tSC,tInnerSC)
		}
	}
	Quit tSC
}

ClassMethod CopyDir(pSource As %String, pDest As %String, pDeleteFirst As %Boolean = 1, pVerbose As %Boolean = 0) As %Status
{
	New %objlasterror
	Set tSC = $$$OK
	Set tBadSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying directory %1 to %2",pSource,pDest))
	Try {
		If $$$isUNIX {
			Kill %objlasterror
			If '##class(%Library.File).CopyDir(pSource,pDest,1,.tCreated,pDeleteFirst) {
				Set tLastErr = $Get(%objlasterror)
				Set tSC = $$$EMBEDSC(tBadSC,tLastErr)
			}
		} ElseIf $$$isWINDOWS {
			If pDeleteFirst {
				Set tSC = ..RemoveDirectoryTree(pDest)
				If $$$ISERR(tSC) {
					Quit
				}
			}
			Set pSource = ##class(%Library.File).NormalizeDirectory(pSource)
			Set pDest = ##class(%Library.File).NormalizeDirectory(pDest)
			Set tCmd = "ROBOCOPY "_pSource_" "_pDest_" /E"
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).RunCommandViaZF(tCmd,.tLog,.tErr)
      If (pVerbose) {
        For i=1:1:$Get(tLog) {
          Write tLog(i),!
        }
      }
		}
	} Catch e {
		Set tSC = $$$EMBEDSC(tBadSC,e.AsStatus())
	}
	Quit tSC
}

ClassMethod MakeDirectoryWriteable(pDirectory As %String, Output pCmd, Output pOutputLog, Output pErrLog) As %Status
{
	Set tSC = $$$OK
	Set pCmd = ""
	Try {
		Kill pOutputLog
		Kill pErrLog
		If $$$isWINDOWS {
			Set pCmd = "attrib -r "_##class(%Library.File).NormalizeDirectory(pDirectory)_"*.* /s"
		} ElseIf $$$isUNIX {
			Set pCmd = "chmod -R 775 "_##class(%Library.File).NormalizeDirectory(pDirectory)
		}
		Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).RunCommandViaZF(pCmd,.pOutputLog,.pErrLog)
		$$$ThrowOnError(tSC)
		if ($get(pErrLog(1))'="") {
			set error = pErrLog(1)
			Throw ##class(%Exception.General).%New(error)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod SetReadOnly(pFileOrDirectoryName As %String, pLeaveExisting As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		If '##class(%Library.File).SetReadOnly(pFileOrDirectoryName,.pLeaveExisting,.tReturn) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error making '%1' read-only: %2",pFileOrDirectoryName,$zu(209,tReturn)))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod SetWriteable(pFileName As %String, pWriteable As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		If '##class(%Library.File).SetWriteable(pFileName,.pWriteable,.tReturn) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error making '%1' writeable: %2",pFileName,$zu(209,tReturn)))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod FindFiles(pPath As %String, pWildcards As %String = "", Output pList) As %Integer
{
	Kill pList
	Set pList = 0
	Set fileSetRS = ##class(%File).FileSetFunc(##class(%File).NormalizeDirectory(pPath), pWildcards, , 1)
	While fileSetRS.%Next() {
		If (fileSetRS.Type = "D") {
			Do ..FindFiles(fileSetRS.Name, pWildcards, .tList)
			for i=1:1:tList {
				Set pList($i(pList)) = tList(i)
			}
		} Else {
			Set pList($i(pList)) = $LISTBUILD(fileSetRS.ItemName, fileSetRS.Name)
		}
	}

	Return pList
}

}
