Include %IPM.Common

Class %IPM.Utils.Update.Controller
{

/// Iterates through a module and its dependencies and applies their update steps that haven't been run up through the current version
/// Starts with the most dependent module and works its way backwards to the base module we are calling "update" on
ClassMethod ApplyUpdatesInOrder(
	module As %IPM.Storage.Module,
	logFile As %Library.File = "",
	verbose As %Boolean = 0)
{
    if verbose {
        write !, "Acquiring lock on ^%IPM.Update("_module.Name_")"
    }
    $$$LockUpdateModule(module.Name)
    if ('$test) {
        quit
    }

    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        tstart
        // For each base module dependency
        set processList = ..GetModulesToUpdateOrderedList(module)

        set ptr = 0
        while $listnext(processList, ptr, moduleName) {
            set nextModule = ##class(%IPM.Storage.Module).NameOpen(moduleName)
            set toVersion = nextModule.Version.Major
            for version=1:1:toVersion {
                if verbose {
                    write !, "Starting to run update steps for module="_nextModule.Name_" version="_version
                }
                set tSC = ##class(%IPM.Utils.Update.VersionBase).ApplyStepsInOrder(nextModule, version, logFile, verbose)
            }
        }
        tcommit
    } catch (ex) {
        set tSC = ex.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }

    if verbose {
        write !, "Releasing lock on ^IPM.Update("_module.Name_")"
    }
    $$$UnlockUpdateModule(module.Name)
    quit tSC
}

/// Get list of dependency modules in order of how we want to update them.
/// We want to perform updates in reverse order of dependencies depth.
/// i.e. Call update steps for highest depth dependent module all the way up back the base module being updated
ClassMethod GetModulesToUpdateOrderedList(module As %IPM.Storage.Module) As %List [ Private ]
{
    $$$ThrowOnError(module.BuildDependencyGraph(.pDependencyGraph))
    set key = ""
    for {
        set key = $order(pDependencyGraph(key))
        quit:key=""
        // Order elements based on dependency depth
        set depth = $list(pDependencyGraph(key), 1)
        set depths(depth, key) = ""
    }

    // Reverse the order so we process most dependent modules first
    set processList = $listbuild(module.Name)
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
