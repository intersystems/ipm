Class %IPM.Utils.Upgrade.Controller
{

ClassMethod ApplyUpgradesInOrder(verbose As %Boolean = 0)
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
    if ('$TEST) {
        // TODO: Should this actually return $$$OK?
        if verbose { w !, "This is locked, skipping" }
        return $$$OK
    }
    if verbose { w !, "SUCCESS"}

    Set tSC = $$$OK
    Set tInitTLevel = $TLevel
    Try {
        TSTART
        // For each base module dependency
        Set tModule = ##class(%IPM.Storage.Module).NameOpen(moduleName,,.tSC)
        Set dependencyList = tModule.Dependencies
        Set index = 1
        For {
            Set dependency = dependencyList.GetAt(index)
            Quit:dependency=""
            Set depModule = ##class(%IPM.Storage.Module).NameOpen(dependency.Name,, .tSC)
            If depModule.UpgradePackage '= "" {
                // Loop through each of the versions (<Upgrade Package>.V#) between current version and desired module version
                // Call their ApplySteps() methods
                // Skips methods that have already been run
                // Jimmy note: Probably an edge case where it's not upgrading dependency but installing a new one
                Set depVersion = depModule.VersionString
            }
            Set index = index + 1
        }
        // Followed by the base module itself
        TCOMMIT
    } Catch (ex) {
        Set sc = ex.AsStatus()
    }
    While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}

    if verbose { w !, "Releasing lock on ^IPM("_moduleName_")" }
    lock -^IPM(moduleName)
    Quit tSC
}

}
