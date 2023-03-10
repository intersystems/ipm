/// Utility to make managing locking/unlocking easier in more complex settings.
/// Usage pattern:
/// <ol>
/// <li>Create an instance of this class at the beginning of a method.</li>
/// <li>Call the Lock() and (optionally) Unlock() methods.</li>
/// <li>When the object goes out of scope, remaining locks are automatically released with the correct flags.</li>
/// </ol>
Class %IPM.Utils.LockManager Extends %RegisteredObject
{

/// Map of (<global>,<flags>) to lock count
Property Cache [ MultiDimensional, Private ];

/// Map of (<class>,<id>) to lock count
Property OIDCache [ MultiDimensional, Private ];

/// If true, locks are released immediately when the instance of this class goes out of scope.
/// (If not, standard handling for transactions will apply instead.)
Property ImmediateReleaseOnClose As %Boolean [ Private ];

/// Set <var>pImmediateRelease</var> to 0 to keep locks in an instance of this class
/// until the end of the current transaction even once the instance goes out of scope.
Method %OnNew(pImmediateRelease As %Boolean = 1) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..ImmediateReleaseOnClose = pImmediateRelease
	Quit $$$OK
}

Method Lock(pGlobalName As %String, pFlags As %String = "", pTimeout As %Integer = {$$$LockTimeout}) As %Status
{
	Set tSC = $$$OK
	Try {
		Lock +@pGlobalName#pFlags:pTimeout
		If '$Test {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Failed to lock %1",pGlobalName))
			Quit
		}
		
		If $Increment(i%Cache(pGlobalName,$Case(pFlags,"":$c(0),:pFlags)))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method Unlock(pGlobalName As %String, pFlags As %String = "", pImmediate As %Boolean = 0, pUpdateCache As %Boolean = 1)
{
	If (pFlags = $c(0)) {
		Set pFlags = ""
	}
	Lock -@pGlobalName#pFlags_$Select(pImmediate:"I",1:"")
	If pUpdateCache {
		Set i%Cache(pGlobalName,$Case(pFlags,"":$c(0),:pFlags)) = $Get(i%Cache(pGlobalName,$Case(pFlags,"":$c(0),:pFlags)),0) - 1
		If (i%Cache(pGlobalName,$Case(pFlags,"":$c(0),:pFlags)) <= 0) {
			Kill i%Cache(pGlobalName,$Case(pFlags,"":$c(0),:pFlags))
		}
	}
}

Method LockClassId(pClassName As %Dictionary.Classname, pID As %String, pShared As %Boolean = 0, pTimeout As %Integer) As %Status
{
	Set tSC = $classmethod(pClassName,"%LockId",pID,pShared,.pTimeout)
	If $$$ISOK(tSC) {
		Set tOID = $$$oidCompose(pID,pClassName)
		Set i%OIDCache(tOID,pShared) = $Get(i%OIDCache(tOID,pShared)) + 1
	}
	Quit tSC
}

Method UnlockClassId(pClassName As %Dictionary.Classname, pID As %String, pShared As %Boolean = 0, pImmediate As %Boolean = 0)
{
	Set tOID = $$$oidCompose(pID,pClassName)
	If $Data(i%OIDCache(tOID,pShared),tLockCount) {
		Do $classmethod(pClassName,"%UnlockId",pID,pShared,pImmediate)
		Set i%OIDCache(tOID,pShared) = tLockCount - 1
	}
}

Method UnlockAll(pImmediate As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tGlobalName = ""
		For {
			Set tGlobalName = $Order(i%Cache(tGlobalName))
			If (tGlobalName = "") {
				Quit
			}
			Set tFlags = ""
			For {
				Set tFlags = $Order(i%Cache(tGlobalName,tFlags),1,tLockCount)
				If (tFlags = "") {
					Quit
				}
				For i=1:1:tLockCount {
					Do ..Unlock(tGlobalName,tFlags,pImmediate,0)
				}
			}
		}
		Kill i%Cache
		
		Set tOID = ""
		For {
			Set tOID = $Order(i%OIDCache(tOID))
			If (tOID = "") {
				Quit
			}
			Set tShared = ""
			For {
				Set tShared = $Order(i%OIDCache(tOID,tShared),1,tLockCount)
				If (tShared = "") {
					Quit
				}
				Set tID = $$$oidPrimary(tOID)
				Set tClassName = $$$oidClassName(tOID)
				For i=1:1:tLockCount {
					Do ..UnlockClassId(tClassName,tID,tShared,pImmediate)
				}
			}
		}
		Kill i%OIDCache
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Performs an immediate unlock 
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	Quit ..UnlockAll(..ImmediateReleaseOnClose)
}

ClassMethod LockClassesRecursive(ByRef pLockManager = {..%New()}, ByRef pClasses, ByRef pSharedLockedClasses) As %Status
{
	// Based on LockClassesRecursive^%occLock.
	// This method (and the rest of the class to support it) is really just a workaround for PL 149632
	Set tSC = $$$OK
	Try {
		Set tLockManager = ..%New()
		Merge tVisited = pSharedLockedClasses
		Set tClassKey = ""
		For {
			Set tClassKey = $Order(pClasses(tClassKey))
			If (tClassKey = "") {
				Quit
			}
			
			Set tClassName = tClassKey
			If ($ZConvert($Extract(tClassKey,*-3,*),"U") = ".CLS") {
				// This isn't actually a legal classname - must be class with extension included.
				Set tClassName = $Extract(tClassKey,1,*-4)
			}
			
			// Based on lockoneclassrecursive^%occLock, but locks each dependency in shared mode.
			// We always lock the top-level class, because it may need to be locked exclusively; pVisited is just for
			// classes locked in shared mode.
			$$$ThrowOnError(tLockManager.LockClassDefinition(tClassName))
			If $Data(tVisited(tClassName)) {
				Continue
			}
			
			// It would be nice if there was an API for this that accepted tVisited.
			Kill tDependencies
			Do getalldependencyclasses^%occDepend(tClassName,.tDependencies,.tVisited,,,,,1)
			
			Set tDependencyKey = "A" //Start at 'A' to skip % classes.
			For {
				Set tDependencyKey = $Order(tDependencies(tDependencyKey))
				If (tDependencyKey = "") {
					Quit
				}
				
				$$$ThrowOnError(tLockManager.LockClassDefinition(tDependencyKey,1))
			}
		}
		
		// If all classes were locked successfully, record that they were,
		// and move ownership of the locks from tLockManager to pLockManager.
		// If an error occurred, any locks taken out will be released when tLockManager
		// goes out of scope.
		Merge pSharedLockedClasses = tVisited
		Do tLockManager.MergeTo(pLockManager)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method LockClassDefinition(pClass As %String, pShared As %Boolean = 0, pTimeout As %Integer = 0) As %Status
{
	// Based on ^%occLock (particularly, the error handling and $$Function^%SYS.* calls are taken from there).
	Set tSourceNamespace = $$GetClassLockDatabase^%SYS.SECURITY(pClass,"")
	If tSourceNamespace = "" {
		Quit $$$OK
	}
	Set tLockGlobal = $Name(^|tSourceNamespace|oddDEF(pClass))
	Set tSC = ..Lock(tLockGlobal,$Select(pShared:"SE",1:"E"),pTimeout)
	If $$$ISERR(tSC) {
		Set tEscalate = 0
		Set tType = $$FindLockOwner^%SYS.cspServer2(tSourceNamespace,"^oddDEF",pClass,.tJob,.tUser,.tEscalate)
		If (tType = 2) {
			Quit $$$ERROR($$$ClassLockTableFull,pClass)
		} ElseIf (tType = 1) {
			If tEscalate {
				Quit $$$ERROR($$$ClassLockEscalate,pClass,tUser,tJob)
			} Else {
				Quit $$$ERROR($$$CanNotLockRoutineInfo,pClass_".cls",tUser,tJob)
			}
		}
		If pShared {
			Quit $$$ERROR($$$ClassSharedLockFailed,pClass)
		} Else {
			Quit $$$ERROR($$$ClassExclusiveLockFailed,pClass)
		}
	}
	Quit tSC
}

Method MergeTo(pTargetLockManager As %IPM.Utils.LockManager)
{
	Set tGlobalName = ""
	For {
		Set tGlobalName = $Order(i%Cache(tGlobalName))
		If (tGlobalName = "") {
			Quit
		}
		
		Set tFlags = ""
		For {
			Set tFlags = $Order(i%Cache(tGlobalName,tFlags),1,tLockCount)
			If (tFlags = "") {
				Quit
			}
			If $Increment(pTargetLockManager.Cache(tGlobalName,tFlags),tLockCount)
		}
	}
		
	Kill i%Cache
		
	Set tOID = ""
	For {
		Set tOID = $Order(i%OIDCache(tOID))
		If (tOID = "") {
			Quit
		}
		Set tShared = ""
		For {
			Set tShared = $Order(i%OIDCache(tOID,tShared),1,tLockCount)
			If (tShared = "") {
				Quit
			}
			If $Increment(pTargetLockManager.OIDCache(tOID,tShared),tLockCount)
		}
	}
	
	Kill i%OIDCache
}

}
