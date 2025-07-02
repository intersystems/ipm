/// This class contains inheritence hacks to override final methods in %Studio.* methods
/// And provides utilities to work with extension classes and namespace-specific source control classes
Class %IPM.ExtensionBase.CompositeMethodOverrides
{

/// Array of top-level menu ID to configured handling class.
Property SubExtensions As array Of %Studio.Extension.Base [ Private ];

/// Array associating top-level menu IDs to the class that implements them.
Property MenuMap As array Of %String [ Private ];

/// The username of this source control user. (From %Studio.Extension.Base.)
Property Username As %String;

/// Version of Studio that is connecting to this server. (From %Studio.Extension.Base.)
Property StudioVersion As %String;

/// $Job number of the main Studio process or blank if this is the main Studio connection.
/// This can be used to help co-ordinate between the jobs if Studio is using another server
/// process for things like find in files or a big compile. (From %Studio.Extension.Base.)
Property MainJob As %String;

/// Namespace this extension started out in
Property Namespace As %String [ InitialExpression = {$namespace} ];

/// Cache of information related to mapping of resources across namespaces
Property ResourceMappingCache As %IPM.ExtensionBase.ResourceMappingCache [ InitialExpression = {##class(%IPM.ExtensionBase.ResourceMappingCache).%Get()} ];

Parameter PRIMARYEXTENSIONGBL = {"^SYS(""SourceControl"",""%IPM.ExtensionBase.Composite"",""PrimaryExtensionClass"")"};

Parameter SUBEXTENSIONGBL = {"^SYS(""SourceControl"",""%IPM.ExtensionBase.Composite"",""SubExtensionClasses"")"};

/// This just calls the <method>Login</method> to perform an initialisation.
/// Note that this is called by Studio automatically via the <class>%Studio.SourceControl.Interface</class>
/// class, do not call %New directly.
Method %OnNew(initval As %String) As %Status [ Final ]
{
    set tStatus = $$$OK
    try {
        set ..Username=$listget(initval)
        set ..MainJob=$listget(initval,3),..StudioVersion=$listget(initval,4)
        set tClasses = ..GetSubExtensionClasses()
        set tPtr = 0
        while $listnext(tClasses,tPtr,tClassName) {
            set tExt = $classmethod(tClassName,"%New",initval)
            if '$isobject(tExt) {
                set tStatus = $get(%objlasterror,$$$ERROR($$$GeneralError,"Could not create new extension object of type "_tClassName))
                quit
            }
            set tStatus = ..SubExtensions.SetAt(tExt,tClassName)
            $$$ThrowOnError(tStatus)
            set tStatus = ..MapMenus(tClassName)
            $$$ThrowOnError(tStatus)
        }
    } catch e {
        set tStatus = e.AsStatus()
    }
    quit tStatus
}

ClassMethod SetExtensionClasses(
	pPrimaryClassName As %String,
	pSubExtensionClassNames As %List) As %Status
{
    set tStatus = $$$OK
    set tInitTLevel = $tlevel
    try {
        tstart
        set tStatus = ..SetPrimaryExtensionClass(pPrimaryClassName)
        $$$ThrowOnError(tStatus)
        set tStatus = ..SetSubExtensionClasses(pSubExtensionClassNames)
        $$$ThrowOnError(tStatus)
        tcommit
    } catch e {
        set tStatus = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) { trollback 1 }
    quit tStatus
}

ClassMethod SetPrimaryExtensionClass(pClassName As %String) As %Status
{
    set tStatus = $$$OK
    set tInitTLevel = $tlevel
    try {
        if '##class(%Dictionary.ClassDefinition).%ExistsId(pClassName) {
            quit
        }
        if '$classmethod(pClassName,"%Extends","%Studio.Extension.Base") {
            set tStatus = $$$ERROR($$$GeneralError,"Class '"_pClassName_"' does not extend %Studio.Extension.Base")
            quit
        }
        tstart
        if '$listfind($get(@..#SUBEXTENSIONGBL),pClassName) {
            set @..#SUBEXTENSIONGBL = $listbuild(pClassName)_$get(@..#SUBEXTENSIONGBL)
        }
        set @..#PRIMARYEXTENSIONGBL = pClassName
        tcommit
    } catch e {
        set tStatus = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) { trollback 1 }
    quit tStatus
}

