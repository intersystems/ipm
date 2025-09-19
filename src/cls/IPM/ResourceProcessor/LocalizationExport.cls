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

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        set tIsLoc = ($piece(..ResourceReference.Name,".",*) = "LOC")
        if tIsLoc {
            set ..Domains = ..GetDomainsForResource()
        } else {
            set ..Filename = ..ResourceReference.Name
        }

        set tSC = ##super(pPhase,.pParams)
        if $$$ISERR(tSC) {
            quit
        }

        if (pPhase = "Activate") {
            set tExportDir = ..ResourceReference.Module.Root
            if (tExportDir = "") {
                // No-op in this case.
                quit
            }

            // This is only an error at this stage.
            if (..Domains = "") {
                if tIsLoc {
                    // No-op
                    quit
                }
                set tSC = $$$ERROR($$$PropertyRequired,"Domains")
                quit
            }
            if (..Filename '= "") {
                set tExportFile = ##class(%File).NormalizeFilename(tExportDir_"/"_..Filename)
            } elseif ($extract(..ResourceReference.Name) = "/") {
                set tExportFile = ##class(%File).NormalizeFilename(tExportDir_..ResourceReference.Name)
            } else {
                $$$ThrowStatus($$$ERROR($$$PropertyRequired,"Filename"))
            }
            if tVerbose {
                write !,"Exporting messages for '",..Domains,"' domain(s) to ",tExportFile
            }
            set tDirectory = ##class(%Library.File).GetDirectory(tExportFile)
            if '##class(%Library.File).DirectoryExists(tDirectory) {
                $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(tDirectory))
            }
            set tSC=$$ExportDomainList^%occMessages(tExportFile,..Domains)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = $$$OK
    if (..Filename = "") && ($extract(..ResourceReference.Name) '= "/") {
        // If we're using a database resource as a source, Filename is required.
        set tSC = $$$ERROR($$$PropertyRequired,"Filename")
    }
    quit tSC
}

/// Returns a comma-separated list of domains for the specified resource.
Method GetDomainsForResource() As %String
{
    set tDomains = ""
    set tExt = $piece(..ResourceReference.Name,".",*)
    if ($extract(..ResourceReference.Name) '= "/") && (tExt = "LOC") {
        // Get list of domains in .LOC file. We'll ignore errors, since the file may not be loaded yet.
        #dim tMsgFile As %IPM.ResourceProcessor.LocalizationExport.MsgFile
        set tSC = ..GetMessageFile(..ResourceReference.Name,.tMsgFile)
        if $$$ISOK(tSC) {
            set tDomain = ""
            for {
                do tMsgFile.Domains.GetNext(.tDomain)
                if (tDomain = "") {
                    quit
                }
                set tDomains = tDomains_$listbuild(tDomain)
            }
        }
    }
    quit $listtostring(tDomains)
}

/// <var>pDocName</var> is the full document name (including the .LOC extension) <br />
/// <var>pFileObject</var> is an instance of %IPM.ResourceProcessor.LocalizationExport.MsgFile corresponding to the document's content. <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod GetMessageFile(
	pDocName As %String,
	Output pFileObject As %IPM.ResourceProcessor.LocalizationExport.MsgFile) As %Status
{
    set tSC = $$$OK
    set pFileObject = $$$NULLOREF
    try {
        set tRtn = ##class(%Library.RoutineMgr).%OpenId(pDocName,0)
        if (tRtn = $$$NULLOREF) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error message document '%1' does not exist.",pDocName))
            quit
        }

        set tReader = ##class(%XML.Reader).%New()
        do tReader.Correlate("MsgFile","%IPM.ResourceProcessor.LocalizationExport.MsgFile")
        $$$ThrowOnError(tReader.OpenStream(tRtn.Code))

        do tReader.Next(.pFileObject,.tSC)
        $$$ThrowOnError(tSC)
    } catch e {
        set pFileObject = $$$NULLOREF
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// <var>pDocName</var> is the full document name (including the .LOC extension) <br />
/// <var>pFileObject</var> is an instance of %IPM.ResourceProcessor.LocalizationExport.MsgFile corresponding to the document's content. <br />
/// If <var>pCompile</var> is set to 1 (by default, it is), then the file will be compiled after save. <br />
/// <var>pConsoleOutput</var> is an integer-subscripted array of lines of output from everything that happened. <br />
/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod SaveMessageFile(
	pDocName As %String,
	pFileObject As %IPM.ResourceProcessor.LocalizationExport.MsgFile,
	pCompile As %Boolean = 1,
	Output pConsoleOutput) As %Status
{
    set tSC = $$$OK
    try {
        set tSC = ..Export(pDocName, pFileObject, .pConsoleOutput)
        if $$$ISERR(tSC) {
            quit
        }

        if (pCompile) {
            set tRtn = ##class(%Library.RoutineMgr).%OpenId(pDocName,0)
            if (tRtn = $$$NULLOREF) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error message document '%1' does not exist.",pDocName))
                quit
            }
            do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)
            set tSC = tRtn.Compile("ckvd")
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if $data(tCookie) {
        do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pConsoleOutput)
    }
    quit tSC
}

/// Utility method to export an error message document (with a given name).
ClassMethod Export(
	pDocName As %String,
	pSource As %IPM.ResourceProcessor.LocalizationExport.MsgFile,
	Output pSourceControlOutput) As %Status [ Private ]
{
    set tSC = $$$OK
    try {
        new %SourceControl

        do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)

        do ##class(%Studio.SourceControl.Interface).SourceControlCreate()

        set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(pDocName,,.tIsEditable)
        if $$$ISERR(tSC) {
            quit
        }

        if 'tIsEditable {
            set tSC = $$$ERROR($$$ItemNotCheckedOut,tDocName)
            quit
        }

        // Use document API
        #dim tExportStream As %Stream.Object
        set tSC = pSource.XMLExportToStream(.tExportStream,,"literal,indent")
        if $$$ISERR(tSC) {
            quit
        }

        set tRtn = ##class(%Library.RoutineMgr).%OpenId(pDocName)
        if (tRtn = $$$NULLOREF) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error message document '%1' does not exist.",pDocName))
            quit
        }
        do tRtn.Code.ImportFromXML(tExportStream)

        set tSC = tRtn.%Save()
        if $$$ISERR(tSC) {
            quit
        }
    } catch e {
        set tSC = e.AsStatus()
    }

    // Ensure I/O redirection ends.
    do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pSourceControlOutput)
    quit tSC
}

}
