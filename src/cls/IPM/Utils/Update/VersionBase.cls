/// Class %IPM.Utils.Update.VersionBase [ Abstract ]
Class %IPM.Utils.Update.VersionBase
{

/// Returns dynamic array of update method names to apply in order and whether or not they contain data changes. No base implementation.
/// Example output list: [["methodA", 1], ["methodB", 0], ["methodC", 0]]
ClassMethod GetMethodNameList() As %Library.DynamicArray [ Abstract ]
{
}

/// Returns dynamic array of update method names to apply in order that can be run on both primary and backup
/// Example output list: ["methodA", "methodB", "methodC"]
ClassMethod GetOrderedMirroredMethodNames() As %Library.DynamicArray [ Abstract ]
{
}

/// Returns dynamic array of update method names to apply in order that must be run on the primary
/// Example output list: ["methodA", "methodB", "methodC"]
ClassMethod GetOrderedNonMirroredMethodNames() As %Library.DynamicArray [ Abstract ]
{
}

ClassMethod ApplyStepsInOrder(
	module As %IPM.Storage.Module,
	version As %String,
	logFile As %Library.File,
	verbose As %Boolean = 0) As %Status
{
    // Attempt to acquire lock, quit if we cannot
    if verbose { w !, "Acquiring lock on ^IPM("_module.Name_", "_version_")" }
    lock +^IPM(module.Name, version):3
    if ('$test) {
        // TODO: Should this actually return $$$OK?
        if verbose { w !, "This is locked, skipping" }
        return $$$OK
    }

    set className = module.UpdatePackage_".V"_version
    set uniqueInstanceName = ##class(%SYS.System).GetUniqueInstanceName()
    set mirroredHostName = $piece(uniqueInstanceName, ":", 1)
    set mirroredInstanceName = $piece(uniqueInstanceName, ":", 2)

    // Regardless of mirror status, run these methods first
    set mirroredMethodNames = $ClassMethod(className, "GetOrderedMirrorMethodNames")
    do ..ExecuteMethodList(module, mirroredMethodNames, className, 1, mirroredHostName, mirroredInstanceName, logFile, verbose, .newStepAdded)

    // Don't run these steps on mirror members that are not primary
    if '($System.Mirror.IsMember() && '$System.Mirror.IsPrimary()) {
        set nonMirroredMethodNames = $ClassMethod(className, "GetOrderedNonMirroredMethodNames")
        do ..ExecuteMethodList(module, nonMirroredMethodNames, className, 0, mirroredHostName, mirroredInstanceName, logFile, verbose, .newStepAdded)
    }

    if verbose { w !, "Releasing lock on ^IPM("_module.Name_", "_version_")" }
    lock -^IPM(module.Name, version)
    return $$$OK
}

ClassMethod ExecuteMethodList(
	module As %IPM.Storage.Module,
	methodList As %Library.DynamicArray,
	className As %String,
	mirrored As %Boolean,
	mirroredHostName As %String,
	mirroredInstanceName As %String,
	logfile As %Library.File,
	verbose As %Boolean = 0,
	ByRef newStepAdded As %Boolean = 0) [ Private ]
{
    set iter = methodList.%GetIterator()
    while iter.%GetNext(, .methodName) {
        set stepObj = ##class(%IPM.Storage.UpdateStep).GetUpdateStepObject(className, methodName, mirrored, mirroredHostName, mirroredInstanceName)
        if '$IsObject(stepObj) {
            set stepObj = module.AddUpdateStep(className, methodName)
        }
        if 'newStepAdded && 'stepObj.TimeStampEnd {
            set newStepAdded = 1
        }
        if newStepAdded {
            set stepObj.TimeStampStart = $zdt($h,3)
            do stepObj.%Save()
            if verbose { w !, "Running "_className_"::"_methodName_"()" }
            set stepObj.Status = $ClassMethod(className, methodName)
            if verbose { w !, className_"::"_methodName_"() Finished" }
            // TODO: Logging method status
            set stepObj.TimeStampEnd = $zdt($h,3)
            $$$ThrowOnError(stepObj.%Save())
        }
    }
}

ClassMethod LogToFile(
	logFile As %Library.File,
	verbose As %Boolean = 0)
{
    // TODO: Implement logging function
    // non-verbose: only the status of UpdateStep.Status
}

}
