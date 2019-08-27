/// Resource processor to automatically export messages in given list of domains to a particular file after compilation.
/// This works with a resource like /localize/MessageFileName.xml (Domains attribute required; resource name used as export target), or
/// MyPackage.Errors.LOC (Filename attribute required; Domains populated automatically from the message file)
/// For .LOC resources, the default resource processor class (%ZPM.PackageManager.Developer.Processor.Default.LocalizedErrorMessages) should be used instead.
Class %ZPM.PackageManager.Developer.Processor.LocalizationExport Extends %ZPM.PackageManager.Developer.Processor.Abstract
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
			// This is only an error at this stage.
			If (..Domains = "") {
				Set tSC = $$$ERROR($$$PropertyRequired,"Domains")
			}
			
			Set tExportDir = ..ResourceReference.Module.Root
			If (..Filename '= "") {
				Set tExportFile = ##class(%File).NormalizeFilename(tExportDir_"/"_..Filename)
			} ElseIf ($Extract(..ResourceReference.Name) = "/") {
				Set tExportFile = ##class(%File).NormalizeFilename(tExportDir_..ResourceReference.Name)
			} Else {
				Set tSC = $$$ERROR($$$PropertyRequired,"Filename")
			}
			If tVerbose {
				Write !,"Exporting messages for '",..Domains,"' domain(s) to ",tExportFile
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
		#dim tMsgFile As %ZPM.PackageManager.Developer.ErrorMessages.MsgFile
		Set tSC = ##class(%ZPM.PackageManager.Developer.API.ErrorMessages).GetMessageFile(..ResourceReference.Name,.tMsgFile)
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

}
