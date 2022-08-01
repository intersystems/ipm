Class %ZPM.PackageManager.Developer.API.ErrorMessages
{

/// <var>pDocName</var> is the full document name (including the .LOC extension) <br />
/// <var>pFileObject</var> is an instance of %ZPM.PackageManager.Developer.ErrorMessages.MsgFile corresponding to the document's content. <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod GetMessageFile(pDocName As %String, Output pFileObject As %ZPM.PackageManager.Developer.ErrorMessages.MsgFile) As %Status
{
	Set tSC = $$$OK
	Set pFileObject = $$$NULLOREF
	Try {
		Set tRtn = ##class(%Library.RoutineMgr).%OpenId(pDocName)
		If (tRtn = $$$NULLOREF) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error message document '%1' does not exist.",pDocName))
			Quit
		}
		
		Set tReader = ##class(%XML.Reader).%New()
		Do tReader.Correlate("MsgFile","%ZPM.PackageManager.Developer.ErrorMessages.MsgFile")
		$$$ThrowOnError(tReader.OpenStream(tRtn.Code))
		
		Do tReader.Next(.pFileObject,.tSC)
		$$$ThrowOnError(tSC)
	} Catch e {
		Set pFileObject = $$$NULLOREF
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// <var>pDocName</var> is the full document name (including the .LOC extension) <br />
/// <var>pFileObject</var> is an instance of %ZPM.PackageManager.Developer.ErrorMessages.MsgFile corresponding to the document's content. <br />
/// If <var>pCompile</var> is set to 1 (by default, it is), then the file will be compiled after save. <br />
/// <var>pConsoleOutput</var> is an integer-subscripted array of lines of output from everything that happened. <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod SaveMessageFile(pDocName As %String, pFileObject As %ZPM.PackageManager.Developer.ErrorMessages.MsgFile, pCompile As %Boolean = 1, Output pConsoleOutput) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ..Export(pDocName, pFileObject, .pConsoleOutput)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pCompile) {
			Set tRtn = ##class(%Library.RoutineMgr).%OpenId(pDocName)
			If (tRtn = $$$NULLOREF) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error message document '%1' does not exist.",pDocName))
				Quit
			}
			Do ##class(%ZPM.PackageManager.Developer.Utils).BeginCaptureOutput(.tCookie)
			Set tSC = tRtn.Compile("ckvd")
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If $Data(tCookie) {
		Do ##class(%ZPM.PackageManager.Developer.Utils).EndCaptureOutput(tCookie,.pConsoleOutput)
	}
	Quit tSC
}

/// Utility method to export an error message document (with a given name).
ClassMethod Export(pDocName As %String, pSource As %ZPM.PackageManager.Developer.ErrorMessages.MsgFile, Output pSourceControlOutput) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		New %SourceControl
		
		Do ##class(%ZPM.PackageManager.Developer.Utils).BeginCaptureOutput(.tCookie)
		
		Do ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		
		Set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(pDocName,,.tIsEditable)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If 'tIsEditable {
			Set tSC = $$$ERROR($$$ItemNotCheckedOut,tDocName)
			Quit
		}
		
		// Use document API
		#dim tExportStream As %Stream.Object
		Set tSC = pSource.XMLExportToStream(.tExportStream,,"literal,indent")
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tRtn = ##class(%Library.RoutineMgr).%OpenId(pDocName)
		If (tRtn = $$$NULLOREF) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error message document '%1' does not exist.",pDocName))
			Quit
		}
		Do tRtn.Code.ImportFromXML(tExportStream)
		
		Set tSC = tRtn.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	
	// Ensure I/O redirection ends.
	Do ##class(%ZPM.PackageManager.Developer.Utils).EndCaptureOutput(tCookie,.pSourceControlOutput)
	Quit tSC
}

}
