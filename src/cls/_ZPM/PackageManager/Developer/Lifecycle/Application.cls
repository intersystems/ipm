Class %ZPM.PackageManager.Developer.Lifecycle.Application Extends %ZPM.PackageManager.Developer.Lifecycle.Base
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
			#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
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
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Initialize and switch to build namespace
		Set tInitNS = $Namespace
		New $Namespace
		Set tSC = ##class(%ZPM.PackageManager.Developer.Build).InitializeBuildNamespace()
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Ensure all resources that are part of the module are swizzled.
		Set tKey = ""
		For {
			Set tResource = ..Module.Resources.GetNext(.tKey)
			Quit:(tKey="")
		}
		
		// Actually switch to build namespace
		Set tSC = ##class(%ZPM.PackageManager.Developer.Build).SwitchToBuildNamespace()
		If $$$ISERR(tSC) {
			Quit
		}
		
		Write:tVerbose !,"Building in namespace: ",$Namespace
		
		// In the build namespace, create a filesystem repository pointing to the export directory.
		// First, remove all filesystem repository.
		Write:tVerbose !,"Clearing FileSystems registry..."
		Set tSC = ##class(%ZPM.PackageManager.Client.FilesystemServerDefinition).%DeleteExtent()
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tFSDef = ##class(%ZPM.PackageManager.Client.FilesystemServerDefinition).%New()
		Set tFSDef.Name = "Build Directory"
		Set tFSDef.Enabled = 1
		Set tFSDef.Snapshots = 1
		Set tFSDef.Prereleases = 1
		Set tFSDef.Root = tExportDirectory_".modules/"
		Set tFSDef.Depth = 1
		Set tSC = tFSDef.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Load the export directory for this module
		// LoadNewModule will execute up through the Activate step. (Reload, Validate, Compile, Activate.)
		Kill tParams
		Set tParams("DeveloperMode") = 0
		Set tParams("Verbose") = tVerbose
		Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).LoadNewModule(tExportDirectory,.tParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Retrieve built code database
		Set tWorkingDirectory = ##class(%File).NormalizeDirectory($$$FileTempDir)
		Set tWorkingFile = ##class(%File).NormalizeFilename(..Module.Name_".tgz", tWorkingDirectory)
		If '##class(%File).DirectoryExists(tWorkingDirectory),'##class(%File).CreateDirectory(tWorkingDirectory,.tReturn) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Could not create directory %1: %2",tWorkingDirectory,tReturn))
			Quit
		}
		
		Set tStream = ##class(%Stream.FileBinary).%New()
		Set tDBDirectory = ##class(%File).NormalizeDirectory("db", tWorkingDirectory)
		If '##class(%File).CreateDirectory(tDBDirectory,.tReturn) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Could not create directory %1: %2", tDBDirectory, tReturn))
			Quit
		}
		Set tSC = tStream.LinkToFile(##class(%File).NormalizeFilename(tDBDirectory_"CODE.DAT"))
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..OnBeforeCaptureDatabase(.pParams)
		
		Set tSC = ##class(%ZPM.PackageManager.Developer.Build).RetrieveBuiltDatabase(.tTempStream)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = tStream.CopyFromAndSave(tTempStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Export module manifest
		Set tSC = $System.OBJ.Export(..Module.Name_".ZPM",tWorkingDirectory_"module.xml", "/diffexport")
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..OnBeforeArtifact(tExportDirectory,tWorkingDirectory,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		 
		// Package as .tgz
		Set tSC = ##class(%ZPM.PackageManager.Developer.Archive).Create(tWorkingDirectory,tWorkingFile,.tOutput)
		For i=1:1:tOutput {
			Write:tVerbose !,tOutput(i)
		}
		
		Write !,"Application package generated:",!,$C(9),tWorkingFile
		
		Set tSrcFileStream = ##class(%Stream.FileBinary).%New()
		Set tSC = tSrcFileStream.LinkToFile(tWorkingFile)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..Payload.CopyFrom(tSrcFileStream)
		If $$$ISERR(tSC) {
			Quit
		}
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
				Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModName,,.tSC)
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
		Set tVerbose = $Get(pParams("Verbose"))
		
		// Default implementation: see which resources are expicitly flagged with Deploy = true.
		// Build an array of those, then mark them as deployed.
		Set tSC = ..Module.GetResolvedReferences(.tResourceArray,..#EXPORTDEPENDENCIES,..PhaseList,1,.pDependencyGraph)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tResourceKey = ""
		For {
			Set tResourceKey = $Order(tResourceArray(tResourceKey))
			Quit:(tResourceKey="")
			
			// Skip file resources - these are handled separately;
			// "deployment" is the responsibility of resource processor classes.
			If ($Extract(tResourceKey) = "/") {
				Continue
			}
			
			Kill tResourceInfo
			Merge tResourceInfo = tResourceArray(tResourceKey)
			Set tSC = ..OnBeforeCaptureResource(.tResourceInfo,.tDeploy)
			$$$ThrowOnError(tSC)
			
			If tDeploy {
				Set tName = $Piece(tResourceKey,".",1,*-1)
				Set tExt = $Piece(tResourceKey,".",*)
				If (tExt = "CLS") {
					Set tDeployClassArray($Piece(tResourceKey,".",1,*-1)) = ""
				} ElseIf (tExt = "MAC") || (tExt = "INT") {
					Set tDeployRtnArray(tResourceKey) = ""
				} Else {
					// TODO: Handle making other types deployed?
				}
			}
		}
		
		If $Data(tDeployClassArray) {
			If (tVerbose) {
				Set tClass = ""
				Write !,"Marking classes as deployed:"
				For {
					Set tClass = $Order(tDeployClassArray(tClass))
					Quit:tClass=""
					Write !,$c(9),tClass
				}
			}
			$$$ThrowOnError($System.OBJ.MakeClassDeployed(.tDeployClassArray))
		} ElseIf tVerbose {
			Write !,"No classes to mark as deployed."
		}
		If $Data(tDeployRtnArray) {
			Set tRtn = ""
			For {
				Set tRtn = $Order(tDeployRtnArray(tRtn))
				Quit:tRtn=""
				Write:tVerbose !,"Deploying routine: ",tRtn
				$$$ThrowOnError(##class(%Routine).Delete(tRtn,2))
			}
		} ElseIf tVerbose {
			Write !,"No routines to deploy."
		}
		
		// Ensure that no code is left over in the code database.
		Set tCodeDeployed = $Data(tDeployClassArray) || $Data(tDeployRtnArray)
		If (tCodeDeployed) {
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

Method OnBeforeCaptureResource(ByRef pResourceInfo, Output pDeploy As %Boolean) As %Status
{
	Set tSC = $$$OK
	Try {
		// Only deploy things expicitly flagged for deployment.
		Set pDeploy = $Case($Get(pResourceInfo("Deploy")),1:1,:0)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Namespace(ByRef pParams) As %Status
{
	Quit $$$OK
}

}
