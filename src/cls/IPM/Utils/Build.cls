Include (%occErrors, %occOptions, %syPrompt)

Class %IPM.Utils.Build
{

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod InitializeBuildNamespace(pVerbose As %Boolean = 1, pNSConfig As %IPM.Storage.ModuleSetting.NamespaceConfig) As %Status
{
	Quit ..InitializeNamespace("BUILD", pVerbose,, pNSConfig)
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod InitializeNamespace(pPostfix As %String, pVerbose As %Boolean = 1, Output pNewNamespace, pNSConfig As %IPM.Storage.ModuleSetting.NamespaceConfig) As %Status
{
	// TODO: Support custom mappings and additional databases.
	New $Namespace
	Set tSC = $$$OK
	Set pNewNamespace = ""
	Try {
		Set tInitNS = $Select($Namespace="%SYS": "USER", 1: $Namespace)
		Set pNewNamespace = tInitNS_"-"_pPostfix
		Set tBuildDBName = pNewNamespace_"-CODE"
		Set tDataDBName = pNewNamespace_"-DATA"
		
		// These can fail safely.
		Do ..CleanUpNamespace(pPostfix,pVerbose)
		
		For tDatabase = tBuildDBName,tDataDBName {
			If (pVerbose) {
				Write !,"Creating and mounting database ",tDatabase
			}
			$$$ThrowOnError(..CreateDatabase(tDatabase))
		}
		If (pVerbose) {
			Write !,"Creating namespace ",pNewNamespace
			If (pNSConfig.EnableHealthShare) {
				Write " and HealthShare-enabling it."
			} ElseIf (pNSConfig.EnableEnsemble) {
				Write " and Ensemble-enabling it."
			}
		}
		$$$ThrowOnError(..CreateNamespace(pNewNamespace, tBuildDBName, tDataDBName, pVerbose, pNSConfig))

		$$$ThrowOnError(..MapPackageEquivalently("%IPM",$Namespace,pNewNamespace))

		Set oldNamespace = $Namespace
		Set $Namespace = pNewNamespace

		// Copy over registries from the source namespace as well
		$$$ThrowOnError(##class(%IPM.Main).Shell("repo -copy-from "_oldNamespace))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod CleanUpNamespace(pPostfix As %String, pVerbose As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Set tInitNS = $Namespace
	Try {
		Set tTargetNamespace = tInitNS_"-"_pPostfix
		Set tBuildDBName = tTargetNamespace_"-CODE"
		Set tDataDBName = tTargetNamespace_"-DATA"
		
		If (pVerbose) {
			Write !,"Cleaning up ",tTargetNamespace
		}
		Set tSC = $$$ADDSC(tSC,##class(%Library.EnsembleMgr).DisableNamespace(tTargetNamespace))
		Set tSC = $$$ADDSC(tSC,..DeleteNamespace(tTargetNamespace))
		Set tSC = $$$ADDSC(tSC,..DeleteDatabase(tBuildDBName))
		Set tSC = $$$ADDSC(tSC,..DeleteDatabase(tDataDBName))
	} Catch e {
		Set tSC = $System.Status.AppendStatus(tSC,e.AsStatus())
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod SwitchToBuildNamespace() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tInitNS = $Select($Namespace="%SYS": "USER", 1: $Namespace)
		Set $Namespace = tInitNS_"-BUILD"
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod SwitchToNamespace(pPostfix As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tInitNS = $Select($Namespace="%SYS": "USER", 1: $Namespace)
		Set $Namespace = tInitNS_"-"_pPostfix
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod RetrieveBuiltDatabase(Output pStream As %Stream.TmpBinary, pVerbose As %Boolean = 0) As %Status
{
	// TODO: Support retrieval of databases other than the code DB
	New $Namespace
	Set tSC = $$$OK
	Set pStream = ##class(%Stream.TmpBinary).%New()
	Try {
		Set tInitNS = $Select($Namespace="%SYS": "USER", 1: $Namespace)
		Set tCodeDBName = tInitNS_"-CODE"
		
		Set $Namespace = "%SYS"
		
		Set tDB = ##class(Config.Databases).Open(tCodeDBName,,.tSC)
		$$$ThrowOnError(tSC)
		If $IsObject(tDB) {
			// Dismount database
			$$$ThrowOnError(##class(SYS.Database).DismountDatabase(tDB.Directory))
			
			// Copy database to temp binary stream
			Set tSourceStream = ##class(%Stream.FileBinary).%OpenId(##class(%File).NormalizeFilename(tDB.Directory_"\IRIS.DAT"),,.tSC)
			$$$ThrowOnError(tSC)
			
			$$$ThrowOnError(pStream.CopyFrom(tSourceStream))
			
			Do pStream.Rewind()
			
			// Remount database
      Set tSysDB = ##class(SYS.Database).%OpenId(tDB.Directory)
      If ('tSysDB.Mounted) {
        $$$ThrowOnError(##class(SYS.Database).MountDatabase(tDB.Directory))      
      }
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod PrepareDatabase(pDBName As %String, pVerbose As %Boolean = 1) As %Status
{
	New $Namespace
	Set tSC = $$$OK
	Try {
		Set $Namespace = "%SYS"
		
		Set tDB = ##class(Config.Databases).Open(pDBName,,.tSC)
		$$$ThrowOnError(tSC)
		If $IsObject(tDB) {
			// Compact
			Write:pVerbose !,"Compacting "_tDB.Directory_" ..."
			Set tSC = ##class(SYS.Database).CompactDatabase(tDB.Directory,100,.tMBProcessed,.tMBCompressed,0,$io)
			$$$ThrowOnError(tSC)
			Write:pVerbose !,$c(9),tMBProcessed,"MB processed; ",tMBCompressed,"MB compressed."
			
			// Defragment
			Write:pVerbose !,"Defragmenting "_tDB.Directory_" ..."
			Set tSC = ##class(SYS.Database).Defragment(tDB.Directory)
			$$$ThrowOnError(tSC)
			Write:pVerbose !,$c(9),"done."
			
			// Return unused space
			Write:pVerbose !,"Returning unused space in "_tDB.Directory_" ..."
			Set tSC = ##class(SYS.Database).ReturnUnusedSpace(tDB.Directory,,.tNewSize)
			$$$ThrowOnError(tSC)
			Write:pVerbose !,$c(9),"New file size: ",tNewSize,"MB"
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod CreateDatabase(pDBName As %String, pInitFile As %String = "", pOverwrite As %Boolean = 0, Output pCreated As %Boolean) As %Status
{
	New $Namespace
	Set tSC = $$$OK
	Set pCreated = 0
	Try {
		Set $Namespace = "%SYS"
		Set tLowerName = $ZCVT(pDBName,"L")

		//Create directory
		Set tPath = ##class(%Library.File).NormalizeDirectory(##class(%File).ManagerDirectory() _ pDBName)
		If '##class(%Library.File).DirectoryExists(tPath) {
			Set tCreated = ##class(%Library.File).CreateDirectory(tPath,.tResult)
			If '##class(%Library.File).Exists(tPath),'tCreated {
				Set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tPath_"': "_tResult)
				Quit
			}
		}

		Set tRoleResourceName = "%DB_" _ $zconvert(pDBName,"U")
		If '##class(Security.Resources).Exists(tRoleResourceName) {
			Set tSC = ##class(Security.Resources).Create(tRoleResourceName,"","","")
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If '##class(Security.Roles).Exists(tRoleResourceName) {
			Set tSC = ##class(Security.Roles).Create(tRoleResourceName,"",tRoleResourceName_":RW","")
			If $$$ISERR(tSC) {
				Quit
			}
		}
		// Create database
		Set tExists = 0
		If '##class(SYS.Database).%ExistsId(tPath) {
			Set tSC = ##class(SYS.Database).CreateDatabase(tPath,,,,tRoleResourceName)
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set tExists = 1
			Set tDatabase = ##class(SYS.Database).%OpenId(tPath,,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
			If (tDatabase.ResourceName '= tRoleResourceName) {
				Set tDatabase.ResourceName = tRoleResourceName
				Set tSC = tDatabase.%Save()
				If $$$ISERR(tSC) {
					Quit
				}
			}
		}
		Set tSC = ##class(SYS.Database).DismountDatabase(tPath)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pInitFile '= "") && (pOverwrite || 'tExists) {
			Set tDBFile = tPath_"IRIS.DAT"
			Set tGood = ##class(%Library.File).CopyFile(pInitFile,tDBFile,pOverwrite,.tReturn)
			If 'tGood {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying %1 to %2: %3",pInitFile,tDBFile,tReturn))
				Quit
			}
		}

		// Create (if necessary) and mount database
		If '##class(Config.Databases).Exists(pDBName) {
			Set tDBProps("Directory") = tPath
			Set tDBProps("MountRequired") = 1
			Set tSC = ##class(Config.Databases).Create(pDBName,.tDBProps)
			If $$$ISERR(tSC) {
				Quit
			}
			Set pCreated = 1
		}
		
		// Ensure that database is really mounted.
		Set tSC = ##class(SYS.Database).MountDatabase(tPath)
		If $$$ISERR(tSC) {
			If $System.Status.Equals(tSC,$$$ERRORCODE($$$AlreadyMounted)) {
				Set tSC = $$$OK
			} Else {
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Delete the given database with name <var>pDBName</var>. <br />
/// Optionally indicate whether this is a component library database (like HSLIB). <br />
ClassMethod DeleteDatabase(pDBName As %String, pIsLibraryDatabase As %Boolean = 0) As %Status
{
	New $Namespace
	Set tFinalStatus = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tPath = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).ManagerDirectory() _ pDBName)
		If pIsLibraryDatabase {
			Set tPath = ##class(%Library.File).NormalizeDirectory($System.Util.InstallDirectory()_"mgr/"_$$$lcase(pDBName))
		}
		
		If ##class(Config.Databases).Exists(pDBName) {
			// Delete database
			Set tSC = ##class(Config.Databases).Delete(pDBName)
			Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
		}

		// Delete database file
		If ##class(%Library.File).Exists(tPath_"IRIS.DAT") {
			// It is fine if this fails because the directory will be removed below, so no need to check status
			Do ##class(SYS.Database).DeleteDatabase(tPath)
		}

		// Delete directories
		If ##class(%Library.File).DirectoryExists(tPath) {
			Set tDirRemoved = ##class(%Library.File).RemoveDirectoryTree(tPath)
			If 'tDirRemoved {
				Set tFinalStatus = $$$ADDSC(tFinalStatus,$$$ERROR($$$GeneralError,"Error removing directory '"_tPath_"'"))
			}
		}
		
		Set tRoleResourceName = "%DB_" _ $zconvert(pDBName,"U")
		// If the role for the database exists, remove it
		If ##class(Security.Roles).Exists(tRoleResourceName) {
			Set tSC = ##class(Security.Roles).Delete(tRoleResourceName)
			Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
		}
		// If the resource for the database exists, remove it
		If ##class(Security.Resources).Exists(tRoleResourceName) {
			Set tSC = ##class(Security.Resources).Delete(tRoleResourceName)
			Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
		}

	} Catch e {
		Set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
	}
	Quit tFinalStatus
}

ClassMethod CreateNamespace(pNSName As %String, pCodeDBName As %String, pDataDBName As %String, pVerbose As %Boolean = 1, pNSConfig As %IPM.Storage.ModuleSetting.NamespaceConfig) As %Status
{
	Set prevNS = $Namespace
	New $Namespace
	Set tSC = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tLowerName = $ZCVT(pNSName,"L")
		
		// The csp directory is lower case on unix but upper case on windows
		Set tCSP = "csp"
		If $$$isWINDOWS {
			Set tCSP = $ZConvert(tCSP, "U")
		}

		//Create CSP directory
		Set tWebPath = ##class(%Library.File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ tCSP) _ pNSName
		Set tCreated = ##class(%Library.File).CreateDirectory(tWebPath,.tResult)
		If '##class(%Library.File).Exists(tWebPath),'tCreated {
			Set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tWebPath_"': "_tResult)
			Quit
		}

		// Create namespace
		Set tNSProps("Globals") = pDataDBName
		Set tNSProps("Library") = "IRISLIB"
		Set tNSProps("Routines") = pCodeDBName
		Set tNSProps("SysGlobals") = "IRISSYS"
		Set tNSProps("SysRoutines") = "IRISSYS"
		Set tNSProps("TempGlobals") = "IRISTEMP"
		Set tSC = ##class(Config.Namespaces).Create(pNSName,.tNSProps)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If pNSConfig.EnableEnsemble || pNSConfig.EnableHealthShare {
			// Ensemble-enable namespace
			// HealthShare at some point will ignore Verbose = 0, so redirect output to the null device if we're not in verbose mode.
			Set tOldIO = $IO
			Try {
				If 'pVerbose {
					Open ##class(%Library.Device).GetNullDevice()
					Use ##class(%Library.Device).GetNullDevice()
				}
				// The fourth arg, pFromInstall, is a hack to prevent HS-enabling namespaces we don't want to.
				Set tSC = ##class(%Library.EnsembleMgr).EnableNamespace(pNSName,,,'pNSConfig.EnableHealthShare)
				If $$$ISERR(tSC) {
					Quit
				}
			} Catch e {
				Set tSC = e.AsStatus()
			}
			If 'pVerbose {
				Use tOldIO
			}
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		// Always add mapping for ^%IPM.Dev.* to the CODE database (for modules)
		// Switch back from %SYS to previous namespace as %SYS does not contain IPM classes
		Set $Namespace = prevNS
		Set tSC = ##class(%IPM.Utils.Module).AddGlobalMapping(pNSName,"HS.PM.Dev.*",pCodeDBName)
		If $$$ISERR(tSC) {
			Quit
		}
		Set $Namespace = "%SYS"

		If pNSConfig.EnableHealthShare {
			// Create default web application
			Set tWebProps("AutheEnabled") = $$$AutheCache + $$$AutheUnauthenticated
			Set tWebProps("NameSpace") = pNSName
			Set tWebProps("Path") = tWebPath
			Set tWebProps("IsNameSpaceDefault") = 1
			Set tSC = ##class(Security.Applications).Create("/csp/"_tLowerName,.tWebProps)
			If $$$ISERR(tSC) {
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Delete the given namespace with name <var>pNSName</var>. <br />
/// Optionally indicate whether this is a component namespace (like HSLIB). <br />
ClassMethod DeleteNamespace(pNSName As %String, pVerbose As %Boolean = 0) As %Status
{
	New $Namespace
	Set tFinalStatus = $$$OK
	Try {
    If pVerbose Write !,"Deleting namespace: " _ pNSName
		Set $Namespace = "%SYS"
		Set tLowerName = $ZConvert(pNSName,"L")
		// The csp directory is lower case on unix but upper case on windows
		Set tCSP = "csp"
		If $$$isWINDOWS {
			Set tCSP = $ZConvert(tCSP, "U")
		}
		// All directories under the csp directory are lower case (on all platforms)
		Set tCSPChildName = $ZConvert(pNSName, "L")
		Set tWebPath = ##class(%Library.File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ tCSP) _ tCSPChildName
		Set tWebPath = ##class(%Library.File).NormalizeDirectory(tWebPath)
		Set tWebPathExists = ##class(%Library.File).DirectoryExists(tWebPath)
		
		// Delete Web Applications
		Set tSC = ..DeleteWebApplications(pNSName)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		Set tDBList = ""
    // Delete namespace
		If ##class(Config.Namespaces).Exists(pNSName) {
			Do ##class(Config.Namespaces).Get(pNSName, .params)
			Set tDBList = tDBList _ $ListBuild(params("Routines"))
			Set tDBList = tDBList _ $ListBuild(params("Globals"))
			Set tSC = ##class(Config.Namespaces).Delete(pNSName)
			Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
		}
		Else {
			Set tDBList = tDBList _ $ListBuild(pNSName _ "-CODE")
			Set tDBList = tDBList _ $ListBuild(pNSName _ "-DATA")
		}

		// Delete secondary databases
		Set tSecondaryDB = pNSName_##class(%Library.EnsembleMgr).#SECONDARYSUFFIX
		Set tEnsTempDB = pNSName_##class(%Library.EnsembleMgr).#TEMPSUFFIX
		Set tDBList = tDBList _ $ListBuild(tSecondaryDB, tEnsTempDB)
		Set ptr = 0
		While $ListNext(tDBList, ptr, tDB) {
			If pVerbose Write !,"Deleting database: " _ tDB
			Set tSC = ..DeleteDatabase(tDB)
			Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
		}
		
		// Delete csp directory
		If tWebPathExists {
			Set tDirRemoved = ##class(%Library.File).RemoveDirectoryTree(tWebPath)
			If 'tDirRemoved {
				// This isn't a fatal error so just write to console log as a warning
				Do ##class(%SYS.System).WriteToConsoleLog("Error removing directory '"_tWebPath_"'", , 1)
			}
		}
		
		// Disable if ensemble enabled (only on primary if mirrored because it tries to modify
		// globals in read-only databases if run on backup which causes <PROTECT> errors)
		If '$System.Mirror.IsMember() || $System.Mirror.IsPrimary() {
		 	If ((##class(%Library.EnsembleMgr).IsEnsembleInstalled() || ##class(%Library.EnsembleMgr).IsHealthShareInstalled())) {
		 		Set tSC = ##class(%Library.EnsembleMgr).DisableNamespace(pNSName)
		 		If $$$ISERR(tSC) {
					Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
		 		}
		 	}
		}
	} Catch e {
		Set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
	}
	Quit tFinalStatus
}

ClassMethod DeleteWebApplications(pNamespace As %String) As %Status
{
	New $Namespace
	Set tFinalStatus = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tApps = ##class(%SQL.Statement).%ExecDirect(,
			"select Name from Security.Applications where Namespace = ?",pNamespace)
		If (tApps.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tApps.%SQLCODE,tApps.%Message)
		}
		While tApps.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tSC = ##class(Security.Applications).Delete(tApps.%Get("Name"))
			Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
		}
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
	}
	Quit tFinalStatus
}

