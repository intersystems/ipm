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

Method %PrepareDeploy(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
    Merge tParams = pParams

		Set tNSConfig = ..Module.GetNamespaceConfig()

		Set pParams("InitNamespace") = $Namespace

		Set tNSPostfix = "PACKAGE-" _ $Piece($ZHorolog, ".")
		Set tSC = ##class(%IPM.Utils.Build).InitializeNamespace(tNSPostfix, tVerbose, .tPackageDeployNamespace, tNSConfig)
		$$$ThrowOnError(tSC)
		Set pParams("PackageDeployNamespace") = tPackageDeployNamespace

		$$$ThrowOnError(..Module.%Reload())

    Set tSource = tPackageDeployNamespace _ "-CODE"
		Set tKey = ""
		For {
			Set tResource = ..Module.Resources.GetNext(.tKey)
			Quit:(tKey="")

			Set tName = $Piece(tResource.Name, ".", 1, *-1)
			Set tExtension = $$$ucase($Piece(tResource.Name, ".", *))
			if (tExtension = "") || ($Extract(tExtension) = "/") {
				continue
			}

			Set tSC = $Case(tExtension,
				"GBL":##class(%IPM.Utils.Module).AddGlobalMapping(tPackageDeployNamespace, tName, tSource),
				"INC":##class(%IPM.Utils.Module).AddRoutineMapping(tPackageDeployNamespace, tName, "INC", tSource),
				"INT":##class(%IPM.Utils.Module).AddRoutineMapping(tPackageDeployNamespace, tName, "INT", tSource),
				"MAC":##class(%IPM.Utils.Module).AddRoutineMapping(tPackageDeployNamespace, tName, "MAC", tSource),
				"PKG":##class(%IPM.Utils.Module).AddPackageMapping(tPackageDeployNamespace, tName, tSource),
				"":##class(%IPM.Utils.Module).AddRoutineMapping(tPackageDeployNamespace, tName, "ALL", tSource),
				:$$$OK)
			$$$ThrowOnError(tSC)
		}
		Set $Namespace = tPackageDeployNamespace
		Write:tVerbose !,"Packaging in namespace: ",$Namespace

	} Catch e {
		Set tSC = e.AsStatus()

		If $Get(tPackageDeployNamespace)'="" {
			Do ##class(%IPM.Utils.Build).DeleteNamespace(tPackageDeployNamespace, tVerbose)
		}
	}
	Quit tSC
}

Method %Package(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
    if ..Module.HaveToDeploy() {
      $$$ThrowOnError(..MakeDeployed(.pParams))
    }

		Set tExportDirectory = $Get(pParams("Path"))
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

  If '$Get(pParams("Package","KeepNamespace")) {
    Set tPackageDeployNamespace = $Get(pParams("PackageDeployNamespace"))
    Set tInitNamespace = $Get(pParams("InitNamespace"))
    If (tInitNamespace '= ""), (tPackageDeployNamespace '= ""), tInitNamespace '= $Namespace {
      Set $Namespace = tInitNamespace
      Do ##class(%IPM.Utils.Build).DeleteNamespace(tPackageDeployNamespace, tVerbose)
      Kill pParams("PackageDeployNamespace"), pParams("InitNamespace")
    }
  }

  Quit tSC
}

}
