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
Property Namespace As %String [ InitialExpression = {$Namespace} ];

/// Cache of information related to mapping of resources across namespaces
Property ResourceMappingCache As %IPM.ExtensionBase.ResourceMappingCache [ InitialExpression = {##class(%IPM.ExtensionBase.ResourceMappingCache).%Get()} ];

Parameter PRIMARYEXTENSIONGBL = {"^SYS(""SourceControl"",""%IPM.ExtensionBase.Composite"",""PrimaryExtensionClass"")"};

Parameter SUBEXTENSIONGBL = {"^SYS(""SourceControl"",""%IPM.ExtensionBase.Composite"",""SubExtensionClasses"")"};

/// This just calls the <method>Login</method> to perform an initialisation.
/// Note that this is called by Studio automatically via the <class>%Studio.SourceControl.Interface</class>
/// class, do not call %New directly.
Method %OnNew(initval As %String) As %Status [ Final ]
{
	Set tStatus = $$$OK
	Try {
		Set ..Username=$listget(initval)
		Set ..MainJob=$listget(initval,3),..StudioVersion=$listget(initval,4)
		Set tClasses = ..GetSubExtensionClasses()
		Set tPtr = 0
		While $ListNext(tClasses,tPtr,tClassName) {
			Set tExt = $ClassMethod(tClassName,"%New",initval)
			If '$IsObject(tExt) {
				Set tStatus = $Get(%objlasterror,$$$ERROR($$$GeneralError,"Could not create new extension object of type "_tClassName))
				Quit
			}
			Set tStatus = ..SubExtensions.SetAt(tExt,tClassName)
			$$$ThrowOnError(tStatus)
			Set tStatus = ..MapMenus(tClassName)
			$$$ThrowOnError(tStatus)
		}
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

ClassMethod SetExtensionClasses(pPrimaryClassName As %String, pSubExtensionClassNames As %List) As %Status
{
	Set tStatus = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		TSTART
		Set tStatus = ..SetPrimaryExtensionClass(pPrimaryClassName)
		$$$ThrowOnError(tStatus)
		Set tStatus = ..SetSubExtensionClasses(pSubExtensionClassNames)
		$$$ThrowOnError(tStatus)
		TCOMMIT
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tStatus
}

ClassMethod SetPrimaryExtensionClass(pClassName As %String) As %Status
{
	Set tStatus = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		If '##class(%Library.ClassDefinition).%ExistsId(pClassName) {
			Quit
		}
		If '$ClassMethod(pClassName,"%Extends","%Studio.Extension.Base") {
			Set tStatus = $$$ERROR($$$GeneralError,"Class '"_pClassName_"' does not extend %Studio.Extension.Base")
			Quit
		}
		TSTART
		If '$ListFind($Get(@..#SUBEXTENSIONGBL),pClassName) {
			Set @..#SUBEXTENSIONGBL = $ListBuild(pClassName)_$Get(@..#SUBEXTENSIONGBL)
		}
		Set @..#PRIMARYEXTENSIONGBL = pClassName
		TCOMMIT
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tStatus
}

ClassMethod SetSubExtensionClasses(pClassNames As %List) As %Status
{
	Set tStatus = $$$OK
	Try {
		Set tClassNames = ""
		Set tPrimaryExtension = ..GetPrimaryExtensionClass()
		If (tPrimaryExtension '= "") {
			Set tClassNames = $ListBuild(tPrimaryExtension)
		}
		Set tPtr = 0
		While $ListNext(pClassNames,tPtr,tClassName) {
			If ($Get(tClassName) = "") {
				Continue
			}
			If '##class(%Library.ClassDefinition).%ExistsId(tClassName) {
				Continue
			}
			If '$ClassMethod(tClassName,"%Extends","%Studio.Extension.Base") {
				Set tStatus = $$$ERROR($$$GeneralError,"Class '"_tClassName_"' does not extend %Studio.Extension.Base")
				Quit
			}
			If '$Data(tClassNames(tClassName)) {
				Set tClassNames = tClassNames_$ListBuild(tClassName)
				Set tClassNames(tClassName) = ""
			}
		}
		$$$ThrowOnError(tStatus)
		Set @..#SUBEXTENSIONGBL = pClassNames
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

