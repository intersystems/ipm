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
Method %OnAddToSaveSet(depth As %Integer = 3, insert As %Integer = 0, callcount As %Integer = 0) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	Try {
		// See if the module definition has actually changed
		Set tHash = $System.Encryption.SHA1HashStream(..Contents,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		If (..Hash '= tHash) {
			Set ..Hash = tHash
			Set ..LastModifiedTimestamp = $zdt($h,3)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Ensures that <var>pName</var> is a valid Studio document name (including / based on extension) for this stream class.
ClassMethod %ValidateName(pName As %String, Output pLogicalName As %String) As %Status
{
	Set tSC = $$$OK
	Set pLogicalName = ""
	Try {
		If '##class(%Library.RoutineMgr).UserType(pName,.tDocumentClass) || ($parameter(tDocumentClass,"STREAMCLASS") '= $classname()) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid document name for stream class %1: '%2'",$classname(),pName))
			Quit
		}
		Set pLogicalName = $Piece(pName,".",1,*-1)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Given a document name (including extension), lock it and report a descriptive error if the lock fails.
ClassMethod %LockName(pName As %String, pShared As %Boolean = 0, pTimeout As %Integer) As %Status
{
	Set tSC = ..%ValidateName(pName,.tLogicalName)
	If $$$ISERR(tSC) {
		Quit
	}
	
	If ..NameExists(tLogicalName,.tID) {
		Set tSC = ..%LockId(tID,pShared,.pTimeout)
	}
	If $$$ISOK(tSC) {
		Quit $$$OK
	}
	
	// Error handling: convert to descriptive error message
	// Taken from $$lockfail^%occLock, to provide equivalent behavior to classes.
	Set tGlobal = $Extract($$$EXTADDRglobal($$$pMAP,$classname(),"IDKEY"),2,*) //Remove leading "^" - $$FindLockOwner adds it back in.
	Set tEscalate = 0
	Set tLockType = $$FindLockOwner^%SYS.cspServer2($Namespace,tGlobal,tID,.tJob,.tUser,.tEscalate)
	If (tLockType = 2) {
		Quit $$$ERROR($$$ClassLockTableFull,pName)
	} Else {
		If tEscalate {
			Quit $$$ERROR($$$ClassLockEscalate,pName,tUser,tJob)
		} Else {
			Quit $$$ERROR($$$CanNotLockRoutineInfo,pName,tUser,tJob)
		}
	}
}

/// Given a document name (including extension), unlock it
ClassMethod %UnlockName(pName As %String, pShared As %Boolean = 0, pImmediate As %Boolean = 0) As %Status
{
	Set tSC = ..%ValidateName(pName,.tLogicalName)
	If $$$ISERR(tSC) {
		Quit
	}
	
	If ..NameExists(tLogicalName,.tID) {
		Set tSC = ..%UnlockId(tID,pShared,pImmediate)
	}
	Quit tSC
}

}
