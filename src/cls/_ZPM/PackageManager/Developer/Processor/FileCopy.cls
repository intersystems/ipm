Class %ZPM.PackageManager.Developer.Processor.FileCopy Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Copies the specified directory (the resource name) to a specific target location (InstallDirectory) during the Activate phase.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "InstallDirectory,Overlay";

/// Directory to which the directory should be copied upon installation; may contain expressions.
Property InstallDirectory As %String(MAXLEN = "") [ Required ];

/// If true, the files should be added to the target location (rather than fully replacing it, causing other files there to be deleted)
Property Overlay As %Boolean;

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	// Default implementation: call %ValidateObject to validate attributes
	Set tSC = $$$OK
	Try {
		Set tSC = ##super(pPhase,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pPhase = "Activate") && (..InstallDirectory '= "") {
			Set tSourceDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
			Set tTargetDir = ##class(%File).NormalizeDirectory(..InstallDirectory)
			Write !,"Copying ",tSourceDir," to ",tTargetDir
			Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(tSourceDir,tTargetDir,'..Overlay)
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

}