ClassMethod SetSubExtensionClasses(pClassNames As %List) As %Status
{
    set tStatus = $$$OK
    try {
        set tClassNames = ""
        set tPrimaryExtension = ..GetPrimaryExtensionClass()
        if (tPrimaryExtension '= "") {
            set tClassNames = $listbuild(tPrimaryExtension)
        }
        set tPtr = 0
        while $listnext(pClassNames,tPtr,tClassName) {
            if ($get(tClassName) = "") {
                continue
            }
            if '##class(%Dictionary.ClassDefinition).%ExistsId(tClassName) {
                continue
            }
            if '$classmethod(tClassName,"%Extends","%Studio.Extension.Base") {
                set tStatus = $$$ERROR($$$GeneralError,"Class '"_tClassName_"' does not extend %Studio.Extension.Base")
                quit
            }
            if '$data(tClassNames(tClassName)) {
                set tClassNames = tClassNames_$listbuild(tClassName)
                set tClassNames(tClassName) = ""
            }
        }
        $$$ThrowOnError(tStatus)
        set @..#SUBEXTENSIONGBL = pClassNames
    } catch e {
        set tStatus = e.AsStatus()
    }
    quit tStatus
}

ClassMethod GetPrimaryExtensionClass() As %String [ SqlProc ]
{
    quit $get(@..#PRIMARYEXTENSIONGBL)
}

ClassMethod GetSubExtensionClasses() As %List [ SqlProc ]
{
    set tSubExts = $get(@..#SUBEXTENSIONGBL)
    set tPrimaryExt = ..GetPrimaryExtensionClass()
    if (tPrimaryExt '= "") && '$listfind(tSubExts,tPrimaryExt) {
        set tSubExts = $listbuild(tPrimaryExt)_tSubExts
    }
    quit tSubExts
}

Method GetPrimaryExtension(pInternalName As %String = "") As %Studio.Extension.Base
{
    if (pInternalName '= "") && ($length(pInternalName,",") = 1) {
        set $namespace = ..FindNamespaceForInternalName(pInternalName)
    }
    if ($namespace '= ..Namespace) {
        quit ..GetCurrentNamespaceExtension()
    }
    quit ..SubExtensions.GetAt(..GetPrimaryExtensionClass())
}

Method GetSubExtension(pClassName As %String) As %Studio.Extension.Base
{
    quit ..SubExtensions.GetAt(pClassName)
}

Method GetMenuExtension(
	pMenuID As %String,
	pInternalName As %String = "") As %Studio.Extension.Base
{
    set tSettings = ##class(%IPM.ExtensionBase.UniversalSettings).%Get(.tSC)
    if $$$ISOK(tSC) && tSettings.MappedSourceControl {
        set tCache = ##class(%IPM.ExtensionBase.ResourceMappingCache).%Get()
        if (pInternalName '= "") && ($length(pInternalName,",") = 1) {
            set tSourceNamespace = ..FindNamespaceForInternalName(pInternalName)
            if (tSourceNamespace '= ..Namespace) {
                set tMenuName = $piece(pMenuID,",")
                try {
                    set $namespace = tSourceNamespace
                    if '$data(tCache.MenuMap(tSourceNamespace,tMenuName),tPresent) {
                        set tOtherNSExtension = ..GetCurrentNamespaceExtension()
                        set tCache.MenuMap(tSourceNamespace,tMenuName) = 0

                        // If tOtherNSExtension defines the menu item in question...
                        set tCheckItemResult = $method(tOtherNSExtension,"MainMenusFunc",$classname(tOtherNSExtension))
                        if (tCheckItemResult.%SQLCODE < 0) {
                            throw ##class(%Exception.SQL).CreateFromSQLCODE(tCheckItemResult.%SQLCODe,tCheckItemResult.%Message)
                        }
                        while tCheckItemResult.%Next(.tSC) {
                            $$$ThrowOnError(tSC)
                            if (tCheckItemResult.%Get("Name") = tMenuName) {
                                set tCache.MenuMap(tSourceNamespace,tMenuName) = 1
                            }
                        }
                        $$$ThrowOnError(tSC)
                    } elseif (tPresent) {
                        // Intentionally stays in tSourceNamespace
                        return ..GetCurrentNamespaceExtension()
                    }
                } catch e {
                    set tSC = e.AsStatus()
                    write !,"Error checking Studio extension menu item in ",tSourceNamespace,": ",$system.Status.GetErrorText(tSC)
                }
                set $namespace = ..Namespace
            }
        }
    }
    quit ..GetSubExtension(..MenuMap.GetAt($piece(pMenuID,",")))
}

Method MapMenus(pSourceClass As %String) As %Status [ Private ]
{
    set tStatus = $$$OK
    try {
        set tStmt = ##class(%SQL.Statement).%New()
        set tStatus = tStmt.%PrepareClassQuery(pSourceClass,"MainMenus")
        $$$ThrowOnError(tStatus)
        set tResult = tStmt.%Execute(pSourceClass)
        if (tResult.%SQLCODE < 0) {
            set tStatus = $$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message)
            quit
        }
        while tResult.%Next(.tStatus) {
            set tStatus = ..MenuMap.SetAt(pSourceClass,tResult.%Get("Name"))
        }
        $$$ThrowOnError(tStatus)
    } catch e {
        set tStatus = e.AsStatus()
    }
    quit tStatus
}

Method ForEachExtension(
	pMethodName As %String,
	pArgs...) As %Status
{
    set tStatus = $$$OK
    try {
        set tKey = ""
        for {
            set tExt = ..SubExtensions.GetNext(.tKey)
            if (tKey = "") {
                quit
            }
            set tOneSC = $method(tExt,pMethodName,pArgs...)
            set tStatus = $$$ADDSC(tStatus,tOneSC)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tStatus
}

ClassMethod GetCurrentNamespaceExtension() As %Studio.Extension.Base
{
    new %SourceControl
    set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
    $$$ThrowOnError(tSC)
    quit %SourceControl
}

ClassMethod FindNamespaceForInternalName(pInternalName As %String) As %String
{
    set tNamespace = $namespace
    if (pInternalName = "") {
        quit tNamespace
    }

    set tSettings = ##class(%IPM.ExtensionBase.UniversalSettings).%Get(.tSC)
    if $$$ISERR(tSC) || 'tSettings.MappedSourceControl {
        quit tNamespace
    }

    set tCache = ##class(%IPM.ExtensionBase.ResourceMappingCache).%Get()
    if $data(tCache.InternalNameMap($namespace,pInternalName),tNamespace) {
        quit tNamespace
    }

    set tExternalName = ""
    set tPrimaryClass = ..GetPrimaryExtensionClass()
    if (tPrimaryClass '= "") {
        set tExternalName = $classmethod(tPrimaryClass,"ExtName",pInternalName)
    }
    if (tExternalName = "") && ($length(pInternalName,",") = 1) {
        if ##class(%Library.RoutineMgr).IsMapped(pInternalName,.tSourceDB) {
            // See if another namespace has tSourceDB as its default routine database

            // Nothing to do but ignore this status, unfortunately.
            // Could produce a ton of output if there are errors.
            set tSC = ..FindNamespaceForDatabase(tSourceDB,.tSourceNamespace)
            if $$$ISOK(tSC) {
                set tNamespace = tSourceNamespace
            }
        }
    }
    set tCache.InternalNameMap(pInternalName) = tNamespace
    quit tNamespace
}

ClassMethod FindNamespaceForDatabase(
	pDatabase As %String,
	Output pNamespace As %String) As %Status
{
    set tCache = ##class(%IPM.ExtensionBase.ResourceMappingCache).%Get()
    new $namespace
    set tInitNamespace = $namespace
    set pNamespace = $namespace
    set tSC = $$$OK
    try {
        if '$data(tCache.DBMap(pDatabase),pNamespace) {
            set tServer = $piece(pDatabase,"^",2)
            set tDirectory = $piece(pDatabase,"^",3)
            set $namespace = "%SYS"
            // %SYS actually has IRISSYS as the routines DB; switch that out for things mapped to IRISLIB
            // so that %SYS source control is used for % classes in IRISLIB.
            set tQuery = "select Namespace from Config.Namespaces_List() "_
                " where Routines = ( "_
                "	select CASE Name when 'IRISLIB' then 'IRISSYS' else Name end "_
                "	from Config.Databases_List() "_
                "	where "_$case(tServer,"":"Server is null",:"Server = ?")_
                "	and %SQLUPPER(Directory) = %SQLUPPER(?))"
            if (tServer '= "") {
                set tArgs($increment(tArgs)) = tServer
            }
            set tArgs($increment(tArgs)) = tDirectory
            set tResult = ##class(%SQL.Statement).%ExecDirect(,tQuery,tArgs...)
            if (tResult.%SQLCODE < 0) {
                throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE, tResult.%Message)
            }
            while tResult.%Next(.tSC) {
                $$$ThrowOnError(tSC)
                set tNamespace = tResult.%Get("Namespace")
                // In case there are multiple namespaces with the same default code DB, use the
                // first one that has a namespace-specific Studio extension defined.
                // This looks at the global directly rather than using %Studio.SourceControl.Interface:SourceControlClassGet
                // because that might the instance-wide source control class (which could be used to automatically enable
                // this source control class for all namespaces, defeating the purpose of looking for the first NS with
                // source control enabled more specifically)
                if ($get(^|tNamespace|oddStudioMenu("00-SourceControlClass")) '= "") {
                    set pNamespace = tNamespace
                    quit
                }
            }
            $$$ThrowOnError(tSC)

            // NOTE: If no namespace has the given DB as the default routine DB,
            // this will store the original namespace as the one to map to
            set tCache.DBMap(pDatabase) = pNamespace
        }
    } catch e {
        set tSC = e.AsStatus()
        set pNamespace = tInitNamespace
    }
    quit tSC
}

}
