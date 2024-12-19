Include (%sySecurity, %occErrors, %IPM.Common, %IPM.Formatting)

Class %IPM.ResourceProcessor.CSPApplication Extends (%IPM.ResourceProcessor.Abstract, %XML.Adaptor, %Installer.CSPApplication) [ PropertyClass = %IPM.ResourceProcessor.PropertyParameters ]
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Facilitates CSP application definition/configuration during module installation process.";

Parameter ATTRIBUTES = {""_
	// Not in any version of %Installer.CSPApplication (and probably shouldn't be)
	"PasswordAuthEnabled,UnauthenticatedEnabled,DelegatedAuthEnabled,KerberosAuthEnabled,LoginTokenEnabled,"_
	
	// Not in any version of %Installer.CSPApplication (but maybe should be)
	"Enabled,DeepSeeEnabled,iKnowEnabled,"_
	
	// Not in all reasonably modern versions of %Installer.CSPApplication
	"DispatchClass,MatchRoles,"_ 
	
	// The rest of these are in all reasonably modern versions of %Installer.CSPApplication
	// From: Write ##class(%IPM.ResourceProcessor.CSPApplication).GetInheritedProperties()
	// "Grant" removed (since it's replaced by "MatchRoles")
	##class(%IPM.Utils.Module).GetInstallerProperties("CSPApplication", "Grant")};

/// Overridden to avoid issues in %Installer generation
Parameter XMLNAME = "IPMCSPApplication";

/// Overridden to avoid issues in %Installer generation
Parameter XMLTYPE = "IPMCSPApplication";

/// Enabled
Property Enabled As %Boolean [ InitialExpression = 1 ];

/// DeepSee Enabled
Property DeepSeeEnabled As %Installer.Boolean [ InitialExpression = 0 ];

/// iKnow Enabled
Property iKnowEnabled As %Installer.Boolean [ InitialExpression = 0 ];

/// Password authentication enabled
Property PasswordAuthEnabled As %Boolean [ InitialExpression = 0 ];

/// Unauthenticated access enabled
Property UnauthenticatedEnabled As %Boolean [ InitialExpression = 0 ];

/// Delegated authentication enabled
Property DelegatedAuthEnabled As %Boolean [ InitialExpression = 0 ];

/// Kerberos authentication enabled
Property KerberosAuthEnabled As %Boolean [ InitialExpression = 0 ];

/// Login token authentication enabled
Property LoginTokenEnabled As %Boolean [ InitialExpression = 0 ];

/// If defined, this will dispatch all requests in this CSP application to this one class
Property DispatchClass As %String(MAXLEN = 256);

/// Mapping of Match Roles to added Target Role
Property MatchRoles As %String(MAXLEN = 32767);

/// Cookie Path
Property CookiePath As %String(MAXLEN = 256);

/// Physical path for CSP files
Property Directory As %String(ATTRIBUTEREQUIRED = 0, MAXLEN = 1024) [ Required ];

/// PermittedClasses default
Property PermittedClasses As %String(MAXLEN = 32767);

Method %OnNew(pResourceReference As %IPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set packageName = pResourceReference.Module.Name
	If ($Get(packageName) '= "") && '$Data($$$DeprecationWarned(packageName, "CSPApplication")) {
		Set $$$DeprecationWarned(packageName, "CSPApplication") = 1
		Write !, $$$FormattedLine($$$Red, "WARNING: The <CSPApplication></CSPApplication> resource tag is deprecated and may be removed in a future release of IPM.")
		Write !, $$$FormattedLine($$$Red, $$$FormatText("         Please contact the package developer of %1 to use <WebApplication></WebApplication> instead", packageName))
	}
	Set tSC = ##super(pResourceReference)
	Set ..Url = $ZConvert(..Url,"L")
	Quit tSC
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ##super(pPhase,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = ..OnPhaseInternal("After",pPhase,.pParams)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tResourceDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
		If (..Directory = "") && (..DispatchClass = "") {
			Set ..Directory = tResourceDir
		} ElseIf (..Directory '= "") {
			Set ..Directory = ##class(%File).NormalizeDirectory(..Directory)
		} ElseIf (..DispatchClass '= "") {
			// To make validation pass
			Set ..Directory = "<irrelevant>"
		}
		
		Set tSC = ##super(pPhase,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..OnPhaseInternal("Before",pPhase,.pParams)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnPhaseInternal(pTime As %String, pPhase As %String, ByRef pParams) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		Set tCopyFiles = 1
		Set tRoot = $Get(pParams("RootDirectory"),..ResourceReference.Module.Root)
		Set tResourceDir = ##class(%File).NormalizeDirectory(tRoot_..ResourceReference.Name)
		If (..Directory = tResourceDir) || (..Directory = "<irrelevant>") || (..Directory = "") {
			Set tCopyFiles = 0
		}
		
		Set ..CookiePath = $ZConvert(..CookiePath,"L")
		
		If ..Directory = "<irrelevant>" {
			Set ..Directory = ""
		}
		
		Set tVerbose = $Get(pParams("Verbose"))
		
		// TODO: Make mirror-safe?
		// Would require moving mirror-safe APIs to the package manager - at which point, why not just have the package manager manage the whole federation?
		If (pTime = "Before") && ((pPhase = "Configure") || ((pPhase = "Activate"))) {
			// Create CSP application
			Set tSC = ..CreateOrUpdateCSPApp(tVerbose)
			If $$$ISERR(tSC) {
				Quit
			}
		} ElseIf (pTime = "Before") && ((pPhase = "Unconfigure") || ((pPhase = "Clean"))) {
			// Remove CSP application; don't copy files!
			Set tSC = ..DeleteCSPApp(tVerbose)
			Set tCopyFiles = 0
		} ElseIf (pTime = "After") && (pPhase = "Reload") {
			// Copy files to physical directory if it already exists
			// TODO: Content Manager?
			Set tCopyFiles = tCopyFiles && (..Directory '= "") && ##class(%File).DirectoryExists(..Directory) 
		} Else {
			Set tCopyFiles = 0
		}
		
		// If Directory was specified, move resources from module root to that directory
		If (tCopyFiles) {
			// Make directory writeable first (so read-only files can be overwritten)
			If ##class(%File).DirectoryExists(..Directory) {
				$$$ThrowOnError(##class(%IPM.Utils.File).MakeDirectoryWriteable(..Directory,.tCmd,.tOutputLog,.tErrLog))
			
				If (tVerbose) {
					Write !,tCmd
					For i=1:1:$Get(tOutputLog) {
						If (tOutputLog(i) '= "") {
							Write !,tOutputLog(i)
						}
					}
				}
				For i=1:1:$Get(tErrLog) {
					If (tErrLog(i) '= "") {
						Write !,tErrLog(i)
					}
				}
			}
			
			// Actually copy the directory
			$$$ThrowOnError(##class(%IPM.Utils.File).CopyDir(tResourceDir,..Directory,, tVerbose))
			
			// And also make directory writeable afterward (because read-only files were copied in)
			$$$ThrowOnError(##class(%IPM.Utils.File).MakeDirectoryWriteable(..Directory,.tCmd,.tOutputLog,.tErrLog))
			If (tVerbose) {
				Write !,tCmd
				For i=1:1:$Get(tOutputLog) {
					If (tOutputLog(i) '= "") {
						Write !,tOutputLog(i)
					}
				}
			}
			For i=1:1:$Get(tErrLog) {
				If (tErrLog(i) '= "") {
					Write !,tErrLog(i)
				}
			}
			
			// Clear CSPGateway cache of these files.
			Set tClearFiles = ..Url_$Case($Extract(..Url,*),"/":"",:"/")_"*"
			If (tVerbose) {
				Write !,"Clearing CSPGateway cache of ",tClearFiles
			}
			Set tRegistry = $System.CSP.GetGatewayRegistry()
			Set tSC = tRegistry.RemoveFilesFromCaches($ListBuild(tClearFiles))
			$$$ThrowOnError(tSC)
			
			// TODO: Content Manager?
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method ReplaceMatchRoles(matchRoles As %String, dbDir As %String) As %String
{
	Set templates = $Listbuild("{$dbrole}", "${dbrole}")
	For i=1:1:$Listlength(templates) {
		Set template = $Listget(templates, i)
		If matchRoles[template {
			Set dbRole = "%DB_DEFAULT"
			Set db = ##class(SYS.Database).%OpenId(dbDir)
			If $Isobject(db) {
				Set dbRole = db.ResourceName
			}
			Set matchRoles = $Replace(matchRoles, template, dbRole)
		}
	}
	Return matchRoles
}

Method CreateOrUpdateCSPApp(pVerbose As %Boolean = 0) As %Status [ Internal ]
{
	// TODO: Make mirror-safe.
	
	Set tSC = $$$OK
	Try {
		Set tOrigNS = $Namespace
		Set dbDir = $$$defdir
		New $namespace
		Set $namespace="%SYS"
		
		// Map properties of this object (inherited from %Installer.CSPApplication) to subscripts of tProperties
		// In other cases, the default mapping is accepted.
		Set tMap("CustomErrorPage") = "ErrorPage"
		Set tMap("DefaultTimeout") = "Timeout"
		Set tMap("DefaultSuperclass") = "SuperClass"
		Set tMap("Directory") = "Path"
		Set tMap("InboundWebServicesEnabled") = "InbndWebServicesEnabled"
		Set tMap("IsNamespaceDefault") = "IsNameSpaceDefault"
		Set tMap("LoginClass") = "LoginPage"
		Set tMap("PackageName") = "Package"
		Set tMap("UseSessionCookie") = "UseCookies"
		
		// Hard-coded - this is always a Web Application
		Set tProperties("Type") = 2
		Set tProperties("NameSpace") = tOrigNS
		Set tProperties("HyperEvent") = 0
		
		Set tSpecial("PasswordAuthEnabled") = ""
		Set tSpecial("UnauthenticatedEnabled") = ""
		Set tSpecial("DelegatedAuthEnabled") = ""
		Set tSpecial("KerberosAuthEnabled") = ""
		Set tSpecial("Url") = ""
		
		Set tProperties("AutheEnabled") = (..PasswordAuthEnabled * $$$AutheCache) +
			(..UnauthenticatedEnabled * $$$AutheUnauthenticated) +
			(..DelegatedAuthEnabled * $$$AutheDelegated) +
			(..KerberosAuthEnabled * $$$AutheK5API) +
			(..LoginTokenEnabled * $$$AutheLoginToken)

		If tProperties("AutheEnabled") = 0 {
			kill tProperties("AutheEnabled")
		}

		Set tPropList = $ListFromString(..#ATTRIBUTES)
		Set tPtr = 0
		While $ListNext(tPropList,tPtr,tPropName) {
			Continue:$Data(tSpecial(tPropName))
			Set tPropSub = $Get(tMap(tPropName),tPropName)
			Set tProperties(tPropSub) = $Property($This,tPropName)
		}
		
		Set matchRoles = ..MatchRoles
		Set matchRolesR = matchRoles
		Set matchRoles = ..ReplaceMatchRoles(matchRoles, dbDir)
    Set pos = 0
    For {
      Set pos = $Find(matchRoles, ":", pos)
      Quit:pos=0
      Set role = $Extract(matchRoles, pos, *)
      CONTINUE:role=""
      Set role = $PIECE($PIECE(role, ":"), ",")
      If '##class(Security.Roles).Exists(role) {
        Set $EXTRACT(matchRoles, pos, pos + $LENGTH(role)) = ""
        Set pos = pos - 1
      }
		}
		If matchRoles=":" $$$ThrowOnError($$$ERROR($$$GeneralError,"Missing role "_matchRolesR))
		Set tProperties("MatchRoles") = matchRoles
    If (..DelegatedAuthEnabled) {
      Do ..ActivateDelegated(matchRoles)
    }		

		// If we have a "Serve Files Timeout" and Serve Files is set to "Always", change to "Always and Cached."
		// Unfortunately (or perhaps by design?) ServeFiles is a boolean in %Installer.CSPApplication.
		If $Get(tProperties("ServeFiles")) {
			Set tProperties("ServeFiles") = tProperties("ServeFiles") + ($Get(tProperties("ServeFilesTimeout")) '= "")
		}
		If ..CookiePath'="/" && ($Get(tProperties("UseCookies")) = "") {
			Set tProperties("UseCookies") = 1
		}

		If ##class(Security.Applications).Exists(..Url) {
			Write:pVerbose !,"Updating Web Application ",..Url
			Set tSC = ##class(Security.Applications).Get(..Url,.tOldProperties)
			$$$ThrowOnError(tSC)
			
			Kill tChanges
			Set tKey = ""
			For {
				Set tOldNext = $Order(tOldProperties(tKey),1,tOldVal)
				Set tNewNext = $Order(tProperties(tKey),1,tNewVal)
				If (tOldNext = tNewNext) {
					If (tOldVal '= tNewVal) {
						Set tChanges($i(tChanges)) = tOldNext_": "_tOldVal_" -> "_tNewVal 
					} // Else no-op
				} ElseIf (tNewNext]]tOldNext) {
					Set tChanges($i(tChanges)) = tOldNext_": "_tOldVal_" -> [missing]"
				} Else {
					//tOldNext]]tNewNext
					Set tChanges($i(tChanges)) = tNewNext_": [missing] -> "_tNewVal
				}
				Set tKey = $Select(tNewNext]]tOldNext:tOldNext,1:tNewNext)
				Quit:(tKey="")
			}
			
			If $Data(tChanges) {
				If (pVerbose) {
					For i=1:1:$Get(tChanges) {
						Write !,tChanges(i)
					}
				}
				Set tSC = ##class(Security.Applications).Modify(..Url,.tProperties)
				$$$ThrowOnError(tSC)
				Write:pVerbose !,"Done."
			} Else {
				Write:pVerbose !,"No changes detected or made."
			}
		} Else {
			Write:pVerbose !,"Creating Web Application ",..Url
			Set tSC = ##class(Security.Applications).Create(..Url,.tProperties)
			If (pVerbose) {
				Set tKey = ""
				For {
					Set tKey = $Order(tProperties(tKey),1,tValue)
					Quit:tKey=""
					Write !,?4,tKey,": ",tValue
				}
			}
			$$$ThrowOnError(tSC)
			Write:pVerbose !,"Done."
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Enable Delegated Auth system-wide
/// And add role to CSPSystem, so, it will have access to do delegated auth
ClassMethod ActivateDelegated(Role As %String = "") As %Status
{
  New $Namespace
  Set $Namespace = "%SYS"
  $$$QuitOnError(##class(Security.System).Get(, .p))
  Set p("AutheEnabled") = $ZBoolean(p("AutheEnabled"), $$$AutheDelegated, 7)
  $$$QuitOnError(##class(Security.System).Modify(, .p))
  If (Role '= "") {
    $$$QuitOnError(##class(Security.Users).AddRoles("CSPSystem", Role))
  }
  Quit $$$OK
}

/// This removes an existing CSP application
Method DeleteCSPApp(pVerbose As %Boolean = 0) As %Status [ Internal ]
{
	// TODO: Make mirror-safe.
	
	Set tSC = $$$OK
	Try {
		// Only try to purge files if the directory exists.
		Set tDirExists = (..Directory '= "") && ##class(%File).DirectoryExists(..Directory)
		Set tSC = ##class(%Library.EnsembleMgr).deletePortal(..Url,tDirExists,pVerbose)
		If ($System.Status.GetErrorCodes(tSC) [ $$$ApplicationDoesNotExist) {
			// Not actually a problem - allow Clean/Uninstall to continue if it fails while trying to remove something that doesn't exist.
			Set tSC = $$$OK
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

Method OnBeforeArtifact(pExportDirectory As %String, pWorkingDirectory As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If (pExportDirectory = pWorkingDirectory) {
			Quit
		}
		Write !,"[OnBeforeArtifact] "_..ResourceReference.Name
		If '..ResourceReference.Deploy {
			Set tSC = ##class(%IPM.Utils.File).CopyDir(
				pExportDirectory_..ResourceReference.Name,
				pWorkingDirectory_..ResourceReference.Name)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
	If (..Url '= "") {
		Set pUniqueName = ..Url
	}
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
	Set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
	If (..Url '= "") {
		Set pInfo.SourceControlAware = 1
		Set pInfo.ResourceType = "/CSP/"
		Set pInfo.Prefix = ..Url
		Set pInfo.RelativePath = ..ResourceReference.Name
		Set pInfo.IsDirectory = ($Piece(..ResourceReference.Name,"/",*) '[ ".")
	}
	Quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
	Quit ..ResourceReference.Name_$Piece(pItemName,..Url,2)
}

Method OnGetStudioProject(pProject As %Studio.Project, Output pHandled As %Boolean = 0)
{
	// IMPORTANT: Remove leading *and* trailing slash.
	do pProject.AddItem($Extract(..Url,2,*-1),"DIR")
	set pHandled = 1
}

}
