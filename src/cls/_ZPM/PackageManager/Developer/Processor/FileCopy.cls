Class %ZPM.PackageManager.Developer.Processor.FileCopy Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Copies the specified directory (the resource name) to a specific target location (InstallDirectory) during the Activate phase.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "InstallDirectory,Overlay";

Property InstallDirectory As %String(MAXLEN = "") [ Aliases = {Target,Dest} ];

/// Directory to which the directory should be copied upon installation; may contain expressions.
/// If true, the files should be added to the target location (rather than fully replacing it, causing other files there to be deleted)
Property Overlay As %Boolean;

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

		If (pPhase = "Activate") && (..InstallDirectory '= "") {
      Set tSource = ..ResourceReference.Module.Root _ ..ResourceReference.Name
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
			Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(
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
      Write:tVerbose " as file "
      If '##class(%File).CopyFile(tSource, tTarget,'..Overlay, .return) {
        Set tSC = $Get(%objlasterror, return)
      }
    }
    Else {
      Write:tVerbose " as directory "
      Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(tSource,tTarget,'..Overlay)
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
    Set tSource = ..ResourceReference.Module.Root _ ..ResourceReference.Name
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
