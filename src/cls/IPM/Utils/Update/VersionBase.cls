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
	toVersion As %String,
	verbose As %Boolean = 0,
	logFile As %Library.File) As %Status
{
    ///////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////// Hard-Coding Values During Development //////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////
    set moduleName = "update-test"
    set toVersion = "1"
    set tModule = ##class(%IPM.Storage.Module).NameOpen(moduleName,,.tSC)
    ///////////////////////////////////////////////////////////////////////////////////////////
    
    if verbose { w !, "Attempting to acquire lock on ^IPM("_moduleName_", "_toVersion_")" }
    lock +^IPM(moduleName, toVersion):3
    if ('$test) {
        // TODO: Should this actually return $$$OK?
        if verbose { w !, "This is locked, skipping" }
        return $$$OK
    }
    if verbose { w !, "SUCCESS"}

    set className = tModule.UpdatePackage_".V"_toVersion
    set isPrimary = $System.Mirror.IsPrimary()
    set mirroredHostName = ""
    set mirroredInstanceName = ##class(%SYS.System).GetUniqueInstanceName()

    set mirroredMethodNames = ..GetOrderedMirroredMethodNames()
    do ..ExecuteMethodList(.mirroredMethodNames, className, mirroredHostName, mirroredInstanceName)

    set nonMirroredMethodNames = ..GetOrderedNonMirroredMethodNames()
    do ..ExecuteMethodList(.nonMirroredMethodNames, className, mirroredHostName, mirroredInstanceName)

    if verbose { w !, "Releasing lock on ^IPM("_moduleName_", "_toVersion_")" }
    lock -^IPM(moduleName, toVersion)
    return $$$OK
}

ClassMethod ExecuteMethodList(
	verbose As %Boolean = 0,
	ByRef methodList As %Library.DynamicArray,
	className As %String,
	mirroredHostName As %String,
	mirroredInstanceName As %String) [ Private ]
{
    set runRest = "0"
    set iter = methodList.%GetIterator()
    while iter.%GetNext(, .methodName) {
        set stepObj = ..GetUpdateStepObject(className, methodName, mirroredHostName, mirroredInstanceName)
        if 'runRest {
            // TODO: Check if method has been run on this mirror instance
            set runRest = ""
        }
        if runRest {
            set stepObj.TimeStampStart = $zdt($h,3)
            do stepObj.%Save()
            // TODO: Logging method invocation
            if verbose { w !, "Running "_className_"::"_methodName_"()" }
            $$$ThrowOnError($ClassMethod(className, methodName))
            if verbose { w !, className_"::"_methodName_"() Finished" }
            // TODO: Logging method done
            set stepObj.TimeStampEnd = $zdt($h,3)
            do stepObj.%Save()
        }
    }
}

ClassMethod GetUpdateStepObject(
	className As %String,
	methodName As %String,
	mirroredHostName As %String,
	mirroredInstanceName As %String) As %IPM.Storage.UpdateStep
{
    set tRes = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID "_
        "FROM %IPM_Storage.UpdateStep "_
        "WHERE ClassName = '"_className_
        "' AND MethodName = '"_methodName_
        "' AND MirroredHostName = '"_mirroredHostName_
        "' AND MirroredInstanceName = '"_mirroredInstanceName_"'")
    if (tRes.%SQLCODE < 0) {
        Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
    }
    do tRes.%Next()
    set stepObj = ##class(%IPM.Storage.UpdateStep).%OpenId(tRes.%Get("Id"))
    if '$IsObject(stepObj) {
        set stepObj = ##class(%IPM.Storage.UpdateStep).%New()
    }
    return stepObj
}

}
