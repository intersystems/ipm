Include %occInclude

Class %IPM.Utils.Migration
{

ClassMethod RunAll(verbose As %Boolean = 1) As %Status
{
    set tOriginalNS = $namespace
    do ##class(%IPM.Main).GetListNamespace(.list)
    new $namespace
    set $namespace = "%SYS"
    set sourceDB = ##class(%SYS.Namespace).GetPackageDest(tOriginalNS, "%IPM")

    set ns = ""
    set sc = $$$OK
    for {
        set ns = $order(list(ns))
        // Perform migration for namespaces to which %IPM is mapped from the current namespace's default routine database
        if ##class(%SYS.Namespace).GetPackageDest(ns, "%IPM") '= sourceDB {
            continue
        }
        if (ns = "") {
            quit
        }
        try {
            set $namespace = $zstrip(ns,"<>WC")
            do ..MigrateReposFromIPM09(verbose) // Do this first; MigrateZPMToIPM will fail with <FRAMESTACK> otherwise.
            do ..MigrateZPMToIPM(verbose)
        } catch e {
            set sc = $$$ADDSC(sc, e.AsStatus())
        }
    }
    quit sc
}

ClassMethod HasLegacyZPMPackage()
{
    set oldTopPackage = "%ZPM.PackageManager."
    quit $order(^oddCOM(oldTopPackage)) [ oldTopPackage
}

ClassMethod MigrateZPMToIPM(verbose As %Boolean = 1)
{
    if verbose {
        write !, "Migrating ZPM data to IPM... in namespace ", $namespace
    }
    if '..HasLegacyZPMPackage() {
        write:verbose !,"Older IPM version not found; nothing to migrate.",!
        quit
    }

    set sc = $$$OK
    set successPackageList = ""
    set failedPackageList = ""

    // Intentionally runs for current namespace only
    try {
        // ^ZPM.Dev.ModuleD -> ^IPM.Storage.ModuleD
        for lockName = $name(^ZPM.Dev.ModuleD),$name(^IPM.Storage.ModuleD) {
            set locks(lockName) = $system.AutoLock.Lock(lockName,,2)
            if locks(lockName) = $$$NULLOREF {
                $$$ThrowStatus($$$ERROR($$$LockFailedExtent,lockName))
            }
        }
        set oldId = ""
        for {
            set oldId = $order(^ZPM.Dev.ModuleD(oldId),1,moduleData)
            quit:oldId=""
            set moduleName = $listget(moduleData,2)
            set oneSC = ..MigrateOnePackageToIPM(oldId, moduleName, verbose)
            if $$$ISOK(oneSC) {
                set successPackageList = successPackageList _ $listbuild(moduleName)
            } else {
                set failedPackageList = failedPackageList _ $listbuild(moduleName)
            }
            set sc = $$$ADDSC(sc,oneSC)
        }

        set sc = $$$ADDSC(sc,##class(%IPM.Storage.Module).%BuildIndices(,1,1))
        set sc = $$$ADDSC(sc,..MigrateRepoDefinitions())
        $$$ThrowOnError(sc)

        if verbose && (successPackageList '= "") {
            write !,"Migrated successfully: ",!,$listtostring(successPackageList,$char(13,10))
        }
    } catch e {
        set sc = e.AsStatus()
        // Show these messages even in verbose mode.
        write !,"IPM data migration was not fully successful. You may be able to reinstall the impacted packages to correct the issues."
        if (successPackageList '= "") {
            write !,"Migrated successfully: ",!,$listtostring(successPackageList,$char(13,10))
        }
        if (failedPackageList '= "") {
            write !,"Failed to migrate: ",!,$listtostring(failedPackageList,$char(13,10))
        }
        write !,$system.Status.GetErrorText(sc)
    }
    write:verbose !
    $$$ThrowOnError(sc)
}

ClassMethod MigrateOnePackageToIPM(
	oldId As %Integer,
	name As %String,
	verbose As %Boolean = 1)
{
    set sc = $$$OK
    set initTLevel = $tlevel
    try {
        if ##class(%IPM.Storage.Module).NameExists(name) {
            write:verbose !,"Package already found in new storage: ",name
            quit
        }

        write:verbose !,"Migrating storage for ",name," ... "

        // Bring everything over - storage definitions are fortunately compatible.
        tstart
        kill moduleData
        merge moduleData = ^ZPM.Dev.ModuleD(oldId)

        // In ^IPM.Storage.ModuleD(<ID>,"Defaults",n) = $lb($lb(<data>),classname), map classname
        // to equivalent - %ZPM.PackageManager.Developer.ModuleSetting -> %IPM.Storage.ModuleSetting
        set defaultKey = ""
        for {
            set defaultKey = $order(moduleData("Defaults",defaultKey),1,defaultData)
            quit:defaultKey=""
            set moduleData("Defaults",defaultKey) = $listbuild($listget(defaultData,1),$replace($listget(defaultData,2),"%ZPM.PackageManager.Developer.ModuleSetting","%IPM.Storage.ModuleSetting"))
        }

        set newId = $increment(^IPM.Storage.ModuleD)
        merge ^IPM.Storage.ModuleD(newId) = moduleData

        // Make sure loading the object works
        set newObj = ##class(%IPM.Storage.Module).%OpenId(newId,,.sc)
        $$$ThrowOnError(sc)

        // Save object to validate
        $$$ThrowOnError(newObj.%Save())

        write:verbose "done."

        // Migrate %ZPM.PackageManager.Developer.Document.ModuleStream to %IPM.StudioDocument.ModuleStream
        // ^ZPM.Dev.ModuleDocD -> ^IPM.StudioDoc.ModuleStreamD
        // Uses objects for the actual data migration to more cleanly handle the stream.
        if ##class(%IPM.StudioDocument.ModuleStream).NameExists(name) {
            write:verbose !,"Document already found in new storage: ",name
        } else {
            set oldObj = $classmethod("%ZPM.PackageManager.Developer.Document.ModuleStream", "NameOpen",name,,.sc)
            $$$ThrowOnError(sc)
            set newObj = ##class(%IPM.StudioDocument.ModuleStream).%New()
            set newObj.Name = oldObj.Name
            set newObj.Hash = oldObj.Hash
            set newObj.LastModifiedTimestamp = oldObj.LastModifiedTimestamp
            $$$ThrowOnError(newObj.Contents.CopyFrom(oldObj.Contents))
            $$$ThrowOnError(newObj.%Save())

            write:verbose !,"Migrated document stream - "_newObj.Name_".ZPM"
        }

        tcommit
    } catch e {
        set sc = e.AsStatus()
    }
    while $tlevel > initTLevel {
        trollback 1
    }
    quit sc
}

