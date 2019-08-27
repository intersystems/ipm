Class %ZPM.PackageManager.Developer.Build
{

/// @PrivateAPI
ClassMethod InitializeBuildNamespace(pVerbose As %Boolean = 1) As %Status
{
	Quit ..InitializeNamespace("BUILD", pVerbose)
}

/// @PrivateAPI
ClassMethod InitializeNamespace(pPostfix As %String, pVerbose As %Boolean = 1, Output pNewNamespace) As %Status
{
	// TODO: Support custom mappings and additional databases.
	Set tSC = $$$OK
	Set pNewNamespace = ""
	Try {
		Set tInitNS = $Namespace
		Set pNewNamespace = tInitNS_"-"_pPostfix
		Set tBuildDBName = pNewNamespace_"-CODE"
		Set tDataDBName = pNewNamespace_"-DATA"
		
		// These can fail safely.
		Do ##class(%Library.EnsembleMgr).DisableNamespace(pNewNamespace)
		Do ..DeleteNamespace(pNewNamespace)
		Do ..DeleteDatabase(tBuildDBName)
		Do ..DeleteDatabase(tDataDBName)
		
		$$$ThrowOnError(..CreateDatabase(tBuildDBName))
		$$$ThrowOnError(..CreateDatabase(tDataDBName))
		$$$ThrowOnError(..CreateNamespace(pNewNamespace, tBuildDBName, tBuildDBName, pVerbose))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @PrivateAPI
ClassMethod SwitchToBuildNamespace() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tInitNS = $Namespace
		Set $Namespace = tInitNS_"-BUILD"
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @PrivateAPI
ClassMethod SwitchToNamespace(pPostfix As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tInitNS = $Namespace
		Set $Namespace = tInitNS_"-"_pPostfix
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @PrivateAPI
ClassMethod RetrieveBuiltDatabase(Output pStream As %Stream.TmpBinary, pVerbose As %Boolean = 0) As %Status
{
	// TODO: Support retrieval of databases other than the code DB
	New $Namespace
	Set tSC = $$$OK
	Set pStream = ##class(%Stream.TmpBinary).%New()
	Try {
		Set tInitNS = $Namespace
		Set tCodeDBName = tInitNS_"-CODE"
		
		Set $Namespace = "%SYS"
		
		Set tDB = ##class(Config.Databases).Open(tCodeDBName,,.tSC)
		$$$ThrowOnError(tSC)
		If $IsObject(tDB) {
			// Dismount database
			$$$ThrowOnError(##class(SYS.Database).DismountDatabase(tDB.Directory))
			
			// Copy database to temp binary stream
			Set tDBFile = $SELECT($ZVERSION["IRIS": "IRIS.DAT", 1: "CACHE.DAT")
			Set tDBFile = ##class(%File).NormalizeFilename(tDBFile, tDB.Directory)
			Set tSourceStream = ##class(%Stream.FileBinary).%OpenId(tDBFile,,.tSC)
			$$$ThrowOnError(tSC)
			
			$$$ThrowOnError(pStream.CopyFrom(tSourceStream))
			
			Do pStream.Rewind()
			
			// Remount database
			$$$ThrowOnError(##class(SYS.Database).MountDatabase(tDB.Directory))
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
		Set tPath = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ pDBName)
		If '##class(%File).DirectoryExists(tPath) {
			Set tCreated = ##class(%File).CreateDirectory(tPath,.tResult)
			If 'tCreated {
				Set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tPath_"': "_tResult)
				Quit
			}
		}

		// Create database
		Set tExists = 0
		If '##class(SYS.Database).%ExistsId(tPath) {
			Set tSC = ##class(SYS.Database).CreateDatabase(tPath)
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set tExists = 1
		}
		Set tSC = ##class(SYS.Database).DismountDatabase(tPath)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pInitFile '= "") && (pOverwrite || 'tExists) {
			Set tDBFile = tPath_$SELECT($ZVERSION["IRIS": "IRIS.DAT", 1: "CACHE.DAT")
			Set tGood = ##class(%File).CopyFile(pInitFile,tDBFile,pOverwrite,.tReturn)
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
			Set Properties("MountRequired") = 1
			Set tSC = ##class(Config.Databases).Modify(pDBName,.tDBProps)
			If $$$ISERR(tSC) {
				Quit
			}
			Set pCreated = 1
		}
		$$$ThrowOnError(##class(SYS.Database).MountDatabase(tPath))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod DeleteDatabase(pDBName As %String) As %Status
{
	New $Namespace
	Set tFinalStatus = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tLowerName = $ZCVT(pDBName,"L")
		Set tPath = ##class(%File).ManagerDirectory() _ pDBName
		
		// Delete database
		Set tSC = ##class(Config.Databases).Delete(pDBName)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		// Delete database file
		Set tSC = ##class(SYS.Database).DeleteDatabase(tPath)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		// Delete directories
		Set tDirRemoved = ##class(%File).RemoveDirectoryTree(tPath)
		If 'tDirRemoved {
			Set tFinalStatus = $$$ADDSC(tFinalStatus,$$$ERROR($$$GeneralError,"Error removing directory '"_tPath_"'"))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod CreateNamespace(pNSName As %String, pCodeDBName As %String, pDataDBName As %String, pVerbose As %Boolean = 1) As %Status
{
	New $Namespace
	Set tSC = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tLowerName = $ZCVT(pNSName,"L")

		//Create CSP directory
		Set tWebPath = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ "csp") _ pNSName
		Set tCreated = ##class(%File).CreateDirectory(tWebPath,.tResult)
		If 'tCreated,'##class(%File).DirectoryExists(tWebPath) {
			Set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tWebPath_"': "_tResult)
			Quit
		}

		// Create namespace
		Set tNSProps("Globals") = pDataDBName
		Set tNSProps("Routines") = pCodeDBName
		If $ZVERSION["IRIS" {
			Set tNSProps("Library") = "IRISLIB"
			Set tNSProps("SysGlobals") = "IRISSYS"
			Set tNSProps("SysRoutines") = "IRISSYS"
			Set tNSProps("TempGlobals") = "IRISTEMP"
		} else {
			Set tNSProps("Library") = "CACHELIB"
			Set tNSProps("SysGlobals") = "CACHESYS"
			Set tNSProps("SysRoutines") = "CACHESYS"
			Set tNSProps("TempGlobals") = "CACHETEMP"
		}
		Set tSC = ##class(Config.Namespaces).Create(pNSName,.tNSProps)
		If $$$ISERR(tSC) {
			Quit
		}

		// Ensemble-enable namespace
		// PackageManager at some point will ignore Verbose = 0, so redirect output to the null device if we're not in verbose mode.
		Set tOldIO = $IO
		Try {
			Open ##class(%Device).GetNullDevice()
			Use ##class(%Device).GetNullDevice()
			Set tSC = ##class(%EnsembleMgr).EnableNamespace(pNSName)
			If $$$ISERR(tSC) {
				Quit
			}
		} Catch e {
			Set tSC = e.AsStatus()
		}
		Use tOldIO
		If $$$ISERR(tSC) {
			Quit
		}
		QUIT 
		#; // Temporarily, map HS.Registry to HSLIB...
		#; Set tSC = ##class(Utils).AddPackageMapping(pNSName,"HS.Registry","HSLIB")
		#; If $$$ISERR(tSC) {
		#; 	Quit
		#; }
		
		#; // ...but remove other HS.* mappings
		#; Set tSC = ##class(Utils).RemovePackageMapping(pNSName,"HS")
		#; If $$$ISERR(tSC) {
		#; 	Quit
		#; }
		
		#; Set tSC = ##class(Utils).RemoveRoutineMapping(pNSName,"HS.*")
		#; If $$$ISERR(tSC) {
		#; 	Quit
		#; }
		
		#; // Add mapping for ^ZPM.Dev.* to the CODE database
		#; Set tSC = ##class(Utils).AddGlobalMapping(pNSName,"%ZPM.Dev.*",pCodeDBName)
		#; If $$$ISERR(tSC) {
		#; 	Quit
		#; }

		// Create default web application
		Set tWebProps("AutheEnabled") = $$$AutheCache + $$$AutheUnauthenticated
		Set tWebProps("NameSpace") = pNSName
		Set tWebProps("Path") = tWebPath
		Set tWebProps("IsNameSpaceDefault") = 1
		Set tSC = ##class(Security.Applications).Modify("/csp/"_tLowerName,.tWebProps)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod DeleteNamespace(pNSName As %String) As %Status
{
	New $Namespace
	Set tFinalStatus = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tLowerName = $ZCVT(pNSName,"L")
		Set tWebPath = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ "csp") _ pNSName
		
		Set tSC = ##class(%Library.EnsembleMgr).deleteNamespace(pNSName)
		$$$ThrowOnError(tSC)

		// Delete Web Application
		Set tSC = ##class(Security.Applications).Delete("/csp/"_tLowerName)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		// Delete namespace
		Set tSC = ##class(Config.Namespaces).Delete(pNSName)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		// Delete secondary databases
		Set tSecondaryDB = pNSName_##class(%Library.EnsembleMgr).#SECONDARYSUFFIX
		Set tEnsTempDB = pNSName_##class(%Library.EnsembleMgr).#TEMPSUFFIX
		For tOtherDB = tSecondaryDB,tEnsTempDB {
			Set tSC = $$$OK
			Set tDB = ##class(Config.Databases).Open(tOtherDB,,.tSC)
			If $IsObject(tDB) {
				// Delete database
				Set tSC = ##class(Config.Databases).Delete(tOtherDB)
				Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
				
				// Delete database file
				Set tOtherPath = tDB.Directory
				Set tSC = ##class(SYS.Database).DeleteDatabase(tOtherPath)
				Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
			} ElseIf $$$ISERR(tSC) {
				Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
			}
		}
		
		Set tDirRemoved = ##class(%File).RemoveDirectoryTree(tWebPath)
		If 'tDirRemoved {
			Set tFinalStatus = $$$ADDSC(tFinalStatus,$$$ERROR($$$GeneralError,"Error removing directory '"_tWebPath_"'"))
		}
	} Catch e {
		Set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
	}
	Quit tFinalStatus
}

/// Maps <var>pGlobalName</var> in <var>pMappedToNamespace</var> to the same database in <var>pSourceNamespace</var>
ClassMethod MapGlobalEquivalently(pGlobalName As %String, pSourceNamespace As %String, pMappedToNamespace As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
