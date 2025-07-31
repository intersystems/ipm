Include %IPM.Common

/// Class %IPM.Utils.Update.VersionBase [ Abstract ]
Class %IPM.Utils.Update.VersionBase
{

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
    if verbose {
        write !, "Acquiring lock on ^%IPM.Update("_module.Name_", "_version_")"
    }
    $$$LockUpdateModuleVersion(module.Name, version)
    if ('$test) {
        quit
    }

    set sc = $$$OK
    try {
        set className = module.UpdatePackage_".V"_version
        if '##class(%Dictionary.ClassDefinition).%ExistsId(className) {
            if verbose {
                write !, "Class """_className_""" does not exist. Skipping running its update steps"
            }
            quit
        }
        set hostName = ##class(%SYS.System).GetNodeName()
        set instanceName = ##class(%SYS.System).GetInstanceName()

        // Regardless of mirror status, run these methods first
        set mirroredMethodNames = $classmethod(className, "GetOrderedMirroredMethodNames")
        set sc = ..ExecuteMethodList(module, mirroredMethodNames, className, hostName, instanceName, 1, logFile, verbose, .newStepToApply)

        // Don't run these steps on mirror members that are not primary (changes to DBs that are RO on non-primary members)
        if '($system.Mirror.IsMember() && '$system.Mirror.IsPrimary()) {
            set nonMirroredMethodNames = $classmethod(className, "GetOrderedNonMirroredMethodNames")
            set sc = ..ExecuteMethodList(module, nonMirroredMethodNames, className, hostName, instanceName, 0, logFile, verbose, .newStepToApply)
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }

    if verbose {
        write !, "Releasing lock on ^%IPM.Update("_module.Name_", "_version_")"
    }
    $$$UnlockUpdateModuleVersion(module.Name, version)

    quit sc
}

/// Helper method for ApplyStepsInOrder()
/// Iterates over a method name list and calls their update steps.
/// If an update step does not already exist, a new one gets created.
/// Once reaching the first method that hasn't been run on the instance (no TimeStampEnd value),
/// newStepToApply gets marked as true to tell us to run all remaining steps in the list
/// Can carry this over to subsequent calls by passing the newStepToApply variable to those ExecuteMethodList() calls
/// i.e. We find a new step to apply in the mirroredMethodNames list so we know to execute all steps in the nonMirroredMethodNames list
ClassMethod ExecuteMethodList(
	module As %IPM.Storage.Module,
	methodList As %Library.DynamicArray,
	className As %String,
	hostName As %String,
	instanceName As %String,
	mirrored As %Boolean,
	logfile As %Library.File,
	verbose As %Boolean = 0,
	ByRef newStepToApply As %Boolean = 0) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        set iter = methodList.%GetIterator()
        while iter.%GetNext(, .methodName) {
            set stepObj = ##class(%IPM.Storage.UpdateStep).GetUpdateStep(className, methodName, hostName, instanceName)
            if '$isobject(stepObj) {
                set stepObj = module.AddUpdateStep(className, methodName, mirrored)
            }
            if 'newStepToApply && 'stepObj.TimeStampEnd {
                set newStepToApply = 1
            }
            if newStepToApply {
                set stepObj.TimeStampStart = $zdatetime($horolog,3)
                if verbose {
                    write !, "Running "_className_"::"_methodName_"()"
                }
                set stepObj.Status = $$$OK
                try {
                    do $classmethod(className, methodName)
                    set stepObj.TimeStampEnd = $zdatetime($horolog,3)
                } catch (ex) {
                    set stepObj.Status = ex.AsStatus()
                }
                // TODO: Logging method status
                if verbose {
                    write !, className_"::"_methodName_"() Finished"
                }
                $$$ThrowOnError(stepObj.%Save())
            }
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    quit sc
}

ClassMethod LogToFile(
	logFile As %Library.File,
	verbose As %Boolean = 0)
{
    // TODO: Implement logging function
    // non-verbose: only the status of UpdateStep.Status
}

}
