Include (%occErrors, %ZPM.PackageManager.Common)

Class %ZPM.PackageManager.Developer.Module Extends (%Persistent, %ZPM.PackageManager.Core.ModuleInfo) [ StorageStrategy = "" ]
{

Parameter DOMAIN = "ZPM";

Index Name On Name [ Unique ];

Property GlobalScope As %Boolean;

Property VersionString As %String(MAXLEN = 100, XMLNAME = "Version") [ InitialExpression = "0.0.1+snapshot", Required ];

Property ExternalName As %String(MAXLEN = 255);

Property Description As %String(MAXLEN = "");

Property Keywords As %String(MAXLEN = "");

Property Author As %ZPM.PackageManager.Developer.ModuleAuthorInfo;

/// Typically "module" or "application", but intentionally not enforced with VALUELIST.
Property Packaging As %String [ Required ];

Property Dependencies As list Of %ZPM.PackageManager.Core.ModuleReference(STORAGEDEFAULT = "array");

Relationship Resources As %ZPM.PackageManager.Developer.ResourceReference(XMLITEMNAME = "Resource", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE") [ Cardinality = children, Inverse = Module ];

Relationship Mappings As %ZPM.PackageManager.Developer.MappingReference(XMLITEMNAME = "Mapping", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE") [ Cardinality = children, Inverse = Module ];

Relationship Invokes As %ZPM.PackageManager.Developer.InvokeReference(XMLITEMNAME = "Invoke", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE") [ Cardinality = children, Inverse = Module ];

Property LifecycleClass As %Dictionary.CacheClassname;

Property InstallerClass As %Dictionary.CacheClassname;

Property Lifecycle As %ZPM.PackageManager.Developer.Lifecycle.Abstract(XMLPROJECTION = "NONE") [ Transient ];

Property Hash As %Binary(XMLPROJECTION = "NONE");

Property LastModifiedTimestamp As %TimeStamp(XMLPROJECTION = "NONE") [ InitialExpression = {$ZDateTime($Horolog,3)} ];

Property API As list Of %ZPM.PackageManager.Developer.APIDocumentation(STORAGEDEFAULT = "array", XMLITEMNAME = "Item");

/// Root directory on the filesystem from which this module was loaded.
Property Root As %String(MAXLEN = "", XMLPROJECTION = "NONE");

/// Sources root, where placed any source code
Property SourcesRoot As %String(MAXLEN = 20);

Property SystemRequirements As %ZPM.PackageManager.Developer.SystemRequirements;

/// Default settings - there may be serveral types of these (subclasses of ModuleSetting).
Property Defaults As list Of %ZPM.PackageManager.Developer.ModuleSetting(CLASSNAME = 1, STORAGEDEFAULT = "array", XMLNAME = "Defaults", XMLPROJECTION = "WRAPPED", XMLREFERENCE = "COMPLETE", XMLTYPECONSTRAINT = "SUBSTITUTIONGROUP");

Method NameSet(val As %RawString) As %Status
{
	Set i%Name = $$$lcase(val)
	Return $$$OK
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

/// Execute multiple lifecycle phases in sequence. Execution is terminated if one fails.
/// Example: $ListBuild("Clean","Test") or $ListBuild("Test","Install")
/// @PublicAPI
ClassMethod ExecutePhases(pModuleName As %String, pPhases As %List, pIsComplete As %Boolean = 0, ByRef pParams) As %Status
{
	set tSC = $$$OK
	try {
		set pModuleName = $$$lcase(pModuleName)
		set tModule = ..NameOpen(pModuleName,,.tSC)
		If '$isobject(tModule) {
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Module '"_pModuleName_"' not found."))
		}
		$$$ThrowOnError(tSC)
		
		set tLifecycle = tModule.Lifecycle
		if (tLifecycle = "") {
			if (tModule.Packaging = "application") {
				set tLifecycle = "%ZPM.PackageManager.Developer.Lifecycle.Application"				
			} else {
				set tLifecycle = "%ZPM.PackageManager.Developer.Lifecycle.Module"
			}
		} 
		;
		if pIsComplete {
			set tPhases = tLifecycle.GetCompletePhases(pPhases)
		} else {
			set tPhases = pPhases
		}

		// Subscript by namespace to handle application build and integration testing processes, which may
		// load a module in a different namespace (and call ExecutePhases there) at a lower stack level than the
		// initial call to ExecutePhases
		if '$Data($$$ZPMHandledModules($Namespace)) {
			new $$$ZPMHandledModules
		} else {
			set $$$ZPMHandledModules($Namespace,pModuleName) = $Get($$$ZPMHandledModules($Namespace,pModuleName))_tPhases
		}
		
		do tLifecycle.GetDefaultParameters(.tParams,tPhases)
		Merge tParams = pParams // Overwrite with actual specified parameters
		Kill pParams Merge pParams = tParams // Move back to pParams
		set tLifecycle.PhaseList = tPhases
		;
		; execute resolved phases in sequence
		set tPointer = 0
		while $listnext(tPhases,tPointer,tOnePhase) {
			;
			if tOnePhase="*" {
				kill tModule,tLifecycle
				set tModule = ..NameOpen(pModuleName,,.tSC) quit:$$$ISERR(tSC)
				set tLifecycle = tModule.Lifecycle
				set tLifecycle.PhaseList = tPhases
				write !,"["_pModuleName_"]",$c(9),"Module object refreshed."
				continue
			}
			;
			do {
				;
				write !,"["_pModuleName_"]",$c(9),tOnePhase," START"
				;
				; notify resource processors
				set tKey="" for {
					#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
					set tResource = tModule.Resources.GetNext(.tKey) quit:(tKey="")

					if $IsObject(tResource.Processor) {
						Do tResource.Processor.SetParams(.pParams)
						set tSC = $method(tResource.Processor,"OnBeforePhase",tOnePhase,.pParams) quit:$$$ISERR(tSC)
					}
				}
				Quit:$$$ISERR(tSC)

        #; Call Invoke Methods		
        Set tKey = ""
        For {
          Set tInvoke = tModule.Invokes.GetNext(.tKey)
          Quit:(tKey = "")
          Set tSC = tInvoke.OnBeforePhase(tOnePhase,.pParams)
          Quit:$$$ISERR(tSC)
        }
        Quit:$$$ISERR(tSC)

				; call OnBeforePhase for this class
				set tSC = tLifecycle.OnBeforePhase(tOnePhase,.pParams) quit:$$$ISERR(tSC)
				;
				set tSC = $method(tLifecycle,"%"_tOnePhase,.pParams) quit:$$$ISERR(tSC)
				;
				; call OnAfterPhase for this class

        #; Call Invoke Methods After Phase	
        Set tKey = ""
        For {
          Set tInvoke = tModule.Invokes.GetNext(.tKey)
          Quit:(tKey = "")
          Set tSC = tInvoke.OnAfterPhase(tOnePhase,.pParams)
          Quit:$$$ISERR(tSC)
        }
        Quit:$$$ISERR(tSC)

				; notify resource processors
				set tKey="" for {
					set tResource = tModule.Resources.GetNext(.tKey) quit:(tKey="")			
					if $IsObject(tResource.Processor) {
						Do tResource.Processor.SetParams(.pParams)
						Set tSC = $method(tResource.Processor,"OnAfterPhase",tOnePhase,.pParams) quit:$$$ISERR(tSC)
					}
				}
				quit:$$$ISERR(tSC)
			} while (0)
			
			if $$$ISERR(tSC) {
        write !,"["_pModuleName_"]",$c(9),tOnePhase," FAILURE - ",$SYSTEM.Status.GetErrorText(tSC)
				quit
			} else {
				write !,"["_pModuleName_"]",$c(9),tOnePhase," SUCCESS"
			}
		}
		;
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

/// Uninstalls a named module (<var>pModuleName</var>).
/// May optionally force installation (uninstalling even if required by other modules) if <var>pForce</var> is 1.
/// May optionally recurse to also uninstall dependencies that are not required by other modules if <var>pRecurse</var> is 1.
/// If both <var>pForce</var> and <var>pRecurse</var> are 1, then dependencies will also be uninstalled forcibly.
/// @PublicAPI
ClassMethod Uninstall(pModuleName As %String, pForce As %Boolean = 0, pRecurse As %Boolean = 0, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Merge tParams = pParams
		Set tParams("Clean","Level") = 1 // Simulate clean of module as dependency.
		Set tParams("Clean","Force") = pForce
		Set tParams("Clean","Recurse") = pRecurse
		Set tSC = ##class(%ZPM.PackageManager.Developer.Module).ExecutePhases(pModuleName,$ListBuild("Clean"),,.tParams)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

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
		Set tSC = ..BuildDependencyGraph(.tDependencyGraph,,tReloadSnapshots,.qstruct,pPhaseList)
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
					If ##class(%ZPM.PackageManager.Developer.Module).NameExists(tModuleLoop) {
						Set tMod = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModuleLoop,,.tSC)
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
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).LoadDependencies(.tDependencyGraph,.tParams)
			If $$$ISERR(tSC) { Quit }
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method BuildDependencyGraph(ByRef pDependencyGraph, pDepth As %Integer = 1, pForceSnapshotReload As %Boolean = 0, ByRef qstruct, pPhases As %String = "", ByRef pSubModules, pPass As %Integer = 1, pModulePath As %List = {$ListBuild(..Name)}, pIgnoreInstalledModules As %Boolean = 0) As %Status
{
	#define EXACT 1
	#define FUZZY 2
	
	Set tSC = $$$OK
	Try {
		Kill tSubModules
		For i=1:1:..Dependencies.Count() {
			#dim tDep As %ZPM.PackageManager.Core.ModuleReference
			Set tDep = ..Dependencies.GetAt(i)
			
			If '..HasScope(pPhases,tDep.Scope) {
				Continue
			}
			
			// Ensure this dependency is not an ancestor in the chain of dependencies getting to this point
			If $ListFind(pModulePath,tDep.Name) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Cyclic dependency detected in module '%1': %2",..Name,$ListToString(pModulePath_$ListBuild(tDep.Name)," -> ")))
				Quit
			}
			
			// Test whether dependency version is a valid semantic version. These are handled in the first pass only.
			// Other cases are handled in the second pass only.
			Set tIsExactVersion = +##class(%ZPM.PackageManager.Core.SemanticVersion).IsValid(tDep.VersionString)
			If ((pPass = $$$EXACT) && 'tIsExactVersion) || ((pPass = $$$FUZZY) && tIsExactVersion) {
				Continue
			}
			
			// Build cumulative version requirement string
			#dim tSearchExpr As %ZPM.PackageManager.Core.SemanticVersionExpression
			Set tSearchExpr = tDep.Version.%ConstructClone(1)
			Set tSourcePath = ""
			For {
				Set tSourcePath = $Order(pDependencyGraph(tDep.Name,tSourcePath),1,tOtherReq)
				Quit:tSourcePath=""
				
				Set tSC = ##class(%ZPM.PackageManager.Core.SemanticVersionExpression).FromString(tOtherReq,.tExpr)
				If $$$ISERR(tSC) {
					Quit
				}
				Set tSearchExpr = tSearchExpr.And(tExpr)
			}
			If $$$ISERR(tSC) {
				Quit
			}
			
			Set tOtherDeps = ""
			Set tExistingDepKey = ""
			For {
				Set tExistingDepKey = $Order(pDependencyGraph(tExistingDepKey))
				If (tExistingDepKey = "") {
					Quit
				}
				Set tOtherDeps = tOtherDeps_$ListBuild(tExistingDepKey)
			}
			
			// Also apply requirements presented by other installed modules that are not already in the dependency graph.
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).GetRequiredVersionExpression(tDep.Name,tOtherDeps,.tInstalledReqExpr)
			If $$$ISERR(tSC) {
				Quit
			}
			Set tSearchExpr = tSearchExpr.And(tInstalledReqExpr)
			
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
					Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
					Set pSubModules(tDepth,tDep.Name) = tLocalObj
					Continue
				}
			}
			
			Set tSearchCriteria = ##class(%ZPM.PackageManager.Core.SearchCriteria).%New()
			Set tSearchCriteria.Name = tDep.Name
			Set tSearchCriteria.VersionExpression = tSearchExpr.ToString()
			Set tSC = ##class(%ZPM.PackageManager.Client.Utils).SearchRepositoriesForModule(tSearchCriteria,.tQualifiedReferences,pForceSnapshotReload)
			If $$$ISERR(tSC) {
				Quit
			}
			If (tQualifiedReferences.Count() = 0) {
				Set tMsg = $$$FormatText("Could not find satisfactory module version in any repositories: '%1' version '%2', required by %3",tDep.Name,tSearchCriteria.VersionExpression,..Name)
				Set tSC = $$$ERROR($$$GeneralError,tMsg)
				Quit
			} Else {
				Set tResultFound = 0
				For j=1:1:tQualifiedReferences.Count() {
					Kill tDependencyGraph,tSubModules
					Merge tDependencyGraph = pDependencyGraph
					Merge tSubModules = pSubModules
					Set tQualifiedReference = tQualifiedReferences.GetAt(j)
					Set tSC = ##class(%ZPM.PackageManager.Client.Utils).RetrieveModuleManifest(tQualifiedReference,.tManifest)
					If $$$ISERR(tSC) {
						Quit
					}
					
					// Recursively process dependencies.
					#dim tModule As %ZPM.PackageManager.Developer.Module
					Set tReader = ##class(%XML.Reader).%New()
					Set tSC = tReader.OpenStream(tManifest)
					If $$$ISERR(tSC) {
						Quit
					}
					Do tReader.Correlate("Module","%ZPM.PackageManager.Developer.Module")
					Do tReader.Next(.tModule,.tSC)
					If $$$ISERR(tSC) {
						Quit
					}
					
					Set tDepth = $Select(tPreviousDepth=0:pDepth,tPreviousDepth>pDepth:tPreviousDepth,1:pDepth)
			
					If (pPass = $$$EXACT) {	
						Set pDependencyGraph(tDep.Name) = $ListBuild(pDepth,tQualifiedReference.ServerName,tModule.VersionString)
						Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
						Set pSubModules(tDepth,tDep.Name) = tModule
				
						// If we have an exact match, attempt to resolve exact dependencies recursively.
						Set tSC = tModule.BuildDependencyGraph(.pDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,,.pSubModules,,pModulePath_$ListBuild(tDep.Name),pIgnoreInstalledModules)
						
						// Failure to resolve any of these dependencies is an immediate failure, and can be descriptive.
						If $$$ISERR(tSC) {
							Quit
						}
						
						Set tResultFound = 1
						Quit
					}
					
					If (pPass = $$$FUZZY) {	
						Set tDependencyGraph(tDep.Name) = $ListBuild(tDepth,tQualifiedReference.ServerName,tModule.VersionString)
						Set tDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
				
						Set tSubModules(tDepth,tDep.Name) = tModule
					
						// For fuzzy version matching, preview the next graph step; move to the next version if it would lead to failure.
						// If not, update.
						Set tPossibleSC = tModule.BuildDependencyGraph(.tDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,,.tSubModules,,pModulePath_$ListBuild(tDep.Name),pIgnoreInstalledModules)
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
					Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
					Set pSubModules(tDepth,tDep.Name) = tModule
				}
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pPass = $$$EXACT) {	
			// Call for second pass (fuzzy version matching)
			Set tSC = ..BuildDependencyGraph(.pDependencyGraph,pDepth,pForceSnapshotReload,.qstruct,pPhases,.pSubModules,$$$FUZZY,pModulePath,pIgnoreInstalledModules)
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
					Set tSC = tModule.BuildDependencyGraph(.pDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,,.pSubModules,,pModulePath_$ListBuild(tModName),pIgnoreInstalledModules)
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
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

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
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).LoadDependencies(.pDependencyGraph,.tParams)
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		Set pReferenceArray(..Name_".ZPM") = ""
		
		Set tKey = ""
		For {
			#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
			Set tResource = ..Resources.GetNext(.tKey)
			Quit:tKey=""
			If '..HasScope(pPhases,tResource.Scope) {
				Continue
			}
			
			Set tSC = tResource.ResolveChildren(.pReferenceArray)
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
				
				Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModName,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
				
				// Don't pass along the phase
				Set pReferenceArray(tModName_".ZPM") = ..Name
				Set tSC = tModule.GetResolvedReferences(.pReferenceArray, pLockedDependencies, ,pSkipDependencies)
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

Method UpdateAPIDocumentation() As %Status
{
	Set tSC = $$$OK
	Try {
		// Extract annotations from classes in the module.
		Set tAnnotationList = ##class(%Library.ListOfObjects).%New()
		Set tKey = ""
		For {
			Set tResource =  ..Resources.GetNext(.tKey)
			Quit:tKey=""
			
			Kill tChildArray
			Set tSC = tResource.ResolveChildren(.tChildArray)
			If $$$ISERR(tSC) {
				Quit
			}
			Set tChild = ""
			For {
				Set tChild = $Order(tChildArray(tChild))
				Quit:tChild=""
				
				If ($Piece(tChild,".",*) = "CLS") {
					Set tSC = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).ExtractAnnotations($Piece(tChild,".",1,*-1),tAnnotationList)
					If $$$ISERR(tSC) {
						Quit
					}
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Currently, automatic annotations are only supported for classes and class members.
		// Build an array of members with @API annotations:
		For i=1:1:tAnnotationList.Count() {
			#dim tAnnotation As %ZPM.PackageManager.Developer.Annotation
			Set tAnnotation = tAnnotationList.GetAt(i)
			If (tAnnotation.Tag = "PublicAPI") || (tAnnotation.Tag = "PrivateAPI") {
				Set tSubType = tAnnotation.MemberType
				Set tName = tAnnotation.Classname_$Case(tAnnotation.MemberName,"":"",:":"_tAnnotation.MemberName)
				Set tAPIArray($ListBuild(tSubType,tName)) = (tAnnotation.Tag = "PublicAPI")
			}
		}
		
		// Remove missing annotations from the module's API documentation:
		Set tAPIChanged = 0
		For i=..API.Count():-1:1 {
			#dim tItem As %ZPM.PackageManager.Developer.APIDocumentation
			Set tItem = ..API.GetAt(i)
			If (tItem.Type = "class") {
				Set tKey = $ListBuild(tItem.SubType,tItem.Name)
				If $Data(tAPIArray(tKey),tPublic) {
					// Update "Public" flag
					If (tPublic '= tItem.Public) {
						Set tItem.Public = tPublic
						Set tAPIChanged = 1
					}
					// This is still API. No need to re-add it later.
					Kill tAPIArray(tKey)
				} Else {
					// No longer API. Remove it.
					Do ..API.RemoveAt(i)
					Set tAPIChanged = 1
				}
			}
		}
		
		// Insert new annotations at the end of the module's API documentation:
		Set tKey = ""
		For {
			Set tKey = $Order(tAPIArray(tKey),1,tPublic)
			Quit:tKey=""
			
			Set tAPIDoc = ##class(%ZPM.PackageManager.Developer.APIDocumentation).%New()
			Set tAPIDoc.Type = "class"
			Set tAPIDoc.SubType = $List(tKey,1)
			Set tAPIDoc.Name = $List(tKey,2)
			Set tAPIDoc.Public = tPublic
			Do ..API.Insert(tAPIDoc)
			Set tAPIChanged = 1
		}
		
		// Save changes to the module.
		If (tAPIChanged = 1) {
			// Force timestamp change if there have actually been any changes to the API.
			// %OnAddToSaveSet is not called if there have only been modifications to subordinate objects.
			Set ..Hash = ""
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method LifecycleGet() As %ZPM.PackageManager.Developer.Lifecycle.Abstract
{
	if $isObject(r%Lifecycle) quit r%Lifecycle
	set tLifecycleClass = ..LifecycleClass
	if (tLifecycleClass '= "") && ($Length(tLifecycleClass,".") = 1) {
		set tLifecycleClass = $$$DefaultLifecyclePackageDot_tLifecycleClass
	}
	if (tLifecycleClass = "") || '$$$comClassDefined(tLifecycleClass) {
		if (..Packaging = "application") {
			set ..LifecycleClass = "Application"
		} else {
			set ..LifecycleClass = "Module"
		}
		set tLifecycleClass = $$$DefaultLifecyclePackageDot_..LifecycleClass
	}
	set r%Lifecycle = $ClassMethod(tLifecycleClass,"%New",$this)
	quit r%Lifecycle
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
	Set ..Version = ##class(%ZPM.PackageManager.Core.SemanticVersion).FromString(i%VersionString)
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
			Set ..Root = ##class(%File).GetDirectory(tExternalName,1)
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
			Set tBaseClass = "%ZPM.PackageManager.Developer.Lifecycle.Base"
			If '$ClassMethod(..LifecycleClass,"%Extends",tBaseClass) {
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
		} ElseIf (..Packaging = "") {
			// Default to "module"
			Set ..Packaging = "module"
		}
		
		If (..InstallerClass '= "") && $$$comClassDefined(..InstallerClass) {
			Set tBaseClass = "%ZPM.AbstractInstaller"
			If '$ClassMethod(..InstallerClass,"%Extends",tBaseClass) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid installer class '%1' - must extend %2",..InstallerClass,tBaseClass))
				Quit
			}
		}
		
		// Pre-check for uniqueness among resources (make sure there are no collisions and report descriptive errors if there are).
		// This is simpler than trying to interpret a unique index violation later, and will work in all cases where we're updating modules.
		Set tSC = $$$OK
		Set tKey = ""
		For {
			Set tResource = ..Resources.GetNext(.tKey)
			Quit:(tKey="")
			
			// If it hasn't been saved yet (to account for module renames)...
			If (tResource.%Id() = "") && (tResource.UniqueName '= "") {
				// ... see if some other resource exists with the same name.
				If ##class(%ZPM.PackageManager.Developer.ResourceReference).ResourceNameExists(tResource.UniqueName) {
					Set tOtherResource = ##class(%ZPM.PackageManager.Developer.ResourceReference).ResourceNameOpen(tResource.UniqueName,,.tSC)
					If $$$ISERR(tSC) {
						Quit
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
			Set ..Version = ##class(%ZPM.PackageManager.Core.SemanticVersion).FromString(..VersionString)
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
	// Coupled with %ZPM.PackageManager.Developer.Document.Module to allow editing of the current module rather than matching an existing one.
	Quit $Get($$$ZPMStudioDocumentModule,..%New())
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
	select distinct %exact Dependencies_VersionString "Version"
	from %ZPM_PackageManager_Developer.Module_Dependencies
	where Dependencies_Name = :pOfModuleName and
		(:pExcludeModuleNames is null or "Module"->Name not %INLIST :pExcludeModuleNames)
}

ClassMethod %RegExReplace(pString, pName, pValue) As %String
{
  set tString = pString
  Set tRegEx = "(?i)\{\$" _ pName _ "\}"
	Set tString =  ##class(%Regex.Matcher).%New(tRegEx, tString).ReplaceAll($Replace(pValue,"\","\\"))
  Set tRegEx = "(?i)\$\{" _ pName _ "\}"
	Set tString =  ##class(%Regex.Matcher).%New(tRegEx, tString).ReplaceAll($Replace(pValue,"\","\\"))
  Quit tString
}

/// Evaluates an expression in an attribute
/// Current valid expressions:
/// {$namespace} - the current namespace
/// {$mgrdir} - the instance's mgr directory
/// {$cspdir} - the instance's root CSP directory
/// {$root} - the resource's module's root directory
/// These special expressions are case-insensitive.
Method %Evaluate(pAttrValue, ByRef pParams) As %String [ Internal ]
{
	Set tAttrValue = pAttrValue
	Set tRoot = $Case(..Root,"":"",:##class(%File).NormalizeDirectory(..Root))
  Set tInstallDir = ##class(%File).GetDirectory($zu(86))
	Set tMgrDir = $System.Util.ManagerDirectory()
  Set tBinDir = $System.Util.BinaryDirectory()
	Set tCSPDir = ##class(%File).NormalizeDirectory("csp", tInstallDir)
  Set tLibDir = ##class(%File).NormalizeDirectory("lib", tInstallDir)
  Set tVerbose = +$Get(pParams("Verbose"))

	Set tAttrValue = ..%RegExReplace(tAttrValue, "namespace", $Namespace)
	Set tAttrValue = ..%RegExReplace(tAttrValue, "ns",        $Namespace)
	Set tAttrValue = ..%RegExReplace(tAttrValue, "mgrdir",    tMgrDir)
	Set tAttrValue = ..%RegExReplace(tAttrValue, "cspdir",    tCSPDir)
	Set tAttrValue = ..%RegExReplace(tAttrValue, "root",      tRoot)
	Set tAttrValue = ..%RegExReplace(tAttrValue, "bindir",    tBinDir)
	Set tAttrValue = ..%RegExReplace(tAttrValue, "libdir",    tLibDir)
	Set tAttrValue = ..%RegExReplace(tAttrValue, "verbose",   tVerbose)

  Set regex = ##class(%Regex.Matcher).%New("#\{([^}]+)\}", tAttrValue)
  While regex.Locate() {
    Set expr = regex.Group(1)
    Set value = ..%EvalueateExpression(expr)
    Set $Extract(tAttrValue, regex.Start, regex.End - 1) = value
    Set regex.Text = tAttrValue
  }
  
	Quit tAttrValue
}

Method %EvalueateExpression(pExpr) As %String [ Internal ]
{
  Try {
    return @pExpr
  } Catch ex {
  }
  Return ""
}

Storage Default
{
<Data name="API">
<Attribute>API</Attribute>
<Structure>subnode</Structure>
<Subscript>"API"</Subscript>
</Data>
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
<Value>Repo</Value>
</Value>
<Value name="19">
<Value>SystemRequirements</Value>
</Value>
</Data>
<DataLocation>^ZPM.Dev.ModuleD</DataLocation>
<DefaultData>ModuleDefaultData</DefaultData>
<IdLocation>^ZPM.Dev.ModuleD</IdLocation>
<IndexLocation>^ZPM.Dev.ModuleI</IndexLocation>
<StreamLocation>^ZPM.Dev.ModuleS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
