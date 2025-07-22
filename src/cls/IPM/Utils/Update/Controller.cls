Class %IPM.Utils.Update.Controller
{

ClassMethod ApplyUpdatesInOrder(
	moduleName As %String,
	toVersion As %String,
	verbose As %Boolean = 0)
{
    ///////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////// Hard-Coding Values During Development //////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////
    //set moduleName = "update-test"
    //set toVersion = "3"  // say current version is 1
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
            // Call phase "update" on dependent module

            set index = index + 1
        }

        // Followed by the base module itself
        set index = tModule.Version.Major
        while index <= toVersion {
            w !, index
            do ##class(%IPM.Utils.Update.VersionBase).ApplyStepsInOrder(moduleName, index, verbose, )  // TODO: Add log file
            set index = index + 1
        }
        tcommit
    } catch (ex) {
        set sc = ex.AsStatus()
        zw sc
    }
    while ($TLevel > tInitTLevel) {
        trollback 1
    }

    if verbose { w !, "Releasing lock on ^IPM("_moduleName_")" }
    lock -^IPM(moduleName)
    quit tSC
}

}