ClassMethod MigrateRepoDefinitions(verbose As %Boolean = 1) As %Status
{
    set initTLevel = $tlevel
    try {
        for lockName = $name(^%ZPM.Client.ServerDefD),$name(^IPM.Repo.DefinitionD) {
            set locks(lockName) = $system.AutoLock.Lock(lockName,,2)
            if locks(lockName) = $$$NULLOREF {
                $$$ThrowStatus($$$ERROR($$$LockFailedExtent,lockName))
            }
        }

        tstart
        set key = ""
        for {
            set key = $order(^%ZPM.Client.ServerDefD(key),1,repoData)
            quit:key=""

            set repoName = $listget(repoData,2)
            do ..MigrateOneRepo(key, repoName, verbose)
        }

        $$$ThrowOnError(##class(%IPM.Repo.Definition).%BuildIndices(,1,1))
        $$$ThrowOnError(##class(%IPM.Repo.Remote.Definition).%BuildIndices(,1,1))
        tcommit
    } catch e {
        set sc = e.AsStatus()
    }
    while $tlevel > initTLevel {
        trollback 1
    }
    quit sc
}

ClassMethod MigrateOneRepo(
	oldId As %String,
	name As %String,
	verbose As %Boolean)
{
    if ##class(%IPM.Repo.Remote.Definition).ServerDefinitionKeyExists(name) {
        write:verbose !,"Skipping migrating repo "_name_" - already exists."
        quit
    }
    merge data = ^%ZPM.Client.ServerDefD(oldId)

    set class = $listget(data)
    if (class '= "~%ZPM.PackageManager.Client.RemoteServerDefinition~") {
        write:verbose !,"Skipping migrating repo "_name_" - unsupported repo type."
        quit
    }

    write:verbose !,"Migrating repo "_name_"... "

    set $list(data,1) = "~%IPM.Repo.Http.Definition~%IPM.Repo.Remote.Definition~"
    set data("RepoDefinition") = data
    merge data("RemoteRepoDefinition") = data("RemoteServerDefinition")
    zkill data
    zkill data("RemoteServerDefinition")

    set newId = $increment(^IPM.Repo.DefinitionD)
    merge ^IPM.Repo.DefinitionD(newId) = data

    // Make sure loading/saving the object works
    set newObj = ##class(%IPM.Repo.Definition).%OpenId(newId,,.sc)
    $$$ThrowOnError(sc)

    // Save object to validate
    $$$ThrowOnError(newObj.%Save())

    write:verbose !,"done."
}

ClassMethod MigrateReposFromIPM09(verbose As %Boolean = 1) As %Status
{
    if verbose {
        write !,"Starting IPM repo migration from IPM 0.9..."
    }
    set tSC = $$$OK
    try {
        if $data(^IPM.Repo.DefinitionD) / 2 = 0 {
            if verbose {
                write !,"No IPM repos found; nothing to migrate."
            }
            quit
        }
        set sub = ""
        set oldValue = "~%IPM.Repo.Remote.Definition~"
        set newValue = "~%IPM.Repo.Http.Definition~%IPM.Repo.Remote.Definition~"
        for {
            set sub = $order(^IPM.Repo.DefinitionD(sub))
            if sub = "" {
                quit
            }
            if ($data(^IPM.Repo.DefinitionD(sub,"RepoDefinition"), list) # 2) && ($listget(list, 1) = oldValue){
                set $list(^IPM.Repo.DefinitionD(sub, "RepoDefinition"), 1) = newValue
            }
        }
        if verbose {
            write !,"Repos migrated from IPM 0.9."
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
