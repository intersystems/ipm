Class %IPM.StudioDocument.AbstractStream Extends %Persistent [ Abstract, NoExtent ]
{

Index Name On Name [ Unique ];

Property Name As %String(MAXLEN = 100);

Property Contents As %Stream.GlobalCharacter;

Property Hash As %Binary;

Property LastModifiedTimestamp As %TimeStamp;

/// This callback method is invoked when the current object is added to the SaveSet,
/// either because %Save() was invoked on this object or on an object that references this object.
/// %OnAddToSaveSet can modify the current object. It can also add other objects to the current
/// SaveSet by invoking %AddToSaveSet or remove objects by calling %RemoveFromSaveSet.
/// 
/// <P>If this method returns an error status then %Save() will fail and the transaction
/// will be rolled back.
Method %OnAddToSaveSet(
	depth As %Integer = 3,
	insert As %Integer = 0,
	callcount As %Integer = 0) As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = $$$OK
    try {
        // See if the module definition has actually changed
        set tHash = $system.Encryption.SHA1HashStream(..Contents,.tSC)
        if $$$ISERR(tSC) {
            quit
        }
        if (..Hash '= tHash) {
            set ..Hash = tHash
            set ..LastModifiedTimestamp = $zdatetime($horolog,3)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Ensures that <var>pName</var> is a valid Studio document name (including / based on extension) for this stream class.
ClassMethod %ValidateName(
	pName As %String,
	Output pLogicalName As %String) As %Status
{
    set tSC = $$$OK
    set pLogicalName = ""
    try {
        if '##class(%Library.RoutineMgr).UserType(pName,.tDocumentClass) || ($parameter(tDocumentClass,"STREAMCLASS") '= $classname()) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid document name for stream class %1: '%2'",$classname(),pName))
            quit
        }
        set pLogicalName = $piece(pName,".",1,*-1)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Given a document name (including extension), lock it and report a descriptive error if the lock fails.
ClassMethod %LockName(
	pName As %String,
	pShared As %Boolean = 0,
	pTimeout As %Integer) As %Status
{
    set tSC = ..%ValidateName(pName,.tLogicalName)
    if $$$ISERR(tSC) {
        quit
    }

    if ..NameExists(tLogicalName,.tID) {
        set tSC = ..%LockId(tID,pShared,.pTimeout)
    }
    if $$$ISOK(tSC) {
        quit $$$OK
    }

    // Error handling: convert to descriptive error message
    // Taken from $$lockfail^%occLock, to provide equivalent behavior to classes.
    set tGlobal = $extract($$$EXTADDRglobal($$$pMAP,$classname(),"IDKEY"),2,*) //Remove leading "^" - $$FindLockOwner adds it back in.
    set tEscalate = 0
    set tLockType = $$FindLockOwner^%SYS.cspServer2($namespace,tGlobal,tID,.tJob,.tUser,.tEscalate)
    if (tLockType = 2) {
        quit $$$ERROR($$$ClassLockTableFull,pName)
    } else {
        if tEscalate {
            quit $$$ERROR($$$ClassLockEscalate,pName,tUser,tJob)
        } else {
            quit $$$ERROR($$$CanNotLockRoutineInfo,pName,tUser,tJob)
        }
    }
}

/// Given a document name (including extension), unlock it
ClassMethod %UnlockName(
	pName As %String,
	pShared As %Boolean = 0,
	pImmediate As %Boolean = 0) As %Status
{
    set tSC = ..%ValidateName(pName,.tLogicalName)
    if $$$ISERR(tSC) {
        quit
    }

    if ..NameExists(tLogicalName,.tID) {
        set tSC = ..%UnlockId(tID,pShared,pImmediate)
    }
    quit tSC
}

}
