Class %IPM.Utils.Update.Controller
{

/// TODO: Remove toVersion. I put that in for some manual testing cases (V1,V2 classes but only V1 module). Will use current module version for toVersion
ClassMethod ApplyUpdatesInOrder(
	moduleName As %String,
	fromVersion As %String,
	toVersion As %String,
	logFile As %Library.File,
	verbose As %Boolean = 0)
{
    if verbose { w !, "Acquiring lock on ^IPM("_moduleName_")" }
    lock +^IPM(moduleName):3
    if ('$test) {
        // TODO: Should this actually return $$$OK?
        if verbose { w !, "This is locked, skipping" }
        return $$$OK
    }

    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        tstart
        // For each base module dependency
        set tModule = ##class(%IPM.Storage.Module).NameOpen(moduleName,,.tSC)
        set processList = ..GetProcessModuleList(moduleName)

        set ptr = 0
        while $listnext(processList, ptr, moduleName) {
            set tModule = ##class(%IPM.Storage.Module).NameOpen(moduleName)
            // TODO: Uncomment this line and use it as toVersion instead of parameter sent in
            //set toVersion = tModule.Version.Major
            for version=fromVersion:1:toVersion {
                if verbose { w !, "Calling ApplyStepsInOrder() for module="_moduleName_" version="_version }
                do ##class(%IPM.Utils.Update.VersionBase).ApplyStepsInOrder(moduleName, version, logFile, verbose)
            }
        }

        tcommit
    } catch (ex) {
        set tSC = ex.AsStatus()
    }
    while ($TLevel > tInitTLevel) {
        trollback 1
    }

    if verbose { w !, "Releasing lock on ^IPM("_moduleName_")" }
    lock -^IPM(moduleName)
    quit tSC
}

ClassMethod ApplySingleModuleUpdatesInOrder(moduleName As %String) As %Status [ Private ]
{
}

/// Get list of dependency modules in order of how we want to update them.
/// We want to perform updates in reverse order of dependencies depth.
/// i.e. Call update steps for highest depth dependent module all the way up back the base module being updated
ClassMethod GetProcessModuleList(moduleName As %String) As %List [ Private ]
{
    set tModule = ##class(%IPM.Storage.Module).NameOpen(moduleName,,.tSC)
    do tModule.BuildDependencyGraph(.pDependencyGraph)
    set key = ""
    for {
        set key = $order(pDependencyGraph(key))
        quit:key=""
        // Order elements based on dependency depth
        set depth = $list(pDependencyGraph(key), 1)
        set depths(depth, key) = ""
    }

    // Reverse the order so we process most dependent modules first
    set processList = $listbuild(tModule.Name)
    set depthKey = ""
    for {
        set depthKey = $order(depths(depthKey))
        quit:depthKey=""
        set modKey = ""
        for {
            set modKey = $order(depths(depthKey, modKey))
            quit:modKey=""
            set processList = $listbuild(modKey) _ processList
        }
    }
    return processList
}

}
