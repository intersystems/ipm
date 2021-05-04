Class %ZPM.PackageManager.Developer.Processor.FileCopy Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Copies the specified directory or file  (the resource name) to a specific target location (InstallDirectory) during the Activate phase.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Name,InstallDirectory,Overlay,CSPApplication,Defer";

Property Name As %String(MAXLEN = "")[ Aliases = {SourceDirectory}];

/// Path to which the directory or file (a full filename, in that case) should be copied upon installation; may contain expressions.
Property InstallDirectory As %String(MAXLEN = "") [ Required, Aliases = {Target,Dest} ];

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
	// Default implementation: call %ValidateObject to validate attributes
	Set tSC = $$$OK
	Try {
		Set tSC = ##super(pPhase,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pPhase = "Activate") && '..Defer {
			Set tSC = ..OnActivate(.pParams)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	If (pPhase = "Activate") && ..Defer {
		Set tSC = ..OnActivate(.pParams)
	}
	Quit tSC
}

Method OnActivate(ByRef pParams) As %Status
{
  Set tVerbose = $Get(pParams("Verbose"))
	Set tSC = $$$OK
	Try {
		If (..InstallDirectory '= "") {
			Set tResource = $Case(..SourceDirectory,"":..ResourceReference.Module.Root_..ResourceReference.Name,:..SourceDirectory)
			If ##class(%Library.File).DirectoryExists(tResource) {
				Set tSourceDir = ##class(%Library.File).NormalizeDirectory(tResource)
				Set tTargetDir = ##class(%Library.File).NormalizeDirectory(..InstallDirectory)
				If tVerbose {
					Write !,"Copying ",tSourceDir," to ",tTargetDir
				}
				Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(tSourceDir,tTargetDir,'..Overlay)
			} ElseIf ##class(%Library.File).Exists(tResource) {
				Set tSourceFile = ##class(%Library.File).NormalizeFilename(tResource)
				Set tTargetFile = ##class(%Library.File).NormalizeFilename(..InstallDirectory)
				If tVerbose {
					Write !,"Copying ",tSourceFile," to ",tTargetFile
				}
				Set tTargetDirectory = ##class(%Library.File).GetDirectory(tTargetFile)
				Set tSC = ##class(%ZPM.PackageManager.Developer.File).CreateDirectoryChain(tTargetDirectory)
				$$$ThrowOnError(tSC)
				Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyFile(tSourceFile,tTargetFile,1)
			} Else {
				Set tSC = $$$ERROR($$$FileDoesNotExist,tResource)
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
			Set tSource = pExportDirectory_..ResourceReference.Name
			Set tSourceFile = ##class(%Library.File).NormalizeFilename(tSource)
			If ##class(%File).DirectoryExists(tSource) {
				Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(
					pExportDirectory_..ResourceReference.Name,
					pWorkingDirectory_..ResourceReference.Name)
			} ElseIf ##class(%Library.File).Exists(tSourceFile) {
				Set tTargetFile = ##class(%Library.File).NormalizeFilename(pWorkingDirectory_..ResourceReference.Name)
				Set tTargetDirectory = ##class(%Library.File).GetDirectory(tTargetFile)
				Set tSC = ##class(%ZPM.PackageManager.Developer.File).CreateDirectoryChain(tTargetDirectory)
				$$$ThrowOnError(tSC)
				Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyFile(tSourceFile,tTargetFile,1)
			} Else {
				Set tSC = $$$ERROR($$$FileDoesNotExist,tSource)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnResolveChildren(ByRef pResourceArray, pCheckModuleOwnership As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..CSPApplication '= "") {
			Set tCSPApplication = ..NormalizePath(..CSPApplication)
				
			// If we are verifying module ownership of constituent resources (usually the case),
			// then find other modules with resources underneath ..CSPApplication.
			If pCheckModuleOwnership {
				Set tSubResourceResult = ##class(%SQL.Statement).%ExecDirect(,
					"select UniqueName from %ZPM_PackageManager_Developer.ResourceReference where UniqueName %STARTSWITH ?",
					tCSPApplication)
				If (tSubResourceResult.%SQLCODE < 0) {
					Throw ##class(%Exception.SQL).CreateFromSQLCODE(tSubResourceResult.%SQLCODE,tSubResourceResult.%Message)
				}
				While tSubResourceResult.%Next(.tSC) {
					$$$ThrowOnError(tSC)
					Set tName = tSubResourceResult.%Get("UniqueName")
					If (tName = ..ResourceReference.UniqueName) {
						Continue
					}
					Set tSubResources(..NormalizePath(tName)) = ""
				}
				$$$ThrowOnError(tSC)
			}
			
			// For CSP applications, list contents of the CSP files physical path.
			// TODO: Filter out generated Zen JS/CSS files somehow?
			// Call StudioOpenDialog (flat) with the CSP application.
			
			// Detect single files and handle them efficiently.
			// (tCSPApplication could be a single file within a CSP application, rather than a whole application or a folder.)
			Set tFileOnDisk = $System.CSP.GetFileName(tCSPApplication)
			If (tFileOnDisk '= "") && ##class(%Library.File).Exists(tFileOnDisk) && '##class(%Library.File).DirectoryExists(tFileOnDisk) {
				Set tResourceArray(tCSPApplication) = ..ResourceReference.Module.Name
				Set tResourceArray(tCSPApplication,"Processor") = ..ResourceReference.Processor
				Set tResourceArray(tCSPApplication,"Generated") = ..ResourceReference.Generated
				Set tResourceArray(tCSPApplication,"Preload") = ..ResourceReference.Preload
				Set tResourceArray(tCSPApplication,"Scope") = ..ResourceReference.Scope
				Set tResourceArray(tCSPApplication,"Deploy") = ..ResourceReference.Deploy
			} Else {
				Set tDocSpec = $Extract(tCSPApplication,2,*)_"*"
				Set tStart = $zh
				Set tContents = ##class(%Library.RoutineMgr).StudioOpenDialogFunc(tDocSpec /*Spec*/,,,,1 /*Flat*/)
				If (tContents.%SQLCODE < 0) {
					Throw ##class(%Exception.SQL).CreateFromSQLCODE(tContents.%SQLCODE,tContents.%Message)
				}
				
				While tContents.%Next(.tSC) {
					$$$ThrowOnError(tSC)
					Set tName = tContents.%Get("Name")
					If tContents.%Get("IsDirectory") {
						// This shouldn't actually happen with Flat=1, but just in case.
						Continue
					}
					
					If $Data(tSubResources) {
						// Individual file represented in a module manifest.
						If $Data(tSubResources(tName)) {
							Continue
						}
						
						// Check for parent directories 
						Set tFound = 0
						Set tLength = $Length(tName,"/")
						For tDepth = tLength-1:-1:2 {
							Set tDirectory = $Piece(tName,"/",1,tDepth)_"/"
							If $Data(tSubResources(tDirectory)) {
								Set tFound = 1
								Quit
							}
						}
						If (tFound) {
							Continue
						}
					}
					
					Set tResourceArray(tName) = ..ResourceReference.Module.Name
					Set tResourceArray(tName,"Processor") = ..ResourceReference.Processor
					Set tResourceArray(tName,"Generated") = ..ResourceReference.Generated
					Set tResourceArray(tName,"Preload") = ..ResourceReference.Preload
					Set tResourceArray(tName,"Scope") = ..ResourceReference.Scope
					Set tResourceArray(tName,"Deploy") = ..ResourceReference.Deploy
				}
				$$$ThrowOnError(tSC)
			}
			
			Merge pResourceArray = tResourceArray
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
	If (..CSPApplication '= "") {
		Set pUniqueName = ..CSPApplication
	}
}

Method %OnNew(pResourceReference As %ZPM.PackageManager.Developer.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = ##super(pResourceReference)
	If (..CSPApplication '= "") {
		Set ..CSPApplication = ..NormalizePath(..CSPApplication)
	}
	Quit tSC
}

/// Adds a trailing slash if there is no extension.
ClassMethod NormalizePath(pPath As %String) As %String [ CodeMode = expression ]
{
$Select($Piece(pPath,"/",*)[".":pPath,$Extract(pPath,*)="/":pPath,1:pPath_"/")
}

Method GetSourceControlInfo(Output pInfo As %ZPM.PackageManager.Developer.Extension.SourceControl.ResourceInfo) As %Status
{
	Set pInfo = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ResourceInfo).%New()
	If (..CSPApplication '= "") {
		Set pInfo.SourceControlAware = 1
		Set pInfo.ResourceType = "/CSP/"
		Set pInfo.Prefix = ..CSPApplication
		Set pInfo.RelativePath = ..ResourceReference.Name
		Set pInfo.IsDirectory = ($Piece(..ResourceReference.Name,"/",*) '[ ".")
	}
	Quit $$$OK
}

}
