Class %IPM.Lifecycle.Module Extends %IPM.Lifecycle.Base
{

Property Payload As %Stream.TmpBinary [ Private ];

Parameter PACKAGING As STRING [ Final ] = "module";

Method %Clean(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tSC = ..CheckBeforeClean(.pParams,.tSkip)
        if (tSkip) {
            quit
        }

        set tSC = ..Unconfigure(.pParams)
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = ##super(.pParams)
        if $$$ISERR(tSC) {
            quit
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Activate(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tSC = ##super(.pParams)
        $$$ThrowOnError(tSC)

        set tSC = ..Configure(.pParams)
        $$$ThrowOnError(tSC)

        set verbose = $get(pParams("Verbose"))
        // Create Studio project for package if it is loaded in developer mode and no explicit statement to not create it
        set tNoStudioProject = $get(pParams("NoStudioProject"), 0)
        if ..Module.DeveloperMode && 'tNoStudioProject {
            #dim tProject As %Studio.Project
            // Do not throw exceptions if failure to create because creating a Studio project should not block activation.
            // Just write the exception if in verbose mode
            set tStudioProjectSC = ..Module.GetStudioProject(.tProject)
            if verbose {
                if $$$ISOK(tStudioProjectSC) {
                    write !, "Studio project created/updated: " _ tProject.Name _ ".PRJ"
                } else {
                    write !, "Unable to create/update Studio project: " _ tProject.Name _ ".PRJ"
                    write !, $system.Status.GetErrorText(tStudioProjectSC)
                }
            }
        }
        if '$get(pParams("Update")) && '..Module.DeveloperMode {
            if verbose {
                write !, "Seeding update steps for module = ",..Module.Name, ", for version = ", ..Module.VersionString, !
            }
            $$$ThrowOnError(..Module.HandleAllUpdateSteps(, 1, verbose))
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %PrepareDeploy(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        merge tParams = pParams
        set pParams("RootDirectory") = ..Module.Root

        set tNSConfig = ..Module.GetNamespaceConfig()

        set pParams("InitNamespace") = $namespace

        set tNSPostfix = "PACKAGE-" _ $piece($zhorolog, ".")
        set sysReqs = ..Module.SystemRequirements
        if $isobject(sysReqs) && (sysReqs.Interoperability = "enabled") {
            set tNSConfig.EnableEnsemble = 1
        }
        set tSC = ##class(%IPM.Utils.Build).InitializeNamespace(tNSPostfix, tVerbose, .tPackageDeployNamespace, tNSConfig)
        $$$ThrowOnError(tSC)
        set pParams("PackageDeployNamespace") = tPackageDeployNamespace
        set pParams("PackageDeployOriginalNamespace") = $namespace

        $$$ThrowOnError(..Module.%Reload())

        set tSource = tPackageDeployNamespace _ "-CODE"
        set orderedResourceList = ..Module.GetOrderedResourceList()

        // also map dependencies
        set deps = ..Module.Dependencies
        for i=1:1:deps.Count() {
            set depName = deps.GetAt(i).Name
            set depMod = ##class(%IPM.Storage.Module).NameOpen(depName,,.tSC)
            $$$ThrowOnError(tSC)
            set depResourceList = depMod.GetOrderedResourceList()
            for j=1:1:depResourceList.Count() {
                $$$ThrowOnError(orderedResourceList.Insert(depResourceList.GetAt(j)))
            }
        }

        set tKey = ""
        for {
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:(tKey="")

            set tName = $piece(tResource.Name, ".", 1, *-1)
            set tExtension = $$$ucase($piece(tResource.Name, ".", *))
            if (tExtension = "") || ($extract(tExtension) = "/") {
                continue
            }

            set tSC = $case(tExtension,
                "GBL":##class(%IPM.Utils.Module).AddGlobalMapping(tPackageDeployNamespace, tName, tSource),
                "INC":##class(%IPM.Utils.Module).AddRoutineMapping(tPackageDeployNamespace, tName, "INC", tSource),
                "INT":##class(%IPM.Utils.Module).AddRoutineMapping(tPackageDeployNamespace, tName, "INT", tSource),
                "MAC":##class(%IPM.Utils.Module).AddRoutineMapping(tPackageDeployNamespace, tName, "MAC", tSource),
                "PKG":##class(%IPM.Utils.Module).AddPackageMapping(tPackageDeployNamespace, tName, tSource),
                "":##class(%IPM.Utils.Module).AddRoutineMapping(tPackageDeployNamespace, tName, "ALL", tSource),
                :$$$OK
            )
            $$$ThrowOnError(tSC)
        }
        set $namespace = tPackageDeployNamespace
        write:tVerbose !,"Packaging in namespace: ",$namespace
    } catch e {
        set tSC = e.AsStatus()
        if $get(tPackageDeployNamespace)'="" {
            do ##class(%IPM.Utils.Build).DeleteNamespace(tPackageDeployNamespace, tVerbose)
        }
    }
    quit tSC
}

Method %Package(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        if ..Module.HaveToDeploy() {
            $$$ThrowOnError(..MakeDeployed(.pParams))
        }

        set tExportDirectory = $get(pParams("Path"))
        if (tExportDirectory'="") {
            // create temporary subdirectory to prevent clashes
            set randomDir = $translate($system.Encryption.Base64Encode($system.Encryption.GenCryptRand(6)),"+/=")
            set tExportSubDirectory = ##class(%Library.File).NormalizeDirectory(tExportDirectory) _ randomDir _ "/"
            if '##class(%File).CreateDirectoryChain(tExportSubDirectory,.tReturn) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",tExportSubDirectory,tReturn))
                quit
            }
        }

        set tSC = ..%Export(.pParams,.tExportSubDirectory)
        if $$$ISERR(tSC) {
            quit
        }
        // If no path is specified, the above call to %Export will generate a temporary directory
        if tExportDirectory="" {
            set tExportDirectory = tExportSubDirectory
        }

        set tSC = ..OnBeforeArtifact(tExportSubDirectory,tExportSubDirectory,.pParams)
        if $$$ISERR(tSC) {
            quit
        }

        write:tVerbose !,"Module contents exported to temporary directory:",!,$char(9),tExportSubDirectory,!

        set tTgzFile = $extract(tExportDirectory,1,*-1)_".tgz"
        set tSC = ##class(%IPM.General.Archive).Create(tExportSubDirectory,tTgzFile,.tOutput)
        if $$$ISERR(tSC) {
            quit
        }

        for i=1:1:$get(tOutput) {
            write:tVerbose !,tOutput(i)
        }

        // Always show this message
        write:tVerbose !,"Module package generated:",!,$char(9),tTgzFile

        set tSrcFileStream = ##class(%Stream.FileBinary).%New()
        set tSC = tSrcFileStream.LinkToFile(tTgzFile)
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = ..Payload.CopyFrom(tSrcFileStream)
        if $$$ISERR(tSC) {
            quit
        }
        set pParams("PackageFile") = tTgzFile

    } catch e {
        set tSC = e.AsStatus()
    }

    // Delete the temporary export directory
    if ($get(tExportSubDirectory)'="") && ##class(%Library.File).DirectoryExists(tExportSubDirectory) {
        set tSC = $$$ADDSC(tSC, ##class(%IPM.Utils.File).RemoveDirectoryTree(tExportSubDirectory))
    }

    if '$get(pParams("Package","KeepNamespace")) {
        set tPackageDeployNamespace = $get(pParams("PackageDeployNamespace"))
        set tInitNamespace = $get(pParams("InitNamespace"))
        if (tInitNamespace '= ""), (tPackageDeployNamespace '= ""), tInitNamespace '= $namespace {
            set $namespace = tInitNamespace
            do ##class(%IPM.Utils.Build).DeleteNamespace(tPackageDeployNamespace, tVerbose)
            kill pParams("PackageDeployNamespace"), pParams("InitNamespace")
        }
    }

  quit tSC
}

}
