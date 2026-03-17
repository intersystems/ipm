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

        // Special handling for IPM self-uninstall: clean up operational globals
        if (..Module.Name = $$$IPMModuleName) {
            set verbose = $get(pParams("Verbose"))

            // Check if user wants full cleanup
            set fullCleanup = $get(pParams("Clean","FullCleanup"), 0)

            if fullCleanup {
                // Full cleanup: delete ALL module records and operational globals
                write !,"Performing full cleanup of IPM operational globals..."

                kill ^IPM.Storage.ModuleD          // Delete ALL module records (including orphans)
                kill ^IPM.Storage.ModuleI
                kill ^IPM.Storage.InvokeReferenceC
                kill ^IPM.Storage.ResourceReferenceC
                kill ^IPM.Storage.ResourceReferenceI
                kill ^IPM.Storage.SystemRequirementsD
                kill ^IPM.Repo.DefinitionD
                kill ^IPM.Repo.DefinitionI
                kill ^IPM.Repo.Filesystem.CacheD
                kill ^IPM.General.SettingsD
                kill ^IPM.UpdateStep.AnyMemberD
                kill ^IPM.UpdateStep.PrimaryOnlyD
                kill ^IPM.StudioDoc.ModuleStreamD
                kill ^IPM.StudioDoc.ModuleStreamI
                kill ^IPM.StudioDoc.ModuleStreamS
                kill ^IPM.StudioDoc.LocalMsgStreamD
                kill ^IRIS.Temp.HistoryTempD
                kill ^IRIS.Temp.IPM.LoadedResourceD

                // Note: Preserve ^IPM.General.HistoryD for audit trail
                // Note: Preserve ^IPM.settings in %SYS for user preferences

                write:verbose !,"Full cleanup complete: All module records deleted."
            } else {
                // Check if modules were orphaned (user used -force)
                // IPM is always at index 1, so start checking at index 2
                set tOrphanedModules = ""
                set tIndex = 1
                for {
                    set tIndex = $order(^IPM.Storage.ModuleD(tIndex))
                    quit:tIndex=""
                    set tOrphanedModules = tOrphanedModules _ $listbuild(tIndex)
                }

                if $listlength(tOrphanedModules) > 0 {
                    // Modules were orphaned - warn user but still clean up
                    write !,"Warning: ",$listlength(tOrphanedModules)," module(s) orphaned:"

                    // List orphaned modules with versions
                    set tPtr = 0
                    while $listnext(tOrphanedModules, tPtr, tIndex) {
                        try {
                            set tModData = ^IPM.Storage.ModuleD(tIndex)
                            set tModName = $listget(tModData, 2)
                            set tVersion = $listget(tModData, 4)
                            write !,"  - ",tModName," (",tVersion,")"
                        } catch {
                            write !,"  - (unknown module at index ",tIndex,")"
                        }
                    }
                    write !,"Reinstalling IPM will automatically re-adopt these modules."
                }
            }
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

  quit tSC
}

}
