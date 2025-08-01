Class %IPM.ResourceProcessor.FileCopy Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Copies the specified directory or file  (the resource name) to a specific target location (InstallDirectory) during the Activate phase.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Name,InstallDirectory,Overlay,CSPApplication,Defer";

Property Name As %String(MAXLEN = "") [ Aliases = {SourceDirectory} ];

/// Path to which the directory or file (a full filename, in that case) should be copied upon installation; may contain expressions.
Property InstallDirectory As %String(MAXLEN = "") [ Aliases = {Target,Dest}, Required ];

/// If true, the files should be added to the target location (rather than fully replacing it, causing other files there to be deleted)
/// Relevant for directories only.
Property Overlay As %Boolean;

/// Optional hint to source control class: which CSP application path do these files map to?
/// For use cases where the CSPApplication resource processor is too heavy-handed - e.g., /csp/xslt
/// Of course, this is only relevant for files that need to be copied to a CSP application.
/// Note that this may be a full CSP file path, not only the name of a CSP application.
Property CSPApplication As %String(MAXLEN = "");

/// If true, the files will be copied at the end of the Activate phase rather than at the beginning.
/// The default is to copy the files at the beginning of the Activate phase.
/// Use this for build artifacts.
Property Defer As %Boolean [ InitialExpression = 0 ];

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tVerbose = $get(pParams("Verbose"))
    // Default implementation: call %ValidateObject to validate attributes
    set tSC = $$$OK
    try {
        set tSC = ##super(pPhase,.pParams)
        if $$$ISERR(tSC) {
            quit
        }

        if (pPhase = "Activate") && (..InstallDirectory '= "") && ('..Defer) {
            set tSource = ..GetSource()
            set tTarget = ..InstallDirectory
            set tSC = ..DoCopy(tSource, tTarget, .pParams)
            if $$$ISERR(tSC) {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tVerbose = $get(pParams("Verbose"))
    set tSC = $$$OK
    try {
        set tSC = ##super(pPhase,.pParams)
        if $$$ISERR(tSC) {
            quit
        }

        if (pPhase = "Activate") && (..InstallDirectory '= "") && (..Defer) {
            set tSource = ..GetSource()
            set tTarget = ..InstallDirectory
            set tSC = ..DoCopy(tSource, tTarget, .pParams)
            if $$$ISERR(tSC) {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnBeforeArtifact(
	pExportDirectory As %String,
	pWorkingDirectory As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        if (pExportDirectory = pWorkingDirectory) {
            quit
        }

        write !,"[OnBeforeArtifact] "_..ResourceReference.Name
        if '..ResourceReference.Deploy {
            set tSC = ##class(%IPM.Utils.File).CopyDir(
                pExportDirectory_..ResourceReference.Name,
                pWorkingDirectory_..ResourceReference.Name)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method NormalizeNames(
	ByRef pSource As %String,
	ByRef pTarget As %String,
	Output pTargetDir,
	Output pAsFile As %Boolean)
{
    set pAsFile = 0
    set normalizedSourceDir = ##class(%File).NormalizeDirectory(pSource)
    if ("\/"[$extract(pSource, *))
        || ((normalizedSourceDir'="")
        && ##class(%File).DirectoryExists(normalizedSourceDir)) {
        set pSource = normalizedSourceDir
        set pTarget = ##class(%File).NormalizeDirectory(pTarget)
        set pTargetDir = pTarget
    } else {
        set pAsFile = 1
        set pSource = ##class(%File).NormalizeFilename(pSource)
        if ("\/"[$extract(pTarget, *)) {
            set pTargetDir = ##class(%File).NormalizeDirectory(pTarget)
            set pTarget = ##class(%File).NormalizeFilename(##class(%File).GetFilename(pSource), pTargetDir)
        } else {
            set pTarget = ##class(%File).NormalizeFilename(pTarget)
            set pTargetDir = ##class(%File).ParentDirectoryName(pTarget)
        }
    }
}

/// Prefixes the path to the module root if it does not start with a $ variable
Method GetSource()
{
    set prefix = $extract(..ResourceReference.Attributes.GetAt("SourceDirectory"), 0, 2)
    if ((prefix = "{$") || (prefix = "${")) {
        return $case(..SourceDirectory,
            "": ..ResourceReference.Module.Root _ ..ResourceReference.Name,
            : ..SourceDirectory
        )
    }
    return ..ResourceReference.Module.Root _
        $case(..SourceDirectory,
            "": ..ResourceReference.Name,
            : ..SourceDirectory
        )
}

Method DoCopy(
	tSource,
	tTarget,
	pParams)
{
    set tVerbose = $get(pParams("Verbose"))
    set tSC = $$$OK
    try {
        do ..NormalizeNames(.tSource, .tTarget, .tTargetDir, .copyAsFile)

        if '##class(%File).DirectoryExists(tTargetDir) {
            if '##class(%File).CreateDirectoryChain(tTargetDir,.tReturn) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",tTargetDir,$zutil(209,tReturn)))
                quit
            }
        }

        write:tVerbose !,"Copying ",tSource," to ",tTarget
        if (copyAsFile) {
            if '##class(%File).Exists(tSource) {
                set tSC = $$$ERROR($$$GeneralError, "Source file does not exist: "_tSource)
                quit
            }
            if '##class(%File).CopyFile(tSource, tTarget, 1, .return) {
                set tSC = $$$ERROR($$$GeneralError, "File not copied: " _ return)
                quit
            }
        } else {
            write:tVerbose " as directory "
            set tSC = ##class(%IPM.Utils.File).CopyDir(tSource,tTarget,'..Overlay)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    set tVerbose = $get(pParams("Verbose"))
    set pItemHandled = 1
    set tSource = ..GetSource()
    set tTarget = pParams("ModuleExportPath")
    quit ..DoCopy(tSource, tTarget, .pParams)
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set tVerbose = $get(pParams("Verbose"))
    if (pPhase = "Clean") {
        set pResourceHandled = 1
        set tSource = ..ResourceReference.Module.Root _ ..Name
        set tTarget = ..InstallDirectory
        do ..NormalizeNames(.tSource, .tTarget, .tTargetDir, .copyAsFile)
        write:tVerbose !,"Deleting ",tTarget
        if copyAsFile {
            do ##class(%File).Delete(tTarget)
        } else {
            do ##class(%File).RemoveDirectoryTree(tTarget)
        }
    }
    quit $$$OK
}

}
