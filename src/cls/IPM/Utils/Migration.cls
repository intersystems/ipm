Include %occInclude

Class %IPM.Utils.Migration
{

ClassMethod RunAll(verbose As %Boolean = 1) As %Status
{
    Set tOriginalNS = $Namespace
    Do ##class(%IPM.Main).GetListNamespace(.list)
    New $Namespace
    Set $Namespace = "%SYS"
    Set sourceDB = ##class(%SYS.Namespace).GetPackageDest(tOriginalNS, "%IPM")

    Set ns = ""
    Set sc = $$$OK
    For {
        Set ns = $Order(list(ns))
        // Perform migration for namespaces to which %IPM is mapped from the current namespace's default routine database
        If ##class(%SYS.Namespace).GetPackageDest(ns, "%IPM") '= sourceDB {
            Continue
        }
        If ns = "" {
            Quit
        }
        Try {
            Set $Namespace = $Zstrip(ns,"<>WC")
            Do ..MigrateZPMToIPM(verbose)
        } Catch e {
            Set sc = $$$ADDSC(sc, e.AsStatus())
        }
    }
    Quit sc
}

ClassMethod HasLegacyZPMPackage()
{
    Set oldTopPackage = "%ZPM.PackageManager."
    Quit $Order(^oddCOM(oldTopPackage)) [ oldTopPackage
}

ClassMethod MigrateZPMToIPM(verbose As %Boolean = 1)
{
    If verbose {
        Write !, "Migrating ZPM data to IPM... in namespace ", $Namespace
    }
    If '..HasLegacyZPMPackage() {
        Write:verbose !,"Older IPM version not found; nothing to migrate.",!
        Quit
    }

    Set sc = $$$OK
    Set successPackageList = ""
    Set failedPackageList = ""

    // Intentionally runs for current namespace only
    Try {
        // ^ZPM.Dev.ModuleD -> ^IPM.Storage.ModuleD
        For lockName = $Name(^ZPM.Dev.ModuleD),$Name(^IPM.Storage.ModuleD) {
            Set locks(lockName) = $System.AutoLock.Lock(lockName,,2)
            If locks(lockName) = $$$NULLOREF {
                $$$ThrowStatus($$$ERROR($$$LockFailedExtent,lockName))
            }
        }
        Set oldId = ""
        For {
            Set oldId = $order(^ZPM.Dev.ModuleD(oldId),1,moduleData)
            Quit:oldId=""
            Set moduleName = $ListGet(moduleData,2)
            Set oneSC = ..MigrateOnePackageToIPM(oldId, moduleName, verbose)
            If $$$ISOK(oneSC) {
                Set successPackageList = successPackageList _ $ListBuild(moduleName)
            } Else {
                Set failedPackageList = failedPackageList _ $ListBuild(moduleName)
            }
            Set sc = $$$ADDSC(sc,oneSC)
        }

        Set sc = $$$ADDSC(sc,##class(%IPM.Storage.Module).%BuildIndices(,1,1))
        Set sc = $$$ADDSC(sc,..MigrateRepoDefinitions())
        $$$ThrowOnError(sc)

        If verbose && (successPackageList '= "") {
            Write !,"Migrated successfully: ",!,$ListToString(successPackageList,$c(13,10))
        }
    } Catch e {
        Set sc = e.AsStatus()
        // Show these messages even in verbose mode.
        Write !,"IPM data migration was not fully successful. You may be able to reinstall the impacted packages to correct the issues."
        If (successPackageList '= "") {
            Write !,"Migrated successfully: ",!,$ListToString(successPackageList,$c(13,10))
        }
        If (failedPackageList '= "") {
            Write !,"Failed to migrate: ",!,$ListToString(failedPackageList,$c(13,10))
        }
        Write !,$System.Status.GetErrorText(sc)
    }
    Write:verbose !
    $$$ThrowOnError(sc)
}

ClassMethod MigrateOnePackageToIPM(oldId As %Integer, name As %String, verbose As %Boolean = 1)
{
    Set sc = $$$OK
    Set initTLevel = $TLevel
    Try {
        If ##class(%IPM.Storage.Module).NameExists(name) {
            Write:verbose !,"Package already found in new storage: ",name
            Quit
        }

        Write:verbose !,"Migrating storage for ",name," ... "

        // Bring everything over - storage definitions are fortunately compatible.
        TSTART
        Kill moduleData
        Merge moduleData = ^ZPM.Dev.ModuleD(oldId)

        // In ^IPM.Storage.ModuleD(<ID>,"Defaults",n) = $lb($lb(<data>),classname), map classname
        // to equivalent - %ZPM.PackageManager.Developer.ModuleSetting -> %IPM.Storage.ModuleSetting
        Set defaultKey = ""
        For {
            Set defaultKey = $Order(moduleData("Defaults",defaultKey),1,defaultData)
            Quit:defaultKey=""
            Set moduleData("Defaults",defaultKey) = $ListBuild($ListGet(defaultData,1),$Replace($ListGet(defaultData,2),"%ZPM.PackageManager.Developer.ModuleSetting","%IPM.Storage.ModuleSetting"))
        }

        Set newId = $Increment(^IPM.Storage.ModuleD)
        Merge ^IPM.Storage.ModuleD(newId) = moduleData

        // Make sure loading the object works
        Set newObj = ##class(%IPM.Storage.Module).%OpenId(newId,,.sc)
        $$$ThrowOnError(sc)

        // Save object to validate
        $$$ThrowOnError(newObj.%Save())

        Write:verbose "done."

        // Migrate %ZPM.PackageManager.Developer.Document.ModuleStream to %IPM.StudioDocument.ModuleStream
        // ^ZPM.Dev.ModuleDocD -> ^IPM.StudioDoc.ModuleStreamD
        // Uses objects for the actual data migration to more cleanly handle the stream.
        If ##class(%IPM.StudioDocument.ModuleStream).NameExists(name) {
            Write:verbose !,"Document already found in new storage: ",name
        } Else {
            Set oldObj = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameOpen(name,,.sc)
            $$$ThrowOnError(sc)
            Set newObj = ##class(%IPM.StudioDocument.ModuleStream).%New()
            Set newObj.Name = oldObj.Name
            Set newObj.Hash = oldObj.Hash
            Set newObj.LastModifiedTimestamp = oldObj.LastModifiedTimestamp
            $$$ThrowOnError(newObj.Contents.CopyFrom(oldObj.Contents))
            $$$ThrowOnError(newObj.%Save())

            Write:verbose !,"Migrated document stream - "_newObj.Name_".ZPM"
        }

        TCOMMIT
    } Catch e {
        Set sc = e.AsStatus()
    }
    While $TLevel > initTLevel {
        TROLLBACK 1
    }
    Quit sc
}