ClassMethod GetPrimaryExtensionClass() As %String [ SqlProc ]
{
	Quit $Get(@..#PRIMARYEXTENSIONGBL)
}

ClassMethod GetSubExtensionClasses() As %List [ SqlProc ]
{
	Set tSubExts = $Get(@..#SUBEXTENSIONGBL)
	Set tPrimaryExt = ..GetPrimaryExtensionClass()
	If (tPrimaryExt '= "") && '$ListFind(tSubExts,tPrimaryExt) {
		Set tSubExts = $ListBuild(tPrimaryExt)_tSubExts
	}
	Quit tSubExts
}

Method GetPrimaryExtension(pInternalName As %String = "") As %Studio.Extension.Base
{
	If (pInternalName '= "") && ($Length(pInternalName,",") = 1) {
		Set $Namespace = ..FindNamespaceForInternalName(pInternalName)
	}
	If ($Namespace '= ..Namespace) {
		Quit ..GetCurrentNamespaceExtension()
	}
	Quit ..SubExtensions.GetAt(..GetPrimaryExtensionClass())
}

Method GetSubExtension(pClassName As %String) As %Studio.Extension.Base
{
	Quit ..SubExtensions.GetAt(pClassName)
}

Method GetMenuExtension(pMenuID As %String, pInternalName As %String = "") As %Studio.Extension.Base
{
	Set tSettings = ##class(%IPM.ExtensionBase.UniversalSettings).%Get(.tSC)
	If $$$ISOK(tSC) && tSettings.MappedSourceControl {
		Set tCache = ##class(%IPM.ExtensionBase.ResourceMappingCache).%Get()
		If (pInternalName '= "") && ($Length(pInternalName,",") = 1) {
			Set tSourceNamespace = ..FindNamespaceForInternalName(pInternalName)
			If (tSourceNamespace '= ..Namespace) {
				Set tMenuName = $Piece(pMenuID,",")
				Try {
					Set $Namespace = tSourceNamespace
					If '$Data(tCache.MenuMap(tSourceNamespace,tMenuName),tPresent) {
						Set tOtherNSExtension = ..GetCurrentNamespaceExtension()
						Set tCache.MenuMap(tSourceNamespace,tMenuName) = 0
						
						// If tOtherNSExtension defines the menu item in question...
						Set tCheckItemResult = $Method(tOtherNSExtension,"MainMenusFunc",$ClassName(tOtherNSExtension))
						If (tCheckItemResult.%SQLCODE < 0) {
							Throw ##class(%Exception.SQL).CreateFromSQLCODE(tCheckItemResult.%SQLCODe,tCheckItemResult.%Message)
						}
						While tCheckItemResult.%Next(.tSC) {
							$$$ThrowOnError(tSC)
							If (tCheckItemResult.%Get("Name") = tMenuName) {
								Set tCache.MenuMap(tSourceNamespace,tMenuName) = 1
							}
						}
						$$$ThrowOnError(tSC)
					} ElseIf (tPresent) {
						// Intentionally stays in tSourceNamespace
						Return ..GetCurrentNamespaceExtension()
					}
				} Catch e {
					Set tSC = e.AsStatus()
					Write !,"Error checking Studio extension menu item in ",tSourceNamespace,": ",$System.Status.GetErrorText(tSC)
				}
				Set $Namespace = ..Namespace
			}
		}
	}
	Quit ..GetSubExtension(..MenuMap.GetAt($Piece(pMenuID,",")))
}

Method MapMenus(pSourceClass As %String) As %Status [ Private ]
{
	Set tStatus = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Set tStatus = tStmt.%PrepareClassQuery(pSourceClass,"MainMenus")
		$$$ThrowOnError(tStatus)
		Set tResult = tStmt.%Execute(pSourceClass)
		If (tResult.%SQLCODE < 0) {
			Set tStatus = $$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message)
			Quit
		}
		While tResult.%Next(.tStatus) {
			Set tStatus = ..MenuMap.SetAt(pSourceClass,tResult.%Get("Name"))
		}
		$$$ThrowOnError(tStatus)
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

Method ForEachExtension(pMethodName As %String, pArgs...) As %Status
{
	Set tStatus = $$$OK
	Try {
		Set tKey = ""
		For {
			Set tExt = ..SubExtensions.GetNext(.tKey)
			If (tKey = "") {
				Quit
			}
			Set tOneSC = $Method(tExt,pMethodName,pArgs...)
			Set tStatus = $$$ADDSC(tStatus,tOneSC)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tStatus
}

ClassMethod GetCurrentNamespaceExtension() As %Studio.Extension.Base
{
	New %SourceControl
	Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
	$$$ThrowOnError(tSC)
	Quit %SourceControl
}

ClassMethod FindNamespaceForInternalName(pInternalName As %String) As %String
{
	Set tNamespace = $Namespace
	If (pInternalName = "") {
		Quit tNamespace
	}
	
	Set tSettings = ##class(%IPM.ExtensionBase.UniversalSettings).%Get(.tSC)
	If $$$ISERR(tSC) || 'tSettings.MappedSourceControl {
		Quit tNamespace
	}
	
	Set tCache = ##class(%IPM.ExtensionBase.ResourceMappingCache).%Get()
	If $Data(tCache.InternalNameMap($Namespace,pInternalName),tNamespace) {
		Quit tNamespace
	}
	
	Set tExternalName = ""
	Set tPrimaryClass = ..GetPrimaryExtensionClass()
	If (tPrimaryClass '= "") {
		Set tExternalName = $ClassMethod(tPrimaryClass,"ExtName",pInternalName)
	}
	If (tExternalName = "") && ($Length(pInternalName,",") = 1) {
		If ##class(%Library.RoutineMgr).IsMapped(pInternalName,.tSourceDB) {
			// See if another namespace has tSourceDB as its default routine database
			
			// Nothing to do but ignore this status, unfortunately.
			// Could produce a ton of output if there are errors.
			Set tSC = ..FindNamespaceForDatabase(tSourceDB,.tSourceNamespace)
			If $$$ISOK(tSC) {
				Set tNamespace = tSourceNamespace
			}
		}
	}
	Set tCache.InternalNameMap(pInternalName) = tNamespace
	Quit tNamespace
}

ClassMethod FindNamespaceForDatabase(pDatabase As %String, Output pNamespace As %String) As %Status
{
	Set tCache = ##class(%IPM.ExtensionBase.ResourceMappingCache).%Get()
	New $Namespace
	Set tInitNamespace = $Namespace
	Set pNamespace = $Namespace
	Set tSC = $$$OK
	Try {
		If '$Data(tCache.DBMap(pDatabase),pNamespace) {
			Set tServer = $Piece(pDatabase,"^",2)
			Set tDirectory = $Piece(pDatabase,"^",3)
			Set $Namespace = "%SYS"
			// %SYS actually has IRISSYS as the routines DB; switch that out for things mapped to IRISLIB
			// so that %SYS source control is used for % classes in IRISLIB.
			Set tQuery = "select Namespace from Config.Namespaces_List() "_
				" where Routines = ( "_
				"	select CASE Name when 'IRISLIB' then 'IRISSYS' else Name end "_
				"	from Config.Databases_List() "_
				"	where "_$Case(tServer,"":"Server is null",:"Server = ?")_
				"	and %SQLUPPER(Directory) = %SQLUPPER(?))"
			If (tServer '= "") {
				Set tArgs($i(tArgs)) = tServer
			}
			Set tArgs($i(tArgs)) = tDirectory
			Set tResult = ##class(%SQL.Statement).%ExecDirect(,tQuery,tArgs...)
			If (tResult.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE, tResult.%Message)
			}
			While tResult.%Next(.tSC) {
				$$$ThrowOnError(tSC)
				Set tNamespace = tResult.%Get("Namespace")
				// In case there are multiple namespaces with the same default code DB, use the
				// first one that has a namespace-specific Studio extension defined.
				// This looks at the global directly rather than using %Studio.SourceControl.Interface:SourceControlClassGet
				// because that might the instance-wide source control class (which could be used to automatically enable
				// this source control class for all namespaces, defeating the purpose of looking for the first NS with
				// source control enabled more specifically)
				If ($Get(^|tNamespace|oddStudioMenu("00-SourceControlClass")) '= "") {
					Set pNamespace = tNamespace
					Quit
				}
			}
			$$$ThrowOnError(tSC)
			
			// NOTE: If no namespace has the given DB as the default routine DB, 
			// this will store the original namespace as the one to map to
			Set tCache.DBMap(pDatabase) = pNamespace
		}
	} Catch e {
		Set tSC = e.AsStatus()
		Set pNamespace = tInitNamespace
	}
	Quit tSC
}

}
