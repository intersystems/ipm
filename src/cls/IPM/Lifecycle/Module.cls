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

        // Create Studio project for package if it is loaded in developer mode and no explicit statement to not create it
        set tNoStudioProject = $get(pParams("NoStudioProject"), 0)
        if ..Module.DeveloperMode && 'tNoStudioProject {
            #dim tProject As %Studio.Project
            // Do not throw exceptions if failure to create because creating a Studio project should not block activation.
            // Just write the exception if in verbose mode
            set tStudioProjectSC = ..Module.GetStudioProject(.tProject)
            set tVerbose = $get(pParams("Verbose"))
            if tVerbose {
                if $$$ISOK(tStudioProjectSC) {
                    write !, "Studio project created/updated: " _ tProject.Name _ ".PRJ"
                } else {
                    write !, "Unable to create/update Studio project: " _ tProject.Name _ ".PRJ"
                    write !, $system.Status.GetErrorText(tStudioProjectSC)
                }
            }
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

        set tNSConfig = ..Module.GetNamespaceConfig()

        set pParams("InitNamespace") = $namespace

        set tNSPostfix = "PACKAGE-" _ $piece($zhorolog, ".")
        set tSC = ##class(%IPM.Utils.Build).InitializeNamespace(tNSPostfix, tVerbose, .tPackageDeployNamespace, tNSConfig)
        $$$ThrowOnError(tSC)
        set pParams("PackageDeployNamespace") = tPackageDeployNamespace

        $$$ThrowOnError(..Module.%Reload())

        set tSource = tPackageDeployNamespace _ "-CODE"
        set orderedResourceList = ..GetOrderedResourceList()
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
        if (tExportDirectory'="") && ('##class(%File).DirectoryExists(tExportDirectory)) {
            set tExportDirectory = ##class(%File).NormalizeDirectory(tExportDirectory)
            if '##class(%File).CreateDirectoryChain(tExportDirectory,.tReturn) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",tExportDirectory,tReturn))
                quit
            }
        }

        set tSC = ..%Export(.pParams,.tExportDirectory)
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = ..OnBeforeArtifact(tExportDirectory,tExportDirectory,.pParams)
        if $$$ISERR(tSC) {
            quit
        }

        write:tVerbose !,"Module exported to:",!,$char(9),tExportDirectory,!

        set tTgzFile = $extract(tExportDirectory,1,*-1)_".tgz"
        set tSC = ##class(%IPM.General.Archive).Create(tExportDirectory,tTgzFile,.tOutput)
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
