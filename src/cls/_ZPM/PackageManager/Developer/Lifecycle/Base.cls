Class %ZPM.PackageManager.Developer.Lifecycle.Base Extends %ZPM.PackageManager.Developer.Lifecycle.Abstract [ Abstract ]
{

Parameter PHASES = {$ListBuild("Clean","Reload","*","Validate","ExportData","Compile","Activate","Test","Package","Verify","Register","Publish","Configure","Unconfigure")};

Property Payload As %Stream.Object [ Private ];

Property Installer As %Stream.TmpCharacter [ Private ];

Parameter EXPORTDEPENDENCIES As BOOLEAN = 0;

Parameter DEPOLYABLE As BOOLEAN = 0;

Parameter PACKAGING [ Abstract ];

/// This method defines what a complete phase means for a given list of phases
ClassMethod GetCompletePhases(pPhases As %List) As %List
{
	for i=1:1:$ll(pPhases) {
		set tPhasesList = ..GetCompletePhasesForOne($li(pPhases,i))
		for j=1:1:$ll(tPhasesList) set one = $li(tPhasesList,j) if one'="" set tPhasesArray(one) = ""
	}
	set tResultingPhases = ""
	for i=1:1:$ll(..#PHASES) {
		set one = $li(..#PHASES,i) if $d(tPhasesArray(one)) set tResultingPhases = tResultingPhases_$lb(one)
	}
	quit tResultingPhases
}

/// This method defines what a complete phase means for a given phase
ClassMethod GetCompletePhasesForOne(pOnePhase As %String) As %List
{
	quit $case(pOnePhase,
		"Clean":		$lb("Clean"),
		"Reload":		$lb("Reload","*"),
		"Validate":		$lb("Reload","*","Validate"),
		"ExportData":	$lb("ExportData"),
		"Compile":		$lb("Reload","*","Validate","Compile"),
		"Activate":		$lb("Reload","*","Validate","Compile","Activate"),
		"Test":			$lb("Reload","*","Validate","Compile","Activate","Test"),
		"Package":		$lb("Reload","*","Validate","Compile","Activate","Package"),
		"Verify":		$lb("Reload","*","Validate","Compile","Activate","Package","Verify"),
		"Register":		$lb("Reload","*","Validate","Compile","Activate","Package","Register"),
		"Publish":		$lb("Reload","*","Validate","Compile","Activate","Package","Register","Publish"),
		"Configure":	$lb("Configure"),
		"Unconfigure":	$lb("Unconfigure"),
		:				""
	)
}

Method OnBeforeArtifact(pExportDirectory As %String, pWorkingDirectory As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		// Notify resource processors
		Set tKey = ""
		For {
			#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
			Set tResource = ..Module.Resources.GetNext(.tKey)
			Quit:(tKey="")
			
			If $IsObject(tResource.Processor) {
				Set tSC = $Method(tResource.Processor,"OnBeforeArtifact",pExportDirectory,pWorkingDirectory,.pParams)
				If $$$ISERR(tSC) {
					Quit
				}
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method CheckBeforeClean(ByRef pParams, Output pSkip As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tLevel = $Get(pParams("Clean","Level"),0)
		Set tRecurse = $Get(pParams("Clean","Recurse"),1)
		
		If '$Get(pParams("Clean","Force")) {
			// Check to see if anything depends on this module and return an error status if it does.
			Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).GetDependentsList(.tList,,..Module.Name)
			If $$$ISERR(tSC) {
				Quit
			}
			
			Set tModList = ""
			For i=1:1:tList.Count() {
				Set tName = tList.GetAt(i).Name
				If '$Data(pParams("Clean","Cycle",tName)) {
					Set tModList = tModList_$ListBuild(tName)
				}
			}
			
			If ($ListLength(tModList) > 0) {
				If (tLevel > 0) && tVerbose {
					Write !,"[",..Module.Name,"]",$c(9),"Clean SKIP - required by ",$ListLength(tModList),
						" other module",$Case($ListLength(tModList),1:"",:"s"),". (",$ListToString(tModList,"; "),")"
					Set pSkip = 1
					Set pParams("Clean","Skip",..Module.Name) = ""
					Quit
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Clean(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pParams("Clean","Cycle",..Module.Name) = ""
		
		Set tVerbose = $Get(pParams("Verbose"))
		Set tPurge = $Get(pParams("Purge"))
		Set tLevel = $Get(pParams("Clean","Level"),0)
		Set tRecurse = $Get(pParams("Clean","Recurse"),1)
		
		Set tSC = ..CheckBeforeClean(.pParams,.tSkip)
		If (tSkip) {
			Quit
		}
		
		If (tLevel > 0) {
			Set tKey = ""
			For {
				#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
				Set tResource = ..Module.Resources.GetNext(.tKey)
				Quit:tKey=""
				
				Kill tResourceChildren
				Do tResource.ResolveChildren(.tResourceChildren)
				Set tChildKey = ""
				For {
					Set tChildKey = $Order(tResourceChildren(tChildKey))
					Quit:tChildKey=""
				
					If ($Extract(tChildKey) = "/") || (tChildKey '[ ".") {
						Continue
					}
					
					Set tName = $Piece(tChildKey,".",1,*-1)
					Set tExt = $Piece(tChildKey,".",*)
					Set tDeleteArray(tExt,tName) = ""
				}
			}
			
			If $Data(tDeleteArray("CLS")) {
				Merge tClassArray = tDeleteArray("CLS")
				
				Set tClassKey = ""
				For {
					Set tClassKey = $Order(tClassArray(tClassKey))
					Quit:tClassKey=""
					
					If ##class(%Library.RoutineMgr).IsMapped(tClassKey_".CLS") {
						Continue
					}
					
					If $$$comClassDefined(tClassKey) || $$$defClassDefined(tClassKey) {
						If (tPurge)&&($CLASSMETHOD(tClassKey, "%Extends", "%Persistent")) {
							Set tPurgeSC = $CLASSMETHOD(tClassKey, "%KillExtent")
							If $$$ISERR(tPurgeSC) {
								Write !,"WARN: "_$System.Status.GetErrorText(tPurgeSC)
							}
						}
						Set tDelSC = $System.OBJ.UnCompile(tClassKey)
						Set tDelSC = $System.OBJ.Delete(tClassKey,$Select(tVerbose:"d",1:"-d"))
						If $$$ISERR(tDelSC) {
							Write !,"WARN: "_$System.Status.GetErrorText(tDelSC)
						}
					}
				}
				Kill tDeleteArray("CLS")
			}
			
			Kill tDeleteArray("PKG") // Handled above due to ResolveChildren
			
			// Clean up other items individually.
			If $Data(tDeleteArray) {
				Set tType = ""
				For {
					Set tType = $Order(tDeleteArray(tType))
					Quit:tType=""
					
					Set tItem = ""
					For {
						Set tItem = $Order(tDeleteArray(tType,tItem))
						Quit:tItem=""
						
						Set tFullName = tItem_"."_tType
						
						If ##class(%Library.RoutineMgr).IsMapped(tFullName) {
							Continue
						}
						
						Set tDelSC = ##class(%Library.RoutineMgr).Delete(tFullName)
						If $$$ISERR(tDelSC) {
							Write !,"WARN: "_$System.Status.GetErrorText(tDelSC)
						}
					}
				}
			}
		}
		
		If tRecurse {
			For i=1:1:..Module.Dependencies.Count() {
				Set tModName = ..Module.Dependencies.GetAt(i).Name
				If $Data(pParams("Clean","Cycle",tModName)) {
					Continue
				}
				ZKill pParams("Clean","Skip",tModName)
				If ##class(%ZPM.PackageManager.Developer.Module).NameExists(tModName) {
					Set tModObj = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModName,,.tModSC)
					If $$$ISERR(tModSC) {
						Write !,"WARN: "_$System.Status.GetErrorText(tModSC)
						Continue
					}
					Kill tParams
					Merge tParams = pParams
					ZKill:'tRecurse tParams("Clean","Force")
					Set tParams("Clean","Level") = tLevel + 1
					Set tParams("Clean","Nested") = 1
					Set tSC = tModObj.Lifecycle.Clean(.tParams)
					If $$$ISERR(tSC) {
						Quit
					}
					If '$Data(tParams("Clean","Skip",tModName)) {
						Set tSC = ##class(%ZPM.PackageManager.Developer.Module).NameDelete(tModName)
						If $$$ISERR(tSC) {
							Quit
						}
						Write:tVerbose !,"Deleted ",tModName
					}
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		If (tLevel > 0) && '$Get(pParams("Clean","Nested"),0) {
			Set tSC = ##class(%ZPM.PackageManager.Developer.Module).NameDelete(..Module.Name)
			If $$$ISERR(tSC) {
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %ExportData(ByRef pParams) As %Status
{
	Quit $$$OK
}

Method %Configure(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"),0)

		// getting custom parameters from command line or <Default> element
		Do ##class(%ZPM.PackageManager.Developer.ModuleSetting.Default).GetCustomParameters(.customParams,..Module, .pParams)

		If (..Module.InstallerClass '= "") {
			
			Set tDeveloperMode = $Get(pParams("DeveloperMode"),0)
			Set tDatabaseName = $Get(pParams("Configure","DatabaseName"))
			Set tIsUpgrade = $Get(pParams("Configure","IsUpgrade"),0)
			Merge tVars = pParams
			Merge tVars = pParams("Configure","Parameters")
			Kill tVars("Configure","Parameters")
			Set tVars("PackageManager","Lifecycle") = $This
			Set tVars("InstallDir") = ..Module.Root
			
			// Call OnInstallComponent
			Set tSC = $ClassMethod(..Module.InstallerClass,"OnInstallComponent",tDatabaseName,tVerbose,tDeveloperMode,tIsUpgrade)
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Call OnConfigureComponent
			Set tSC = $ClassMethod(..Module.InstallerClass,"OnConfigureComponent",$Namespace,tVerbose,.tVars)
		}

		// Call Invoke Methods
		
		Set key = ""
		For {
			Set invoke = ..Module.Invokes.GetNext(.key)
			Quit:(key = "")
			Set args = 0
			Do invoke.GetArgsArray(.args)

			Do ##class(%ZPM.PackageManager.Developer.ModuleSetting.Default).EvaluateArgs(.args, .customParams)

			If (tVerbose) { 
				Write !, $$$FormatText("Invoking ClassMethod %1 from Class %2 ... ",invoke.Method,invoke.Class) 
				Set result = $ClassMethod(invoke.Class,invoke.Method,args...)
				Write $$$FormatText("Result: %1 ",result)
			} else {
				Do $ClassMethod(invoke.Class,invoke.Method,args...)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Unconfigure(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..Module.InstallerClass '= "") {
			Set tVerbose = $Get(pParams("Verbose"),0)
			Set tDeveloperMode = $Get(pParams("DeveloperMode"),0)
			Set tDatabaseName = $Get(pParams("Configure","DatabaseName"))
			Set tIsUpgrade = $Get(pParams("Configure","IsUpgrade"),0)
			Set tPurge = $Get(pParams("Configure","Purge"),0)
			Merge tVars = pParams
			Merge tVars = pParams("Configure","Parameters")
			Kill tVars("Configure","Parameters")
			Set tVars("PackageManager","Lifecycle") = $This
			
			// Call OnUnconfigureComponent
			Set tSC = $ClassMethod(..Module.InstallerClass,"OnUnconfigureComponent",$Namespace,tVerbose,tPurge,.tVars)
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Call OnUnInstallComponent
			Set tSC = $ClassMethod(..Module.InstallerClass,"OnUnInstallComponent",tDatabaseName,tVerbose)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Reload(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tModuleName = ..Module.Name
		Set tDefaultDevMode = $g(^%SYS("ModuleRoot",$namespace,tModuleName,"DeveloperMode"))||$g(^%SYS("ModuleRoot","*",tModuleName,"DeveloperMode"))
		Set tDeveloperMode = +$Get(pParams("DeveloperMode"),tDefaultDevMode)
		Set tSkipScoped = 'tDeveloperMode
		Set tVerbose = $Get(pParams("Verbose"))
		Set tRoot = $g(pParams("RootDirectory"))
		If (tRoot = "") && tDeveloperMode {
			Set tRoot = $g(^%SYS("ModuleRoot",$namespace,tModuleName),$g(^%SYS("ModuleRoot","*",tModuleName)))
		}
		
		// For now, no-op if no root is configured.
		Quit:tRoot=""
		
		Set tRoot = ##class(%File).NormalizeDirectory("",tRoot)
		Set tSC = $system.OBJ.Load(tRoot_"module.xml","/nodisplay",.error,.tLoadedList) quit:$$$ISERR(tSC)
		
		// Validate loaded module
		Set first = $$$lcase($o(tLoadedList("")))
		If (first = "") {
			Set tSC = $$$ERROR($$$GeneralError,"No module definition found.")
			Quit
		}
		If ($Order(tLoadedList(first)) '= "") {
			Set tSC = $$$ERROR($$$GeneralError,"module.xml is malformed.")
			Quit
		}
		If ($Piece(first,".",*) '= "zpm") {
			Set tSC = $$$ERROR($$$GeneralError,"No module definition found.")
			Quit
		}
		If (tModuleName '= $Piece(first,".",1,*-1)) {
			Set tSC = $$$ERROR($$$GeneralError,"Module name mismatch.") Quit
		}
		
		// Set up mappings
		Set tKey = ""
		For {
			Set tMapping = ..Module.Mappings.GetNext(.tKey)
			Quit:tKey=""
			
			Set tName = $Piece(tMapping.Name,".",1,*-1)
			Set tExtension = $Piece(tMapping.Name,".",*)
			Set tSource = tMapping.Source
			
			Set tSC = $Case(tExtension,
				"GBL":##class(%ZPM.PackageManager.Developer.Utils).AddGlobalMapping($namespace,tName,tSource),
				"INC":##class(%ZPM.PackageManager.Developer.Utils).AddRoutineMapping($namespace,tName,"INC",tSource),
				"MAC":##class(%ZPM.PackageManager.Developer.Utils).AddRoutineMapping($namespace,tName,"MAC",tSource),
				"PKG":##class(%ZPM.PackageManager.Developer.Utils).AddPackageMapping($namespace,tName,tSource),
				"":##class(%ZPM.PackageManager.Developer.Utils).AddRoutineMapping($namespace,tName,"ALL",tSource))
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tPreloadRoot = tRoot_"preload"
		If ##class(%File).DirectoryExists(tPreloadRoot) {
			Set tSC = $system.OBJ.LoadDir(tPreloadRoot,$Select(tVerbose:"d",1:"-d")_"/compile",,1)
			If $$$ISERR(tSC) {
				Quit
			}
		} ElseIf tVerbose {
			Write !,"Skipping preload - directory does not exist."
		}
		
		// Reload the module definition
		Set tSC = ..Module.%Reload()
		If $$$ISERR(tSC) {
			Quit
		}
		
		If tDeveloperMode {
			If ..Module.GlobalScope {
				Set ^%SYS("ModuleRoot","*",tModuleName) = tRoot
				// clean up in case GlobalScope is changed in the new version of module.xml
				Kill ^%SYS("ModuleRoot",$namespace,tModuleName)
			} Else {
				Set ^%SYS("ModuleRoot",$namespace,tModuleName) = tRoot
				// clean up in case GlobalScope is changed in the new version of module.xml
				Kill ^%SYS("ModuleRoot","*",tModuleName)
			}
		}
		
		Set ..Module.Root = tRoot
		Set tSC = ..Module.%Save() quit:$$$ISERR(tSC)
		
		Set tGlobalScope = ..Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		
		// Standard resource processing
		Set tKey = ""
		For {
			Set tResource = ..Module.Resources.GetNext(.tKey)
			Quit:tKey=""
			
			If $IsObject(tResource.Processor) {
				Set tSC = tResource.Processor.OnPhase("Reload",.pParams)
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
	} Catch e {
		Set tSC = e.AsStatus()
	}
	quit tSC
}

Method %Validate(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		TSTART
		Set tSC = ..Module.UpdateAPIDocumentation()
		If $$$ISERR(tSC) {
			Quit
		}

		Set tSC = ..Module.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

Method %Compile(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		
		// Load dependencies correctly for the requested phases. (This will be a no-op in most cases.)
		Set tSC = ..Module.LoadDependencies(..PhaseList,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Compile items within the module that are compilable using OnPhase
		Set tKey = ""
		For {
			#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
			Set tResource = ..Module.Resources.GetNext(.tKey)
			Quit:tKey=""
			
			Set tHandled = 0
			If $IsObject(tResource.Processor) {
				Do tResource.Processor.OnPhase("Compile",.pParams,.tHandled)
				If (tHandled) {
					Set tHandledMap(tResource.Name) = ""
					Continue
				}
			}
		}
		
		// Build maps of other compilable things
		Set tKey = ""
		For {
			Set tResource = ..Module.Resources.GetNext(.tKey)
			Quit:tKey=""
			
			If '$Data(tHandledMap(tResource.Name)) && $IsObject(tResource.Processor) {
				If tResource.Processor.%IsA("%ZPM.PackageManager.Developer.Processor.AbstractCompilable") {
					Kill tOneResourceList
					Set tOneResourceList(tResource.Name) = ""
					Set tSC = tResource.ResolveChildren(.tOneResourceList)
					If $$$ISERR(tSC) {
						Quit
					}
					
					Set tCompilableMap(tResource.Name) = ""
					
					// Prerequisites
					// Builds two maps:
					// tDependencyMap("<thing to compile first>","<thing dependent on it>") = ""
					// tDependentMap("<dependent thing>","<thing to compile first>") = ""
					Set tCompileAfterList = $ListFromString(tResource.Processor.CompileAfter)
					If (tCompileAfterList '= "") {
						Set tPointer = 0
						While $ListNext(tCompileAfterList,tPointer,tDependency) {
							If '$Data(tHandledMap(tDependency)) {
								Set tDependencyMap(tDependency,tResource.Name) = ""
								Set tDependentMap(tResource.Name,tDependency) = ""
							}
						}
					}
					
					// Compile Flags (second grouping)
					Set tFlags = tResource.Processor.Flags
					Set tFlags = $Case(tFlags,"":"<none>",:tFlags)
					
					Merge tCompileFlagMap(tFlags,tResource.Name) = tOneResourceList
				}
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Ensure there are no CompileAfter dependencies on resources absent from the module.
		Set tKey = ""
		For {
			Set tKey = $Order(tDependencyMap(tKey))
			Quit:tKey=""
			
			If '$Data(tCompilableMap(tKey)) {
				Set tCulprit = $Order(tDependencyMap(tKey,""))
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Resource '%1' cannot compile after nonexistent/non-compilable resource '%2'",tCulprit,tKey))
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Compile in multiple passes, grouped by compile flags.
		Set tCompiledSomething = 0
		For {
			If '$Data(tCompilableMap) {
				Quit
			}
			
			Set tCompiledSomething = 0
			Set tFlags = ""
			For {
				Set tFlags = $Order(tCompileFlagMap(tFlags))
				Quit:tFlags=""
				
				// Build array of classes to compile with a given set of compile flags
				Kill tFlagSet
				Merge tFlagSet = tCompileFlagMap(tFlags)
				Set tResourceKey = ""
				Kill tCompileArray
				Set tCompileList = ""
				For {
					Set tResourceKey = $Order(tFlagSet(tResourceKey))
					Quit:tResourceKey=""
					
					If '$Data(tDependentMap(tResourceKey)) {
						Merge tCompileArray = tFlagSet(tResourceKey)
						Set tCompileList = tCompileList_$ListBuild(tResourceKey)
						Kill tCompileFlagMap(tFlags,tResourceKey)
						Kill tCompilableMap(tResourceKey)
					}
				}
				If $$$ISERR(tSC) {
					Quit
				}
				
				// Actually do the compile
				If $Data(tCompileArray) {
					Set tCompiledSomething = 1
					Set tStruct = $Select(tVerbose:"d",1:"-d")_tFlags
					Set tSC = $System.OBJ.CompileList(.tCompileArray,.tStruct)
					If $$$ISERR(tSC) {
						Quit
					}
				}
				
				// Update dependency tracking to reflect that things were compiled.
				// Reminder:
				// tDependencyMap("<thing to compile first>","<thing dependent on it>") = ""
				// tDependentMap("<dependent thing>","<thing to compile first>") = ""
				Set tPointer = 0
				While $ListNext(tCompileList,tPointer,tCompiledResource) {
					Set tDependent = ""
					For {
						Set tDependent = $Order(tDependencyMap(tCompiledResource,tDependent))
						Quit:tDependent=""
						
						Kill tDependentMap(tDependent,tCompiledResource)
					}
					Kill tDependencyMap(tCompiledResource)
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Cycle detection
			If 'tCompiledSomething {
				Set tFailedResources = ""
				Set tResource = ""
				For {
					Set tResource = $Order(tCompilableMap(tResource))
					Quit:tResource=""
					Set tFailedResources = tFailedResources_$ListBuild(tResource)
				}
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Failed to resolve compile order of module resources: %1",$ListToString(tFailedResources,", ")))
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Activate(ByRef pParams) As %Status
{
	Quit $$$OK
}

Method %Test(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		For i=1:1:..Module.Resources.Count() {
			Set tResource = ..Module.Resources.GetAt(i)
			If $IsObject(tResource.Processor) {
				Set tSC = $$$ADDSC(tSC,tResource.Processor.OnPhase("Test",.pParams))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Note: This is a utility method, and not a full lifecycle phase at this point.
/// This method exports the module's resources, based on the mappings defined in ^Sources (by %Reload), to the specified directory.
/// If no directory is provided, a new temp directory is created (returned by reference).
/// If dependencies are to be exported, <var>pDependencyGraph</var> is augmented with a "Location" subscript
/// with the relative path within <var>pTargetDirectory</var> in which the module's contents have been exported.
Method %Export(ByRef pParams, ByRef pTargetDirectory As %String, Output pDependencyGraph) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		
		Kill pDependencyGraph
		If ($Get(pTargetDirectory) = "") {
			Set pTargetDirectory = $$$lcase(..Module.Name_"-"_..Module.VersionString)
			Set pTargetDirectory = ##class(%File).NormalizeDirectory(pTargetDirectory, $$$FileTempDir)
		}
		
		If '##class(%File).DirectoryExists(pTargetDirectory) {
			Kill %objlasterror
			Set tCreated = ##class(%File).CreateDirectoryChain(pTargetDirectory,.tReturnValue)
			If 'tCreated {
				Set tLastErr = $Get(%objlasterror)
				Set tSC = $$$EMBEDSC($$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",pTargetDirectory,tReturnValue)),tLastErr)
				Quit
			}
		}
		
		Set tSC = ..Module.GetResolvedReferences(.tResourceArray,..#EXPORTDEPENDENCIES,..PhaseList,1,.pDependencyGraph)
		If $$$ISERR(tSC) {
			Quit
		}
		
		// First pass: if we're exporting dependencies, build an array of modules from which we are deriving things.
		If ..#EXPORTDEPENDENCIES {
			Set tFullResourceName = ""
			For {
				Set tFullResourceName = $Order(tResourceArray(tFullResourceName))
				Quit:(tFullResourceName="")
				
				Set tExt = $Piece(tFullResourceName,".",*)
				Set tName = $Piece(tFullResourceName,".",1,*-1)
				If ($$$ucase(tExt) = "ZPM") {
					If (tName '= ..Module.Name) {
						Set pDependencyGraph(tName,"Location") = ".modules/"_tName_"/"
					}
				}
			}
		}
		
		Set tFullResourceName = ""
		For {
			Set tFullResourceName = $Order(tResourceArray(tFullResourceName),1,tSrcModule)
			If (tFullResourceName = "") {
				Quit
			}
			
			If $Get(tResourceArray(tFullResourceName,"Generated")) Continue
			
			Set tName = $Piece(tFullResourceName,".",1,*-1)
			Set tExt = $Piece(tFullResourceName,".",*)
			
			If '$Data(tResourceArray(tFullResourceName,"RelativePath"),tRelativePath) {
				Set tRelativePath = ..GetResourceRelativePath(tName,tExt)
			}

			If $Get(tResourceArray(tFullResourceName,"Preload")) {
				Set tRelativePath = "preload/"_tRelativePath
			}
			
			If (tExt = "ZPM") && (tName '= ..Module.Name) {
				Set tRelativePath = pDependencyGraph(tName,"Location")_tRelativePath
			} ElseIf (tSrcModule '= "") && (tSrcModule '= ..Module.Name) {
				Set tRelativePath = pDependencyGraph(tSrcModule,"Location")_tRelativePath
			}
			
			Set tFullPath = ##class(%File).NormalizeFilenameWithSpaces(pTargetDirectory_tRelativePath)
			
			#dim tProcessor As %ZPM.PackageManager.Developer.Processor.Abstract
			If $Data(tResourceArray(tFullResourceName,"Processor"),tProcessor) && $IsObject(tProcessor) {
				Kill tItemParams
				Merge tItemParams = tResourceArray(tFullResourceName)
				Set tItemHandled = 0
				Set tSC = tProcessor.OnExportItem(tFullPath,tFullResourceName,.tItemParams,.pParams,.tItemHandled)
				If $$$ISERR(tSC) {
					Quit
				}
				If tItemHandled {
					Continue
				}
			}
			
			If ($Extract(tFullResourceName) = "/") {
				// Resources with paths are relative to the module root and are simply copied to the export directory.
				Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tSrcModule,,.tSC)
				If $$$ISERR(tSC) {
					Quit
				}
				
				If (tModule.Root = "") {
					Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("No module root configured for '%1'",tSrcModule))
					Quit
				}
				
				If '##class(%File).DirectoryExists(tModule.Root) {
					Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Directory %2, listed as root for module '%1', does not exist.",tSrcModule,tModule.Root))
					Quit
				}
				
				Set tSourcePath = ##class(%File).NormalizeFilenameWithSpaces(tModule.Root_tFullResourceName)
				Set tExportPath = ##class(%File).NormalizeFilenameWithSpaces(tFullPath_tFullResourceName)
				Set tSC = $$$OK
				Set tDirectory = ##class(%File).GetDirectory(tExportPath,1)
				If '##class(%File).DirectoryExists(tDirectory) {
					Set tGood = ##class(%File).CreateDirectoryChain(tDirectory,.tReturn)
					If 'tGood {
						Set tLastErr = $Get(%objlasterror)
						Set tSC = $$$EMBEDSC($$$ERROR($$$GeneralError,$$$FormatText("Error creating directory '%1': %2",tDirectory,tReturn)),tLastErr)
						Quit
					}
					Write:tVerbose !,"Created ",tDirectory
				}
				If ##class(%File).DirectoryExists(tSourcePath) {
					// NOTE: Does not overlay directories.
					Set tSourcePath = ##class(%File).NormalizeDirectory(tSourcePath)
					Set tExportPath = ##class(%File).NormalizeDirectory(tExportPath)
					Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(tSourcePath,tExportPath)
					If $$$ISERR(tSC) {
						Quit
					}
					Write:tVerbose !,tSourcePath," -> ",tExportPath
				} ElseIf ##class(%File).Exists(tSourcePath) {
					Set tGood = ##class(%File).CopyFile(tSourcePath,tExportPath,1,.tReturn)
					If 'tGood {
						Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying file '%1' to '%2': %3",tSourcePath,tExportPath,tReturn))
						Quit
					}
					Write:tVerbose !,tSourcePath," -> ",tExportPath
				}
			} ElseIf (tExt = "CLS") || (tExt = "PRJ") || ($ZConvert($Extract(tFullPath,$length(tFullPath)-2,*),"l")="xml") || (##class(%RoutineMgr).UserType(tFullResourceName)) {
				If '$$$FileExists(tFullPath) {
					Do ##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(tFullPath))
				}
				Write:tVerbose !,"Exported ",tFullResourceName," to ",tFullPath
				Set tSC = $$Export^%occXMLExport(tFullPath,"-d",tFullResourceName)
			} Else {
				Write:tVerbose !,"Exported '",tFullResourceName,"' to ",tFullPath
				Set tSC = $$Export^%apiRTN(tFullResourceName,tFullPath)
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

Method %Package(ByRef pParams) As %Status [ Abstract ]
{
	Set tSC = $$$OK
	Try {
		// TODO: Implement
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Register(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {

		Set tVerbose = $Get(pParams("Verbose"))
		// "Register" just means "Publish to the local repository"
		Set tServer = ##class(%ZPM.PackageManager.Client.LocalServerDefinition).SingletonOpen(1)
    #; Don't care, no local cache, do not register there
    Quit:'$IsObject(tServer)

		Set tIsApplication = ..%IsA("%ZPM.PackageManager.Developer.Lifecycle.Application")
		
		Set tPublishClient = tServer.GetPublishService()
		Set tModule = $Select(tIsApplication:##class(%ZPM.PackageManager.Core.Application).%New(),1:##class(%ZPM.PackageManager.Core.Module).%New())
		Set tModule.Name = ..Module.Name
		If (0 && '..Module.IsLocked()) {
			Set tSC = ..Module.Lock()
			$$$ThrowOnError(tSC)
		}
		Set tModule.VersionString = ..Module.VersionString
		Set tSC = ..Module.XMLExportToStream(tModule.Manifest)
		$$$ThrowOnError(tSC)
		Set tSC = tModule.Payload.CopyFromAndSave(..Payload)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If tIsApplication {
			Do tPublishClient.PublishApplication(tModule)
		} Else {
			Do tPublishClient.PublishModule(tModule)
		}
		
		If $$$ISOK(tSC) {
			Write:tVerbose !,..Module.Name," ",..Module.VersionString," registered to local cache."
		}
	} Catch e {
		If (e.Name["ZSOAP") {
			Set tSC = $Get(%objlasterror,e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

Method %Verify(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set tInitNS = $Namespace
		Set tVerbose = $Get(pParams("Verbose"))
		
		// Create namespace in which to run tests and switch to it.
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Build).InitializeNamespace("VERIFY",tVerbose,.tNewNamespace))
		
		// Map ^UnitTest* from its home in the original namespace to the VERIFY namespace.
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Build).MapGlobalEquivalently("UnitTest*",tInitNS,tNewNamespace))
		
		// Install this module artifact in the VERIFY namespace.
		Write:tVerbose !,"Installing ",..Module.Name," ",..Module.VersionString," in namespace ",tNewNamespace
		Set $Namespace = tNewNamespace
		Set tTmpStream = ##class(%Stream.FileBinary).%New()
		Do tTmpStream.CopyFromAndSave(..Payload)
		Merge tParams = pParams
		Set tParams("Reload","ForceLocalScope") = 1
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Utils).LoadModuleFromArchive(..Module.Name,..Module.VersionString,tTmpStream,.tParams))
		
		#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
		For i=1:1:..Module.Resources.Count() {
			Set tResource = ..Module.Resources.GetAt(i)
			
			Set tHandled = 0
			If $IsObject(tResource.Processor) {
				Set tSC = $$$ADDSC(tSC,tResource.Processor.OnPhase("Verify",.pParams,.tHandled))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Publish(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tRelease = $Get(pParams("Release",0))
		Set tServer = ##class(%ZPM.PackageManager.Client.RemoteServerDefinition).DeploymentServerOpen(1,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tIsApplication = ..%IsA("%ZPM.PackageManager.Developer.Lifecycle.Application")
		
		Set tPublishClient = tServer.GetPublishService()
		Set tModule = $Select(tIsApplication:##class(%ZPM.PackageManager.Core.Application).%New(),1:##class(%ZPM.PackageManager.Core.Module).%New())
		Set tModule.Name = ..Module.Name
		If tRelease && ('..Module.IsLocked()) {
			Set tSC = ..Module.Lock()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		Set tSC = ..%Installer(.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tModule.VersionString = ..Module.VersionString
		Set tSC = ..Module.XMLExportToStream(tModule.Manifest)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = tModule.Payload.CopyFrom(..Payload)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = tModule.Installer.CopyFrom(..Installer)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If tIsApplication {
			Do tPublishClient.PublishApplication(tModule)
		} Else {
			Do tPublishClient.PublishModule(tModule)
		}
	} Catch e {
		If (e.Name["ZSOAP") {
			Set tSC = $Get(%objlasterror,e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

Method %Installer(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If ..Module.Name = "zpm" {
			Write !,"Build Installer for ", ..Module.Name
			Set tSC = ##class(%ZPM.Installer).Make(..Payload, ..Installer)
			If $$$ISERR(tSC) {
				Quit
			}
		}		
	} Catch e {
		Set tSC = e.AsStatus()
	}

	Quit tSC
}

/// Helper method to get the relative path to the *file* corresponding to a resource (used in %Reload/%Export).
/// If <var>pExtension</var> is empty, then <var>pResource</var> is interpreted as having an extension.
/// If <var>pExtension</var> is specified, then <var>pResource</var> is intrepreted as not having an extension.
/// Note: does not support .PKG
/// Note: does not yet support CSP/static files resources
Method GetResourceRelativePath(pResource As %String, pExtension As %String) As %String
{
	If ($Get(pExtension) = "") {
		Set tName = $Piece(pResource,".",1,*-1)
		Set tExtension = $Piece(pResource,".",*)
	} Else {
		Set tName = pResource
		Set tExtension = pExtension
	}
	
	// For static/CSP resources, this is handled separately.
	If ($Extract(pResource_pExtension) = "/") {
		Quit ""
	}

	// Intentionally does not support PKG - classes must be exported individually.
	Set tDirectory = $Case(tExtension,
		"ZPM":"",
		"LOC":"localize/",
		"INC":"inc/",
		"MAC":"mac/",
		"CLS":"cls/",
		"GBL":"gbl/",
		: $$$lcase(tExtension)_"/"
		)
		
	Set tFile = $Case(tExtension,
		"ZPM":"module.xml",
		"LOC":$tr(tName,".%","/")_".xml",
		"INC":$tr(tName,".%","/_")_".inc",
		"MAC":$tr(tName,".%","/_")_".mac",
		"CLS":$tr(tName,".%","/")_".cls",
		"GBL":$tr(tName,"%,("")","___")_".xml",
		"DFI":$tr(tName,"-","/")_".dfi",
		: tName _ "." _$$$lcase(tExtension)
		)
	
	Quit tDirectory_tFile
}

ClassMethod GetBaseClassForPackaging(pPackaging As %String, Output pBaseClass As %Dictionary.CacheClassname) As %Status [ Final ]
{
	Set tSC = $$$OK
	Set pBaseClass = ""
	Try {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,
			"select BaseClass from %ZPM_PackageManager_Developer_Lifecycle.Base_Packaging(?)",
			pPackaging)
		If (tRes.%SQLCODE < 0) {
			$$$ThrowStatus($$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message))
		}
		
		If tRes.%Next(.tSC) {
			Set pBaseClass = tRes.%Get("BaseClass")
		}
		$$$ThrowOnError(tSC)
		
		// TODO: Error if no results?
	} Catch e {
		Set pBaseClass = ""
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Query Packaging(pPackaging As %String = "") As %SQLQuery [ Final, SqlProc ]
{
	select cp._default as Packaging, cd.Name as BaseClass
	from %Dictionary.CompiledClass cd
	join %Dictionary.CompiledParameter cp
	on cp.Parent = cd.Name
		and cp.Name = 'PACKAGING'
	where cd.Name %STARTSWITH '%ZPM.PackageManager.Developer.Lifecycle' -- This is a critical assumption for performance reasons. Full ^oddCOM scans are expensive!
		and cd.PrimarySuper [ '~%ZPM.PackageManager.Developer.Lifecycle.Abstract~'
		and cp.Final = 1
		and cp.Origin = cd.Name
		and (:pPackaging is null or cp._default = :pPackaging)
}

}
