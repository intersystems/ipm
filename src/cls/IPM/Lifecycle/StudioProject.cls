/// Supports packaging and installing modules from Studio projects.
/// Additional command line flags:
/// <ul>
/// <li><strong>-DPackage.WithDependencies=1</strong>: includes dependencies in the module package</li>
/// <li><strong>-DPackage.Manager=1</strong>: includes package manager itself in the module package, to be bootstrapped in if it is not already installed</li>
/// <li><strong>-DPackage.Target=C:\path\to\file.xml</strong>: exports the package to the specified file</li>
/// <li><strong>-DPackage.Deploy=1</strong>: deploys all resources that are not explicitly listed with "Deploy=false"</li>
/// </ul>
Class %IPM.Lifecycle.StudioProject Extends %IPM.Lifecycle.Base
{

Property Payload As %Stream.TmpCharacter [ Private ];

Parameter PACKAGING As STRING [ Final ] = "studio-project";

/// Packages all of the resources in a module (possibly including its dependencies, possibly including the package manager, possibly deploying by default)
/// into a Studio project with a set of subordinate Studio projects.
Method %Package(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tTarget = $name(^CacheTemp.ZPMProjectExport($increment(^CacheTemp.ZPMProjectExport)))
        kill @tTarget
        set tVerbose = $get(pParams("Verbose"),0)
        set tIncludeDependencies = $get(pParams("Package","WithDependencies"),0)
        set tIncludePackageManager = $get(pParams("Package","Manager"),0)
        set tTargetFile = $get(pParams("Package","Target"),##class(%Library.File).TempFilename("xml"))

        // Installer routine - header/main entry point.
        set tRtn($increment(tRtn)) = " #include %occInclude"
        set tRtn($increment(tRtn)) = " Do MAIN"
        set tRtn($increment(tRtn)) = " Quit"

        // Possibly, include package manager in package and install it if needed.
        if tIncludePackageManager {
            if ##class(%IPM.Storage.Module).NameExists($$$IPMModuleName) {
                set tIPMModule = ##class(%IPM.Storage.Module).NameOpen($$$IPMModuleName,,.tSC)
                $$$ThrowOnError(tSC)
                do ..PackageOneModule(tIPMModule,tTarget,.pParams,.tModuleLocations,.tRtn)
            } else {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Attempted to include package manager, but module not defined in this namespace."))
            }
        }

        // Possibly include dependencies in the package, and install them.
        if tIncludeDependencies {
            $$$ThrowOnError(..Module.BuildDependencyGraph(.tDependencyGraph))
            set tModule = ""
            for {
                set tModule = $order(tDependencyGraph(tModule),1,tData)
                if (tModule = "") {
                    quit
                }
                set tDepthGraph($listget(tData),$increment(tDepthGraph($listget(tData)))) = ##class(%IPM.Storage.Module).NameOpen(tModule,,.tSC)
                $$$ThrowOnError(tSC)
            }

            for tDepth=$order(tDepthGraph(""),-1):-1:1 {
                for tIndex=1:1:tDepthGraph(tDepth) {
                    do ..PackageOneModule(tDepthGraph(tDepth,tIndex),tTarget,.pParams,.tModuleLocations,.tRtn)
                }
            }
        }

        // Export THIS module to a Studio project.
        do ..PackageOneModule(..Module,tTarget,.pParams,.tModuleLocations,.tRtn)

        // Create one Studio project to rule them all
        set tMainProjectName = $replace(..Module.Name,".","_")_"_Bundle"
        if ##class(%Studio.Project).%ExistsId(tMainProjectName) {
            $$$ThrowOnError(##class(%Studio.Project).Delete(tMainProjectName))
        }

        set tMainProject = ##class(%Studio.Project).%New()
        set tMainProject.Name = tMainProjectName
        $$$ThrowOnError(tMainProject.AddItem(tTarget_".GBL"))

        // Installation routine: install sub-projects from globals.
        set tPackedDocumentClass = "zTemp.PackageManager.Container"
        set tRtn($increment(tRtn)) = "MAIN"
        for tIndex = 1:1:tModuleLocations {
            set tModuleName = tModuleLocations(tIndex)
            set tIsPackageManager = (tModuleName = $$$IPMModuleName) && (..Module.Name '= $$$IPMModuleName)
            if tIsPackageManager {
                set tRtn($increment(tRtn)) = " If '$$$comClassDefined(""%IPM.Main"") {"
            }
            if tIncludePackageManager {
                if (tModuleName = $$$IPMModuleName) {
                    // No-op - handled in PackageOneModule.
                } else {
                    set tUndeployableItems(tModuleName_".ZPM") = ""
                }
            }
            set tRtn($increment(tRtn)) = " Write !,""Installing "","_$$$QUOTE(tModuleName)
            set tRtn($increment(tRtn)) = " Do Install"_tIndex
            if tIsPackageManager {
                set tRtn($increment(tRtn)) = " }"
                set tRtn($increment(tRtn)) = " Do ##class("_tPackedDocumentClass_").Unpack()"
            }
        }
        set tRtn($increment(tRtn)) = " Quit"
        do ..AddInstallRoutine(tMainProject,.tRtn)

        if $data(tUndeployableItems) {
            $$$ThrowOnError(##class(%IPM.Lifecycle.StudioProject.ContainerClass).Create(tPackedDocumentClass,.tUndeployableItems,tVerbose))
            do tMainProject.AddItem(tPackedDocumentClass_".CLS")
        }

        $$$ThrowOnError(tMainProject.%Save())

        if tVerbose {
            write !!,"Wrapper project:",!
        }

        $$$ThrowOnError(tMainProject.DeployToFile(tTargetFile,$select(tVerbose:"d",1:"-d")_"/createdirs"))

        set tPayloadStream = ##class(%Stream.FileCharacter).%OpenId(tTargetFile,,.tSC)
        $$$ThrowOnError(tSC)
        $$$ThrowOnError(..Payload.CopyFrom(tPayloadStream))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Packages a single module as a subordinate Studio project, and configures the overall installation routine with instructions to install it.
Method PackageOneModule(
	pModule As %IPM.Storage.Module,
	pTargetGlobal As %String,
	ByRef pParams,
	ByRef pModuleLocations,
	ByRef pInstallerCode) [ Internal, Private ]
{
    set tVerbose = $get(pParams("Verbose"),0)
    set tDeployDefault = $get(pParams("Package","Deploy"),0)
    set tIncludePackageManager = $get(pParams("Package","Manager"),0)
    set tIsPackageManager = (pModule.Name = $$$IPMModuleName)
    set tKeepGenerated = $get(pParams("Package","KeepGenerated"),0)

    set pModuleLocations(0,pModule.Name) = $increment(pModuleLocations)
    set pModuleLocations(pModuleLocations) = pModule.Name
    set pInstallerCode($increment(pInstallerCode)) = "Install"_pModuleLocations_" ;"_pModule.Name

    #dim tProject,tSourceProject As %Studio.Project
    // Project for deployed code
    if tVerbose {
        write !!,"Deployed code (",pModule.Name,"):",!
    }
    $$$ThrowOnError(pModule.GetStudioProject(.tProject,1,tDeployDefault,"object"))

    if tIsPackageManager {
        set tPackedIPMClass = "zTemp.PackageManager.Container."_$$$IPMModuleName
        $$$ThrowOnError(##class(%IPM.Lifecycle.StudioProject.ContainerClass).Create(tPackedIPMClass,$$$IPMModuleName_".ZPM",tVerbose))
        do tProject.AddItem(tPackedIPMClass_".CLS")
    }
    $$$ThrowOnError(tProject.DeployToGbl($name(@pTargetGlobal@(pModuleLocations,"object")),$select(tVerbose:"d-k",1:"-d-k"),1))

    // Project for non-deployed code
    if tVerbose {
        write !!,"Source code (",pModule.Name,"):",!
    }
    $$$ThrowOnError(pModule.GetStudioProject(.tSourceProject,0,tDeployDefault,"source"))

    // Add in static files
    set tTempFileManager = ##class(%IPM.Utils.TempFileManager).%Get(.tSC)
    $$$ThrowOnError(tSC)
    set tWorkingDirectory = tTempFileManager.GetTempFolderName()

    // Notify resource processors for harvest of static files from module root
    set orderedResourceList = pModule.GetOrderedResourceList()
    set tKey = ""
    for {
        #dim tResource As %IPM.Storage.ResourceReference
        set tResource = orderedResourceList.GetNext(.tKey)
        quit:(tKey="")

        if $isobject(tResource.Processor) {
            set tSC = $method(tResource.Processor,"OnBeforeArtifact",pModule.Root,tWorkingDirectory,.pParams)
            if $$$ISERR(tSC) {
                quit
            }
        }
    }
    set tArchive = ##class(%IPM.Lifecycle.StudioProject.XDataArchive).%New(tWorkingDirectory)
    $$$ThrowOnError(tArchive.AddToProject(tSourceProject,tVerbose))

    set tInstallerClass = ""
    if '(tIncludePackageManager || tIsPackageManager) && (pModule.InstallerClass '= "") {
        // Use zTemp package to avoid package collisions, and (more importantly) support installation in %SYS namespace
        set tInstallerClass = "zTemp.PackageManager.Installer."_pModule.Name

        if ##class(%Dictionary.ClassDefinition).%ExistsId(tInstallerClass) {
            $$$ThrowOnError(##class(%Dictionary.ClassDefinition).%DeleteId(tInstallerClass))
        }

        // Copy installer class to a version that doesn't extend %IPM.AbstractInstaller.
        set tSourceClass = ##class(%Dictionary.ClassDefinition).%OpenId(pModule.InstallerClass,,.tSC)
        $$$ThrowOnError(tSC)

        set tDestClass = tSourceClass.%ConstructClone(1)
        set tDestClass.Super = ""
        set tDestClass.Name = tInstallerClass
        $$$ThrowOnError(tDestClass.%Save())
        $$$ThrowOnError($system.OBJ.Compile(tInstallerClass,"c-k-d"))
        $$$ThrowOnError(tSourceProject.AddItem(tInstallerClass,"CLS"))
        do tSourceProject.RemoveItem(pModule.InstallerClass,"CLS")
    }

    $$$ThrowOnError(tSourceProject.DeployToGbl($name(@pTargetGlobal@(pModuleLocations,"source")),$select(tVerbose:"d",1:"-d")_$select(tKeepGenerated:"k",1:"-k")))

    // Map %IPM to current routine database
    if tIsPackageManager {
        set pInstallerCode($increment(pInstallerCode)) = " Set currentNS = $Namespace"
        set pInstallerCode($increment(pInstallerCode)) = " Set mapping = ""%IPM"""
        set pInstallerCode($increment(pInstallerCode)) = " New $Namespace "
        set pInstallerCode($increment(pInstallerCode)) = " Set $Namespace = ""%SYS"""
        set pInstallerCode($increment(pInstallerCode)) = " If '##class(Config.MapPackages).Exists(currentNS, mapping) {"
        set pInstallerCode($increment(pInstallerCode)) = " Kill NSprops"
        set pInstallerCode($increment(pInstallerCode)) = " $$$ThrowOnError(##class(Config.Namespaces).Get(currentNS, .NSprops))"
        set pInstallerCode($increment(pInstallerCode)) = " Kill tProps"
        set pInstallerCode($increment(pInstallerCode)) = " Set tProps(""Database"") = $Get(NSprops(""Routines""))"
        set pInstallerCode($increment(pInstallerCode)) = " $$$ThrowOnError(##class(Config.MapPackages).Create(currentNS, mapping, .tProps))"
        set pInstallerCode($increment(pInstallerCode)) = " }"
        set pInstallerCode($increment(pInstallerCode)) = " Set $Namespace = currentNS"
    }
    set pInstallerCode($increment(pInstallerCode)) = " $$$ThrowOnError(##class(%Studio.Project).InstallFromGbl("_$$$QUOTE($name(@pTargetGlobal@(pModuleLocations,"object")))_",""-d"",0))"
    set pInstallerCode($increment(pInstallerCode)) = " $$$ThrowOnError(##class(%Studio.Project).InstallFromGbl("_$$$QUOTE($name(@pTargetGlobal@(pModuleLocations,"source")))_",""-d"",0))"

    // Unpack static files
    set pInstallerCode($increment(pInstallerCode)) = " Set tExtractDirectory = ##class(%Library.File).TempFilename()_""d"""
    $$$ThrowOnError(tArchive.GenerateInstallerCode("tExtractDirectory",.pInstallerCode))

    if tIsPackageManager {
        // Note: only unpack package manager module manifest if module was installed.
        set pInstallerCode($increment(pInstallerCode)) = " Do ##class("_tPackedIPMClass_").Unpack()"
    }

    // TODO: Support CSP/other files
    if tIncludePackageManager || tIsPackageManager {
        // Just run the Activate lifecycle phase.
        set pInstallerCode($increment(pInstallerCode)) = " Kill tParams"
        set pInstallerCode($increment(pInstallerCode)) = " Set tParams(""RootDirectory"") = tExtractDirectory"
        set pInstallerCode($increment(pInstallerCode)) = " $$$ThrowOnError(##class(%IPM.Storage.Module).ExecutePhases("_$$$QUOTE(pModule.Name)_",$ListBuild(""Activate""),,.tParams))"
    } elseif (tInstallerClass '= "") {
        if $$$defMemberDefined(tInstallerClass,$$$cCLASSmethod,"OnInstallComponent") {
            set pInstallerCode($increment(pInstallerCode)) = " $$$ThrowOnError(##class("_tInstallerClass_").OnInstallComponent(""""))"
        }
        if $$$defMemberDefined(tInstallerClass,$$$cCLASSmethod,"OnConfigureComponent") {
            set pInstallerCode($increment(pInstallerCode)) = " Set tVars(""Lifecycle"") = "_$$$QUOTE($classname())
            set pInstallerCode($increment(pInstallerCode)) = " Set tVars(""InstallDir"") = tExtractDirectory"
            set pInstallerCode($increment(pInstallerCode)) = " $$$ThrowOnError(##class("_tInstallerClass_").OnConfigureComponent($Namespace,,.tVars))"
        }
        set pInstallerCode($increment(pInstallerCode)) = " $$$ThrowOnError($System.OBJ.Delete("_$$$QUOTE(tInstallerClass)_",""-d""))"
    }
    set pInstallerCode($increment(pInstallerCode)) = " Write !,""Successfully installed "","_$$$QUOTE(pModule.Name_" "_pModule.VersionString)
    set pInstallerCode($increment(pInstallerCode)) = " Quit"
}

/// Adds an installation routine with the specified code to the project
Method AddInstallRoutine(
	pProject As %Studio.Project,
	ByRef pCode) [ Internal, Private ]
{
    if ##class(%Library.Routine).Exists("INSTALL.MAC") {
        $$$ThrowOnError(##class(%Library.Routine).Delete("INSTALL.MAC"))
    }
    set tRoutine = ##class(%Routine).%New("INSTALL.MAC")
    for tLine=1:1:$get(pCode) {
        do tRoutine.WriteLine($get(pCode(tLine)))
    }
    $$$ThrowOnError(tRoutine.Save())
    $$$ThrowOnError(tRoutine.Compile("-d"))
    do pProject.AddItem("INSTALL.MAC")
}

/// Callback from the Verify phase to install the module payload in a different namespace.
Method OnInstallFromPayload(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tTmpStream = ##class(%Stream.FileBinary).%New()
        $$$ThrowOnError(tTmpStream.CopyFromAndSave(..Payload))
        $$$ThrowOnError(##class(%Studio.Project).InstallFromFile(tTmpStream.Filename))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