/// Maps <var>pPackageName</var> in <var>pMappedToNamespace</var> to the same database as in <var>pSourceNamespace</var>
ClassMethod MapPackageEquivalently(pPackageName As %String, pSourceNamespace As %String, pMappedToNamespace As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set oldNamespace = $Namespace
		Set tSourceDB = ##class(%SYS.Namespace).GetPackageDest(pSourceNamespace,pPackageName)
		Set $Namespace = "%SYS"
		// In tSourceDB:
		// The first ^-delimited piece is the system (usually empty meaning a local DB)
		// The second ^-delimited piece is the directory.
		// This should uniquely identify a database, so we get back a $ListBuild list with one name.
		Set tSC = ##class(Config.Databases).DatabasesByDirectory($Piece(tSourceDB,"^"),$Piece(tSourceDB,"^",2),.tDBList)
		$$$ThrowOnError(tSC)
		If ($ListLength(tDBList) '= 1) {
			// This is highly unexpected, but worth checking for anyway.
			$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Could not find database name for '%1'",tDBDir)))
		}
		$$$ThrowOnError(tSC)
		Set $Namespace = oldNamespace
		Set tSC = ##class(%IPM.Utils.Module).AddPackageMapping(pMappedToNamespace, pPackageName, $ListGet(tDBList))
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Maps <var>pRoutineName</var> in <var>pMappedToNamespace</var> to the same database as in <var>pSourceNamespace</var>
ClassMethod MapRoutineEquivalently(pRoutineName As %String, pSourceNamespace As %String, pType As %String = "ALL", pMappedToNamespace As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set oldNamespace = $Namespace
		Set tSourceDB = ##class(%SYS.Namespace).GetRoutineDest(pSourceNamespace,pRoutineName,pType)
		Set $Namespace = "%SYS"
		// In tSourceDB:
		// The first ^-delimited piece is the system (usually empty meaning a local DB)
		// The second ^-delimited piece is the directory.
		// This should uniquely identify a database, so we get back a $ListBuild list with one name.
		Set tSC = ##class(Config.Databases).DatabasesByDirectory($Piece(tSourceDB,"^"),$Piece(tSourceDB,"^",2),.tDBList)
		$$$ThrowOnError(tSC)
		If ($ListLength(tDBList) '= 1) {
			// This is highly unexpected, but worth checking for anyway.
			$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Could not find database name for '%1'",tDBDir)))
		}
		$$$ThrowOnError(tSC)
		Set $Namespace = oldNamespace
		Set tSC = ##class(%IPM.Utils.Module).AddRoutineMapping(pMappedToNamespace, pRoutineName, pType, $ListGet(tDBList))
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Maps <var>pGlobalName</var> in <var>pMappedToNamespace</var> to the same database as in <var>pSourceNamespace</var>
ClassMethod MapGlobalEquivalently(pGlobalName As %String, pSourceNamespace As %String, pMappedToNamespace As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set oldNamespace = $Namespace
		Set tSourceDB = ##class(%SYS.Namespace).GetGlobalDest(pSourceNamespace,pGlobalName)
		Set $Namespace = "%SYS"
		// In tSourceDB:
		// The first ^-delimited piece is the system (usually empty meaning a local DB)
		// The second ^-delimited piece is the directory.
		// This should uniquely identify a database, so we get back a $ListBuild list with one name.
		Set tSC = ##class(Config.Databases).DatabasesByDirectory($Piece(tSourceDB,"^"),$Piece(tSourceDB,"^",2),.tDBList)
		$$$ThrowOnError(tSC)
		If ($ListLength(tDBList) '= 1) {
			// This is highly unexpected, but worth checking for anyway.
			$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Could not find database name for '%1'",tDBDir)))
		}
		$$$ThrowOnError(tSC)
		Set $Namespace = oldNamespace
		Set tSC = ##class(%IPM.Utils.Module).AddGlobalMapping(pMappedToNamespace, pGlobalName, $ListGet(tDBList))
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Maps globals used by <var>pClassName</var> to the same database as in <var>pSourceNamespace</var> in <var>pMappedToNamespace</var>.
/// The class does not yet need to exist or be mapped in <var>pMappedToNamespace</var>.
ClassMethod MapClassDataEquivalently(pClassName As %String, pSourceNamespace As %String, pMappedToNamespace As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set $Namespace = pSourceNamespace
		
		// Ensure that the class is registered in the extent manager (in case, for example, it is mapped itself).
		Set tSC = ##class(%ExtentMgr.Util).RegisterClass(pClassName)
		$$$ThrowOnError(tSC)
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,"call %ExtentMgr.GlobalsUsed(?)",pClassName_".cls")
		If (tResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
		}
		While tResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tGlobalName = $Piece(tResult.%Get("GlobalName"),"^",2,*)
			Set tSC = ..MapGlobalEquivalently(tGlobalName,pSourceNamespace,pMappedToNamespace)
			$$$ThrowOnError(tSC)
		}
		$$$ThrowOnError(tSC)
		
		// Also map stream global. The extent manager doesn't handle this. :(
		Set tClassDef = ##class(%Dictionary.CompiledClass).%OpenId(pClassName,,.tSC)
		$$$ThrowOnError(tSC)
		
		#dim tStorage As %Dictionary.CompiledStorage
		Set tStorage = tClassDef.Storages.GetNext("")
		If $IsObject(tStorage) {
			If (tStorage.StreamLocation '= "") {
				Set tGlobalName = $Piece(tStorage.StreamLocation,"^",2,*)
				Set tSC = ..MapGlobalEquivalently(tGlobalName,pSourceNamespace,pMappedToNamespace)
				$$$ThrowOnError(tSC)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called from build.mac
ClassMethod CleanBuild(pModuleToClean As %String, Output pDoBuild As %Boolean = 0) As %Status
{
	New $Namespace
	Set tSC = $$$OK
	Set tAbort = 0
	Try {
		Set tContinue = 1
		Set tBackUp = 1
		Set tPromptMask = $$$DisableHelpCharMask + $$$DisableBackupCharMask + $$$EnableQuitCharMask + $$$TrapCtrlCMask
		Set tResponse = ##class(%Prompt).GetYesNo("Back up default code database for "_$Namespace_" before running build?",.tBackUp,,tPromptMask)
		If tResponse '= $$$SuccessResponse {
			Set tAbort = 1
			Quit
		}
		If tBackUp {
			Set tSC = ..Backup()
			If $$$ISERR(tSC) {
				Write !,"Backup failed:"
				Write !,$System.Status.GetErrorText(tSC)
				Set tAbort = 1
				Quit
			}
		} Else {
			Set tResponse = ##class(%Prompt).GetYesNo("All HealthShare code will be deleted from namespace "_$Namespace_" prior to the build. You may lose work. Are you sure you want to do this?",.tContinue,,tPromptMask)
			If (tContinue '= 1) || (tResponse '= $$$SuccessResponse) {
				Write !,"Exiting build."
				Quit
			}
		}
		Set tSC = ##class(%IPM.Main).Shell("uninstall -r -f "_pModuleToClean)
		Set pDoBuild = 1
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If (tAbort = 1) {
		Write !,"Aborting build."
		Set pDoBuild = 0
	}
	Quit tSC
}

ClassMethod Backup() As %Status [ Internal ]
{
	New $Namespace
	Set tSC = $$$OK
	Set tFrozen = 0
	Try {
		// If we start in HSLIB (for example), this will be the path to the HSLIB database.
		Set tSourceDir = ##class(%Library.File).GetDirectory()
		Set tTargetDir = ##class(%Library.File).SubDirectoryName(tSourceDir,"backup",1)
		Kill %objlasterror
		Set tSC = ##class(%IPM.Utils.File).CreateDirectoryChain(tTargetDir)
		$$$ThrowOnError(tSC)
		Set $Namespace = "%SYS"
		Write !,"Freezing writes..."
		Set tSC = ##class(Backup.General).ExternalFreeze()
		$$$ThrowOnError(tSC)
		Set tFrozen = 1
		Set tSourceFile = tSourceDir_"IRIS.DAT"
		Set tTargetFile = tTargetDir_"IRIS.DAT"
		Set tCopied = ##class(%Library.File).CopyFile(tSourceFile,tTargetFile,1,.tOSError)
		If 'tCopied {
			If '$Data(%objlasterror,tSC) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying %1 to %2: %3",tSourceFile,tTargetFile,$zu(209,tOSError)))
			}
		} Else {
			Write !,"Backed up ",tSourceDir," to ",tTargetFile
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If tFrozen {
		Set tSC = $$$ADDSC(tSC,##class(Backup.General).ExternalThaw())
	}
	Quit tSC
}

}
