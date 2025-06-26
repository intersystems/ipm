/// Class %IPM.Utils.Upgrade.VersionBase [ Abstract ]
Class %IPM.Utils.Upgrade.VersionBase
{

/// Returns dynamic array of upgrade method names to apply in order and whether or not they contain data changes. No base implementation.
/// Example output list: [["methodA", 1], ["methodB", 0], ["methodC", 0]]
ClassMethod GetMethodNameList() As %Library.DynamicArray [ Abstract ]
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
    set moduleName = "upgrade-test"
    set toVersion = "1"
    set tModule = ##class(%IPM.Storage.Module).NameOpen(moduleName,,.tSC)
    ///////////////////////////////////////////////////////////////////////////////////////////
    
    if verbose { w !, "Attempting to acquire lock on ^IPM("_moduleName_", "_toVersion_")" }
    lock +^IPM(moduleName, toVersion):3
    if ('$TEST) {
        // TODO: Should this actually return $$$OK?
        if verbose { w !, "This is locked, skipping" }
        return $$$OK
    }
    if verbose { w !, "SUCCESS"}

    
    set className = tModule.UpgradePackage_".V"_toVersion
    set methodList = $ClassMethod(className, "GetMethodNameList")

    set isMirrorNotPrimary = $SYSTEM.Mirror.IsMember() && '$System.Mirror.IsPrimary()
    set iter = methodList.%GetIterator()
    while iter.%GetNext(, .value) {
        set runOnPrimary = value.%Pop()
        set methodName = value.%Pop()
        if verbose { w !, "Running method "_methodName }
        // TODO: Double check why we need runOnPrimary = 1 instead of just runOnPrimary
        if (runOnPrimary = 1 && isMirrorNotPrimary) {
            if verbose { w !, "This is not primary, skipping" }
            continue
        }
        // TODO: Check if step has already been run

        $$$ThrowOnError($ClassMethod(className, methodName))

        // Update timestamp
        set tRes = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID "_
            "FROM %IPM.Storage.UpgradeStep "_
            "WHERE ClassName = '"_className_"' AND MethodName = '"_methodName_"'")
        If (tRes.%SQLCODE < 0) {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
        }
        Set stepObj = ##class(%IPM.Storage.UpgradeStep).%OpenId(tRes.%Next().%Get("ID"))
        Set stepObj.TimeStamp = $zdt($h,3)
        Set tSC = stepObj.%Save()
        // TODO: Add logging, here?
        $$$ThrowOnError(tSC)
    }

    if verbose { w !, "Releasing lock on ^IPM("_moduleName_", "_toVersion_")" }
    lock -^IPM(moduleName, toVersion)
    return $$$OK
}

}
