/// Resource processor to automatically export messages in given list of domains to a particular file after compilation.
/// This works with a resource like /localize/MessageFileName.xml (Domains attribute required; resource name used as export target), or
/// MyPackage.Errors.LOC (Filename attribute required; Domains populated automatically from the message file)
/// For .LOC resources, the default resource processor class (%IPM.ResourceProcessor.Default.LocalizedMessages) should be used instead.
Class %IPM.ResourceProcessor.LocalizationExport Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Exports messages for localization after the module is compiled.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Domains,Filename";

/// Comma-separated list of domains to export to the specified file. For .LOC documents, this is determined automatically and is not overridable.
Property Domains As %String(MAXLEN = "");

/// Filename to export to. For .LOC documents, this is required; otherwise, this is set to the resource name and is not overridable.
Property Filename As %String(MAXLEN = 255);

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tIsLoc = ($Piece(..ResourceReference.Name,".",*) = "LOC")
		If tIsLoc {
			Set ..Domains = ..GetDomainsForResource()
		} Else {
			Set ..Filename = ..ResourceReference.Name
		}
		
		Set tSC = ##super(pPhase,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pPhase = "Activate") {
			Set tExportDir = ..ResourceReference.Module.Root
			If (tExportDir = "") {
				// No-op in this case.
				Quit
			}
			
			// This is only an error at this stage.
			If (..Domains = "") {
				If tIsLoc {
					// No-op
					Quit
				}
				Set tSC = $$$ERROR($$$PropertyRequired,"Domains")
				Quit
			}
			If (..Filename '= "") {
				Set tExportFile = ##class(%File).NormalizeFilename(tExportDir_"/"_..Filename)
			} ElseIf ($Extract(..ResourceReference.Name) = "/") {
				Set tExportFile = ##class(%File).NormalizeFilename(tExportDir_..ResourceReference.Name)
			} Else {
				$$$ThrowStatus($$$ERROR($$$PropertyRequired,"Filename"))
			}
			If tVerbose {
				Write !,"Exporting messages for '",..Domains,"' domain(s) to ",tExportFile
			}
			Set tDirectory = ##class(%Library.File).GetDirectory(tExportFile)
			If '##class(%Library.File).DirectoryExists(tDirectory) {
				$$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(tDirectory))
			}
			Set tSC=$$ExportDomainList^%occMessages(tExportFile,..Domains)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to 
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	If (..Filename = "") && ($Extract(..ResourceReference.Name) '= "/") {
		// If we're using a database resource as a source, Filename is required.
		Set tSC = $$$ERROR($$$PropertyRequired,"Filename")
	}
	Quit tSC
}

/// Returns a comma-separated list of domains for the specified resource.
Method GetDomainsForResource() As %String
{
	Set tDomains = ""
	Set tExt = $Piece(..ResourceReference.Name,".",*)
	If ($Extract(..ResourceReference.Name) '= "/") && (tExt = "LOC") {
		// Get list of domains in .LOC file. We'll ignore errors, since the file may not be loaded yet.
		#dim tMsgFile As %IPM.ResourceProcessor.LocalizationExport.MsgFile
		Set tSC = ..GetMessageFile(..ResourceReference.Name,.tMsgFile)
		If $$$ISOK(tSC) {
			Set tDomain = ""
			For {
				Do tMsgFile.Domains.GetNext(.tDomain)
				If (tDomain = "") {
					Quit
				}
				Set tDomains = tDomains_$ListBuild(tDomain)
			}
		}
	}
	Quit $ListToString(tDomains)
}

/// <var>pDocName</var> is the full document name (including the .LOC extension) <br />
/// <var>pFileObject</var> is an instance of %IPM.ResourceProcessor.LocalizationExport.MsgFile corresponding to the document's content. <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod GetMessageFile(pDocName As %String, Output pFileObject As %IPM.ResourceProcessor.LocalizationExport.MsgFile) As %Status
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
		Do tReader.Correlate("MsgFile","%IPM.ResourceProcessor.LocalizationExport.MsgFile")
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
/// <var>pFileObject</var> is an instance of %IPM.ResourceProcessor.LocalizationExport.MsgFile corresponding to the document's content. <br />
/// If <var>pCompile</var> is set to 1 (by default, it is), then the file will be compiled after save. <br />
/// <var>pConsoleOutput</var> is an integer-subscripted array of lines of output from everything that happened. <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod SaveMessageFile(pDocName As %String, pFileObject As %IPM.ResourceProcessor.LocalizationExport.MsgFile, pCompile As %Boolean = 1, Output pConsoleOutput) As %Status
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
			Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)
			Set tSC = tRtn.Compile("ckvd")
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If $Data(tCookie) {
		Do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pConsoleOutput)
	}
	Quit tSC
}

/// Utility method to export an error message document (with a given name).
ClassMethod Export(pDocName As %String, pSource As %IPM.ResourceProcessor.LocalizationExport.MsgFile, Output pSourceControlOutput) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		New %SourceControl
		
		Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)
		
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
	Do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pSourceControlOutput)
	Quit tSC
}

}
