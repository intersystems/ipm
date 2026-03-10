Include (%occErrors, %occOptions, %syPrompt)

Class %IPM.Utils.Build
{

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod InitializeBuildNamespace(
	pVerbose As %Boolean = 1,
	pNSConfig As %IPM.Storage.ModuleSetting.NamespaceConfig) As %Status
{
    quit ..InitializeNamespace("BUILD", pVerbose,, pNSConfig)
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod InitializeNamespace(
	pPostfix As %String,
	pVerbose As %Boolean = 1,
	Output pNewNamespace,
	pNSConfig As %IPM.Storage.ModuleSetting.NamespaceConfig) As %Status
{
    // TODO: Support custom mappings and additional databases.
    new $namespace
    set tSC = $$$OK
    set pNewNamespace = ""
    try {
        set tInitNS = $select($namespace="%SYS": "USER", 1: $namespace)
        set pNewNamespace = tInitNS_"-"_pPostfix
        set tBuildDBName = pNewNamespace_"-CODE"
        set tDataDBName = pNewNamespace_"-DATA"

        // These can fail safely.
        do ..CleanUpNamespace(pPostfix,pVerbose)

        for tDatabase = tBuildDBName,tDataDBName {
            if (pVerbose) {
                write !,"Creating and mounting database ",tDatabase
            }
            $$$ThrowOnError(..CreateDatabase(tDatabase))
        }
        if (pVerbose) {
            write !,"Creating namespace ",pNewNamespace
            if (pNSConfig.EnableHealthShare) {
                write " and HealthShare-enabling it."
            } elseif (pNSConfig.EnableEnsemble) {
                write " and Ensemble-enabling it."
            }
        }
        $$$ThrowOnError(..CreateNamespace(pNewNamespace, tBuildDBName, tDataDBName, pVerbose, pNSConfig))

        $$$ThrowOnError(..MapPackageEquivalently("%IPM",$namespace,pNewNamespace))

        set oldNamespace = $namespace
        set $namespace = pNewNamespace

        // Copy over registries from the source namespace as well
        $$$ThrowOnError(##class(%IPM.Main).Shell("repo -copy-from "_oldNamespace))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod CleanUpNamespace(
	pPostfix As %String,
	pVerbose As %Boolean = 1) As %Status
{
    set tSC = $$$OK
    set tInitNS = $namespace
    try {
        set tTargetNamespace = tInitNS_"-"_pPostfix
        set tBuildDBName = tTargetNamespace_"-CODE"
        set tDataDBName = tTargetNamespace_"-DATA"

        if (pVerbose) {
            write !,"Cleaning up ",tTargetNamespace
        }
        set tSC = $$$ADDSC(tSC,##class(%Library.EnsembleMgr).DisableNamespace(tTargetNamespace))
        set tSC = $$$ADDSC(tSC,..DeleteNamespace(tTargetNamespace))
        set tSC = $$$ADDSC(tSC,..DeleteDatabase(tBuildDBName))
        set tSC = $$$ADDSC(tSC,..DeleteDatabase(tDataDBName))
    } catch e {
        set tSC = $system.Status.AppendStatus(tSC,e.AsStatus())
    }
    quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod SwitchToBuildNamespace() As %Status
{
    set tSC = $$$OK
    try {
        set tInitNS = $select($namespace="%SYS": "USER", 1: $namespace)
        set $namespace = tInitNS_"-BUILD"
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod SwitchToNamespace(pPostfix As %String) As %Status
{
    set tSC = $$$OK
    try {
        set tInitNS = $select($namespace="%SYS": "USER", 1: $namespace)
        set $namespace = tInitNS_"-"_pPostfix
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod RetrieveBuiltDatabase(
	Output pStream As %Stream.TmpBinary,
	pVerbose As %Boolean = 0) As %Status
{
    // TODO: Support retrieval of databases other than the code DB
    new $namespace
    set tSC = $$$OK
    set pStream = ##class(%Stream.TmpBinary).%New()
    try {
        set tInitNS = $select($namespace="%SYS": "USER", 1: $namespace)
        set tCodeDBName = tInitNS_"-CODE"

        set $namespace = "%SYS"

        set tDB = ##class(Config.Databases).Open(tCodeDBName,,.tSC)
        $$$ThrowOnError(tSC)
        if $isobject(tDB) {
            // Dismount database
            $$$ThrowOnError(##class(SYS.Database).DismountDatabase(tDB.Directory))

            // Copy database to temp binary stream
            set tSourceStream = ##class(%Stream.FileBinary).%OpenId(##class(%File).NormalizeFilename(tDB.Directory_"\IRIS.DAT"),,.tSC)
            $$$ThrowOnError(tSC)

            $$$ThrowOnError(pStream.CopyFrom(tSourceStream))

            do pStream.Rewind()

            // Remount database
            set tSysDB = ##class(SYS.Database).%OpenId(tDB.Directory)
            if ('tSysDB.Mounted) {
                $$$ThrowOnError(##class(SYS.Database).MountDatabase(tDB.Directory))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod PrepareDatabase(
	pDBName As %String,
	pVerbose As %Boolean = 1) As %Status
{
    new $namespace
    set tSC = $$$OK
    try {
        set $namespace = "%SYS"

        set tDB = ##class(Config.Databases).Open(pDBName,,.tSC)
        $$$ThrowOnError(tSC)
        if $isobject(tDB) {
            // Compact
            write:pVerbose !,"Compacting "_tDB.Directory_" ..."
            set tSC = ##class(SYS.Database).CompactDatabase(tDB.Directory,100,.tMBProcessed,.tMBCompressed,0,$io)
            $$$ThrowOnError(tSC)
            write:pVerbose !,$char(9),tMBProcessed,"MB processed; ",tMBCompressed,"MB compressed."

            // Defragment
            write:pVerbose !,"Defragmenting "_tDB.Directory_" ..."
            set tSC = ##class(SYS.Database).Defragment(tDB.Directory)
            $$$ThrowOnError(tSC)
            write:pVerbose !,$char(9),"done."

            // Return unused space
            write:pVerbose !,"Returning unused space in "_tDB.Directory_" ..."
            set tSC = ##class(SYS.Database).ReturnUnusedSpace(tDB.Directory,,.tNewSize)
            $$$ThrowOnError(tSC)
            write:pVerbose !,$char(9),"New file size: ",tNewSize,"MB"
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod CreateDatabase(
	pDBName As %String,
	pInitFile As %String = "",
	pOverwrite As %Boolean = 0,
	Output pCreated As %Boolean) As %Status
{
    new $namespace
    set tSC = $$$OK
    set pCreated = 0
    try {
        set $namespace = "%SYS"
        set tLowerName = $zconvert(pDBName,"L")

        //Create directory
        set tPath = ##class(%Library.File).NormalizeDirectory(##class(%File).ManagerDirectory() _ pDBName)
        if '##class(%Library.File).DirectoryExists(tPath) {
            set tCreated = ##class(%Library.File).CreateDirectory(tPath,.tResult)
            if '##class(%Library.File).Exists(tPath),'tCreated {
                set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tPath_"': "_tResult)
                quit
            }
        }

        set tRoleResourceName = "%DB_" _ $zconvert(pDBName,"U")
        if '##class(Security.Resources).Exists(tRoleResourceName) {
            set tSC = ##class(Security.Resources).Create(tRoleResourceName,"","","")
            if $$$ISERR(tSC) {
                quit
            }
        }
        if '##class(Security.Roles).Exists(tRoleResourceName) {
            set tSC = ##class(Security.Roles).Create(tRoleResourceName,"",tRoleResourceName_":RW","")
            if $$$ISERR(tSC) {
                quit
            }
        }
        // Create database
        set tExists = 0
        if '##class(SYS.Database).%ExistsId(tPath) {
            set tSC = ##class(SYS.Database).CreateDatabase(tPath,,,,tRoleResourceName)
            if $$$ISERR(tSC) {
                quit
            }
        } else {
            set tExists = 1
            set tDatabase = ##class(SYS.Database).%OpenId(tPath,,.tSC)
            if $$$ISERR(tSC) {
                quit
            }
            if (tDatabase.ResourceName '= tRoleResourceName) {
                set tDatabase.ResourceName = tRoleResourceName
                set tSC = tDatabase.%Save()
                if $$$ISERR(tSC) {
                    quit
                }
            }
        }
        set tSC = ##class(SYS.Database).DismountDatabase(tPath)
        if $$$ISERR(tSC) {
            quit
        }

        if (pInitFile '= "") && (pOverwrite || 'tExists) {
            set tDBFile = tPath_"IRIS.DAT"
            set tGood = ##class(%Library.File).CopyFile(pInitFile,tDBFile,pOverwrite,.tReturn)
            if 'tGood {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying %1 to %2: %3",pInitFile,tDBFile,tReturn))
                quit
            }
        }

        // Create (if necessary) and mount database
        if '##class(Config.Databases).Exists(pDBName) {
            set tDBProps("Directory") = tPath
            set tDBProps("MountRequired") = 1
            set tSC = ##class(Config.Databases).Create(pDBName,.tDBProps)
            if $$$ISERR(tSC) {
                quit
            }
            set pCreated = 1
        }

        // Ensure that database is really mounted.
        set tSC = ##class(SYS.Database).MountDatabase(tPath)
        if $$$ISERR(tSC) {
            if $system.Status.Equals(tSC,$$$ERRORCODE($$$AlreadyMounted)) {
                set tSC = $$$OK
            } else {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Delete the given database with name <var>pDBName</var>. <br />
/// Optionally indicate whether this is a component library database (like HSLIB). <br />
ClassMethod DeleteDatabase(
	pDBName As %String,
	pIsLibraryDatabase As %Boolean = 0) As %Status
{
    new $namespace
    set tFinalStatus = $$$OK
    try {
        set $namespace = "%SYS"
        set tPath = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).ManagerDirectory() _ pDBName)
        if pIsLibraryDatabase {
            set tPath = ##class(%Library.File).NormalizeDirectory($system.Util.InstallDirectory()_"mgr/"_$$$lcase(pDBName))
        }

        if ##class(Config.Databases).Exists(pDBName) {
            // Delete database
            set tSC = ##class(Config.Databases).Delete(pDBName)
            set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
        }

        // Delete database file
        if ##class(%Library.File).Exists(tPath_"IRIS.DAT") {
            // It is fine if this fails because the directory will be removed below, so no need to check status
            do ##class(SYS.Database).DeleteDatabase(tPath)
        }

        // Delete directories
        if ##class(%Library.File).DirectoryExists(tPath) {
            set tDirRemoved = ##class(%Library.File).RemoveDirectoryTree(tPath)
            if 'tDirRemoved {
                set tFinalStatus = $$$ADDSC(tFinalStatus,$$$ERROR($$$GeneralError,"Error removing directory '"_tPath_"'"))
            }
        }

        set tRoleResourceName = "%DB_" _ $zconvert(pDBName,"U")
        // If the role for the database exists, remove it
        if ##class(Security.Roles).Exists(tRoleResourceName) {
            set tSC = ##class(Security.Roles).Delete(tRoleResourceName)
            set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
        }
        // If the resource for the database exists, remove it
        if ##class(Security.Resources).Exists(tRoleResourceName) {
            set tSC = ##class(Security.Resources).Delete(tRoleResourceName)
            set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
        }
    } catch e {
        set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
    }
    quit tFinalStatus
}

ClassMethod CreateNamespace(
	pNSName As %String,
	pCodeDBName As %String,
	pDataDBName As %String,
	pVerbose As %Boolean = 1,
	pNSConfig As %IPM.Storage.ModuleSetting.NamespaceConfig) As %Status
{
    set prevNS = $namespace
    new $namespace
    set tSC = $$$OK
    try {
        set $namespace = "%SYS"
        set tLowerName = $zconvert(pNSName,"L")

        // The csp directory is lower case on unix but upper case on windows
        set tCSP = "csp"
        if $$$isWINDOWS {
            set tCSP = $zconvert(tCSP, "U")
        }

        //Create CSP directory
        set tWebPath = ##class(%Library.File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ tCSP) _ pNSName
        set tCreated = ##class(%Library.File).CreateDirectory(tWebPath,.tResult)
        if '##class(%Library.File).Exists(tWebPath),'tCreated {
            set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tWebPath_"': "_tResult)
            quit
        }

        // Create namespace
        set tNSProps("Globals") = pDataDBName
        set tNSProps("Library") = "IRISLIB"
        set tNSProps("Routines") = pCodeDBName
        set tNSProps("SysGlobals") = "IRISSYS"
        set tNSProps("SysRoutines") = "IRISSYS"
        set tNSProps("TempGlobals") = "IRISTEMP"
        set tSC = ##class(Config.Namespaces).Create(pNSName,.tNSProps)
        if $$$ISERR(tSC) {
            quit
        }

        if pNSConfig.EnableEnsemble || pNSConfig.EnableHealthShare {
            // Ensemble-enable namespace
            // HealthShare at some point will ignore Verbose = 0, so redirect output to the null device if we're not in verbose mode.
            set tOldIO = $io
            try {
                if 'pVerbose {
                    open ##class(%Library.Device).GetNullDevice()
                    use ##class(%Library.Device).GetNullDevice()
                }
                // The fourth arg, pFromInstall, is a hack to prevent HS-enabling namespaces we don't want to.
                set tSC = ##class(%Library.EnsembleMgr).EnableNamespace(pNSName,,,'pNSConfig.EnableHealthShare)
                if $$$ISERR(tSC) {
                    quit
                }
            } catch e {
                set tSC = e.AsStatus()
            }
            if 'pVerbose {
                use tOldIO
            }
            if $$$ISERR(tSC) {
                quit
            }
        }

        // Always add mapping for ^%IPM.Dev.* to the CODE database (for modules)
        // Switch back from %SYS to previous namespace as %SYS does not contain IPM classes
        set $namespace = prevNS
        set tSC = ##class(%IPM.Utils.Module).AddGlobalMapping(pNSName,"HS.PM.Dev.*",pCodeDBName)
        if $$$ISERR(tSC) {
            quit
        }
        set $namespace = "%SYS"

        if pNSConfig.EnableHealthShare {
            // Create default web application
            set tWebProps("AutheEnabled") = $$$AutheCache + $$$AutheUnauthenticated
            set tWebProps("NameSpace") = pNSName
            set tWebProps("Path") = tWebPath
            set tWebProps("IsNameSpaceDefault") = 1
            set tSC = ##class(Security.Applications).Create("/csp/"_tLowerName,.tWebProps)
            if $$$ISERR(tSC) {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Delete the given namespace with name <var>pNSName</var>. <br />
/// Optionally indicate whether this is a component namespace (like HSLIB). <br />
ClassMethod DeleteNamespace(
	pNSName As %String,
	pVerbose As %Boolean = 0) As %Status
{
    new $namespace
    set tFinalStatus = $$$OK
    try {
    if pVerbose write !,"Deleting namespace: " _ pNSName
        set $namespace = "%SYS"
        set tLowerName = $zconvert(pNSName,"L")
        // The csp directory is lower case on unix but upper case on windows
        set tCSP = "csp"
        if $$$isWINDOWS {
            set tCSP = $zconvert(tCSP, "U")
        }
        // All directories under the csp directory are lower case (on all platforms)
        set tCSPChildName = $zconvert(pNSName, "L")
        set tWebPath = ##class(%Library.File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ tCSP) _ tCSPChildName
        set tWebPath = ##class(%Library.File).NormalizeDirectory(tWebPath)
        set tWebPathExists = ##class(%Library.File).DirectoryExists(tWebPath)

        // Delete Web Applications
        set tSC = ..DeleteWebApplications(pNSName)
        set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

        set tDBList = ""
        // Delete namespace
        if ##class(Config.Namespaces).Exists(pNSName) {
            do ##class(Config.Namespaces).Get(pNSName, .params)
            set tDBList = tDBList _ $listbuild(params("Routines"))
            set tDBList = tDBList _ $listbuild(params("Globals"))
            set tSC = ##class(Config.Namespaces).Delete(pNSName)
            set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
        } else {
            set tDBList = tDBList _ $listbuild(pNSName _ "-CODE")
            set tDBList = tDBList _ $listbuild(pNSName _ "-DATA")
        }

        // Delete secondary databases
        set tSecondaryDB = pNSName_##class(%Library.EnsembleMgr).#SECONDARYSUFFIX
        set tEnsTempDB = pNSName_##class(%Library.EnsembleMgr).#TEMPSUFFIX
        set tDBList = tDBList _ $listbuild(tSecondaryDB, tEnsTempDB)
        set ptr = 0
        while $listnext(tDBList, ptr, tDB) {
            if pVerbose write !,"Deleting database: " _ tDB
            set tSC = ..DeleteDatabase(tDB)
            set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
        }

        // Delete csp directory
        if tWebPathExists {
            set tDirRemoved = ##class(%Library.File).RemoveDirectoryTree(tWebPath)
            if 'tDirRemoved {
                // This isn't a fatal error so just write to console log as a warning
                do ##class(%SYS.System).WriteToConsoleLog("Error removing directory '"_tWebPath_"'", , 1)
            }
        }

        // Disable if ensemble enabled (only on primary if mirrored because it tries to modify
        // globals in read-only databases if run on backup which causes <PROTECT> errors)
        if '$system.Mirror.IsMember() || $system.Mirror.IsPrimary() {
             if ((##class(%Library.EnsembleMgr).IsEnsembleInstalled() || ##class(%Library.EnsembleMgr).IsHealthShareInstalled())) {
                 set tSC = ##class(%Library.EnsembleMgr).DisableNamespace(pNSName)
                 if $$$ISERR(tSC) {
                    set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
                 }
             }
        }
    } catch e {
        set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
    }
    quit tFinalStatus
}

ClassMethod DeleteWebApplications(pNamespace As %String) As %Status
{
    new $namespace
    set tFinalStatus = $$$OK
    try {
        set $namespace = "%SYS"
        set tApps = ##class(%SQL.Statement).%ExecDirect(,
            "select Name from Security.Applications where Namespace = ?",pNamespace)
        if (tApps.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tApps.%SQLCODE,tApps.%Message)
        }
        while tApps.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            set tSC = ##class(Security.Applications).Delete(tApps.%Get("Name"))
            set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
        }
        $$$ThrowOnError(tSC)
    } catch e {
        set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
    }
    quit tFinalStatus
}

/// Maps <var>pPackageName</var> in <var>pMappedToNamespace</var> to the same database as in <var>pSourceNamespace</var>
ClassMethod MapPackageEquivalently(
	pPackageName As %String,
	pSourceNamespace As %String,
	pMappedToNamespace As %String,
	pSkipActivation As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        new $namespace
        set oldNamespace = $namespace
        set tSourceDB = ##class(%SYS.Namespace).GetPackageDest(pSourceNamespace,pPackageName)
        set $namespace = "%SYS"
        // In tSourceDB:
        // The first ^-delimited piece is the system (usually empty meaning a local DB)
        // The second ^-delimited piece is the directory.
        // This should uniquely identify a database, so we get back a $ListBuild list with one name.
        set tSC = ##class(Config.Databases).DatabasesByDirectory($piece(tSourceDB,"^"),$piece(tSourceDB,"^",2),.tDBList)
        $$$ThrowOnError(tSC)
        if ($listlength(tDBList) '= 1) {
            // This is highly unexpected, but worth checking for anyway.
            $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Could not find database name for '%1'",tDBDir)))
        }
        $$$ThrowOnError(tSC)
        set $namespace = oldNamespace
        set tSC = ##class(%IPM.Utils.Module).AddPackageMapping(pMappedToNamespace, pPackageName, $listget(tDBList), pSkipActivation)
        $$$ThrowOnError(tSC)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Maps <var>pRoutineName</var> in <var>pMappedToNamespace</var> to the same database as in <var>pSourceNamespace</var>
ClassMethod MapRoutineEquivalently(
	pRoutineName As %String,
	pSourceNamespace As %String,
	pType As %String = "ALL",
	pMappedToNamespace As %String,
	pSkipActivation As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        new $namespace
        set oldNamespace = $namespace
        set tSourceDB = ##class(%SYS.Namespace).GetRoutineDest(pSourceNamespace,pRoutineName,pType)
        set $namespace = "%SYS"
        // In tSourceDB:
        // The first ^-delimited piece is the system (usually empty meaning a local DB)
        // The second ^-delimited piece is the directory.
        // This should uniquely identify a database, so we get back a $ListBuild list with one name.
        set tSC = ##class(Config.Databases).DatabasesByDirectory($piece(tSourceDB,"^"),$piece(tSourceDB,"^",2),.tDBList)
        $$$ThrowOnError(tSC)
        if ($listlength(tDBList) '= 1) {
            // This is highly unexpected, but worth checking for anyway.
            $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Could not find database name for '%1'",tDBDir)))
        }
        $$$ThrowOnError(tSC)
        set $namespace = oldNamespace
        set tSC = ##class(%IPM.Utils.Module).AddRoutineMapping(pMappedToNamespace, pRoutineName, pType, $listget(tDBList), pSkipActivation)
        $$$ThrowOnError(tSC)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Maps <var>pGlobalName</var> in <var>pMappedToNamespace</var> to the same database as in <var>pSourceNamespace</var>
ClassMethod MapGlobalEquivalently(
	pGlobalName As %String,
	pSourceNamespace As %String,
	pMappedToNamespace As %String,
	pSkipActivation As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        new $namespace
        set oldNamespace = $namespace
        set tSourceDB = ##class(%SYS.Namespace).GetGlobalDest(pSourceNamespace,pGlobalName)
        set $namespace = "%SYS"
        // In tSourceDB:
        // The first ^-delimited piece is the system (usually empty meaning a local DB)
        // The second ^-delimited piece is the directory.
        // This should uniquely identify a database, so we get back a $ListBuild list with one name.
        set tSC = ##class(Config.Databases).DatabasesByDirectory($piece(tSourceDB,"^"),$piece(tSourceDB,"^",2),.tDBList)
        $$$ThrowOnError(tSC)
        if ($listlength(tDBList) '= 1) {
            // This is highly unexpected, but worth checking for anyway.
            $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Could not find database name for '%1'",tDBDir)))
        }
        $$$ThrowOnError(tSC)
        set $namespace = oldNamespace
        set tSC = ##class(%IPM.Utils.Module).AddGlobalMapping(pMappedToNamespace, pGlobalName, $listget(tDBList), pSkipActivation)
        $$$ThrowOnError(tSC)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Maps globals used by <var>pClassName</var> to the same database as in <var>pSourceNamespace</var> in <var>pMappedToNamespace</var>.
/// The class does not yet need to exist or be mapped in <var>pMappedToNamespace</var>.
ClassMethod MapClassDataEquivalently(
	pClassName As %String,
	pSourceNamespace As %String,
	pMappedToNamespace As %String) As %Status
{
    set tSC = $$$OK
    try {
        new $namespace
        set $namespace = pSourceNamespace

        // Ensure that the class is registered in the extent manager (in case, for example, it is mapped itself).
        set tSC = ##class(%ExtentMgr.Util).RegisterClass(pClassName)
        $$$ThrowOnError(tSC)
        set tResult = ##class(%SQL.Statement).%ExecDirect(,"call %ExtentMgr.GlobalsUsed(?)",pClassName_".cls")
        if (tResult.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
        }
        while tResult.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            set tGlobalName = $piece(tResult.%Get("GlobalName"),"^",2,*)
            set tSC = ..MapGlobalEquivalently(tGlobalName,pSourceNamespace,pMappedToNamespace)
            $$$ThrowOnError(tSC)
        }
        $$$ThrowOnError(tSC)

        // Also map stream global. The extent manager doesn't handle this. :(
        set tClassDef = ##class(%Dictionary.CompiledClass).%OpenId(pClassName,,.tSC)
        $$$ThrowOnError(tSC)

        #dim tStorage As %Dictionary.CompiledStorage
        set tStorage = tClassDef.Storages.GetNext("")
        if $isobject(tStorage) {
            if (tStorage.StreamLocation '= "") {
                set tGlobalName = $piece(tStorage.StreamLocation,"^",2,*)
                set tSC = ..MapGlobalEquivalently(tGlobalName,pSourceNamespace,pMappedToNamespace)
                $$$ThrowOnError(tSC)
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Called from build.mac
ClassMethod CleanBuild(
	pModuleToClean As %String,
	Output pDoBuild As %Boolean = 0) As %Status
{
    new $namespace
    set tSC = $$$OK
    set tAbort = 0
    try {
        set tContinue = 1
        set tBackUp = 1
        set tPromptMask = $$$DisableHelpCharMask + $$$DisableBackupCharMask + $$$EnableQuitCharMask + $$$TrapCtrlCMask
        set tResponse = ##class(%Prompt).GetYesNo("Back up default code database for "_$namespace_" before running build?",.tBackUp,,tPromptMask)
        if tResponse '= $$$SuccessResponse {
            set tAbort = 1
            quit
        }
        if tBackUp {
            set tSC = ..Backup()
            if $$$ISERR(tSC) {
                write !,"Backup failed:"
                write !,$system.Status.GetErrorText(tSC)
                set tAbort = 1
                quit
            }
        } else {
            set tResponse = ##class(%Prompt).GetYesNo("All HealthShare code will be deleted from namespace "_$namespace_" prior to the build. You may lose work. Are you sure you want to do this?",.tContinue,,tPromptMask)
            if (tContinue '= 1) || (tResponse '= $$$SuccessResponse) {
                write !,"Exiting build."
                quit
            }
        }
        set tSC = ##class(%IPM.Main).Shell("uninstall -r -f "_pModuleToClean)
        set pDoBuild = 1
    } catch e {
        set tSC = e.AsStatus()
    }
    if (tAbort = 1) {
        write !,"Aborting build."
        set pDoBuild = 0
    }
    quit tSC
}

ClassMethod Backup() As %Status [ Internal ]
{
    new $namespace
    set tSC = $$$OK
    set tFrozen = 0
    try {
        // If we start in HSLIB (for example), this will be the path to the HSLIB database.
        set tSourceDir = ##class(%Library.File).GetDirectory()
        set tTargetDir = ##class(%Library.File).SubDirectoryName(tSourceDir,"backup",1)
        kill %objlasterror
        set tSC = ##class(%IPM.Utils.File).CreateDirectoryChain(tTargetDir)
        $$$ThrowOnError(tSC)
        set $namespace = "%SYS"
        write !,"Freezing writes..."
        set tSC = ##class(Backup.General).ExternalFreeze()
        $$$ThrowOnError(tSC)
        set tFrozen = 1
        set tSourceFile = tSourceDir_"IRIS.DAT"
        set tTargetFile = tTargetDir_"IRIS.DAT"
        set tCopied = ##class(%Library.File).CopyFile(tSourceFile,tTargetFile,1,.tOSError)
        if 'tCopied {
            if '$data(%objlasterror,tSC) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying %1 to %2: %3",tSourceFile,tTargetFile,$zutil(209,tOSError)))
            }
        } else {
            write !,"Backed up ",tSourceDir," to ",tTargetFile
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if tFrozen {
        set $namespace = "%SYS"
        set tSC = $$$ADDSC(tSC,##class(Backup.General).ExternalThaw())
    }
    quit tSC
}

}
