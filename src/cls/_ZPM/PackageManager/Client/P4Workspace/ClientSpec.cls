Include %ZPM.PackageManager.Common

/// Captures important information about the current Perforce workspace's client specification - the root and client view.
/// This is used to provide an equivalent to "p4 where" when Perforce is unavailable.
/// Property names should match the field names in the output from "p4 client -o"; this class may also be extended at some point
/// to allow editing of the current workspace view.
Class %ZPM.PackageManager.Client.P4Workspace.ClientSpec Extends %SerialObject
{

/// The name of the Perforce workspace
Property Client As %String(MAXLEN = 255);

/// The filesystem root of the Perforce workspace
Property Root As %String(MAXLEN = 255);

/// Map of (depot path) to (workspace-relative path)
Property View As array Of %String(MAXLEN = 255);

/// Populates an instance of this object for the current workspace.
Method UpdateForCurrentWorkspace(Output pModified As %Boolean) As %Status
{
	Set tSC = $$$OK
	Set pModified = 0
	Try {
		Set tSC = ##class(%Studio.SourceControl.ISC).P4Cmd("client -o",.tOutput)
		$$$ThrowOnError(tSC)
		
		// Ensure Root is normalized (with trailing slash)
		If ($Get(tOutput(1,"Root")) '= "") {
			Set tOutput(1,"Root") = ##class(%Library.File).NormalizeDirectory(tOutput(1,"Root"))
		}
		
		For tProperty = "Client","Root" {
			If $Property($This,tProperty) '= tOutput(1,tProperty) {
				Set pModified = 1
				Set $Property($This,tProperty) = tOutput(1,tProperty)
			}
		}
		
		// Build map of view before any changes were made.
		Set tOldViewKey = ""
		For {
			Set tOldViewPath = ..View.GetNext(.tOldViewKey)
			If (tOldViewKey = "") {
				Quit
			}
			Set tOldView(tOldViewKey) = tOldViewPath
		}
		
		// View lines have key View0...ViewN
		Set tKey = "View"
		For {
			Set tKey = $Order(tOutput(1,tKey),1,tPaths)
			If (tKey = "") || ($Extract(tKey,1,4) '= "View") {
				Quit
			}
			
			Set tDepotPath = $Piece(tPaths," ")
			Set tWorkspacePath = $Piece(tPaths," ",2)
			
			// If missing or changed...
			If '$Data(tOldView(tDepotPath),tOldWorkspacePath) || (tOldWorkspacePath '= tWorkspacePath) {
				Set pModified = 1
				$$$ThrowOnError(..View.SetAt(tWorkspacePath,tDepotPath))
			}
			Kill tOldView(tDepotPath)
		}
		
		// Anything removed from the view?
		If $Data(tOldView) {
			Set pModified = 1
			Set tOldViewKey = ""
			For {
				Set tOldViewKey = $Order(tOldView(tOldViewKey))
				If (tOldViewKey = "") {
					Quit
				}
				Do ..View.RemoveAt(tOldViewKey)
			}
		}
		
		Set pModified = pModified
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method AddToView(pDepotPath As %String, pMapTo As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..View.GetAt(pDepotPath) = "") {
			Set tMapTo = $Get(pMapTo,$Replace(pDepotPath,"//","//"_..Client_"/"))
			Do ..View.SetAt(tMapTo,pDepotPath)
		} Else {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("%1 is already in the client view.",pDepotPath))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method SaveView() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tTempFile = ##class(%Stream.FileCharacter).%New()
		Set tTempFile.Filename = ##class(%Library.File).TempFilename()
		Set tTempFile.RemoveOnClose = 1
		
		Set tSC = ##class(%Studio.SourceControl.ISC).RunCmd("p4 client -o",.tOutput,0)
		$$$ThrowOnError(tSC)
		
		Set tViewFound = 0
		For tLineIndex=1:1:$Get(tOutput) {
			Set tLine = tOutput(tLineIndex)
			Do tTempFile.WriteLine(tLine)
			If (tLine = "View:") {
				Set tViewFound = 1
				Quit
			}
		}
		
		If 'tViewFound {
			Set tSC = $$$ERROR($$$GeneralError,"Unexpected output from p4 client -o")
			$$$ThrowStatus(tSC)
		}
		
		Set tViewKey = ""
		For {
			Set tViewPath = ..View.GetNext(.tViewKey)
			If (tViewKey = "") {
				Quit
			}
			Do tTempFile.WriteLine($c(9)_tViewKey_" "_tViewPath)
		}
		Do tTempFile.WriteLine() //Extra newline at the end
		
		Set tSC = ##class(%Studio.SourceControl.ISC).RunCmd("p4 client -i < "_tTempFile.Filename,,0)
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Given a file/folder path in the depot (<var>pDepotPath</var>), returns in <var>pLocalPath</var> the corresponding filesystem path.
Method GetLocalPathForDepot(pDepotPath As %String, Output pLocalPath As %String) As %Status
{
	Set tSC = $$$OK
	Set pLocalPath = ""
	Try {
		Set tFound = 0
		Set tDepotKey = pDepotPath
		For {
			// Get previous subscript; this will hit more specific matches first.
			Set tWorkspacePath = ..View.GetPrevious(.tDepotKey)
			If (tDepotKey = "") {
				Quit
			}
			
			//Strip trailing ...
			Set tWorkspacePath = $$$ZPMStripP4Dots(tWorkspacePath)
			Set tDepotPath = $$$ZPMStripP4Dots(tDepotKey)
			If ($Extract(pDepotPath,1,$Length(tDepotPath)) = tDepotPath) {
				Set tFound = 1
				Quit
			}
		}
		
		If 'tFound {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("File(s) not in client view: %1",pDepotPath))
			$$$ThrowStatus(tSC)
		}
		
		Set tRoot = ##class(%Library.File).NormalizeDirectory(..Root)
		Set pLocalPath = tRoot_$Extract(tWorkspacePath,1+$Length("//"_..Client_"/"),*)_$Extract(pDepotPath,1+$Length(tDepotPath),*)
		Set pLocalPath = ##class(%Library.File).NormalizeFilename(pLocalPath)
	} Catch e {
		Set pLocalPath = ""
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Given a local filepath (<var>pLocalPath</var>), returns in <var>pDepotPath</var> the corresponding depot path.
Method GetDepotPathForLocal(pLocalPath As %String, Output pDepotPath As %String) As %Status
{
	Set tSC = $$$OK
	Set pDepotPath = ""
	Try {
		Set pLocalPath = ##class(%Library.File).NormalizeFilename(pLocalPath)
		Set tRoot = ##class(%Library.File).NormalizeFilename(..Root)
		
		If $Extract(pLocalPath,1,$Length(tRoot)) '= tRoot {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("File(s) not in workspace root: %1",tRoot))
			$$$ThrowStatus(tSC)
		}
		
		Set tRelativePath = $Extract(pLocalPath,$Length(tRoot)+1,*)
		Set tRelativePath = "//"_..Client_$Replace(tRelativePath,"\","/")
		
		// Build reverse of view.
		Set tDepotKey = ""
		For {
			Set tWorkspacePath = ..View.GetNext(.tDepotKey)
			If (tDepotKey = "") {
				Quit
			}
			
			Set tWorkspaceMap(tWorkspacePath) = tDepotKey
		}
		
		// Find correct workspace mapping
		Set tFound = 0
		Set tWorkspaceKey = tRelativePath
		For {
			// Get previous subscript; this will hit more specific matches first.
			Set tWorkspaceKey = $Order(tWorkspaceMap(tWorkspaceKey),-1,tDepotPath)
			If (tWorkspaceKey = "") {
				Quit
			}
			
			//Strip trailing ...
			Set tWorkspacePath = $$$ZPMStripP4Dots(tWorkspaceKey)
			Set tDepotPath = $$$ZPMStripP4Dots(tDepotPath)
			If ($Extract(tRelativePath,1,$Length(tWorkspacePath)) = tWorkspacePath) {
				Set tFound = 1
				Quit
			}
		}
		
		If 'tFound {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("File(s) not in client view: %1",pLocalPath))
			$$$ThrowStatus(tSC)
		}
		
		Set pDepotPath = $Replace(tRelativePath,tWorkspacePath,tDepotPath)
	} Catch e {
		Set pDepotPath = ""
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Storage Default
{
<Data name="ClientSpecState">
<Value name="1">
<Value>Client</Value>
</Value>
<Value name="2">
<Value>Root</Value>
</Value>
<Value name="3">
<Value>View</Value>
</Value>
</Data>
<State>ClientSpecState</State>
<StreamLocation>^%ZPM.Dev.P4ClientSpecS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
