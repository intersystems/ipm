Include (%occErrors, %IPM.Common)

Class %IPM.Storage.Module Extends (%Persistent, %IPM.General.ModuleInfo, %IPM.Utils.ComparisonAdaptor) [ SqlTableName = ModuleItem, StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.Module";

Parameter DOMAIN = "ZPM";

Index Name On Name [ Unique ];

Property GlobalScope As %Boolean;

Property VersionString As %String(MAXLEN = 100, XMLNAME = "Version") [ InitialExpression = "0.0.1+snapshot", Required ];

/// Does not need comparison method to be code generated because that comparing <property>VersionString</property> is good enough.
Property Version As %IPM.General.SemanticVersion(ForceCodeGenerate = 0, XMLPROJECTION = "NONE") [ Required ];

Property ExternalName As %String(MAXLEN = 255);

Index ExternalName On ExternalName [ Unique ];

Property Description As %String(MAXLEN = "");

Property Keywords As %String(MAXLEN = "");

Property Author As %IPM.Storage.ModuleAuthorInfo;

/// Typically "module" or "application", but intentionally not enforced with VALUELIST.
Property Packaging As %String [ Required ];

Property Dependencies As list Of %IPM.Storage.ModuleReference(STORAGEDEFAULT = "array");

Property LastUpdated As %TimeStamp;

Relationship Resources As %IPM.Storage.ResourceReference(XMLIO = "IN", XMLITEMNAME = "Resource", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE") [ Cardinality = children, Inverse = Module ];

/// Calculated property used for XML output of Resources relationship (in a reasonable order:
/// packages, classes, includes, globals, routines, CSP resources, then in alphabetical order within those categories).
Property CalculatedResources As list Of %IPM.Storage.ResourceReference(XMLIO = "OUT", XMLITEMNAME = "Resource", XMLNAME = "Resources", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE") [ Calculated ];

Method CalculatedResourcesGet() As %Collection.AbstractListOfObj [ CodeMode = objectgenerator ]
{
 	Set tCodeStream = %code
 	Do ##class(%IPM.Utils.CodeGeneration).BuildRelationshipSorter(tCodeStream, "Resources", "GetSortKey()")
 	Quit $$$OK
}

Relationship Mappings As %IPM.Storage.MappingReference(XMLITEMNAME = "Mapping", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE") [ Cardinality = children, Inverse = Module ];

Relationship Invokes As %IPM.Storage.InvokeReference(XMLITEMNAME = "Invoke", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE") [ Cardinality = children, Inverse = Module ];

/// Lifecycle class used by default for this module
Property LifecycleClass As %Dictionary.Classname [ InitialExpression = "%IPM.Lifecycle.Module" ];

/// Lifecycle class to use for a specific command (may be overridden from command line)
Property OverrideLifecycleClass As %Dictionary.Classname [ Transient ];

/// Defined class which can report that a module is not available for this instance/namespace
Property AvailabilityClass As %Dictionary.Classname;

Property InstallerClass As %Dictionary.Classname;

Property Lifecycle As %IPM.Lifecycle.Base(XMLPROJECTION = "NONE") [ Transient ];

Property Hash As %Binary(ForceCodeGenerate = 0, XMLPROJECTION = "NONE");

Property LastModifiedTimestamp As %TimeStamp(ForceCodeGenerate = 0, XMLPROJECTION = "NONE") [ InitialExpression = {$ZDateTime($Horolog,3)} ];

/// Root directory on the filesystem from which this module was loaded.
Property Root As %String(ForceCodeGenerate = 0, MAXLEN = "", XMLPROJECTION = "NONE");

/// Sources root, where placed any source code
Property SourcesRoot As %String(MAXLEN = 20);

Property SystemRequirements As %IPM.Storage.SystemRequirements(ForceCodeGenerate = 0);

/// Set to 1 if this module is in development mode, 0 if it is not.
Property DeveloperMode As %Boolean(ForceCodeGenerate = 0, XMLPROJECTION = "NONE");

/// Default settings - there may be serveral types of these (subclasses of ModuleSetting).
Property Defaults As list Of %IPM.Storage.ModuleSetting(CLASSNAME = 1, STORAGEDEFAULT = "array", XMLNAME = "Defaults", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE", XMLTYPECONSTRAINT = "SUBSTITUTIONGROUP");

Property AfterInstallMessage As %String(MAXLEN = "", XMLPROJECTION = "Element");

Property Deployed As %Boolean(XMLPROJECTION = "Element");

Method HaveToDeploy() As %Boolean
{
	Set deploy = 0
	Set key = ""
	For {
		Set ref = ..Resources.GetNext(.key)
		Quit:key=""
		Set deploy = +ref.Deploy
		Quit:deploy
	}
	Quit ''deploy
}

ClassMethod CheckSystemRequirements(pModuleName As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pModuleName = $$$lcase(pModuleName)
		Set tModule = ..NameOpen(pModuleName,,.tSC)
		If '$isobject(tModule) {
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Module '"_pModuleName_"' not found."))
		}
		$$$ThrowOnError(tSC)

		If ($IsObject(tModule.SystemRequirements)) {
			$$$ThrowOnError(tModule.SystemRequirements.CheckRequirements())
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Return tSC
}

Method WriteAfterInstallMessage()
{
	If ..AfterInstallMessage '= "" {
		Write !,..%Evaluate(..AfterInstallMessage),!
	}
}

/// Calls <method>%CompareTo</method> on this object and also calls it on any relationships in the class
/// specifically <property>Mappings</property> and <property>Resources</property>. <br />
Method CompareWithRelationships(pModuleObj As %IPM.Storage.Module, pIgnorePropertyList As %Library.List = "", Output pDifferingPropertyArray As %Library.List) As %Boolean
{
	Kill pDifferingPropertyArray
	Set isEqual = ..%CompareTo(pModuleObj, pIgnorePropertyList, .pDifferingPropertyArray)
	// Mappings
	If '$ListFind(pIgnorePropertyList, "Mappings") {
		Set count1 = ..Mappings.Count()
		Set count2 = pModuleObj.Mappings.Count()
		If (count1 '= count2) {
			Set pDifferingPropertyArray("Mappings") = $ListBuild(count1, count2)
		} Else {
			For i=1:1:..Mappings.Count() {
				Set item1 = ..Mappings.GetAt(i)
				Set item2 = pModuleObj.Mappings.GetAt(i)
				Set isEqual = item1.%CompareTo(item2, , .diffInfo)
				If 'isEqual {
					Merge pDifferingPropertyArray("Mappings", i) = diffInfo
				}
			}
		}
	}
	// Resources
	If '$ListFind(pIgnorePropertyList, "Resources") {
		Set count1 = ..Resources.Count()
		Set count2 = pModuleObj.Resources.Count()
		If (count1 '= count2) {
			Set pDifferingPropertyArray("Resources") = $ListBuild(count1, count2)
		} Else {
			For i=1:1:..Resources.Count() {
				Set item1 = ..Resources.GetAt(i)
				Set item2 = pModuleObj.Resources.GetAt(i)
				Set isEqual = item1.%CompareTo(item2, , .diffInfo)
				If 'isEqual {
					Merge pDifferingPropertyArray("Resources", i) = diffInfo
				}
			}
		}
	}
	Return isEqual
}

/// Returns a multidimensional array of custom phases defined by the module's invokes,
/// where the keys are the custom phase names and the values are empty strings.
/// Custom phases do not have corresponding %method implementation in the lifecycle class.
/// Return the phases in lower case for case-insensitive lookup.
Method GetCustomPhases(Output pPhases)
{
    Kill pPhases
    Set pPhases = ""
    Set key = ""
    For {
        Set tInvoke = ..Invokes.GetNext(.key)
		If key = "" {
			Quit
		}
        If (tInvoke.CustomPhase '= "") {
            Set pPhases($$$lcase(tInvoke.CustomPhase)) = tInvoke.CustomPhase
        }
    }
	For {
		Set tResource = ..Resources.GetNext(.key)
		If key = "" {
			Quit
		}
		Set tProcessor = tResource.Processor
		// %IsA() only returns true if the class is the "primary" superclass, while %Extends() works for other superclasses (such as mixins).
		If $IsObject(tProcessor) && tProcessor.%Extends("%IPM.ResourceProcessor.CustomPhaseMixin") {
			Set cp = tProcessor.CustomPhase
			If cp '= "" {
				Set pPhases($$$lcase(cp)) = cp
			}
		}
	}
}

