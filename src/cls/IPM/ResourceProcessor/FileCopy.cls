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

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
  Set tVerbose = $Get(pParams("Verbose"))
	// Default implementation: call %ValidateObject to validate attributes
	Set tSC = $$$OK
	Try {
		Set tSC = ##super(pPhase,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}

		If (pPhase = "Activate") && (..InstallDirectory '= "") && ('..Defer) {
      Set tSource = $Case(..SourceDirectory, "": ..ResourceReference.Module.Root _ ..ResourceReference.Name,: ..SourceDirectory)
      Set tTarget = ..InstallDirectory
      Set tSC = ..DoCopy(tSource, tTarget, .pParams)
      If $$$ISERR(tSC) {
        Quit
      }
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
  Set tVerbose = $Get(pParams("Verbose"))
	// Default implementation: call %ValidateObject to validate attributes
	Set tSC = $$$OK
	Try {
    
		Set tSC = ##super(pPhase,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}

		If (pPhase = "Activate") && (..InstallDirectory '= "") && (..Defer) {
      Set tSource = $Case(..SourceDirectory, "": ..ResourceReference.Module.Root _..ResourceReference.Name,: ..SourceDirectory)
      Set tTarget = ..InstallDirectory
      Set tSC = ..DoCopy(tSource, tTarget, .pParams)
      If $$$ISERR(tSC) {
        Quit
      }
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnBeforeArtifact(pExportDirectory As %String, pWorkingDirectory As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If (pExportDirectory = pWorkingDirectory) {
			Quit
		}

		Write !,"[OnBeforeArtifact] "_..ResourceReference.Name
		If '..ResourceReference.Deploy {
			Set tSC = ##class(%IPM.Utils.File).CopyDir(
				pExportDirectory_..ResourceReference.Name,
				pWorkingDirectory_..ResourceReference.Name)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method NormalizeNames(ByRef pSource As %String, ByRef pTarget As %String, Output pTargetDir, Output pAsFile As %Boolean)
{
  Set pAsFile = 0
  If ("\/"[$Extract(pSource, *))
    ||(
      (##class(%File).NormalizeDirectory(pSource)'="")
      &&##class(%File).DirectoryExists(##class(%File).NormalizeDirectory(pSource))) {
    Set pSource = ##class(%File).NormalizeDirectory(pSource)
    Set pTarget = ##class(%File).NormalizeDirectory(pTarget)
    Set pTargetDir = pTarget
  } Else {
    Set pAsFile = 1
    Set pSource = ##class(%File).NormalizeFilename(pSource)
    If ("\/"[$Extract(pTarget, *)) {
      Set pTargetDir = ##class(%File).NormalizeDirectory(pTarget)
      Set pTarget = ##class(%File).NormalizeFilename(##class(%File).GetFilename(pSource), pTargetDir)
    } Else {
      Set pTarget = ##class(%File).NormalizeFilename(pTarget)
      Set pTargetDir = ##class(%File).ParentDirectoryName(pTarget)
    }
  }
}

Method DoCopy(tSource, tTarget, pParams)
{
  Set tVerbose = $Get(pParams("Verbose"))
  Set tSC = $$$OK
  Try {
    Do ..NormalizeNames(.tSource, .tTarget, .tTargetDir, .copyAsFile)

    If '##class(%File).DirectoryExists(tTargetDir) {
      If '##class(%File).CreateDirectoryChain(tTargetDir,.tReturn) {
        Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",tTargetDir,$ZUtil(209,tReturn)))
        Quit
      }
    }

    Write:tVerbose !,"Copying ",tSource," to ",tTarget
    If (copyAsFile) {
      If '##class(%File).Exists(tSource) {
        Set tSC = $$$ERROR($$$GeneralError, "Source file does not exists: "_tSource)
        Quit
      }
      If '##class(%File).CopyFile(tSource, tTarget, 1, .return) {
        Set tSC = $$$ERROR($$$GeneralError, "File not copied: " _ return)
        Quit
      }
    }
    Else {
      Write:tVerbose " as directory "
      Set tSC = ##class(%IPM.Utils.File).CopyDir(tSource,tTarget,'..Overlay)
    }
	} Catch e {
		Set tSC = e.AsStatus()
	}

  Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
  
  Set tVerbose = $Get(pParams("Verbose"))
  Set pItemHandled = 1
  
  Set tExportPath = $Get(pParams("ModuleExportPath"))
  Set tSource = ..InstallDirectory
  Set tTarget = tExportPath _ ..ResourceReference.Name

	Quit ..DoCopy(tSource, tTarget, .pParams)
}

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
  Set tVerbose = $Get(pParams("Verbose"))
  If (pPhase = "Clean") {
    Set pResourceHandled = 1
    Set tSource = ..ResourceReference.Module.Root _ ..Name
    Set tTarget = ..InstallDirectory
    Do ..NormalizeNames(.tSource, .tTarget, .tTargetDir, .copyAsFile)
    Write:tVerbose !,"Deleting ",tTarget
    If copyAsFile {
      Do ##class(%File).Delete(tTarget)
    } Else {
      Do ##class(%File).RemoveDirectoryTree(tTarget)
    }
  }
	Quit $$$OK
}

}