ClassMethod MigrateRepoDefinitions(verbose As %Boolean = 1) As %Status
{
    Set initTLevel = $TLevel
    Try {
        For lockName = $Name(^%ZPM.Client.ServerDefD),$Name(^IPM.Repo.DefinitionD) {
            Set locks(lockName) = $System.AutoLock.Lock(lockName,,2)
            If locks(lockName) = $$$NULLOREF {
                $$$ThrowStatus($$$ERROR($$$LockFailedExtent,lockName))
            }
        }

        TSTART
        Set key = ""
        For {
            Set key = $Order(^%ZPM.Client.ServerDefD(key),1,repoData)
            Quit:key=""

            Set repoName = $ListGet(repoData,2)
            Do ..MigrateOneRepo(key, repoName, verbose)
        }

        $$$ThrowOnError(##class(%IPM.Repo.Definition).%BuildIndices(,1,1))
        $$$ThrowOnError(##class(%IPM.Repo.Remote.Definition).%BuildIndices(,1,1))
        TCOMMIT
    } Catch e {
        Set sc = e.AsStatus()
    }
    While $TLevel > initTLevel {
        TROLLBACK 1
    }
    Quit sc
}

ClassMethod MigrateOneRepo(oldId As %String, name As %String, verbose As %Boolean)
{
    If ##class(%IPM.Repo.Remote.Definition).ServerDefinitionKeyExists(name) {
        Write:verbose !,"Skipping migrating repo "_name_" - already exists."
        Quit
    }
    Merge data = ^%ZPM.Client.ServerDefD(oldId)

    Set class = $ListGet(data)
    If (class '= "~%ZPM.PackageManager.Client.RemoteServerDefinition~") {
        Write:verbose !,"Skipping migrating repo "_name_" - unsupported repo type."
        Quit
    }

    Write:verbose !,"Migrating repo "_name_"... "

    Set $List(data,1) = "~%IPM.Repo.Remote.Definition~"
    Set data("RepoDefinition") = data
    Merge data("RemoteRepoDefinition") = data("RemoteServerDefinition")
    ZKill data
    ZKill data("RemoteServerDefinition")

    Set newId = $Increment(^IPM.Repo.DefinitionD)
    Merge ^IPM.Repo.DefinitionD(newId) = data

    // Make sure loading/saving the object works
    Set newObj = ##class(%IPM.Repo.Definition).%OpenId(newId,,.sc)
    $$$ThrowOnError(sc)

    // Save object to validate
    $$$ThrowOnError(newObj.%Save())

    Write:verbose !,"done."
}

}
