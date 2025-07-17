Class %IPM.Utils.Update.Controller
{

ClassMethod ApplyUpdatesInOrder(verbose As %Boolean = 0)
{
    ///////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////// Hard-Coding Values During Development //////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////
    set moduleName = "fc-dep-same-resource"
    set toVersion = "1"
    set tModule = ##class(%IPM.Storage.Module).NameOpen(moduleName,,.tSC)
    ///////////////////////////////////////////////////////////////////////////////////////////

    if verbose { w !, "Attempting to acquire lock on ^IPM("_moduleName_")" }
    lock +^IPM(moduleName):3
    if ('$test) {
        // TODO: Should this actually return $$$OK?
        if verbose { w !, "This is locked, skipping" }
        return $$$OK
    }
    if verbose { w !, "SUCCESS"}

    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        tstart
        // For each base module dependency
        set tModule = ##class(%IPM.Storage.Module).NameOpen(moduleName,,.tSC)
        set dependencyList = tModule.Dependencies
        set index = 1
        for {
            set dependency = dependencyList.GetAt(index)
            quit:dependency=""
            set depModule = ##class(%IPM.Storage.Module).NameOpen(dependency.Name,, .tSC)
            If depModule.UpgradePackage '= "" {
                // Loop through each of the versions (<Upgrade Package>.V#) between current version and desired module version
                // Call their ApplySteps() methods
                // Skips methods that have already been run
                // Jimmy note: Probably an edge case where it's not upgrading dependency but installing a new one
                set depVersion = depModule.VersionString
            }
            set index = index + 1
        }
        // Followed by the base module itself
        do ##class(%IPM.Utils.Update.VersionBase).ApplyStepsInOrder()
        tcommit
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    while ($TLevel > tInitTLevel) {
        trollback 1
    }

    if verbose { w !, "Releasing lock on ^IPM("_moduleName_")" }
    lock -^IPM(moduleName)
    quit tSC
}

}
