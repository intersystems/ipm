Include %sySecurity

Class %IPM.Test.Utils
{

ClassMethod CreateNamespace(pNSName As %String) As %Status
{
    new $namespace
    set tSC = $$$OK
    try {
        set oldNamespace = $namespace
        set $namespace = "%SYS"
        set tLowerName = $zconvert(pNSName,"L")

        //Create directories
        set tPath = ##class(%File).ManagerDirectory() _ pNSName
        set tCreated = ##class(%File).CreateDirectory(tPath,.tResult)
        if 'tCreated {
            set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tPath_"': "_tResult)
            quit
        }

        set tWebPath = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ "csp") _ pNSName
        if '##class(%File).DirectoryExists(tWebPath) {
            set tCreated = ##class(%File).CreateDirectory(tWebPath,.tResult)
            if 'tCreated {
                set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tWebPath_"': "_tResult)
                quit
            }
        }

        // Create database
        set tSC = ##class(SYS.Database).CreateDatabase(tPath)
        if $$$ISERR(tSC) {
            quit
        }

        // Mount database
        set tDBProps("Directory") = tPath
        set tDBProps("MountRequired") = 1
        set tSC = ##class(Config.Databases).Create(pNSName,.tDBProps)
        if $$$ISERR(tSC) {
            quit
        }
        set Properties("MountRequired") = 1
        set tSC = ##class(Config.Databases).Modify(pNSName,.tDBProps)
        if $$$ISERR(tSC) {
            quit
        }

        // Create namespace
        set tNSProps("Globals") = pNSName
        set tNSProps("Routines") = pNSName

        set tNSProps("Library") = "IRISLIB"
        set tNSProps("SysGlobals") = "IRISSYS"
        set tNSProps("SysRoutines") = "IRISSYS"
        set tNSProps("TempGlobals") = "IRISTEMP"

        set tSC = ##class(Config.Namespaces).Create(pNSName,.tNSProps)
        if $$$ISERR(tSC) {
            quit
        }

        // Ensemble-enable namespace
        set tSC = ##class(%EnsembleMgr).EnableNamespace(pNSName)
        if $$$ISERR(tSC) {
            quit
        }

        // Create default web application
        set tWebProps("AutheEnabled") = $$$AutheCache + $$$AutheUnauthenticated
        set tWebProps("NameSpace") = pNSName
        set tWebProps("Path") = tWebPath
        set tWebProps("IsNameSpaceDefault") = 1
        if ##class(Security.Applications).Exists("/csp/"_tLowerName) {
            set tSC = ##class(Security.Applications).Modify("/csp/"_tLowerName,.tWebProps)
        } else {
            set tSC = ##class(Security.Applications).Create("/csp/"_tLowerName,.tWebProps)
        }
        if $$$ISERR(tSC) {
            quit
        }

        set $namespace = oldNamespace
        $$$ThrowOnError(##class(%IPM.Utils.Build).MapPackageEquivalently("%IPM",oldNamespace,pNSName))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod DeleteNamespace(pNSName As %String) As %Status
{
    new $namespace
    set oldNamespace = $namespace
    set tFinalStatus = $$$OK
    try {
        set $namespace = "%SYS"
        set tLowerName = $zconvert(pNSName,"L")
        set tPath = ##class(%File).ManagerDirectory() _ pNSName
        set tWebPath = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ "csp") _ pNSName

        // Delete Web Application
        set tSC = ##class(Security.Applications).Delete("/csp/"_tLowerName)
        set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

        // Delete namespace
        set tSC = ##class(Config.Namespaces).Delete(pNSName)
        set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

        // Close CSP connections for the namespace
        // (There were some issues with these processes locking the DB folder and preventing its deletion later.)
        set tSC = ..CloseConnectionsForNamespace(pNSName)
        set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

        // Delete secondary database
        set tSecondaryDB = pNSName_##class(%Library.EnsembleMgr).#SECONDARYSUFFIX
        set tEnsTempDB = pNSName_##class(%Library.EnsembleMgr).#TEMPSUFFIX
        for tOtherDB = tSecondaryDB,tEnsTempDB {
            set tSC = $$$OK
            set tDB = ##class(Config.Databases).Open(tOtherDB,,.tSC)
            if $isobject(tDB) {
                // Delete database
                set tSC = ##class(Config.Databases).Delete(tOtherDB)
                set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

                // Delete database file
                set tOtherPath = tDB.Directory
                set tSC = ##class(SYS.Database).DeleteDatabase(tOtherPath)
                set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
            } elseif $$$ISERR(tSC) {
                set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
            }
        }

        // Delete database
        set tSC = ##class(Config.Databases).Delete(pNSName)
        set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

        // Delete database file
        set tSC = ##class(SYS.Database).DeleteDatabase(tPath)
        set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

        // Delete directories
        set $namespace = oldNamespace
        set tDirRemoved = ##class(%IPM.Utils.File).RemoveDirectoryTree(tPath)
        if 'tDirRemoved {
            set tFinalStatus = $$$ADDSC(tFinalStatus,$$$ERROR($$$GeneralError,"Error removing directory '"_tPath_"'"))
        }

        set tDirRemoved = ##class(%IPM.Utils.File).RemoveDirectoryTree(tWebPath)
        if 'tDirRemoved {
            set tFinalStatus = $$$ADDSC(tFinalStatus,$$$ERROR($$$GeneralError,"Error removing directory '"_tWebPath_"'"))
        }
    } catch e {
        set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
    }
    quit tFinalStatus
}

ClassMethod CreateUser(
	pName As %String,
	pPassword As %String,
	pRoles As %String = "%All") As %Status
{
    new $namespace
    set tStatus = $$$OK
    try {
        set $namespace = "%SYS"
        set tStatus = ##class(Security.Users).Create(pName,pRoles,pPassword)
    } catch e {
        set tStatus = e.AsStatus()
    }
    quit tStatus
}

ClassMethod DeleteUser(pName As %String) As %Status
{
    new $namespace
    set tStatus = $$$OK
    try {
        set $namespace = "%SYS"
        set tStatus = ##class(Security.Users).Delete(pName)
    } catch e {
        set tStatus = e.AsStatus()
    }
    quit tStatus
}

ClassMethod CloseConnectionsForNamespace(pNamespace As %String) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set tStatus = $$$OK
    set tClosed = 0
    try {
        set tProcs = ##class(%SQL.Statement).%ExecDirect(,"select PID from %SYS.ProcessQuery where Namespace = ?",pNamespace)
        if (tProcs.%SQLCODE < 0) {
            set tStatus = $$$ERROR($$$SQLCode,tProcs.%SQLCODE,tProcs.%Message)
            quit
        }
        while tProcs.%Next(.tStatus) {
            set tProc = ##class(SYS.Process).%OpenId(tProcs.%Get("PID"))
            set tStatus = $$$ADDSC(tStatus,tProc.Terminate())
        }
    } catch e {
        set tStatus = e.AsStatus()
    }
    quit tStatus
}

}
