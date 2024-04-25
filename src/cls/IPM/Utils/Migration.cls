Class %IPM.Utils.Migration
{

ClassMethod RunAll(verbose As %Boolean = 1) As %Status
{
    Set sc = $$$OK
    Try {
        Do ..MigrateZPMToIPM(verbose)
    } Catch e {
        Set sc = e.AsStatus()
    }
    Quit sc
}

ClassMethod MigrateZPMToIPM(verbose As %Boolean = 1)
{
    If '$$$comClassDefined("%ZPM.PackageManager.Developer.Module") {
        Write:verbose !,"Older IPM version not found; nothing to migrate.",!
        Quit
    }

    Set sc = $$$OK
    Set initTLevel = $TLevel
    // Intentionally runs for current namespace only
    Try {
        TSTART

        // ^ZPM.Dev.ModuleD -> ^IPM.Storage.ModuleD
        Set oldId = ""
        For {
            Set oldId = $order(^ZPM.Dev.ModuleD(oldId),1,moduleData)
            Quit:oldId=""

            Set name = $ListGet(moduleData,2)
            If ##class(%IPM.Storage.Module).NameExists(name) {
                Write:verbose !,"Package already found in new storage: ",name
                Continue
            }

            Write:verbose !,"Migrating storage for ",name," ... "

            // Bring everything over - storage definitions are fortunately compatible.
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
        }

        $$$ThrowOnError(##class(%IPM.Storage.Module).%BuildIndices(,1,1))

        // Migrate %ZPM.PackageManager.Developer.Document.ModuleStream to %IPM.StudioDocument.ModuleStream
        // ^ZPM.Dev.ModuleDocD -> ^IPM.StudioDoc.ModuleStreamD
        // Uses objects for the actual data migration to more cleanly handle the stream.
        Set oldId = ""
        For {
            Set oldId = $order(^ZPM.Dev.ModuleDocD(oldId),1,moduleDocData)
            Quit:oldId=""

            Set name = $ListGet(moduleDocData,2)
            If ##class(%IPM.StudioDocument.ModuleStream).NameExists(name) {
                Write:verbose !,"Document already found in new storage: ",name
                Continue
            }
            Set oldObj = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).%OpenId(oldId,,.sc)
            $$$ThrowOnError(sc)
            Set newObj = ##class(%IPM.StudioDocument.ModuleStream).%New()
            Set newObj.Name = oldObj.Name
            Set newObj.Hash = oldObj.Hash
            Set newObj.LastModifiedTimestamp = oldObj.LastModifiedTimestamp
            $$$ThrowOnError(newObj.Contents.CopyFrom(oldObj.Contents))
            $$$ThrowOnError(newObj.%Save())

            Write:verbose !,"Migrated document stream data for "_newObj.Name
        }

        TCOMMIT        
    } Catch e {
        Set sc = e.AsStatus()
        Write:verbose !,"IPM data migration unsuccessful."
        Write:verbose !,$System.Status.GetErrorText(sc)
    }
    Write:verbose !
    While $TLevel > initTLevel {
        TROLLBACK 1
    }
    $$$ThrowOnError(sc)
}

}