/// Execute multiple lifecycle phases in sequence. Execution is terminated if one fails.
/// Example: $ListBuild("Clean","Test") or $ListBuild("Test","Install")
/// @API.Method
ClassMethod ExecutePhases(pModuleName As %String, pPhases As %List, pIsComplete As %Boolean = 0, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"),0)
		Set tModule = ..NameOpen(pModuleName,,.tSC)
		If '$Isobject(tModule) {
			Set tModule = ..ExternalNameOpen(pModuleName,,.tSC)
		}
		If '$Isobject(tModule) {	
			$$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Module '%1' not found.", pModuleName)))
		}
		$$$ThrowOnError(tSC)

		// Regardless of whether the module was opened by name or external name, we want to use the name for the rest of the method.
		Set pModuleName = tModule.Name
		
		// Ensure we reload and reinitialize transient properties.
		// For example, prevents reuse of a previous OverrideLifecycleClass if the module object is in memory in the caller.
		Set tSC = tModule.%Reload()
		$$$ThrowOnError(tSC)
		
		// Allow per-command customization of root directory
		// Useful primarily for non-module packaging installation
		If $Data(pParams("RootDirectory"),tRoot) {
			Set tModule.Root = tRoot
		}
		
		// Permit override of lifecycle class as either a class name or a file containing a lifecycle class (and possibly other bundled/related resources)
		If $Data(pParams("Lifecycle"),tLifecycle) && ($Get(tLifecycle) '= "") {
			If $$$comClassDefined(tLifecycle) {
				Set tModule.OverrideLifecycleClass = tLifecycle
			} ElseIf $$$comClassDefined($$$DefaultLifecyclePackageDot_tLifecycle) {
				Set tModule.OverrideLifecycleClass = $$$DefaultLifecyclePackageDot_tLifecycle
			} ElseIf ##class(%Library.File).Exists(tLifecycle) {
				Set tSC = $System.OBJ.Load(tLifecycle,"k"_$Select(tVerbose:"d",1:"-d"),,.tLoadedList)
				$$$ThrowOnError(tSC)
				Set tSC = ##class(%IPM.Utils.LegacyCompat).UpdateSuperclassAndCompile(.tLoadedList)
				$$$ThrowOnError(tSC)
				Set tLoadedList = $ListFromString(tLoadedList)
				Set tLifecycleClassFound = 0
				Set tPointer = 0
				While $ListNext(tLoadedList,tPointer,tLoadedItem) {
					Set tClass = $Piece(tLoadedItem,".cls",1,*-1)
					If (tClass '= "") && $$$comClassDefined(tClass) && $ClassMethod(tClass,"%Extends",$$$DefaultLifecyclePackageDot_"Base") {
						Set tLifecycleClassFound = 1
						Set tModule.OverrideLifecycleClass = tClass
					}
				}
				If 'tLifecycleClassFound {
					Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("File '%1' did not contain a valid lifecycle class.",tLifecycle))
					$$$ThrowStatus(tSC)
				}
			} Else {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("'%1' is neither a valid filename nor a valid lifecycle class name.",tLifecycle))
				$$$ThrowStatus(tSC)
			}
			
			// Note: this is used later if the module object is reloaded.
			Set tOverrideClass = $Classname(tModule.Lifecycle)
			If tVerbose {
				Write !,"Using lifecycle class ",tOverrideClass,"; override class is "_tModule.OverrideLifecycleClass
			}
		}
		
		Set tLifecycle = tModule.Lifecycle
  
		If pIsComplete {
			Set tPhases = tLifecycle.GetCompletePhases(pPhases)
			If ($ListFind(tPhases, "Package") && tModule.HaveToDeploy()) {
				Set tPhases = $ListBuild("PrepareDeploy") _ tPhases
			}
		} Else {
			Set tPhases = $ListBuild(##class(%IPM.Lifecycle.Base).MatchSinglePhase($LISTTOSTRING(pPhases)))
		}
		
		// Lifecycle-provided default parameters
		Do tLifecycle.GetDefaultParameters(.tParams, tPhases)
		
		// Module manifest Defaults/Parameter default parameters
		Do tModule.GetDefaultParameters(.tModuleParams)
		Merge tParams = tModuleParams
		
		// Overwrite with actual specified parameters
		Merge tParams = pParams
		
		// Move back to pParams
		Kill pParams
		Merge pParams = tParams
		
		// Report timing subject to parameter; overall timing if only one phase has yet been tracked in context
		// (e.g., set up in multithreaded load) and more than one phase is to be executed.
		Set tTiming = $Get(pParams("Timing"),0)
		Set tOverallTiming = tTiming && ($ListLength(tPhases) > 1) && ($ListLength($Get($$$ZPMHandledModules($Namespace,pModuleName))) < 2)
		
		// Subscript by namespace to handle application build and integration testing processes, which may
		// load a module in a different namespace (and call ExecutePhases there) at a lower stack level than the
		// initial call to ExecutePhases
		If '$Data($$$ZPMHandledModules($Namespace)) {
			New $$$ZPMHandledModules
		} Else {
			Set $$$ZPMHandledModules($Namespace,pModuleName) = $Get($$$ZPMHandledModules($Namespace,pModuleName))_tPhases
		}
		
		// Execute resolved phases in sequence
		Set tLifecycle.PhaseList = tPhases
		Set tPointer = 0
		Set tFullStart = $zh
		Do tModule.GetCustomPhases(.tCustomPhases)
		While $ListNext(tPhases,tPointer,tOnePhase) {
            Set tIsCustomPhase = $Data(tCustomPhases($$$lcase(tOnePhase)), tNormalizedPhaseName) # 2
			If tIsCustomPhase {
				Set tOnePhase = tNormalizedPhaseName
			}
			Set tStart = $zh
			If tOnePhase="*" {
				Kill tModule,tLifecycle
				Set tModule = ..NameOpen(pModuleName,,.tSC)
				$$$ThrowOnError(tSC)
				If ($Get(tOverrideClass) '= "") {
					Set tModule.OverrideLifecycleClass = tOverrideClass
				}
				Set tLifecycle = tModule.Lifecycle
				Set tLifecycle.PhaseList = tPhases
				Write !,"["_tModule.DisplayName_"]",$c(9),"Module object refreshed."
				Continue
			}
			
			Set tSC = $$$OK
			Try {
				Write !,"["_$Namespace_"|"_tModule.DisplayName_"]",$c(9),tOnePhase," START"
				// for the reload phase, print root from which module is being loaded
				If tOnePhase = "Reload" {
					Write " ("_tModule.Root_")"
				}
				
				// Notify source control (no-op if not configured)
				Set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnBeforePhase(tModule,tOnePhase,.pParams)
				$$$ThrowOnError(tSC)
				$$$ThrowOnError(tLifecycle.OnBeforeResourceProcessing(tOnePhase, .pParams))
				// Notify resource processors
				Set tKey = ""
				For {
					#dim tResource As %IPM.Storage.ResourceReference
					Set tResource = tModule.Resources.GetNext(.tKey)
					If (tKey = "") {
						Quit
					}
					If $IsObject(tResource.Processor) {
            			Do tResource.Processor.SetParams(.pParams)
						Set tSC = $Method(tResource.Processor,"OnBeforePhase",tOnePhase,.pParams)
						$$$ThrowOnError(tSC)
					}
				}

        #; Call Invoke Methods Before Phase
        Set tKey = ""
        For {
          Set tInvoke = tModule.Invokes.GetNext(.tKey)
          Quit:(tKey = "")
          Set tSC = tInvoke.OnBeforePhase(tOnePhase,.pParams)
          Quit:$$$ISERR(tSC)
        }
        Quit:$$$ISERR(tSC)

        If tIsCustomPhase {
            Set tKey = ""
            For {
                Set tResource = tModule.Resources.GetNext(.tKey)
                If tKey = "" {
                    Quit
                }
                Set tProcessor = tResource.Processor
                // %IsA() only returns true if the class is the "primary" superclass, while %Extends() works for other superclasses (such as mixins).
                If $IsObject(tProcessor) && tProcessor.%Extends("%IPM.ResourceProcessor.CustomPhaseMixin") {
                    $$$ThrowOnError(tProcessor.OnCustomPhase(tOnePhase, .pParams))
                }
            }
        } Else {
            // Lifecycle before / (phase) / after
            $$$ThrowOnError(tLifecycle.OnBeforePhase(tOnePhase,.pParams))
            $$$ThrowOnError($Method(tLifecycle,"%"_tOnePhase,.pParams))
            $$$ThrowOnError(tLifecycle.OnAfterPhase(tOnePhase,.pParams))
        }

        #; Call Invoke Methods After Phase	
        Set tKey = ""
        For {
          Set tInvoke = tModule.Invokes.GetNext(.tKey)
          If (tKey = "") || '$IsObject(tInvoke) {
            Quit // '$IsObject can happen reasonably after namespace changes
          }
          Set tSC = tInvoke.OnAfterPhase(tOnePhase,.pParams)
          Quit:$$$ISERR(tSC)
        }
        Quit:$$$ISERR(tSC)

				// Notify resource processors
				Set tKey=""
				For {
					Set tResource = tModule.Resources.GetNext(.tKey)
					If (tKey = "") {
						Quit
					}		
					If $IsObject(tResource.Processor) {
            Do tResource.Processor.SetParams(.pParams)
						Set tSC = $Method(tResource.Processor,"OnAfterPhase",tOnePhase,.pParams)
						$$$ThrowOnError(tSC)
					}
				}
				///Works after resource processing
				$$$ThrowOnError(tLifecycle.OnAfterResourceProcessing(tOnePhase, .pParams))
				// Notify source control (no-op if not configured)
				Set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnAfterPhase(tModule,tOnePhase,.pParams)
				$$$ThrowOnError(tSC)
			} Catch e {
				Set tSC = e.AsStatus()
			}
			
			If $$$ISERR(tSC) {
				Write !,"["_tModule.DisplayName_"]",$c(9),tOnePhase," FAILURE"
			} else {
				Write !,"["_$Namespace_"|"_tModule.DisplayName_"]",$c(9),tOnePhase," SUCCESS"
			}
			If tTiming {
				Write " ("_($zh-tStart)_" s)"
			}
			$$$ThrowOnError(tSC)
		}
		If tOverallTiming {
			Write !,"["_tModule.DisplayName_"]",$c(9),"(total time: ",($zh-tFullStart)," s)"
		}
	} catch e {
		set tSC = e.AsStatus()
	}
	If $$$ISERR(tSC),$Data(pParams("PackageDeployNamespace"),tPackageDeployNamespace),tPackageDeployNamespace'="" {
  Set $Namespace = $Get(pParams("InitNamespace"))
		Do ##class(%IPM.Utils.Build).DeleteNamespace(tPackageDeployNamespace, tVerbose)
		Kill pParams("PackageDeployNamespace"), pParams("InitNamespace")
	}
	quit tSC
}

