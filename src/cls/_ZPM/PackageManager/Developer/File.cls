/// Wraps a set of more robust file operations
Class %ZPM.PackageManager.Developer.File
{

ClassMethod RemoveDirectoryTree(pRoot As %String) As %Status
{
	New %objlasterror
	Set tSC = $$$OK
	Set tBadSC = $$$ERROR($$$GeneralError,$$$FormatText("Error removing directory %1",pRoot))
	Try {
		If $$$isUNIX {
			Kill %objlasterror
			If '##class(%File).RemoveDirectoryTree(pRoot) {
				Set tLastErr = $Get(%objlasterror)
				Set tSC = $$$EMBEDSC(tBadSC,tLastErr)
			}
		} ElseIf $$$isWINDOWS {
			// Handle long directories
			// Based on https://superuser.com/a/620474/227743
			Set tEmptyDir = ##class(%File).NormalizeDirectory(##class(%File).TempFilename()_"dir")
			If '##class(%File).CreateDirectory(tEmptyDir,.tReturn) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",tEmptyDir,$zu(209,tReturn)))
				Quit
			}
			Set pRoot = ##class(%File).NormalizeDirectory(pRoot)
			
			Set tCmd = "ROBOCOPY "_tEmptyDir_" "_pRoot_" /MIR"
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).RunCommandViaZF(tCmd,.tLog,.tErr)
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Don't bother checking if these succeed - dirs will be empty so it always will
			Do ##class(%File).RemoveDirectory(pRoot)
			Do ##class(%File).RemoveDirectory(tEmptyDir) 
		}
	} Catch e {
		Set tSC = $$$EMBEDSC(tBadSC,e.AsStatus())
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
			If '##class(%File).CopyDir(pSource,pDest,1,.tCreated,pDeleteFirst) {
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
			Set pSource = ##class(%File).NormalizeDirectory(pSource)
			Set pDest = ##class(%File).NormalizeDirectory(pDest)
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
			Set pCmd = "attrib -r "_##class(%File).NormalizeDirectory(pDirectory)_"*.* /s"
		} ElseIf $$$isUNIX {
			Set pCmd = "chmod -R 775 "_##class(%File).NormalizeDirectory(pDirectory)
		}
		Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).RunCommandViaZF(pCmd,.pOutputLog,.pErrLog)
		$$$ThrowOnError(tSC)
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
