/// Supports packaging and installing modules from Studio projects.
/// Additional command line flags:
/// <ul>
/// <li><strong>-DPackage.WithDependencies=1</strong>: includes dependencies in the module package</li>
/// <li><strong>-DPackage.Manager=1</strong>: includes package manager itself in the module package, to be bootstrapped in if it is not already installed</li>
/// <li><strong>-DPackage.Target=C:\path\to\file.xml</strong>: exports the package to the specified file</li>
/// <li><strong>-DPackage.Deploy=1</strong>: deploys all resources that are not explicitly listed with "Deploy=false"</li>
/// </ul>
Class %ZPM.Lifecycle.StudioProject Extends %ZPM.Lifecycle.Base
{

Property Payload As %Stream.TmpCharacter [ Private ];

Parameter PACKAGING As STRING [ Final ] = "studio-project";

/// Packages all of the resources in a module (possibly including its dependencies, possibly including the package manager, possibly deploying by default)
/// into a Studio project with a set of subordinate Studio projects.
Method %Package(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tTarget = $Name(^CacheTemp.ZPMProjectExport($Increment(^CacheTemp.ZPMProjectExport)))
		Kill @tTarget
		Set tVerbose = $Get(pParams("Verbose"),0)
		Set tIncludeDependencies = $Get(pParams("Package","WithDependencies"),0)
		Set tIncludePackageManager = $Get(pParams("Package","Manager"),0)
		Set tTargetFile = $Get(pParams("Package","Target"),##class(%Library.File).TempFilename("xml"))
		
		// Installer routine - header/main entry point.
		Set tRtn($i(tRtn)) = " #include %occInclude"
		Set tRtn($i(tRtn)) = " Do MAIN"
		Set tRtn($i(tRtn)) = " Quit"
		
		// Possibly, include package manager in package and install it if needed.
		If tIncludePackageManager {
			If ##class(%ZPM.PackageManager.Developer.Module).NameExists("ZHSLIB") {
				Set tZPMModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen("ZHSLIB",,.tSC)
				$$$ThrowOnError(tSC)
				Do ..PackageOneModule(tZPMModule,tTarget,.pParams,.tModuleLocations,.tRtn)
			} Else {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Attempted to include package manager, but ZHSLIB module not defined in this namespace."))
			}
		}
		
		// Possibly include dependencies in the package, and install them.
		If tIncludeDependencies {
			$$$ThrowOnError(..Module.BuildDependencyGraph(.tDependencyGraph))
			Set tModule = ""
			For {
				Set tModule = $Order(tDependencyGraph(tModule),1,tData)
				If (tModule = "") {
					Quit
				}
				Set tDepthGraph($ListGet(tData),$Increment(tDepthGraph($ListGet(tData)))) = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModule,,.tSC)
				$$$ThrowOnError(tSC)
			}
			
			For tDepth=$Order(tDepthGraph(""),-1):-1:1 {
				For tIndex=1:1:tDepthGraph(tDepth) {
					Do ..PackageOneModule(tDepthGraph(tDepth,tIndex),tTarget,.pParams,.tModuleLocations,.tRtn)
				}
			}
		}
		
		// Export THIS module to a Studio project.
		Do ..PackageOneModule(..Module,tTarget,.pParams,.tModuleLocations,.tRtn)
		
		// Create one Studio project to rule them all
		Set tMainProjectName = $Replace(..Module.Name,".","_")_"_Bundle"
		If ##class(%Studio.Project).%ExistsId(tMainProjectName) {
			$$$ThrowOnError(##class(%Studio.Project).Delete(tMainProjectName))
		}
		
		Set tMainProject = ##class(%Studio.Project).%New()
		Set tMainProject.Name = tMainProjectName
		$$$ThrowOnError(tMainProject.AddItem(tTarget_".GBL"))
		
		// Installation routine: install sub-projects from globals.
		Set tPackedDocumentClass = "zTemp.PackageManager.Container"
		Set tRtn($i(tRtn)) = "MAIN"
		For tIndex = 1:1:tModuleLocations {
			Set tModuleName = tModuleLocations(tIndex)
			Set tIsPackageManager = (tModuleName = "ZHSLIB") && (..Module.Name '= "ZHSLIB")
			If tIsPackageManager {
				Set tRtn($i(tRtn)) = " If '$$$comClassDefined(""%ZPM.PackageManager"") {"
			}
			If tIncludePackageManager {
				If (tModuleName = "ZHSLIB") {
					// No-op - handled in PackageOneModule.
				} Else {
					Set tUndeployableItems(tModuleName_".ZPM") = ""
				}
			}
			Set tRtn($i(tRtn)) = " Write !,""Installing "","_$$$QUOTE(tModuleName)
			Set tRtn($i(tRtn)) = " Do Install"_tIndex
			If tIsPackageManager {
				Set tRtn($i(tRtn)) = " }"
				Set tRtn($i(tRtn)) = " Do ##class("_tPackedDocumentClass_").Unpack()"
			}
		}
		Set tRtn($i(tRtn)) = " Quit"
		Do ..AddInstallRoutine(tMainProject,.tRtn)
		
		If $Data(tUndeployableItems) {
			$$$ThrowOnError(##class(%ZPM.Lifecycle.StudioProject.ContainerClass).Create(tPackedDocumentClass,.tUndeployableItems,tVerbose))
			Do tMainProject.AddItem(tPackedDocumentClass_".CLS")
		}
		
		$$$ThrowOnError(tMainProject.%Save())
		
		If tVerbose {
			Write !!,"Wrapper project:",!
		}
		
		$$$ThrowOnError(tMainProject.DeployToFile(tTargetFile,$Select(tVerbose:"d",1:"-d")))
		
		Set tPayloadStream = ##class(%Stream.FileCharacter).%OpenId(tTargetFile,,.tSC)
		$$$ThrowOnError(tSC)
		$$$ThrowOnError(..Payload.CopyFrom(tPayloadStream))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Packages a single module as a subordinate Studio project, and configures the overall installation routine with instructions to install it.
Method PackageOneModule(pModule As %ZPM.PackageManager.Developer.Module, pTargetGlobal As %String, ByRef pParams, ByRef pModuleLocations, ByRef pInstallerCode) [ Internal, Private ]
{
	Set tVerbose = $Get(pParams("Verbose"),0)
	Set tDeployDefault = $Get(pParams("Package","Deploy"),0)
	Set tIncludePackageManager = $Get(pParams("Package","Manager"),0)
	Set tIsPackageManager = (pModule.Name = "ZHSLIB")
	Set tKeepGenerated = $Get(pParams("Package","KeepGenerated"),0)
	
	Set pModuleLocations(0,pModule.Name) = $Increment(pModuleLocations)
	Set pModuleLocations(pModuleLocations) = pModule.Name
	Set pInstallerCode($i(pInstallerCode)) = "Install"_pModuleLocations_" ;"_pModule.Name
	
	#dim tProject,tSourceProject As %Studio.Project
	// Project for deployed code
	If tVerbose {
		Write !!,"Deployed code (",pModule.Name,"):",!
	}
	$$$ThrowOnError(pModule.GetStudioProject(.tProject,1,tDeployDefault,"object"))
	
	If tIsPackageManager {
		Set tPackedZHSLIBClass = "zTemp.PackageManager.Container.ZHSLIB"
		$$$ThrowOnError(##class(%ZPM.Lifecycle.StudioProject.ContainerClass).Create(tPackedZHSLIBClass,"ZHSLIB.ZPM",tVerbose))
		Do tProject.AddItem(tPackedZHSLIBClass_".CLS")
	}
	$$$ThrowOnError(tProject.DeployToGbl($Name(@pTargetGlobal@(pModuleLocations,"object")),$Select(tVerbose:"d-k",1:"-d-k"),1))
	
	// Project for non-deployed code
	If tVerbose {
		Write !!,"Source code (",pModule.Name,"):",!
	}
	$$$ThrowOnError(pModule.GetStudioProject(.tSourceProject,0,tDeployDefault,"source"))
	
	// Add in static files
	Set tTempFileManager = ##class(%ZPM.PackageManager.Core.TempFileManager).%Get(.tSC)
	$$$ThrowOnError(tSC)
	Set tWorkingDirectory = tTempFileManager.GetTempFolderName()
	
	// Notify resource processors for harvest of static files from module root
	Set tKey = ""
	For {
		#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
		Set tResource = pModule.Resources.GetNext(.tKey)
		Quit:(tKey="")
		
		If $IsObject(tResource.Processor) {
			Set tSC = $Method(tResource.Processor,"OnBeforeArtifact",pModule.Root,tWorkingDirectory,.pParams)
			If $$$ISERR(tSC) {
				Quit
			}
		}
	}
	Set tArchive = ##class(%ZPM.PackageManager.Core.XDataArchive).%New(tWorkingDirectory)
	$$$ThrowOnError(tArchive.AddToProject(tSourceProject,tVerbose))
	
	Set tInstallerClass = ""
	If '(tIncludePackageManager || tIsPackageManager) && (pModule.InstallerClass '= "") {
		// Use zTemp package to avoid package collisions, and (more importantly) support installation in %SYS namespace
		Set tInstallerClass = "zTemp.PackageManager.Installer."_pModule.Name
		
		If ##class(%Dictionary.ClassDefinition).%ExistsId(tInstallerClass) {
			$$$ThrowOnError(##class(%Dictionary.ClassDefinition).%DeleteId(tInstallerClass))
		}
		
		// Copy installer class to a version that doesn't extend %ZPM.AbstractInstaller.
		Set tSourceClass = ##class(%Dictionary.ClassDefinition).%OpenId(pModule.InstallerClass,,.tSC)
		$$$ThrowOnError(tSC)
		
		Set tDestClass = tSourceClass.%ConstructClone(1)
		Set tDestClass.Super = ""
		Set tDestClass.Name = tInstallerClass
		$$$ThrowOnError(tDestClass.%Save())
		$$$ThrowOnError($System.OBJ.Compile(tInstallerClass,"c-k-d"))
		$$$ThrowOnError(tSourceProject.AddItem(tInstallerClass,"CLS"))
		Do tSourceProject.RemoveItem(pModule.InstallerClass,"CLS")
	}
	
	$$$ThrowOnError(tSourceProject.DeployToGbl($Name(@pTargetGlobal@(pModuleLocations,"source")),$Select(tVerbose:"d",1:"-d")_$Select(tKeepGenerated:"k",1:"-k")))
	
	Set pInstallerCode($i(pInstallerCode)) = " $$$ThrowOnError(##class(%Studio.Project).InstallFromGbl("_$$$QUOTE($Name(@pTargetGlobal@(pModuleLocations,"object")))_",""-d"",0))"
	Set pInstallerCode($i(pInstallerCode)) = " $$$ThrowOnError(##class(%Studio.Project).InstallFromGbl("_$$$QUOTE($Name(@pTargetGlobal@(pModuleLocations,"source")))_",""-d"",0))"
	
	// Unpack static files
	Set pInstallerCode($i(pInstallerCode)) = " Set tExtractDirectory = ##class(%Library.File).TempFilename()_""d"""
	$$$ThrowOnError(tArchive.GenerateInstallerCode("tExtractDirectory",.pInstallerCode))
	
	If tIsPackageManager {
		// Note: only unpack ZHSLIB module manifest if ZHSLIB module was installed.
		Set pInstallerCode($i(pInstallerCode)) = " Do ##class("_tPackedZHSLIBClass_").Unpack()"
	}
	
	// TODO: Support CSP/other files
	If tIncludePackageManager || tIsPackageManager {
		// Just run the Activate lifecycle phase.
		Set pInstallerCode($i(pInstallerCode)) = " Kill tParams"
		Set pInstallerCode($i(pInstallerCode)) = " Set tParams(""RootDirectory"") = tExtractDirectory"
		Set pInstallerCode($i(pInstallerCode)) = " $$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Module).ExecutePhases("_$$$QUOTE(pModule.Name)_",$ListBuild(""Activate""),,.tParams))"
	} ElseIf (tInstallerClass '= "") {
		If $$$defMemberDefined(tInstallerClass,$$$cCLASSmethod,"OnInstallComponent") {
			Set pInstallerCode($i(pInstallerCode)) = " $$$ThrowOnError(##class("_tInstallerClass_").OnInstallComponent(""""))"
		}
		If $$$defMemberDefined(tInstallerClass,$$$cCLASSmethod,"OnConfigureComponent") {
			Set pInstallerCode($i(pInstallerCode)) = " Set tVars(""Lifecycle"") = "_$$$QUOTE($classname())
			Set pInstallerCode($i(pInstallerCode)) = " Set tVars(""InstallDir"") = tExtractDirectory"
			Set pInstallerCode($i(pInstallerCode)) = " $$$ThrowOnError(##class("_tInstallerClass_").OnConfigureComponent($Namespace,,.tVars))"
		}
		Set pInstallerCode($i(pInstallerCode)) = " $$$ThrowOnError($System.OBJ.Delete("_$$$QUOTE(tInstallerClass)_",""-d""))"
	}
	Set pInstallerCode($i(pInstallerCode)) = " Write !,""Successfully installed "","_$$$QUOTE(pModule.Name_" "_pModule.VersionString)
	Set pInstallerCode($i(pInstallerCode)) = " Quit"
}

/// Adds an installation routine with the specified code to the project
Method AddInstallRoutine(pProject As %Studio.Project, ByRef pCode) [ Internal, Private ]
{
	If ##class(%Library.Routine).Exists("INSTALL.MAC") {
		$$$ThrowOnError(##class(%Library.Routine).Delete("INSTALL.MAC"))
	}
	Set tRoutine = ##class(%Routine).%New("INSTALL.MAC")
	For tLine=1:1:$Get(pCode) {
		Do tRoutine.WriteLine($Get(pCode(tLine)))
	}
	$$$ThrowOnError(tRoutine.Save())
	$$$ThrowOnError(tRoutine.Compile("-d"))
	Do pProject.AddItem("INSTALL.MAC")
}

/// Callback from the Verify phase to install the module payload in a different namespace.
Method OnInstallFromPayload(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tTmpStream = ##class(%Stream.FileBinary).%New()
		$$$ThrowOnError(tTmpStream.CopyFromAndSave(..Payload))
		$$$ThrowOnError(##class(%Studio.Project).InstallFromFile(tTmpStream.Filename))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
