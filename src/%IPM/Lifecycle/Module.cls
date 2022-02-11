Class %IPM.Lifecycle.Module Extends %IPM.Lifecycle.Base
{

Property Payload As %Stream.TmpBinary [ Private ];

Parameter PACKAGING As STRING [ Final ] = "module";

Method %Clean(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ..CheckBeforeClean(.pParams,.tSkip)
		If (tSkip) {
			Quit
		}
		
		Set tSC = ..Unconfigure(.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ##super(.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Activate(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ##super(.pParams)
		$$$ThrowOnError(tSC)
		
		Set tSC = ..Configure(.pParams)
		$$$ThrowOnError(tSC)
		
		If '$ListFind(..PhaseList,"Package") {
			// Code cannot be deployed if it is to be reexported and packaged.
			Set tSC = ..MakeDeployed(.pParams)
			$$$ThrowOnError(tSC)
		}
		
		
		// Create Studio project for package if it is loaded in developer mode and no explicit statement to not create it
		Set tNoStudioProject = $Get(pParams("NoStudioProject"), 0)
		If ..Module.DeveloperMode && 'tNoStudioProject {
			#dim tProject As %Studio.Project
			// Do not throw exceptions if failure to create because creating a Studio project should not block activation.
			// Just write the exception if in verbose mode
			Set tStudioProjectSC = ..Module.GetStudioProject(.tProject)
			Set tVerbose = $Get(pParams("Verbose"))
			If tVerbose {
				If $$$ISOK(tStudioProjectSC) {
					Write !, "Studio project created/updated: " _ tProject.Name _ ".PRJ"
				} Else {
					Write !, "Unable to create/update Studio project: " _ tProject.Name _ ".PRJ"
					Write !, $System.Status.GetErrorText(tStudioProjectSC)
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Package(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tExportDirectory = $Get(pParams("zpm", "Path"))
		If (tExportDirectory'="") && ('##class(%File).DirectoryExists(tExportDirectory)) {
      Set tExportDirectory = ##class(%File).NormalizeDirectory(tExportDirectory)
			If '##class(%File).CreateDirectoryChain(tExportDirectory,.tReturn) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",tExportDirectory,tReturn))
				Quit
			}
		}

		Set tSC = ..%Export(.pParams,.tExportDirectory)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..OnBeforeArtifact(tExportDirectory,tExportDirectory,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Write:tVerbose !,"Module exported to:",!,$c(9),tExportDirectory,!
		
		Set tTgzFile = $Extract(tExportDirectory,1,*-1)_".tgz"
		Set tSC = ##class(%IPM.General.Archive).Create(tExportDirectory,tTgzFile,.tOutput)
		If $$$ISERR(tSC) {
			Quit
		}
		
		For i=1:1:$Get(tOutput) {
			Write:tVerbose !,tOutput(i)
		}
		
		// Always show this message
		Write:tVerbose !,"Module package generated:",!,$c(9),tTgzFile
		
		Set tSrcFileStream = ##class(%Stream.FileBinary).%New()
		Set tSC = tSrcFileStream.LinkToFile(tTgzFile)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..Payload.CopyFrom(tSrcFileStream)
		If $$$ISERR(tSC) {
			Quit
		}
    Set pParams("PackageFile") = tTgzFile
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