/// Uninstalls a named module (<var>pModuleName</var>).
/// May optionally force installation (uninstalling even if required by other modules) if <var>pForce</var> is 1.
/// May optionally recurse to also uninstall dependencies that are not required by other modules if <var>pRecurse</var> is 1.
/// If both <var>pForce</var> and <var>pRecurse</var> are 1, then dependencies will also be uninstalled forcibly.
/// @API.Method
ClassMethod Uninstall(pModuleName As %String, pForce As %Boolean = 0, pRecurse As %Boolean = 0, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Merge tParams = pParams
		Set tParams("Clean","Level") = 1 // Simulate clean of module as dependency.
		Set tParams("Clean","Force") = pForce
		Set tParams("Clean","Recurse") = pRecurse
		Set tSC = ##class(%IPM.Storage.Module).ExecutePhases(pModuleName,$ListBuild("Clean"),,.tParams)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method GetNamespaceConfig(ByRef pCheckedModules) As %IPM.Storage.ModuleSetting.NamespaceConfig
{
	Set tNSConfig = ##class(%IPM.Storage.ModuleSetting.NamespaceConfig).%New()
	
	// See if this module has any settings.
	Set tCount = ..Defaults.Count()
	For tDefaultIndex = 1:1:tCount {
		Set tDefault = ..Defaults.GetAt(tDefaultIndex)
		If (tDefault.%IsA("%IPM.Storage.ModuleSetting.NamespaceConfig")) {
			Set tNSConfig = tDefault
			Quit
		}
	}
	
	// Recursively merge in settings from installed dependencies.
	Set tDependencyKey = ""
	For {
		#dim tDependency As %IPM.Storage.ModuleReference
		Set tDependency = ..Dependencies.GetNext(.tDependencyKey)
		If (tDependencyKey = "") {
			Quit
		}
		
		If $Data(pCheckedModules(tDependency.Name)) {
			Continue
		}
		Set pCheckedModules(tDependency.Name) = ""
		
		// If installed...
		If ..NameExists(tDependency.Name,.tID) {
			Set tModule = ..%OpenId(tID,,.tSC)
			$$$ThrowOnError(tSC)
			
			Do tNSConfig.MergeFrom(tModule.GetNamespaceConfig(.pCheckedModules))
		}
	}
	Quit tNSConfig
}

Method GetDefaultParameters(Output pParams)
{
	Set tReferenceLifecycle = $ClassName(..Lifecycle)
	Set tDefaultKey = ""
	For {
		Set tDefault = ..Defaults.GetNext(.tDefaultKey)
		If (tDefaultKey = "") {
			Quit
		}
		If tDefault.%IsA("%IPM.Storage.ModuleSetting.Parameter") {
			#dim tDefault As %IPM.Storage.ModuleSetting.Parameter
			
			// Filter out defaults for other lifecycle classes
			If (tDefault.LifecycleClass '= "") {
				If '((tDefault.LifecycleClass = tReferenceLifecycle) || ($$$DefaultLifecyclePackageDot_tDefault.LifecycleClass = tReferenceLifecycle)) {
					Continue
				}
			}
			
			// Convert "."-delimited pieces to subscripts in pParams
			Set tPieces = $ListFromString(tDefault.Name,".")
			Set tValue = tDefault.Value
			For tSubscript=$ListLength(tPieces):-1:1 {
				Kill tData
				Merge tData($ListGet(tPieces,tSubscript)) = tValue
				Kill tValue
				Merge tValue = tData
			}
			Merge pParams = tValue
		}
	}
}

/// Returns whether pScope is in the list of pPhases <br />
ClassMethod HasScope(pPhases As %List, pScope As %String) [ Private ]
{
	If (pScope = "") {
		Quit 1
	}
	Set tPhases = $zcvt(pPhases,"L")
	Quit $ListFind(tPhases,pScope)
}

