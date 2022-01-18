Class %ZPM.PackageManager.Developer.Lifecycle.Application Extends %ZPM.Lifecycle.Base
{

Parameter EXPORTDEPENDENCIES As BOOLEAN = 1;

Parameter DEPLOYABLE As BOOLEAN = 1;

Parameter PACKAGING As STRING [ Final ] = "application";

Property Payload As %Stream.TmpBinary [ Private ];

Method %Verify(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		// TODO: Install application (from ..Payload) in a new namespace
		
		// TODO: Run tests in new application namespace
		
		// Inherited implementation:
		If $$$comClassDefined("HS.Test.Manager") {
			#dim tResource As %ZPM.Storage.ResourceReference
			For i=1:1:..Module.Resources.Count() {
				Set tResource = ..Module.Resources.GetAt(i)
				Continue:(tResource.Scope'="verify")
				
				Set tPrefix = $Piece(tResource.Name,".",1,*-1)
				Set tExt = $Piece(tResource.Name,".",*)
				If (tExt = "CLS") || (tExt = "PKG") {
					Set tOneRunSC = ##class(HS.Test.Manager).Run(tPrefix)
					Set tSC = $$$ADDSC(tSC,tOneRunSC)
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
		
		// Export module contents
		Set tSC = ..%Export(.pParams, .tExportDirectory, .tDependencyGraph)
		$$$ThrowOnError(tSC)
		
		// Initialize and switch to build namespace
		Set tInitNS = $Namespace
		New $Namespace
		Set tSC = ##class(%ZPM.PackageManager.Developer.Build).InitializeBuildNamespace(,..Module.GetNamespaceConfig())
		$$$ThrowOnError(tSC)
		
		// Ensure all resources that are part of the module are swizzled.
		Set tKey = ""
		For {
			Set tResource = ..Module.Resources.GetNext(.tKey)
			Quit:(tKey="")
		}
		
		// Actually switch to build namespace
		Set tSC = ##class(%ZPM.PackageManager.Developer.Build).SwitchToBuildNamespace()
		$$$ThrowOnError(tSC)
		
		Write:tVerbose !,"Building in namespace: ",$Namespace
		
		// In the build namespace, create a filesystem repository pointing to the export directory.
		// First, remove all existing server definitions to force use of the one filesystem repository.
		Write:tVerbose !,"Clearing repository registry..."
		Set tSC = ##class(%ZPM.Repo.Definition).%DeleteExtent()
		$$$ThrowOnError(tSC)
		
		Set tFSDef = ##class(%ZPM.Repo.Filesystem.Definition).%New()
		Set tFSDef.Name = "Build Directory"
		Set tFSDef.Enabled = 1
		Set tFSDef.Snapshots = 1
		Set tFSDef.Prereleases = 1
		Set tFSDef.Root = tExportDirectory_".modules/"
		Set tFSDef.Depth = 1
		Set tSC = tFSDef.%Save()
		$$$ThrowOnError(tSC)
		
		// Load the export directory for this module
		// LoadNewModule will execute up through the Activate step. (Reload, Validate, Compile, Activate.)
		Kill tParams
		Set tParams("DeveloperMode") = 0
		Set tParams("Verbose") = tVerbose
		Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).LoadNewModule(tExportDirectory,.tParams)
		$$$ThrowOnError(tSC)
		
		// Retrieve built code database
		Set tWorkingFile = $Piece(##class(%File).TempFilename(),".",1,*-1)
		Set tWorkingDirectory = ##class(%File).NormalizeDirectory(tWorkingFile)
		Set tWorkingFile = tWorkingFile_".tgz"
		If '##class(%File).CreateDirectory(tWorkingDirectory,.tReturn) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Could not create directory %1: %2",tWorkingDirectory,tReturn))
			Quit
		}
		
		Set tStream = ##class(%Stream.FileBinary).%New()
		Set tDBDirectory = ##class(%File).NormalizeDirectory(tWorkingDirectory_"db\")
		If '##class(%File).CreateDirectory(tDBDirectory,.tReturn) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Could not create directory %1: %2",tWorkingDirectory,tReturn))
			Quit
		}
		Set tSC = tStream.LinkToFile(##class(%File).NormalizeFilename(tDBDirectory_"CODE.DAT"))
		$$$ThrowOnError(tSC)
		
		Set tSC = ..OnBeforeCaptureDatabase(.pParams)
		$$$ThrowOnError(tSC)
		
		Set tSC = ##class(%ZPM.PackageManager.Developer.Build).RetrieveBuiltDatabase(.tTempStream)
		$$$ThrowOnError(tSC)
		Set tSC = tStream.CopyFromAndSave(tTempStream)
		$$$ThrowOnError(tSC)
		
		// Export module manifest
		Set tSC = $System.OBJ.Export(..Module.Name_".ZPM",tWorkingDirectory_"module.xml", "/diffexport")
		$$$ThrowOnError(tSC)
		
		Set tSC = ..OnBeforeArtifact(tExportDirectory,tWorkingDirectory,.pParams)
		$$$ThrowOnError(tSC)
		
		// Package as .tgz
		Set tSC = ##class(%ZPM.General.Archive).Create(tWorkingDirectory,tWorkingFile,.tOutput)
		$$$ThrowOnError(tSC)
		For i=1:1:tOutput {
			Write:tVerbose !,tOutput(i)
		}
		
		Write:tVerbose !,"Application package generated:",!,$C(9),tWorkingFile
		
		Set tSrcFileStream = ##class(%Stream.FileBinary).%New()
		Set tSC = tSrcFileStream.LinkToFile(tWorkingFile)
		$$$ThrowOnError(tSC)
		
		Set tSC = ..Payload.CopyFrom(tSrcFileStream)
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Configure(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		// First, configure all dependencies in reverse order. (Only applications do this; modules do so at other lifecycle phases.)
		Set tSC = ..Module.BuildDependencyGraph(.tDependencyGraph)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Sort dependencies by depth.
		Set tKey = ""
		For {
			Set tKey = $Order(tDependencyGraph(tKey),1,tData)
			Quit:tKey=""
			
			Set $ListBuild(tDepth,tServerName,tVersion) = tData
			Set tDepthList(tDepth,$Increment(tDepthList(tDepth))) = tKey
		}
		
		// Actually configure dependencies in reverse order by depth.
		Set tDepth = ""
		For {
			Set tDepth = $Order(tDepthList(tDepth),-1,tCount)
			Quit:tDepth=""
			For i=1:1:tCount {
				Set tModName = tDepthList(tDepth,i)
				Set tModule = ##class(%ZPM.Storage.Module).NameOpen(tModName,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
				Kill tParams
				Merge tParams = pParams
				// TODO: Propagate parameters the child module is expecting?
				Set tSC = tModule.Lifecycle.Configure(.tParams)
				If $$$ISERR(tSC) {
					Quit
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Default behavior - invoke this application's installer (to avoid code duplication building installer variable array)
		Set tSC = ##super(.pParams)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnBeforeCaptureDatabase(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ..%MakeDeployed(.pParams)
		$$$ThrowOnError(tSC)
		
		// Ensure that no code is left over in the code database.
		If (..HasDeployedResources) {
			Set tVerbose = $Get(pParams("Verbose"))
			Set tCodeDatabase = $Piece(##class(%SYS.Namespace).GetRoutineDest(),"^",2)
			Set tCopyDatabase = ##class(%File).NormalizeDirectory(tCodeDatabase_"/comp/")
			
			New $Namespace
			Set $Namespace = "%SYS"
			/*
			Flags - Bit string specifying the following options (Default = 0):
			...
			Bit 2 - If the destination database already exists, do not generate an error.
			...
			Bit 4 - Replace the source database with the destination database after the copy completes. If the source database is cluster mounted or mirrored, this option is not allowed.
			WARNING: If you are replacing the source database with the destination database, you MUST make a backup of your source database before running this method.
			Bit 5 - Set switch 10 (freeze reads and write on the system) for the duration of the copy. Setting this bit will allow the source database to be copied and replaced by the destination database while avoiding having any processes trying to write to the database error with a protect error.
			*/
			Set tFlags = (2**2) + (2**4) + (2**5)
			Set tSC = ##class(SYS.Database).Copy(tCodeDatabase,tCopyDatabase,,.tCopyMsg,tFlags)
			If tVerbose {
				For i=1:1:tCopyMsg {
					Write !,tCopyMsg(i)
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
