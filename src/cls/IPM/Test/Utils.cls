Include %sySecurity

Class %IPM.Test.Utils
{

ClassMethod CreateNamespace(pNSName As %String) As %Status
{
	New $Namespace
	Set tSC = $$$OK
	Try {
		Set oldNamespace = $Namespace
		Set $Namespace = "%SYS"
		Set tLowerName = $ZCVT(pNSName,"L")

		//Create directories
		Set tPath = ##class(%File).ManagerDirectory() _ pNSName
		Set tCreated = ##class(%File).CreateDirectory(tPath,.tResult)
		If 'tCreated {
			Set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tPath_"': "_tResult)
			Quit
		}
		
		Set tWebPath = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ "csp") _ pNSName
		If '##class(%File).DirectoryExists(tWebPath) {
			Set tCreated = ##class(%File).CreateDirectory(tWebPath,.tResult)
			If 'tCreated {
				Set tSC = $$$ERROR($$$GeneralError,"Error creating directory '"_tWebPath_"': "_tResult)
				Quit
			}
		}	

		// Create database
		Set tSC = ##class(SYS.Database).CreateDatabase(tPath)
		If $$$ISERR(tSC) {
			Quit
		}

		// Mount database
		Set tDBProps("Directory") = tPath
		Set tDBProps("MountRequired") = 1
		Set tSC = ##class(Config.Databases).Create(pNSName,.tDBProps)
		If $$$ISERR(tSC) {
			Quit
		}
		Set Properties("MountRequired") = 1
		Set tSC = ##class(Config.Databases).Modify(pNSName,.tDBProps)
		If $$$ISERR(tSC) {
			Quit
		}

		// Create namespace
		Set tNSProps("Globals") = pNSName
		Set tNSProps("Routines") = pNSName
		
		Set tNSProps("Library") = "IRISLIB"
		Set tNSProps("SysGlobals") = "IRISSYS"
		Set tNSProps("SysRoutines") = "IRISSYS"
		Set tNSProps("TempGlobals") = "IRISTEMP"

		Set tSC = ##class(Config.Namespaces).Create(pNSName,.tNSProps)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Ensemble-enable namespace
		Set tSC = ##class(%EnsembleMgr).EnableNamespace(pNSName)
		If $$$ISERR(tSC) {
			Quit
		}

		// Create default web application
		Set tWebProps("AutheEnabled") = $$$AutheCache + $$$AutheUnauthenticated
		Set tWebProps("NameSpace") = pNSName
		Set tWebProps("Path") = tWebPath
		Set tWebProps("IsNameSpaceDefault") = 1
		if ##class(Security.Applications).Exists("/csp/"_tLowerName) {
			Set tSC = ##class(Security.Applications).Modify("/csp/"_tLowerName,.tWebProps)
		} else {
			Set tSC = ##class(Security.Applications).Create("/csp/"_tLowerName,.tWebProps)
		}
		If $$$ISERR(tSC) {
			Quit
		}

		Set $Namespace = oldNamespace
		$$$ThrowOnError(##class(%IPM.Utils.Build).MapPackageEquivalently("%IPM",oldNamespace,pNSName))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod DeleteNamespace(pNSName As %String) As %Status
{
	New $Namespace
	Set oldNamespace = $Namespace
	Set tFinalStatus = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tLowerName = $ZCVT(pNSName,"L")
		Set tPath = ##class(%File).ManagerDirectory() _ pNSName
		Set tWebPath = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory()) _ "csp") _ pNSName
		
		// Delete Web Application
		Set tSC = ##class(Security.Applications).Delete("/csp/"_tLowerName)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		// Delete namespace
		Set tSC = ##class(Config.Namespaces).Delete(pNSName)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)
		
		// Close CSP connections for the namespace
		// (There were some issues with these processes locking the DB folder and preventing its deletion later.)
		Set tSC = ..CloseConnectionsForNamespace(pNSName)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		// Delete secondary database
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

		// Delete database
		Set tSC = ##class(Config.Databases).Delete(pNSName)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		// Delete database file
		Set tSC = ##class(SYS.Database).DeleteDatabase(tPath)
		Set tFinalStatus = $$$ADDSC(tFinalStatus,tSC)

		// Delete directories
		Set $Namespace = oldNamespace
		Set tDirRemoved = ##class(%IPM.Utils.File).RemoveDirectoryTree(tPath)
		If 'tDirRemoved {
			Set tFinalStatus = $$$ADDSC(tFinalStatus,$$$ERROR($$$GeneralError,"Error removing directory '"_tPath_"'"))
		}
		
		Set tDirRemoved = ##class(%IPM.Utils.File).RemoveDirectoryTree(tWebPath)
		If 'tDirRemoved {
			Set tFinalStatus = $$$ADDSC(tFinalStatus,$$$ERROR($$$GeneralError,"Error removing directory '"_tWebPath_"'"))
		}
	} Catch e {
		Set tFinalStatus = $$$ADDSC(tFinalStatus,e.AsStatus())
	}
	Quit tFinalStatus
}

ClassMethod CreateUser(pName As %String, pPassword As %String, pRoles As %String = "%All") As %Status
{
	New $Namespace
	Set tStatus = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tStatus = ##class(Security.Users).Create(pName,pRoles,pPassword)
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

ClassMethod DeleteUser(pName As %String) As %Status
{
	New $Namespace
	Set tStatus = $$$OK
	Try {
		Set $Namespace = "%SYS"
		Set tStatus = ##class(Security.Users).Delete(pName)
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

ClassMethod CloseConnectionsForNamespace(pNamespace As %String) As %Status
{
	Set tStatus = $$$OK
	Set tClosed = 0
	Try {
		Set tProcs = ##class(%SQL.Statement).%ExecDirect(,"select PID from %SYS.ProcessQuery where Namespace = ?",pNamespace)
		If (tProcs.%SQLCODE < 0) {
			Set tStatus = $$$ERROR($$$SQLCode,tProcs.%SQLCODE,tProcs.%Message)
			Quit
		}
		While tProcs.%Next(.tStatus) {
			Set tProc = ##class(SYS.Process).%OpenId(tProcs.%Get("PID"))
			Set tStatus = $$$ADDSC(tStatus,tProc.Terminate())
		}
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

}
