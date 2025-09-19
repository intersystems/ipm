Include (%sySecurity, %occErrors, %IPM.Common, %IPM.Formatting)

/// DEPRECATED. Use <class>%IPM.ResourceProcessor.WebApplication</class> instead.
Class %IPM.ResourceProcessor.CSPApplication Extends (%IPM.ResourceProcessor.Abstract, %XML.Adaptor, %Installer.CSPApplication) [ Deprecated, PropertyClass = %IPM.ResourceProcessor.PropertyParameters ]
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
    set packageName = pResourceReference.Module.Name
    if ($get(packageName) '= "") && '$data($$$DeprecationWarned(packageName, "CSPApplication")) {
        set $$$DeprecationWarned(packageName, "CSPApplication") = 1
        write !, $$$FormattedLine($$$Red, "WARNING: The <CSPApplication></CSPApplication> resource tag is deprecated and may be removed in a future release of IPM.")
        write !, $$$FormattedLine($$$Red, $$$FormatText("         Please contact the package developer of %1 to use <WebApplication></WebApplication> instead", packageName))
    }
    set tSC = ##super(pResourceReference)
    set ..Url = $zconvert(..Url,"L")
    quit tSC
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tSC = ##super(pPhase,.pParams)
        if $$$ISERR(tSC) {
            quit
        }
        set tSC = ..OnPhaseInternal("After",pPhase,.pParams)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tResourceDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
        if (..Directory = "") && (..DispatchClass = "") {
            set ..Directory = tResourceDir
        } elseif (..Directory '= "") {
            set ..Directory = ##class(%File).NormalizeDirectory(..Directory)
        } elseif (..DispatchClass '= "") {
            // To make validation pass
            set ..Directory = "<irrelevant>"
        }

        set tSC = ##super(pPhase,.pParams)
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = ..OnPhaseInternal("Before",pPhase,.pParams)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnPhaseInternal(
	pTime As %String,
	pPhase As %String,
	ByRef pParams) As %Status [ Private ]
{
    set tSC = $$$OK
    try {
        set tCopyFiles = 1
        set tRoot = $get(pParams("RootDirectory"),..ResourceReference.Module.Root)
        set tResourceDir = ##class(%File).NormalizeDirectory(tRoot_..ResourceReference.Name)
        if (..Directory = tResourceDir) || (..Directory = "<irrelevant>") || (..Directory = "") {
            set tCopyFiles = 0
        }

        set ..CookiePath = $zconvert(..CookiePath,"L")

        if ..Directory = "<irrelevant>" {
            set ..Directory = ""
        }

        set tVerbose = $get(pParams("Verbose"))

        if (pTime = "Before") && ((pPhase = "Configure") || ((pPhase = "Activate"))) {
            // Create CSP application
            set tSC = ..CreateOrUpdateCSPApp(tVerbose)
            if $$$ISERR(tSC) {
                quit
            }
        } elseif (pTime = "Before") && ((pPhase = "Unconfigure") || ((pPhase = "Clean"))) {
            // Remove CSP application; don't copy files!
            set tSC = ..DeleteCSPApp(tVerbose)
            set tCopyFiles = 0
        } elseif (pTime = "After") && (pPhase = "Reload") {
            // Copy files to physical directory if it already exists
            // TODO: Content Manager?
            set tCopyFiles = tCopyFiles && (..Directory '= "") && ##class(%File).DirectoryExists(..Directory)
        } else {
            set tCopyFiles = 0
        }

        // If Directory was specified, move resources from module root to that directory
        if (tCopyFiles) {
            // Make directory writeable first (so read-only files can be overwritten)
            if ##class(%File).DirectoryExists(..Directory) {
                $$$ThrowOnError(##class(%IPM.Utils.File).MakeDirectoryWriteable(..Directory,.tCmd,.tOutputLog,.tErrLog))

                if (tVerbose) {
                    write !,tCmd
                    for i=1:1:$get(tOutputLog) {
                        if (tOutputLog(i) '= "") {
                            write !,tOutputLog(i)
                        }
                    }
                }
                for i=1:1:$get(tErrLog) {
                    if (tErrLog(i) '= "") {
                        write !,tErrLog(i)
                    }
                }
            }

            // Actually copy the directory
            $$$ThrowOnError(##class(%IPM.Utils.File).CopyDir(tResourceDir,..Directory,, tVerbose))

            // And also make directory writeable afterward (because read-only files were copied in)
            $$$ThrowOnError(##class(%IPM.Utils.File).MakeDirectoryWriteable(..Directory,.tCmd,.tOutputLog,.tErrLog))
            if (tVerbose) {
                write !,tCmd
                for i=1:1:$get(tOutputLog) {
                    if (tOutputLog(i) '= "") {
                        write !,tOutputLog(i)
                    }
                }
            }
            for i=1:1:$get(tErrLog) {
                if (tErrLog(i) '= "") {
                    write !,tErrLog(i)
                }
            }

            // Clear CSPGateway cache of these files.
            set tClearFiles = ..Url_$case($extract(..Url,*),"/":"",:"/")_"*"
            if (tVerbose) {
                write !,"Clearing CSPGateway cache of ",tClearFiles
            }
            set tRegistry = $system.CSP.GetGatewayRegistry()
            set tSC = tRegistry.RemoveFilesFromCaches($listbuild(tClearFiles))
            $$$ThrowOnError(tSC)

            // TODO: Content Manager?
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method ReplaceMatchRoles(
	matchRoles As %String,
	dbDir As %String) As %String
{
    new $namespace
    set $namespace = "%SYS"
    set templates = $listbuild("{$dbrole}", "${dbrole}")
    for i=1:1:$listlength(templates) {
        set template = $listget(templates, i)
        if matchRoles[template {
            set dbRole = "%DB_DEFAULT"
            set db = ##class(SYS.Database).%OpenId(dbDir,0)
            if $isobject(db) {
                set dbRole = db.ResourceName
            }
            set matchRoles = $replace(matchRoles, template, dbRole)
        }
    }
    return matchRoles
}

Method CreateOrUpdateCSPApp(pVerbose As %Boolean = 0) As %Status [ Internal ]
{
    set tSC = $$$OK
    try {
        set tOrigNS = $namespace
        set dbDir = $$$defdir
        new $namespace
        set $namespace="%SYS"

        // Map properties of this object (inherited from %Installer.CSPApplication) to subscripts of tProperties
        // In other cases, the default mapping is accepted.
        set tMap("CustomErrorPage") = "ErrorPage"
        set tMap("DefaultTimeout") = "Timeout"
        set tMap("DefaultSuperclass") = "SuperClass"
        set tMap("Directory") = "Path"
        set tMap("InboundWebServicesEnabled") = "InbndWebServicesEnabled"
        set tMap("IsNamespaceDefault") = "IsNameSpaceDefault"
        set tMap("LoginClass") = "LoginPage"
        set tMap("PackageName") = "Package"
        set tMap("UseSessionCookie") = "UseCookies"

        // Hard-coded - this is always a Web Application
        set tProperties("Type") = 2
        set tProperties("NameSpace") = tOrigNS
        set tProperties("HyperEvent") = 0

        set tSpecial("PasswordAuthEnabled") = ""
        set tSpecial("UnauthenticatedEnabled") = ""
        set tSpecial("DelegatedAuthEnabled") = ""
        set tSpecial("KerberosAuthEnabled") = ""
        set tSpecial("Url") = ""

        set tProperties("AutheEnabled") = (..PasswordAuthEnabled * $$$AutheCache) +
            (..UnauthenticatedEnabled * $$$AutheUnauthenticated) +
            (..DelegatedAuthEnabled * $$$AutheDelegated) +
            (..KerberosAuthEnabled * $$$AutheK5API) +
            (..LoginTokenEnabled * $$$AutheLoginToken)

        if tProperties("AutheEnabled") = 0 {
            kill tProperties("AutheEnabled")
        }

        set tPropList = $listfromstring(..#ATTRIBUTES)
        set tPtr = 0
        while $listnext(tPropList,tPtr,tPropName) {
            continue:$data(tSpecial(tPropName))
            set tPropSub = $get(tMap(tPropName),tPropName)
            set tProperties(tPropSub) = $property($this,tPropName)
        }

        set matchRoles = ..MatchRoles
        set matchRolesR = matchRoles
        set matchRoles = ..ReplaceMatchRoles(matchRoles, dbDir)
        set pos = 0
        for {
            set pos = $find(matchRoles, ":", pos)
            quit:pos=0
            set role = $extract(matchRoles, pos, *)
            continue:role=""
            set role = $piece($piece(role, ":"), ",")
            if '##class(Security.Roles).Exists(role) {
                set $extract(matchRoles, pos, pos + $length(role)) = ""
                set pos = pos - 1
            }
        }
        if (matchRoles=":") {
            $$$ThrowOnError($$$ERROR($$$GeneralError,"Missing role "_matchRolesR))
        }
        set tProperties("MatchRoles") = matchRoles
        if (..DelegatedAuthEnabled) {
            do ..ActivateDelegated(matchRoles)
        }

        // If we have a "Serve Files Timeout" and Serve Files is set to "Always", change to "Always and Cached."
        // Unfortunately (or perhaps by design?) ServeFiles is a boolean in %Installer.CSPApplication.
        if $get(tProperties("ServeFiles")) {
            set tProperties("ServeFiles") = tProperties("ServeFiles") + ($get(tProperties("ServeFilesTimeout")) '= "")
        }
        if (..CookiePath'="/") && ($get(tProperties("UseCookies")) = "") {
            set tProperties("UseCookies") = 1
        }

        if ##class(Security.Applications).Exists(..Url) {
            write:pVerbose !,"Updating Web Application ",..Url
            set tSC = ##class(Security.Applications).Get(..Url,.tOldProperties)
            $$$ThrowOnError(tSC)

            kill tChanges
            set tKey = ""
            for {
                set tOldNext = $order(tOldProperties(tKey),1,tOldVal)
                set tNewNext = $order(tProperties(tKey),1,tNewVal)
                if (tOldNext = tNewNext) {
                    if (tOldVal '= tNewVal) {
                        set tChanges($increment(tChanges)) = tOldNext_": "_tOldVal_" -> "_tNewVal
                    } // Else no-op
                } elseif (tNewNext]]tOldNext) {
                    set tChanges($increment(tChanges)) = tOldNext_": "_tOldVal_" -> [missing]"
                } else {
                    //tOldNext]]tNewNext
                    set tChanges($increment(tChanges)) = tNewNext_": [missing] -> "_tNewVal
                }
                set tKey = $select(tNewNext]]tOldNext:tOldNext,1:tNewNext)
                quit:(tKey="")
            }

            if $data(tChanges) {
                if (pVerbose) {
                    for i=1:1:$get(tChanges) {
                        write !,tChanges(i)
                    }
                }
                set tSC = ##class(Security.Applications).Modify(..Url,.tProperties)
                $$$ThrowOnError(tSC)
                write:pVerbose !,"Done."
            } else {
                write:pVerbose !,"No changes detected or made."
            }
        } else {
            write:pVerbose !,"Creating Web Application ",..Url
            set tSC = ##class(Security.Applications).Create(..Url,.tProperties)
            if (pVerbose) {
                set tKey = ""
                for {
                    set tKey = $order(tProperties(tKey),1,tValue)
                    quit:tKey=""
                    write !,?4,tKey,": ",tValue
                }
            }
            $$$ThrowOnError(tSC)
            write:pVerbose !,"Done."
        }
    } catch ex {
        set tSC = ex.AsStatus()
    }
    quit tSC
}

/// Enable Delegated Auth system-wide
/// And add role to CSPSystem, so, it will have access to do delegated auth
ClassMethod ActivateDelegated(Role As %String = "") As %Status
{
    new $namespace
    set $namespace = "%SYS"
    $$$QuitOnError(##class(Security.System).Get(, .p))
    set p("AutheEnabled") = $zboolean(p("AutheEnabled"), $$$AutheDelegated, 7)
    $$$QuitOnError(##class(Security.System).Modify(, .p))
    if (Role '= "") {
        $$$QuitOnError(##class(Security.Users).AddRoles("CSPSystem", Role))
    }
    quit $$$OK
}

/// This removes an existing CSP application
Method DeleteCSPApp(pVerbose As %Boolean = 0) As %Status [ Internal ]
{
    set tSC = $$$OK
    try {
        // Only try to purge files if the directory exists.
        set tDirExists = (..Directory '= "") && ##class(%File).DirectoryExists(..Directory)
        set tSC = ##class(%Library.EnsembleMgr).deletePortal(..Url,tDirExists,pVerbose)
        if ($system.Status.GetErrorCodes(tSC) [ $$$ApplicationDoesNotExist) {
            // Not actually a problem - allow Clean/Uninstall to continue if it fails while trying to remove something that doesn't exist.
            set tSC = $$$OK
        }
    } catch ex {
        set tSC = ex.AsStatus()
    }
    quit tSC
}

Method OnBeforeArtifact(
	pExportDirectory As %String,
	pWorkingDirectory As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        if (pExportDirectory = pWorkingDirectory) {
            quit
        }
        write !,"[OnBeforeArtifact] "_..ResourceReference.Name
        if '..ResourceReference.Deploy {
            set tSC = ##class(%IPM.Utils.File).CopyDir(
                pExportDirectory_..ResourceReference.Name,
                pWorkingDirectory_..ResourceReference.Name)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
    if (..Url '= "") {
        set pUniqueName = ..Url
    }
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
    set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
    if (..Url '= "") {
        set pInfo.SourceControlAware = 1
        set pInfo.ResourceType = "/CSP/"
        set pInfo.Prefix = ..Url
        set pInfo.RelativePath = ..ResourceReference.Name
        set pInfo.IsDirectory = ($piece(..ResourceReference.Name,"/",*) '[ ".")
    }
    quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
    quit ..ResourceReference.Name_$piece(pItemName,..Url,2)
}

Method OnGetStudioProject(
	pProject As %Studio.Project,
	Output pHandled As %Boolean = 0)
{
    // IMPORTANT: Remove leading *and* trailing slash.
    do pProject.AddItem($extract(..Url,2,*-1),"DIR")
    set pHandled = 1
}

}