Method LoadDependencies(pPhaseList As %List, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		
		If '$Data(pParams("qstruct")) {
			Set qstruct = "ck"_$Select(tVerbose:"d",1:"-d")
		} Else {
			Merge qstruct = pParams("qstruct")
		}
		
		// Resolve and validate dependencies
		Set tReloadSnapshots = +$Get(pParams("UpdateSnapshots"))
		Set tPermitDowngrade = +$Get(pParams("PermitDowngrade"))
		Set tSC = ..BuildDependencyGraph(.tDependencyGraph,,tReloadSnapshots,.qstruct,pPhaseList,,,,,,tPermitDowngrade)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If $Data(tDependencyGraph) {
			Set tOptimizeInstalled = 'tReloadSnapshots
			Write:tVerbose !,"Dependencies:"
			Set tModuleLoop = ""
			For {
				Set tModuleLoop = $Order(tDependencyGraph(tModuleLoop),1,tValue)
				Quit:tModuleLoop=""
				
				If (tOptimizeInstalled) && '$Data($$$ZPMHandledModules($Namespace,tModuleLoop)) {
					// Optimize for exact version matches that are already installed.
					If ##class(%IPM.Storage.Module).NameExists(tModuleLoop) {
						Set tMod = ##class(%IPM.Storage.Module).NameOpen(tModuleLoop,,.tSC)
						$$$ThrowOnError(tSC)
						If (tMod.VersionString = $ListGet(tValue,3)) {
							Set $List(tValue,2) = ""
							Set $List(tDependencyGraph(tModuleLoop),2) = ""
						}
					}
				}
				
				Set tServer = $Case($ListGet(tValue,2),"":" (installed)",:" @ "_$ListGet(tValue,2))
				Write:tVerbose !,tModuleLoop," ",$ListGet(tValue,3),tServer
			}
		
			// Download dependencies.
			Kill tParams
			Merge tParams("qstruct") = qstruct
			Merge tParams = pParams
			Set tSC = ##class(%IPM.Utils.Module).LoadDependencies(.tDependencyGraph,.tParams)
			If $$$ISERR(tSC) { Quit }
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method BuildDependencyGraph(ByRef pDependencyGraph, pDepth As %Integer = 1, pForceSnapshotReload As %Boolean = 0, ByRef qstruct, pPhases As %String = "", ByRef pSubModules, pPass As %Integer = 1, pModulePath As %List = {$ListBuild(..Name)}, pIgnoreInstalledModules As %Boolean = 0, pKnownDependencies As %List = {..GetKnownDependencies(..Name)}, pPermitDowngrade As %Boolean = 0, pCheckNestedScoped As %Boolean = 0, ByRef pSearchList, pIncludeDisplayName As %Boolean = 0) As %Status
{
	#define EXACT 1
	#define FUZZY 2
	#define SCOPE "Scope"
	
	Set tSC = $$$OK
	Try {
		Kill tSubModules
		// Create an instance of the repository manager singleton (or get the existing one)
		// This makes it available at lower stack levels, which helps
		// to avoid significant duplicate work in dependency resolution.
		Set tRepositoryManager = ##class(%IPM.Repo.Manager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		// Disregard violation of dependencies of pending modules
		Set tInstallContext = ##class(%IPM.General.InstallContext).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		// May want to pass phases to subsequent calls
		Set tPhases = $Case(pCheckNestedScoped, 1: pPhases, : "")
		For i=1:1:..Dependencies.Count() {
			#dim tDep As %IPM.Storage.ModuleReference
			Set tDep = ..Dependencies.GetAt(i)
			Set tModulePath = pModulePath
			If '..HasScope(pPhases,tDep.Scope) {
				Continue
			} ElseIf (tDep.Scope '= "") && (pModulePath = $ListBuild(..Name)) {
				// Exclude the root module from cyclic dependency checking if the dependency is scoped.
				Set tModulePath = ""
			}
			
			// Ensure this dependency is not an ancestor in the chain of dependencies getting to this point
			If $ListFind(tModulePath,tDep.Name) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Cyclic dependency detected in module '%1': %2",..Name,$ListToString(tModulePath_$ListBuild(tDep.Name)," -> ")))
				Quit
			}
			
			// Test whether dependency version is a valid semantic version. These are handled in the first pass only.
			// Other cases are handled in the second pass only.
			Set tIsExactVersion = +##class(%IPM.General.SemanticVersion).IsValid(tDep.VersionString) kill %objlasterror
			If ((pPass = $$$EXACT) && 'tIsExactVersion) || ((pPass = $$$FUZZY) && tIsExactVersion) {
				Continue
			}
			
			// Build cumulative version requirement string
			#dim tSearchExpr As %IPM.General.SemanticVersionExpression
			Set tSearchExpr = tDep.Version.%ConstructClone(1)
			Set tConstraintList = $ListBuild(..Name_": "_tDep.VersionString)
			Set tSourcePath = ""
			For {
				Set tSourcePath = $Order(pDependencyGraph(tDep.Name,tSourcePath),1,tOtherReq)
				Quit:tSourcePath=""
				
				Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tOtherReq,.tExpr)
				If $$$ISERR(tSC) {
					Quit
				}
				Set tSearchExpr = tSearchExpr.And(tExpr)
				Set tConstraintList = tConstraintList_$ListBuild(tSourcePath_": "_tOtherReq)
			}
			If $$$ISERR(tSC) {
				Quit
			}
			
			If 'pIgnoreInstalledModules {
				// Also apply requirements presented by other installed modules, with the exception of those that are:
				//	* Known as dependencies of the root module being installed (and thus eligible for upgrade)
				//	* Pending (re)installation
				//  * Already in the dependency graph
				Set tOtherDeps = pKnownDependencies_tInstallContext.GetPendingModuleList()
				Set tExistingDepKey = ""
				For {
					Set tExistingDepKey = $Order(pDependencyGraph(tExistingDepKey))
					If (tExistingDepKey = "") {
						Quit
					}
					Set tOtherDeps = tOtherDeps_$ListBuild(tExistingDepKey)
				}
				
				Set tSC = ##class(%IPM.Utils.Module).GetRequiredVersionExpression(tDep.Name,tOtherDeps,.tInstalledReqExpr,.tInstalledConstraintList)
				If $$$ISERR(tSC) {
					Quit
				}
				Set tSearchExpr = tSearchExpr.And(tInstalledReqExpr)
				Set tConstraintList = tConstraintList_tInstalledConstraintList
			}
			
			// See if we already have a version that satisfies the dependency:
			Set tDepFound = $Data(pDependencyGraph(tDep.Name),tDepInfo)
			Set tPreviousDepth = 0
			Set tServerName = ""
			Set tVersion = ""
			If tDepFound {
				Set $ListBuild(tPreviousDepth,tServerName,tVersion) = tDepInfo
			}
			
			// See if a satisfactory version already exists in the current namespace.
			// If it does, always use it
			// Particularly relevant for compilation of dependencies
			// The "clean" phase can be used to bypass this (by removing modules from the current namespace)
			// Forcing an update from disk can also override this, although we ensure that the same module is
			// not loaded multiple times in a given operation.
			Set tForceSnapshotReload = pForceSnapshotReload
			If tForceSnapshotReload && $Data($$$ZPMHandledModules($Namespace,tDep.Name),tHandled) {
				If $ListFind(tHandled,"Activate") {
					// If we have already activated the given module, don't do so again.
					Set tForceSnapshotReload = 0
				}
			}
			If ('pIgnoreInstalledModules) && ..NameExists(tDep.Name) {
				Set tLocalObj = ..NameOpen(tDep.Name,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
				
				Set tInstalledVersionValid = tLocalObj.Version.Satisfies(tSearchExpr) && ((tVersion = "") || (tVersion = tLocalObj.VersionString))
				If tInstalledVersionValid && '(tLocalObj.Version.IsSnapshot() && tForceSnapshotReload) {
					Set tLocalMod = 1
					Set tDepth = $Select(tPreviousDepth=0:pDepth,tPreviousDepth>pDepth:tPreviousDepth,1:pDepth)
					Set pDependencyGraph(tDep.Name) = $ListBuild(pDepth,"",tLocalObj.VersionString)
					If (pIncludeDisplayName) {
						Set pDependencyGraph(tDep.Name) = pDependencyGraph(tDep.Name)_$ListBuild(tDep.DisplayName)
					}
					Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
					Set pSubModules(tDepth,tDep.Name) = tLocalObj
					Set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope
					Continue
				}
				
				If 'pPermitDowngrade {
					// Add a minimum of the currently-installed version as a constraint.
					Set tRangeString = ">="_tLocalObj.VersionString
					Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tRangeString,.tCurrentlyInstalledExpr)
					$$$ThrowOnError(tSC)
					Set tSearchExpr = tSearchExpr.And(tCurrentlyInstalledExpr)
					Set tConstraintList = tConstraintList_$ListBuild(tLocalObj.Name_": "_tRangeString_" (currently installed, downgrade not permitted)")
				}
			}
			
			Set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
			Set tSearchCriteria.Name = tDep.Name
			Set searchExprStr = tSearchExpr.ToString()
			Set tSearchCriteria.VersionExpression = searchExprStr
			// If the dependencyname has not been visited, actually do the search;
			// otherwise, see if the stored search expression contains the current search expression or the other way
			// If former, then use the stored qualifiedref; if latter, then need to do new search
			
			If ($Data(pSearchList(tDep.Name)) '= 10) {
				Set tSC = tRepositoryManager.SearchRepositoriesForModule(tSearchCriteria,.tQualifiedReferences,pForceSnapshotReload)
				If $$$ISERR(tSC) {
					Quit
				}
				Set pSearchList(tDep.Name, tSearchExpr) = tQualifiedReferences
				Set pSearchList(tDep.Name, tSearchExpr, "SearchString") = searchExprStr
			} Else {
				Set key = ""
				While 1 {
					Set key = $Order(pSearchList(tDep.Name, key))
					If (key = "") {
						Quit
					}
					If (pSearchList(tDep.Name, key, "SearchString") = searchExprStr) {
						Set tQualifiedReferences = pSearchList(tDep.Name, key)
						Quit
					}
				}
				If (key = "") {
					// no satisfied searchExpr found
					Set tSC = tRepositoryManager.SearchRepositoriesForModule(tSearchCriteria,.tQualifiedReferences,pForceSnapshotReload)
					If $$$ISERR(tSC) {
						Quit
					}
					Set pSearchList(tDep.Name, tSearchExpr) = tQualifiedReferences
					Set pSearchList(tDep.Name, tSearchExpr, "SearchString") = searchExprStr
				}
			}
			If (tQualifiedReferences.Count() = 0) {
				Set tMsg = $$$FormatText("Could not find satisfactory version of %1 in any repositories. Required by: %2",tDep.Name,$ListToString(tConstraintList,"; "))
				Set tSC = $$$ERROR($$$GeneralError,tMsg)
				Quit
			} Else {
				Set tResultFound = 0
				For j=1:1:tQualifiedReferences.Count() {
					Kill tDependencyGraph,tSubModules
					Merge tDependencyGraph = pDependencyGraph
					Merge tSubModules = pSubModules
					Set tQualifiedReference = tQualifiedReferences.GetAt(j)
					Set tSC = tRepositoryManager.RetrieveModuleManifest(tQualifiedReference,.tManifest)
					If $$$ISERR(tSC) {
						Quit
					}
					
					// Recursively process dependencies.
					Set tMsg = "Error reading module manifest for %1 %2 from repository %3"
					Set tOuterSC = $$$ERROR($$$GeneralError,$$$FormatText(tMsg,tQualifiedReference.Name,tQualifiedReference.VersionString,tQualifiedReference.ServerName))
					
					#dim tModule As %IPM.Storage.Module
					Set tReader = ##class(%XML.Reader).%New()
					Set tSC = tReader.OpenStream(tManifest)
					If $$$ISERR(tSC) {
						Set tSC = $System.Status.EmbedStatus(tOuterSC,tSC)
						Quit
					}
					Do tReader.Correlate("Module","%IPM.Storage.Module")
					Do tReader.Next(.tModule,.tSC)
					If $$$ISERR(tSC) {
						Set tSC = $System.Status.EmbedStatus(tOuterSC,tSC)
						Quit
					}
					
					Set tDepth = $Select(tPreviousDepth=0:pDepth,tPreviousDepth>pDepth:tPreviousDepth,1:pDepth)
					
					If (pPass = $$$EXACT) {	
						Set pDependencyGraph(tDep.Name) = $ListBuild(pDepth, tQualifiedReference.ServerName, tModule.VersionString, tQualifiedReference.Deployed, tQualifiedReference.PlatformVersion)
						If (pIncludeDisplayName) {
							Set pDependencyGraph(tDep.Name) = pDependencyGraph(tDep.Name)_$ListBuild(tDep.DisplayName)
						}
						Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
						Set pSubModules(tDepth,tDep.Name) = tModule
						Set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope
				
						// If we have an exact match, attempt to resolve exact dependencies recursively.
						Set tSC = tModule.BuildDependencyGraph(.pDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,tPhases,.pSubModules,,tModulePath_$ListBuild(tDep.Name),pIgnoreInstalledModules,pKnownDependencies,pPermitDowngrade,,.pSearchList,pIncludeDisplayName)
						
						// Failure to resolve any of these dependencies is an immediate failure, and can be descriptive.
						If $$$ISERR(tSC) {
							Quit
						}
						
						Set tResultFound = 1
						Quit
					}
					
					If (pPass = $$$FUZZY) {	
						Set tDependencyGraph(tDep.Name) = $ListBuild(tDepth,tQualifiedReference.ServerName,tModule.VersionString)
						If (pIncludeDisplayName) {
							Set tDependencyGraph(tDep.Name) = tDependencyGraph(tDep.Name)_$ListBuild(tDep.DisplayName)
						}
						Set tDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
				
						Set tSubModules(tDepth,tDep.Name) = tModule
					
						// For fuzzy version matching, preview the next graph step; move to the next version if it would lead to failure.
						// If not, update.
						Set tPossibleSC = tModule.BuildDependencyGraph(.tDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,tPhases,.tSubModules,,tModulePath_$ListBuild(tDep.Name),pIgnoreInstalledModules,pKnownDependencies,pPermitDowngrade,,.pSearchList,pIncludeDisplayName)
						If $$$ISOK(tPossibleSC) {
							// We have a match - let's go with it. Actually dependency resolution will be done later, breadth-first.
							// TODO: Caching of results to avoid duplicate web service calls.
							Set tResultFound = 1
							Quit
						}
					}
				}
				If $$$ISERR(tSC) {
					Quit
				}
				
				If (pPass = $$$FUZZY) {
					// We don't actually care if a valid result was found.
					// There will always be something in here, it just might lead to a descriptive error later on in the case of fuzzy matching with no valid option.
					Set pDependencyGraph(tDep.Name) = $ListBuild(pDepth,tQualifiedReference.ServerName,tModule.VersionString)
					If (pIncludeDisplayName) {
						Set pDependencyGraph(tDep.Name) = pDependencyGraph(tDep.Name)_$ListBuild(tDep.DisplayName)
					}
					Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
					Set pSubModules(tDepth,tDep.Name) = tModule
					Set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope
				}
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pPass = $$$EXACT) {	
			// Call for second pass (fuzzy version matching)
			Set tSC = ..BuildDependencyGraph(.pDependencyGraph,pDepth,pForceSnapshotReload,.qstruct,pPhases,.pSubModules,$$$FUZZY,pModulePath,pIgnoreInstalledModules,pKnownDependencies,pPermitDowngrade,,.pSearchList,pIncludeDisplayName)
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		// Breadth-first dependency resolution for depth 1, pass 1.
		// Things to resolve have been accumulated in previous passes and/or will continue to be accumulated.
		If (pDepth = 1) && (pPass = $$$EXACT) {
			 While $Data(pSubModules(pDepth)) {	
				Set tModName = ""
				For {
					Set tModName = $Order(pSubModules(pDepth,tModName),1,tModule)
					Quit:tModName=""
					Set tModulePath = $Case(pSubModules(pDepth,tModName,$$$SCOPE),"":pModulePath,:"")
					Set tSC = tModule.BuildDependencyGraph(.pDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,tPhases,.pSubModules,,tModulePath_$ListBuild(tModName),pIgnoreInstalledModules,pKnownDependencies,pPermitDowngrade,,.pSearchList,pIncludeDisplayName)
					If $$$ISERR(tSC) {
						Quit
					}
				}
				If $$$ISERR(tSC) {
					Quit
				}
				Set pDepth = pDepth + 1
			}
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Ensure cyclic dependencies (possible with scopes) are removed from the graph; otherwise, not everything will be installed.
			Kill pDependencyGraph(..Name)
			Set tDependencyKey = ""
			For {
				Set tDependencyKey = $Order(pDependencyGraph(tDependencyKey))
				If (tDependencyKey = "") {
					Quit
				}
				
				Set tDependencySource = $Order(pDependencyGraph(tDependencyKey,..Name))
				If ($Piece(tDependencySource," ") = ..Name) {
					Kill pDependencyGraph(tDependencyKey,tDependencySource)
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// This method builds a list of any direct/indirect dependencies of the module named <var>pModuleName</var> in a breadth-first manner.
ClassMethod GetKnownDependencies(pModuleName As %String) As %List
{
	Set tStatement = ##class(%SQL.Statement).%New()
	$$$ThrowOnError(tStatement.%Prepare("select Dependencies_Name as ModuleName from %IPM_Storage.ModuleItem_Dependencies where ModuleItem->Name = ?"))
	
	Set tKnownDependencyList = ""
	Set tSearchList = $ListBuild(pModuleName)
	
	// For each tree level (starting out at the top level node)...
	While (tSearchList '= "") {
		Set tNewSearchList = ""
		Set tPointer = 0
		
		// Iterate over modules at the current tree level.
		While $ListNext(tSearchList,tPointer,tModule) {
			// If we have already seen the module at this level (earlier in the list), skip it.
			If $Data(tKnownDependencies(tModule)) {
				Continue
			}
			Set tKnownDependencyList = tKnownDependencyList_$ListBuild(tModule)
			Set tKnownDependencies(tModule) = ""
			
			// Find all dependencies of the module.
			Set tResult = tStatement.%Execute(tModule)
			If (tResult.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
			}
			While tResult.%Next(.tSC) {
				$$$ThrowOnError(tSC)
				If $Data(tKnownDependencies(tResult.%Get("ModuleName"))) {
					// If we have already seen the module at a higher level in the tree, skip it.
					Continue
				}
				// Flag this module so its dependencies are checked (and it is added to the list itself) in the iteration for the next tree level.
				Set tNewSearchList = tNewSearchList_$ListBuild(tResult.%Get("ModuleName"))
			}
			$$$ThrowOnError(tSC)
		}
		Set tSearchList = tNewSearchList
	}
	Quit tKnownDependencyList
}

/// Builds a module's immediate dependency graph and array of resources.<br />
/// Optionally loads uninstalled dependency modules and recurses over each module in the dependency graph.<br />
/// @Argument	pReferenceArray		Array of all module's resources (including resources that compose a resource) that contain the appropriate phase scope.<br />
/// @Argument	pLockedDependencies	Whether method should be recursively applied to the module's dependencies (true = yes).<br />
/// @Argument	pPhases				List of IPM lifecycle phases to be applied to the current module.<br />
/// @Argument	pSkipDependencies	Whether to skip loading uninstalled dependency modules.<br />
/// @Argument	pDependencyGraph 	Tree of module's dependencies.<br />
Method GetResolvedReferences(Output pReferenceArray, pLockedDependencies As %Boolean = 0, pPhases As %List = "", pSkipDependencies As %Boolean = 0, ByRef pDependencyGraph) As %Status
{
	Set tSC = $$$OK
	Try {
		If '$Data(pDependencyGraph) {
			Set tSC = ..BuildDependencyGraph(.pDependencyGraph,,,,pPhases)
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		If 'pSkipDependencies {
			Kill tParams
			Set tParams("Verbose") = 0
			Set tParams("qstruct") = "k"
			Set tSC = ##class(%IPM.Utils.Module).LoadDependencies(.pDependencyGraph,.tParams)
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		Set pReferenceArray(..Name, ..Name_".ZPM") = ""
		
		Set tKey = ""
		For {
			#dim tResource As %IPM.Storage.ResourceReference
			Set tResource = ..Resources.GetNext(.tKey)
			Quit:tKey=""
			If '..HasScope(pPhases,tResource.Scope) {
				Continue
			}
			
			kill tempArray
			Set tSC = tResource.ResolveChildren(.tempArray)
			Merge pReferenceArray(..Name) = tempArray
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		If pLockedDependencies {
			Set tModName = ""
			For {
				Set tModName = $Order(pDependencyGraph(tModName))
				Quit:tModName=""
				
				Set tModule = ##class(%IPM.Storage.Module).NameOpen(tModName,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
				
				// Don't pass along the phase
				Set pReferenceArray(tModName, tModName_".ZPM") = ..Name
				
				// pLockedDependencies=0 to avoid duplicating effort on nested dependencies;
				// this loop will already get all of them.
				Set tSC = tModule.GetResolvedReferences(.pReferenceArray,0,,1)
				If $$$ISERR(tSC) {
					Quit
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method LifecycleGet() As %IPM.Lifecycle.Base
{
	If $IsObject(r%Lifecycle) {
		Quit r%Lifecycle
	}
	For tBasis = ..OverrideLifecycleClass,..LifecycleClass {
		If (tBasis '= "") && ($Length(tBasis,".") = 1) {
			Set tLifecycleClass = $$$DefaultLifecyclePackageDot_tBasis
		} Else {
			Set tLifecycleClass = tBasis
		}
		
		If (tLifecycleClass '= "") && $$$comClassDefined(tLifecycleClass) {
			Quit
		}
	}
	If (tLifecycleClass = "") || '$$$comClassDefined(tLifecycleClass) {
		Set ..LifecycleClass = "Module"
		Set tLifecycleClass = $$$DefaultLifecyclePackageDot_..LifecycleClass
	}
	Set r%Lifecycle = $ClassMethod(tLifecycleClass,"%New",$this)
	Quit r%Lifecycle
}

Method OverrideLifecycleClassSet(pValue As %Dictionary.Classname) As %Status
{
	If (..OverrideLifecycleClass '= pValue) && $IsObject(..Lifecycle) {
		Set ..Lifecycle = ""
		Set i%OverrideLifecycleClass = pValue
	}
	Quit $$$OK
}

/// This callback method is invoked by the <METHOD>%New</METHOD> method to 
/// provide notification that a new instance of an object is being created.
/// 
/// <P>If this method returns an error then the object will not be created.
/// <p>It is passed the arguments provided in the %New call.
/// When customizing this method, override the arguments with whatever variables and types you expect to receive from %New().
/// For example, if you're going to call %New, passing 2 arguments, %OnNew's signature could be:
/// <p>Method %OnNew(dob as %Date = "", name as %Name = "") as %Status
/// If instead of returning a %Status code this returns an oref and this oref is a subclass of the current
/// class then this oref will be the one returned to the caller of %New method.
Method %OnNew() As %Status [ Private, ServerOnly = 1 ]
{
	Set ..Version = ##class(%IPM.General.SemanticVersion).FromString(i%VersionString)
  Quit $$$OK
}

/// This callback method is invoked by the <METHOD>%Open</METHOD> method to 
/// provide notification that the object specified by <VAR>oid</VAR> is being opened.
/// 
/// <P>If this method returns an error then the object will not be opened.
Method %OnOpen() As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	Try {
		// In Studio, use the existing %SourceControl object.
		// From other contexts, create a new one.
		If '$IsObject($Get(%SourceControl)) {
			New %SourceControl
			Do ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		}
		Set tExternalName = ##class(%Studio.SourceControl.Interface).ExternalName(..Name_".ZPM")
		If (tExternalName '= "") {
			Set tDirectory = ##class(%File).GetDirectory(tExternalName, 0)
			If (tDirectory '= "") {
				Set ..Root = tDirectory
			}
		}
    If ..Deployed,..DeveloperMode {
      Set ..DeveloperMode = 0
    }
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to 
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	Try {
		// Ensure packaging property is set to the correct value.
		// This validation only runs if the lifecycle class exists.
		If (..LifecycleClass '= "") && $$$comClassDefined(..LifecycleClass) {
			Set tBaseClass = "%IPM.Lifecycle.Base"
			Set legacyBaseClass = "%ZPM.PackageManager.Developer.Lifecycle.Base"
			If '$ClassMethod(..LifecycleClass,"%Extends",tBaseClass) && '$ClassMethod(..LifecycleClass,"%Extends",legacyBaseClass) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid lifecycle class '%1' - must extend %2",..LifecycleClass,tBaseClass))
				Quit
			}
			Set tPackaging = $Parameter(..LifecycleClass,"PACKAGING")
			If (..Packaging = "") {
				Set ..Packaging = tPackaging
			} ElseIf (..Packaging '= tPackaging) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Module's packaging is set to '%1', but lifecycle class '%2' has packaging '%3'.",..Packaging,..LifecycleClass,tPackaging))
				Quit
			}
		} ElseIf (..LifecycleClass = "") && (..Packaging '= "") {
      		Set ..LifecycleClass = $Case(..Packaging,"application": "Application", : "Module")
		} ElseIf (..Packaging = "") {
			// Default to "module"
			Set ..Packaging = "module"
		}

		// Can have only one NamespaceConfig module setting.
		Set tNSConfigCount = 0
		Set tDefaultCount = ..Defaults.Count()
		For tDefaultIndex=1:1:tDefaultCount {
			Set tDefault = ..Defaults.GetAt(tDefaultIndex)
			If tDefault.%IsA("%IPM.Storage.ModuleSetting.NamespaceConfig") {
				Set tNSConfigCount = tNSConfigCount + 1
			}
		}
		If (tNSConfigCount > 1) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Only one NamespaceConfig may be specified per module."))
			Quit
		}
		
		// Pre-check for uniqueness among resources (make sure there are no collisions and report descriptive errors if there are).
		// This is simpler than trying to interpret a unique index violation later, and will work in all cases where we're updating modules.
		Set tInstallContext = ##class(%IPM.General.InstallContext).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		Set tSC = $$$OK
		Set tKey = ""
		For {
			Set tResource = ..Resources.GetNext(.tKey)
			Quit:(tKey="")
			
			// If it hasn't been saved yet (to account for module renames)...
			If (tResource.%Id() = "") && (tResource.UniqueName '= "") {
				// ... see if some other resource exists with the same name.
				If ##class(%IPM.Storage.ResourceReference).ResourceNameExists(tResource.UniqueName,.tResourceId) {
					Set tOtherResource = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceId,,.tSC)
					If $$$ISERR(tSC) {
						Quit
					}
					If tInstallContext.ModuleIsPending(tOtherResource.Module.Name) {
						// %OnAddToSaveSet will correct for this condition.
						Continue
					}
					If (tResource.Name = tResource.UniqueName) {
						// Common case: classes, packages, include files, etc.
						Set tMsg = $$$FormatText("Resource '%1' is already defined as part of module '%2'; cannot also be listed in module '%3'",tResource.Name,tOtherResource.Module.Name,..Name)
					} Else {
						// Handle the case where resources with different names are uniquely identified the same way.
						Set tResourceName = tResource.Name_" ("_tResource.UniqueName_")"
						Set tMsg = $$$FormatText("Resource '%1' is already defined as part of module '%2' as '%4'; cannot also be listed in module '%3'",tResourceName,tOtherResource.Module.Name,..Name,tOtherResource.Name)
					}
					Set tSC = $$$ERROR($$$GeneralError,tMsg)
					Quit
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
		}
		Set query = "SELECT COUNT(*) AS Conflict FROM %IPM_Storage.ModuleItem WHERE Name = ? AND Name <> ?"
		Set rs = ##class(%SQL.Statement).%ExecDirect(,query, ..ExternalName, ..Name)
		If rs.%Next() && (rs.%Get("Conflict") > 0) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("External name '%1' conflicts with the real name of another module", ..ExternalName)))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// This callback method is invoked when the current object is added to the SaveSet,
/// either because %Save() was invoked on this object or on an object that references this object.
/// %OnAddToSaveSet can modify the current object. It can also add other objects to the current
/// SaveSet by invoking %AddToSaveSet or remove objects by calling %RemoveFromSaveSet.
/// 
/// <P>If this method returns an error status then %Save() will fail and the transaction
/// will be rolled back.
Method %OnAddToSaveSet(depth As %Integer = 3, insert As %Integer = 0, callcount As %Integer = 0) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	Try {
		// Ensure Version serial object is up to date.
		If (..VersionString '= ..Version.ToString()) {
			Set ..Version = ##class(%IPM.General.SemanticVersion).FromString(..VersionString)
		}
		Set tSC = ..XMLExportToStream(.tStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// See if the module definition has actually changed
		Set tHash = $System.Encryption.SHA1HashStream(tStream,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		If (..Hash '= tHash) {
			Set ..Hash = tHash
			Set ..LastModifiedTimestamp = $zdt($h,3)
		}
		
		// Deal with resources moving from a module dependent on the current module that hasn't been reloaded yet
		Set tInstallContext = ##class(%IPM.General.InstallContext).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		Set tSC = $$$OK
		Set tKey = ""
		For {
			Set tResource = ..Resources.GetNext(.tKey)
			Quit:(tKey="")
			
			// If it hasn't been saved yet (to account for module renames)...
			If (tResource.%Id() = "") && (tResource.UniqueName '= "") {
				// ... see if some other resource exists with the same name.
				If ##class(%IPM.Storage.ResourceReference).ResourceNameExists(tResource.UniqueName,.tResourceId) {
					Set tOtherResource = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceId,,.tSC)
					$$$ThrowOnError(tSC)
					
					If tInstallContext.ModuleIsPending(tOtherResource.Module.Name) {
						// Delete the resource. If the pending module still contains it, there will be an error when that module is loaded.
						Set tSC = ##class(%IPM.Storage.ResourceReference).%DeleteId(tResourceId)
						$$$ThrowOnError(tSC)
					}
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Get an instance of an XML enabled class.<br><br>
/// 
/// You may override this method to do custom processing (such as initializing
/// the object instance) before returning an instance of this class.
/// However, this method should not be called directly from user code.<br>
/// Arguments:<br>
///     document is the document with %XML.Node or macros in %xmlDOM.inc.<br>
///     nodeId is a node id of the node which defines this object.
///         An %XML.Node object may be obtained for this node using document.GetNode(nodeId)<br>
///     containerOref is the containing object instance when called from XMLImport and
///         is "" when called from %XML.Reader for Correlate'd objects.<br>
ClassMethod XMLNew(document As %XML.Document, node As %Integer, containerOref As %RegisteredObject = "") As %RegisteredObject [ ServerOnly = 1 ]
{
	// Coupled with %IPM.StudioDocument.Module to allow editing of the current module rather than matching an existing one.
	Quit $Get($$$ZPMStudioDocumentModule,..%New())
}

/// Validates the module manifest in <var>pManifest</var> - both that it can be interpreted properly as XML, and also that the module it contains (returned in <var>pModule</var>) has
/// a name and version matching the supplied <var>pModuleReference</var>.
ClassMethod ValidateStream(pManifest As %Stream.Object, pModuleReference As %IPM.Storage.QualifiedModuleInfo, Output pModule As %IPM.Storage.Module) As %Status
{
	Set pModule = $$$NULLOREF
	Set tSC = $$$OK
	Try {
		Set tModName = pModuleReference.Name
		Set tModVersion = pModuleReference.VersionString
		Set tModSource = pModuleReference.ServerName
			
		Set pModule = ##class(%IPM.Utils.Module).GetModuleObjectFromStream(pManifest, .tModuleFound)
		Set tCorrSC = $$$OK
		If tModuleFound {
			// Ensure that module name and version match.
			If (tModName '= pModule.Name) {
				Set tCorrSC = $$$ERROR($$$GeneralError,$$$FormatText("Incorrect module name in manifest: %1",pModule.Name))
			}
			If (tModVersion '= pModule.VersionString) {
				// Append the status in case neither matches.
				Set tCorrSC = $$$ADDSC(tCorrSC,$$$ERROR($$$GeneralError,$$$FormatText("Incorrect module version in manifest: %1",pModule.Name)))
			}
		} Else {
			// Treat as an error if no element is found.
			Set tCorrSC = $$$ERROR($$$GeneralError,"No root <Module> element found in manifest.")
		}
		$$$ThrowOnError(tCorrSC)
	} Catch e {
		Set pModule = $$$NULLOREF
		Set tMsg = $$$FormatText("Error parsing module manifest for '%1 %2' from repository '%3'",$Get(tModName),$Get(tModVersion),$Get(tModSource))
		Set tOuterSC = $$$ERROR($$$GeneralError,tMsg)
		Set tSC = $System.Status.EmbedStatus(tOuterSC,e.AsStatus())
	}
	Quit tSC
}

/// By default (first byref argument only), creates a Studio project containing all of the module's resources.
/// If <var>pDeployedCode</var> is non-empty, only includes code that should be deployed (if true) or not deployed (if false).
/// <var>pDefaultDeployedValue</var> specifies the default behavior for resources with the Deploy attribute left null.
/// <var>pProjectSuffix</var> is appended to the project name (which defaults to the module name, with periods replaced by underscores).
/// The project suffix may be used (for example) to distinguish between projects for deployed and undeployed code.
Method GetStudioProject(Output pProject As %Studio.Project, pDeployedCode As %Boolean = "", pDefaultDeployedValue As %Boolean = "", pProjectSuffix As %String = "") As %Status
{
	Set tSC = $$$OK
	Try {
		Set tProjectName = $Replace(..DisplayName,".","_")_$Case(pProjectSuffix,"":"",:"_"_pProjectSuffix)
		If ##class(%Studio.Project).%ExistsId(tProjectName) {
			Set pProject = ##class(%Studio.Project).%OpenId(tProjectName,,.tSC)
			$$$ThrowOnError(tSC)
		} Else {
			Set pProject = ##class(%Studio.Project).%New()
			Set pProject.Name = tProjectName
		}
		
		Do pProject.Items.Clear()
		
		If (pDeployedCode = 0) {
			// Include module manifest in project with non-deployed code. Caller will call once with pDeployedCode = 1,
			// once with pDeployedCode = 0 to get separate Studio projects; only want this in one of them.
			Do pProject.AddItem(..Name_".ZPM")
		}
		
		Set tResourceKey = ""
		For {
			#dim tResource As %IPM.Storage.ResourceReference
			Set tResource = ..Resources.GetNext(.tResourceKey)
			If (tResourceKey = "") {
				Quit
			}
			
			If (pDeployedCode '= "") {
				If (tResource.Deploy '= "") && (tResource.Deploy '= pDeployedCode) {
					Continue
				}
				If (tResource.Deploy = "") && (pDefaultDeployedValue '= pDeployedCode) {
					Continue
				}
			}

			If $IsObject(tResource.Processor) {
				Do tResource.Processor.OnGetStudioProject(pProject,.handled)
				Continue:handled
			}
			
			Kill tResourceArray
			$$$ThrowOnError(tResource.ResolveChildren(.tResourceArray))
			
			Set tChildResourceKey = ""
			For {
				Set tChildResourceKey = $Order(tResourceArray(tChildResourceKey))
				If (tChildResourceKey = "") {
					Quit
				}
				
				// Add object code for deployed items, since source is unavailable.
				$$$ThrowOnError(..AddItemToProject(pProject,tChildResourceKey))
			}
		}
		$$$ThrowOnError(pProject.%Save())
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod AddItemToProject(tProject As %Studio.Project, pResourceName As %String) As %Status [ Internal, Private ]
{
	Set tSC = $$$OK
	Try {
		Set tName = $Piece(pResourceName,".",1,*-1)
		Set tExt = $Piece(pResourceName,".",*)
		If ((tExt = "MAC") || (tExt = "INT")) && '##class(%Library.Routine).Exists(pResourceName) {
			Do tProject.AddItem(tName_".OBJ")
		} ElseIf (tExt = "CLS") {
			// If Deployed = 0 (normal) or 3 (datatype), the source is present.
			// If Deployed = 1 or 2, it is not.
			Set tHasSource = $Case($$$comClassKeyGet(tName,$$$cCLASSdeployed),1:0,2:0,:1)
			If 'tHasSource {
				Set tRoutine = ""
				For {
					Set tRoutine = $$$comClassArrayNext(tName,$$$cCLASSroutines,tRoutine)
					If (tRoutine = "") {
						Quit
					}
					Do tProject.AddItem(tRoutine_".OBJ")
				}
			} Else {
				Do tProject.AddItem(pResourceName)
			}
		} Else {
			Do tProject.AddItem(pResourceName)
		}
		$$$ThrowOnError(tProject.Check())
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Compile(ByRef qstruct As %String) As %Status
{
	Quit ..Lifecycle.Compile(.qstruct)
}

Method IsLocked() As %Boolean
{
	Quit ($ZConvert(..Version.Build,"L") '= "snapshot")
}

Method Lock() As %Status
{
	If '..IsLocked() {
		Set ..Version.Build = ""
	}
	Quit $$$OK
}

Query VersionRequirements(pOfModuleName As %String, pExcludeModuleNames As %List = "") As %SQLQuery [ SqlProc ]
{
	select distinct %exact Dependencies_VersionString As Version,%DLIST(ModuleItem->Name) As ModuleNames
	from %IPM_Storage.ModuleItem_Dependencies
	where Dependencies_Name = :pOfModuleName and
		(:pExcludeModuleNames is null or ModuleItem->Name not %INLIST :pExcludeModuleNames)
	group by Dependencies_VersionString
}

/// Evaluates an expression in a provided string. <br />
/// These special expressions are case-insensitive. <br />
/// Current valid expressions:
/// <ul>
/// 	<li>{$root} - the module's root directory </li>
/// 	<li>{name} - the name of the module </li>
/// </ul>
/// In addition to these, look at expressions supported by %EvaluateSystemExpression
/// in class <class>%IPM.Utils.Module</class>.
Method %Evaluate(pAttrValue As %String, ByRef pParams) As %String [ Internal ]
{
	Set tAttrValue = pAttrValue
	If (tAttrValue '[ "{") {
		Return tAttrValue
	}
	Merge tParams = pParams
	Do ##class(%IPM.Storage.ModuleSetting.Default).GetCustomParameters(.customParams, $this, .tParams)
	Set root = ..Root
	If (root '= "") {
		Set root = ##class(%Library.File).NormalizeDirectory(root)
	}
	Set customParams("root") = root
	Set customParams("packagename") = ..Name
	Set customParams("version") = ..VersionString
	Set customParams("verbose") = +$Get(pParams("Verbose"))
	Set tAttrValue = ##class(%IPM.Utils.Module).%EvaluateMacro(tAttrValue)
	Set tAttrValue = ##class(%IPM.Storage.ModuleSetting.Default).EvaluateAttribute(tAttrValue,.customParams)
	Set attrValue = ##class(%IPM.Utils.Module).%EvaluateSystemExpression(tAttrValue)
	
	// {name} expression does not contain dollar sign; handle separately
	Set name = ..Name
	Set attrValue = ##class(%Regex.Matcher).%New("(?i)\{name\}", attrValue).ReplaceAll($Replace(name,"\","\\"))

	Set regex = ##class(%Regex.Matcher).%New("#\{([^}]+)\}", attrValue)
	While regex.Locate() {
		Set expr = regex.Group(1)
		Set value = ..%EvaluateExpression(expr)
		Set $Extract(attrValue, regex.Start, regex.End - 1) = value
		Set regex.Text = attrValue
	}

	Return attrValue
}

/// This callback method is invoked by the <METHOD>%Save</METHOD> method to 
/// provide notification that the object is being saved. It is called before 
/// any data is written to disk.
/// 
/// <P><VAR>insert</VAR> will be set to 1 if this object is being saved for the first time.
/// 
/// <P>If this method returns an error then the call to <METHOD>%Save</METHOD> will fail.
Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..LastUpdated = $ZDateTime($Horolog, 3)
	Quit $$$OK
}

Method %EvaluateExpression(pExpr) As %String [ Internal ]
{
  Try {
	// Remove leading whitespace because there can only be 1 whitespace between "return" and its argument
	set pExpr = $Zstrip(pExpr, "<W") 
    return @pExpr
  } Catch ex {
  }
  Return ""
}

Storage Default
{
<Data name="Defaults">
<Attribute>Defaults</Attribute>
<Structure>subnode</Structure>
<Subscript>"Defaults"</Subscript>
</Data>
<Data name="Dependencies">
<Attribute>Dependencies</Attribute>
<Structure>subnode</Structure>
<Subscript>"Dependencies"</Subscript>
</Data>
<Data name="ModuleDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Namespace</Value>
</Value>
<Value name="4">
<Value>VersionString</Value>
</Value>
<Value name="5">
<Value>Version</Value>
</Value>
<Value name="6">
<Value>LastModifiedTimestamp</Value>
</Value>
<Value name="7">
<Value>LifecycleClass</Value>
</Value>
<Value name="8">
<Value>Hash</Value>
</Value>
<Value name="9">
<Value>Description</Value>
</Value>
<Value name="10">
<Value>ExternalName</Value>
</Value>
<Value name="11">
<Value>Author</Value>
</Value>
<Value name="12">
<Value>InstallerClass</Value>
</Value>
<Value name="13">
<Value>GlobalScope</Value>
</Value>
<Value name="14">
<Value>Root</Value>
</Value>
<Value name="15">
<Value>Packaging</Value>
</Value>
<Value name="16">
<Value>Keywords</Value>
</Value>
<Value name="17">
<Value>SourcesRoot</Value>
</Value>
<Value name="18">
<Value>Repository</Value>
</Value>
<Value name="19">
<Value>SystemRequirements</Value>
</Value>
<Value name="20">
<Value>DeveloperMode</Value>
</Value>
<Value name="21">
<Value>AfterInstallMessage</Value>
</Value>
<Value name="22">
<Value>AllVersions</Value>
</Value>
<Value name="23">
<Value>Origin</Value>
</Value>
<Value name="24">
<Value>Deployed</Value>
</Value>
<Value name="25">
<Value>PlatformVersion</Value>
</Value>
<Value name="26">
<Value>DisplayName</Value>
</Value>
<Value name="27">
<Value>AvailabilityClass</Value>
</Value>
<Value name="28">
<Value>LastUpdated</Value>
</Value>
</Data>
<DataLocation>^IPM.Storage.ModuleD</DataLocation>
<DefaultData>ModuleDefaultData</DefaultData>
<IdLocation>^IPM.Storage.ModuleD</IdLocation>
<IndexLocation>^IPM.Storage.ModuleI</IndexLocation>
<StreamLocation>^IPM.Storage.ModuleS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
