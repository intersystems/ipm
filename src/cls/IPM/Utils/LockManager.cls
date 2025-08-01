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
    set ..ImmediateReleaseOnClose = pImmediateRelease
    quit $$$OK
}

Method Lock(
	pGlobalName As %String,
	pFlags As %String = "",
	pTimeout As %Integer = {$$$LockTimeout}) As %Status
{
    set tSC = $$$OK
    try {
        lock +@pGlobalName#pFlags:pTimeout
        if '$test {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Failed to lock %1",pGlobalName))
            quit
        }

        do $increment(i%Cache(pGlobalName,$case(pFlags,"":$char(0),:pFlags)))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method Unlock(
	pGlobalName As %String,
	pFlags As %String = "",
	pImmediate As %Boolean = 0,
	pUpdateCache As %Boolean = 1)
{
    if (pFlags = $char(0)) {
        set pFlags = ""
    }
    lock -@pGlobalName#pFlags_$select(pImmediate:"I",1:"")
    if pUpdateCache {
        set i%Cache(pGlobalName,$case(pFlags,"":$char(0),:pFlags)) = $get(i%Cache(pGlobalName,$case(pFlags,"":$char(0),:pFlags)),0) - 1
        if (i%Cache(pGlobalName,$case(pFlags,"":$char(0),:pFlags)) <= 0) {
            kill i%Cache(pGlobalName,$case(pFlags,"":$char(0),:pFlags))
        }
    }
}

Method LockClassId(
	pClassName As %Dictionary.Classname,
	pID As %String,
	pShared As %Boolean = 0,
	pTimeout As %Integer) As %Status
{
    set tSC = $classmethod(pClassName,"%LockId",pID,pShared,.pTimeout)
    if $$$ISOK(tSC) {
        set tOID = $$$oidCompose(pID,pClassName)
        set i%OIDCache(tOID,pShared) = $get(i%OIDCache(tOID,pShared)) + 1
    }
    quit tSC
}

Method UnlockClassId(
	pClassName As %Dictionary.Classname,
	pID As %String,
	pShared As %Boolean = 0,
	pImmediate As %Boolean = 0)
{
    set tOID = $$$oidCompose(pID,pClassName)
    if $data(i%OIDCache(tOID,pShared),tLockCount) {
        do $classmethod(pClassName,"%UnlockId",pID,pShared,pImmediate)
        set i%OIDCache(tOID,pShared) = tLockCount - 1
    }
}

Method UnlockAll(pImmediate As %Boolean = 1) As %Status
{
    set tSC = $$$OK
    try {
        set tGlobalName = ""
        for {
            set tGlobalName = $order(i%Cache(tGlobalName))
            if (tGlobalName = "") {
                quit
            }
            set tFlags = ""
            for {
                set tFlags = $order(i%Cache(tGlobalName,tFlags),1,tLockCount)
                if (tFlags = "") {
                    quit
                }
                for i=1:1:tLockCount {
                    do ..Unlock(tGlobalName,tFlags,pImmediate,0)
                }
            }
        }
        kill i%Cache

        set tOID = ""
        for {
            set tOID = $order(i%OIDCache(tOID))
            if (tOID = "") {
                quit
            }
            set tShared = ""
            for {
                set tShared = $order(i%OIDCache(tOID,tShared),1,tLockCount)
                if (tShared = "") {
                    quit
                }
                set tID = $$$oidPrimary(tOID)
                set tClassName = $$$oidClassName(tOID)
                for i=1:1:tLockCount {
                    do ..UnlockClassId(tClassName,tID,tShared,pImmediate)
                }
            }
        }
        kill i%OIDCache
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Performs an immediate unlock
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
    quit ..UnlockAll(..ImmediateReleaseOnClose)
}

ClassMethod LockClassesRecursive(
	ByRef pLockManager = {..%New()},
	ByRef pClasses,
	ByRef pSharedLockedClasses) As %Status
{
    // Based on LockClassesRecursive^%occLock.
    // This method (and the rest of the class to support it) is really just a workaround for PL 149632
    set tSC = $$$OK
    try {
        set tLockManager = ..%New()
        merge tVisited = pSharedLockedClasses
        set tClassKey = ""
        for {
            set tClassKey = $order(pClasses(tClassKey))
            if (tClassKey = "") {
                quit
            }

            set tClassName = tClassKey
            if ($zconvert($extract(tClassKey,*-3,*),"U") = ".CLS") {
                // This isn't actually a legal classname - must be class with extension included.
                set tClassName = $extract(tClassKey,1,*-4)
            }

            // Based on lockoneclassrecursive^%occLock, but locks each dependency in shared mode.
            // We always lock the top-level class, because it may need to be locked exclusively; pVisited is just for
            // classes locked in shared mode.
            $$$ThrowOnError(tLockManager.LockClassDefinition(tClassName))
            if $data(tVisited(tClassName)) {
                continue
            }

            // It would be nice if there was an API for this that accepted tVisited.
            kill tDependencies
            do getalldependencyclasses^%occDepend(tClassName,.tDependencies,.tVisited,,,,,1)

            set tDependencyKey = "A" //Start at 'A' to skip % classes.
            for {
                set tDependencyKey = $order(tDependencies(tDependencyKey))
                if (tDependencyKey = "") {
                    quit
                }

                $$$ThrowOnError(tLockManager.LockClassDefinition(tDependencyKey,1))
            }
        }

        // If all classes were locked successfully, record that they were,
        // and move ownership of the locks from tLockManager to pLockManager.
        // If an error occurred, any locks taken out will be released when tLockManager
        // goes out of scope.
        merge pSharedLockedClasses = tVisited
        do tLockManager.MergeTo(pLockManager)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method LockClassDefinition(
	pClass As %String,
	pShared As %Boolean = 0,
	pTimeout As %Integer = 0) As %Status
{
    // Based on ^%occLock (particularly, the error handling and $$Function^%SYS.* calls are taken from there).
    set tSourceNamespace = $$GetClassLockDatabase^%SYS.SECURITY(pClass,"")
    if tSourceNamespace = "" {
        quit $$$OK
    }
    set tLockGlobal = $name(^|tSourceNamespace|oddDEF(pClass))
    set tSC = ..Lock(tLockGlobal,$select(pShared:"SE",1:"E"),pTimeout)
    if $$$ISERR(tSC) {
        set tEscalate = 0
        set tType = $$FindLockOwner^%SYS.cspServer2(tSourceNamespace,"^oddDEF",pClass,.tJob,.tUser,.tEscalate)
        if (tType = 2) {
            quit $$$ERROR($$$ClassLockTableFull,pClass)
        } elseif (tType = 1) {
            if tEscalate {
                quit $$$ERROR($$$ClassLockEscalate,pClass,tUser,tJob)
            } else {
                quit $$$ERROR($$$CanNotLockRoutineInfo,pClass_".cls",tUser,tJob)
            }
        }
        if pShared {
            quit $$$ERROR($$$ClassSharedLockFailed,pClass)
        } else {
            quit $$$ERROR($$$ClassExclusiveLockFailed,pClass)
        }
    }
    quit tSC
}

Method MergeTo(pTargetLockManager As %IPM.Utils.LockManager)
{
    set tGlobalName = ""
    for {
        set tGlobalName = $order(i%Cache(tGlobalName))
        if (tGlobalName = "") {
            quit
        }

        set tFlags = ""
        for {
            set tFlags = $order(i%Cache(tGlobalName,tFlags),1,tLockCount)
            if (tFlags = "") {
                quit
            }
            if $increment(pTargetLockManager.Cache(tGlobalName,tFlags),tLockCount)
        }
    }

    kill i%Cache

    set tOID = ""
    for {
        set tOID = $order(i%OIDCache(tOID))
        if (tOID = "") {
            quit
        }
        set tShared = ""
        for {
            set tShared = $order(i%OIDCache(tOID,tShared),1,tLockCount)
            if (tShared = "") {
                quit
            }
            if $increment(pTargetLockManager.OIDCache(tOID,tShared),tLockCount)
        }
    }

    kill i%OIDCache
}

}
