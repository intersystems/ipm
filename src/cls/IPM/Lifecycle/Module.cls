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
