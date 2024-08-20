Include %occErrors

Class %ZPM.PackageManager.Developer.Lifecycle.Base Extends %ZPM.PackageManager.Developer.Lifecycle.Abstract [ Abstract ]
{

Parameter PHASES = {$ListBuild("Clean","Reload","*","Validate","ExportData","Compile","Activate","Document","MakeDeployed","Test","Package","Verify","Register","Publish","Configure","Unconfigure")};

Property Payload As %Stream.Object [ Private ];

Property Installer As %Stream.TmpCharacter [ Private ];

Parameter EXPORTDEPENDENCIES As BOOLEAN = 0;

Parameter DEPLOYBYDEFAULT As BOOLEAN = 0;

Parameter PACKAGING [ Abstract ];

Property HasDeployedResources As %Boolean [ InitialExpression = 0 ];

/// This method defines what a complete phase means for a given list of phases
ClassMethod GetCompletePhases(pPhases As %List) As %List
{
	For i=1:1:$ListLength(pPhases) {
		Set tPhasesList = ..GetCompletePhasesForOne($List(pPhases,i))
		For j=1:1:$ListLength(tPhasesList) Set one = $List(tPhasesList,j) If one'="" Set tPhasesArray(one) = ""
	}
	Set tResultingPhases = ""
	For i=1:1:$ListLength(..#PHASES) {
		Set one = $List(..#PHASES,i) If $Data(tPhasesArray(one)) Set tResultingPhases = tResultingPhases_$ListBuild(one)
	}
	Quit tResultingPhases
}

/// This method defines what a complete phase means for a given phase
ClassMethod GetCompletePhasesForOne(pOnePhase As %String) As %List
{
	Quit $Case(pOnePhase,
		"Clean":		$ListBuild("Clean"),
		"Reload":		$ListBuild("Reload","*"),
		"Validate":		$ListBuild("Reload","*","Validate"),
		"ExportData":	$ListBuild("ExportData"),
		"Compile":		$ListBuild("Reload","*","Validate","Compile"),
		"Activate":		$ListBuild("Reload","*","Validate","Compile","Activate"),
		"Document":		$ListBuild("Document"),
		"MakeDeployed":	$ListBuild("MakeDeployed"),
		"Test":			$ListBuild("Reload","*","Validate","Compile","Activate","Test"),
		"Package":		$ListBuild("Reload","*","Validate","Compile","Activate","Package"),
		"Verify":		$ListBuild("Reload","*","Validate","Compile","Activate","Package","Verify"),
		"Register":		$ListBuild("Reload","*","Validate","Compile","Activate","Package","Register"),
		"Publish":		$ListBuild("Reload","*","Validate","Compile","Activate","Package","Register","Publish"),
		"Configure":	$ListBuild("Configure"),
		"Unconfigure":	$ListBuild("Unconfigure"),
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

Method Log(pMessage As %String = "", pValues...)
{
  If pMessage'="" {
    Write !,"[", $Namespace, "|", ..Module.Name, "]", $Char(9), $$FormatText^%occMessages(pMessage, pValues...)
  }
}

Method CheckBeforeClean(ByRef pParams, Output pSkip As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tLevel = $Get(pParams("Clean","Level"),0)
		Set tRecurse = $Get(pParams("Clean","Recurse"),1)
		
		If (..Module.GlobalScope && '$Get(pParams("Clean","GlobalScope"))) {
			Do ..Log("Clean SKIPPED - module has global scope.")
			Set pSkip = 1
			Quit
		}
		
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
          Do ..Log("Clean SKIPPED - required by ",$ListLength(tModList)," other module",$Case($ListLength(tModList),1:"",:"s"),". (",$ListToString(tModList,"; "),")")
					Set pSkip = 1
					Quit
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If pSkip {
		Set pParams("Clean","Skip",..Module.Name) = ""
	}
	Quit tSC
}

Method %Clean(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pParams("Clean","Cycle",..Module.Name) = ""
		
		Set tVerbose = $Get(pParams("Verbose"))
		Set tLevel = $Get(pParams("Clean","Level"),0)
		Set tRecurse = $Get(pParams("Clean","Recurse"),1)
		Set tRemoveMapped = $Get(pParams("Clean","GlobalScope"),0)
		
		// Create an instance of the repository manager singleton
		// This makes it available at lower stack levels, which helps
		// to avoid significant duplicate work in dependency resolution.
		Set tRepositoryManager = ##class(%ZPM.PackageManager.Client.Manager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		Set tSC = ..CheckBeforeClean(.pParams,.tSkip)
		$$$ThrowOnError(tSC)
		If (tSkip) {
			Quit
		}
		
		If (tLevel > 0) {
			Set tKey = ""
			For {
				#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
				Set tResource = ..Module.Resources.GetNext(.tKey)
				Quit:tKey=""
				
				If $IsObject(tResource.Processor) {
					Set tSC = tResource.Processor.OnPhase("Clean",.pParams,.tResourceHandled)
					$$$ThrowOnError(tSC)
					If (tResourceHandled) {
						Continue
					}
				}
				
				Kill tResourceChildren
				Do tResource.ResolveChildren(.tResourceChildren)
				Set tChildKey = ""
				For {
					Set tChildKey = $Order(tResourceChildren(tChildKey))
					Quit:tChildKey=""
				
					If ($Extract(tChildKey) = "/") {
						Continue
					}
					
					Set tName = $Piece(tChildKey,".",1,*-1)
					Set tExt = $Piece(tChildKey,".",*)
          Continue:tExt=""
          Continue:tName=""
					Set tDeleteArray(tExt,tName) = ""
				}
			}
			
			// Pass 1: non-projection classes
			// Pass 2: projection classes (extending %Projection.AbstractProjection)
			// This gives RemoveProjection a decent chance of working if other classes in the module define projections of that type.
			For tPass = 1,2 {
				If $Data(tDeleteArray("CLS")) {
					Kill tClassArray,tDeferArray
					Merge tClassArray = tDeleteArray("CLS")
					Set tClassKey = ""
					For {
						Set tClassKey = $Order(tClassArray(tClassKey))
						Quit:tClassKey=""
						
						If 'tRemoveMapped && ##class(%Library.RoutineMgr).IsMapped(tClassKey_".CLS") {
							Write !,"WARNING: Skipping mapped resource ",tClassKey,".CLS"
							Continue
						}
						
						Set tComClassDefined = $$$comClassDefined(tClassKey)
						If tComClassDefined || $$$defClassDefined(tClassKey) {
							// Test for (primary super) [ "~%Projection.AbstractProjection~" rather than $classmethod/%Extends to avoid <CLASS DOES NOT EXIST>
							If (tPass = 1) && tComClassDefined && ($$$comClassKeyGet(tClassKey,$$$cCLASSprimarysuper) [ "~%Projection.AbstractProjection~") {
								Set tDeferArray(tClassKey) = ""
								Continue
							}
							Set tDelSC = $System.OBJ.Delete(tClassKey,$Select(tVerbose:"d",1:"-d"))
							If $$$ISERR(tDelSC) {
								Write !,"WARNING: ",$System.Status.GetErrorText(tDelSC)
							}
						}
					}
					Kill tDeleteArray("CLS")
					Merge tDeleteArray("CLS") = tDeferArray
				}
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
						
						If 'tRemoveMapped && ##class(%Library.RoutineMgr).IsMapped(tFullName) {
							Write !,"WARNING: Skipping mapped resource ",tFullName
							Continue
						}
						
						Set tDelSC = ##class(%Library.RoutineMgr).Delete(tFullName)
						If $$$ISERR(tDelSC) {
							Write !,"WARNING: "_$System.Status.GetErrorText(tDelSC)
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
						Write !,"WARNING: "_$System.Status.GetErrorText(tModSC)
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

		If (..Module.InstallerClass '= "") {
			Set tVerbose = $Get(pParams("Verbose"),0)
      // getting custom parameters from command line or <Default> element
      Do ##class(%ZPM.PackageManager.Developer.ModuleSetting.Default).GetCustomParameters(.customParams,..Module, .pParams)
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
		// If %SourceControl has been set up by the caller (e.g., ^build), ensure that it does not interfere with resource reload.
		// (Sometimes %Studio.SourceControl.ISC will complain about files not being checked out.)
		New %SourceControl
		
		Set tModuleName = ..Module.Name
		Set tDeveloperMode = +$Get(pParams("DeveloperMode"),..Module.DeveloperMode)
		Set tSkipScoped = 'tDeveloperMode
		Set tVerbose = $Get(pParams("Verbose"))
		Set tRoot = $Get(pParams("RootDirectory"))
		If (tRoot = "") && tDeveloperMode {
			Set tRoot = ..Module.Root
		}
		
		// For now, no-op if no root is configured.
		Quit:tRoot=""
		
		Set tRoot = ##class(%File).NormalizeDirectory("",tRoot)
		Set tSC = $System.OBJ.Load(tRoot_"module.xml","/nodisplay",.error,.tLoadedList) Quit:$$$ISERR(tSC)
		
		// Validate loaded module
		Set first = $Order(tLoadedList(""))
		If (first = "") {
			Set tSC = $$$ERROR($$$GeneralError,"No module definition found.")
			Quit
		}
		If ($Order(tLoadedList(first)) '= "") {
			Set tSC = $$$ERROR($$$GeneralError,"module.xml is malformed.")
			Quit
		}
		Set first = $$$lcase(first)
    If ($Piece(first,".",*) '= "zpm") {
			Set tSC = $$$ERROR($$$GeneralError,"No module definition found.")
			Quit
		}
		If (tModuleName '= $Piece(first,".",1,*-1)) {
			Set tSC = $$$ERROR($$$GeneralError,"Module name mismatch.") Quit
		}

		#; Reopen, usefull in Packaging deployed modules
		Set ..Module = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModuleName,,.tSC)
		$$$ThrowOnError(tSC)

		// Set up mappings
		Set tKey = ""
		For {
			Set tMapping = ..Module.Mappings.GetNext(.tKey)
			Quit:tKey=""
			
			Set tName = $Piece(tMapping.Name,".",1,*-1)
			Set tExtension = $Piece(tMapping.Name,".",*)
			Set tSource = tMapping.Source
			
			Set tSC = $Case(tExtension,
				"GBL":##class(%ZPM.PackageManager.Developer.Utils).AddGlobalMapping($Namespace,tName,tSource),
				"INC":##class(%ZPM.PackageManager.Developer.Utils).AddRoutineMapping($Namespace,tName,"INC",tSource),
				"MAC":##class(%ZPM.PackageManager.Developer.Utils).AddRoutineMapping($Namespace,tName,"MAC",tSource),
				"PKG":##class(%ZPM.PackageManager.Developer.Utils).AddPackageMapping($Namespace,tName,tSource),
				"":##class(%ZPM.PackageManager.Developer.Utils).AddRoutineMapping($Namespace,tName,"ALL",tSource))
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}

    $$$ThrowOnError(..InstallPythonRequirements(tRoot, .pParams))
		
		Set tPreloadRoot = tRoot_"preload"
		If ##class(%File).DirectoryExists(tPreloadRoot) {
			Set tSC = $System.OBJ.ImportDir(tPreloadRoot, "*", $Select(tVerbose:"d",1:"-d")_"/compile" _ $Select($Tlevel:"/multicompile=0", 1: ""), , 1)
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
		
		If (..Module.Root '= tRoot) {
			If tVerbose {
				Write !,"Changing module root from '"_..Module.Root_"' to '"_tRoot_"'"
			}
			Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.Interface).%OnChangeModuleRoot(..Module)
			$$$ThrowOnError(tSC)
		}
		
		Set ..Module.DeveloperMode = tDeveloperMode
		Set ..Module.Root = tRoot
		$$$ThrowOnError(..Module.%Save())
		
		Set tGlobalScope = ..Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
		Set tAbsolutePrefix = $Char($Parameter("%ZPM.PackageManager.Developer.Extension.SourceControl.ISC","NOPREFIXCHARCODE"))
		
		// Ensures, for example, that HS.PM isn't mapped to ^Sources("ZPM","HS.PM")_"HS/module.xml"
		If tDeveloperMode {
			Set ^Sources = $Get(^Sources)
			Set ^Sources("ZPM","*","NoFolders")=1
			Set ^Sources("ZPM",..Module.Name) = tAbsolutePrefix_tRoot
		}
		
		// Standard resource processing
		Set tSC = $$$OK
		Set tKey = ""
		For {
			Set tResource = ..Module.Resources.GetNext(.tKey)
			Quit:tKey=""
			
			If $IsObject(tResource.Processor) {
				Set tSC = $$$ADDSC(tSC,tResource.Processor.OnPhase("Reload",.pParams))
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// call %OnModifyResources to let the source control class do any other mapping it needs to
		Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.Interface).%OnModifyResources(..Module)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method InstallPythonRequirements(pRoot As %String = "", ByRef pParams)
{
  Set cmd = $Get(pParams("cmd"))
  If '$ListFind($ListBuild("install", "load"), cmd) {
    Quit $$$OK
  }
  Set tVerbose = $Get(pParams("Verbose"))
  Set pythonRequirements = ##class(%File).NormalizeFilename("requirements.txt", pRoot)
  If '##class(%File).Exists(pythonRequirements) {
    Quit $$$OK
  }
  Set tSC = $$$OK
  Try {
    Do ..Log("requirements.txt START")
    Write:tVerbose !

    Set target = ##class(%File).NormalizeDirectory("python", $System.Util.ManagerDirectory())
    If '$System.CLS.IsMthd("%SYS.Python", "Import") {
        Throw ##class(%Exception.General).%New("Embedded Python is not available in this instance.")
    }
    Set tSysModule = ##class(%SYS.Python).Import("sys")
    Set tPyMajor = tSysModule."version_info".major
    Set tPyMinor = tSysModule."version_info".minor
    Set tPyMicro = tSysModule."version_info".micro
    Set tPyVersion = tPyMajor_"."_tPyMinor_"."_tPyMicro
    Set command = ..ResolvePipCaller(.pParams) _ $ListBuild("install", "-r", "requirements.txt", "-t", target, "--python-version", tPyVersion, "--only-binary=:all:")
    If 'tVerbose {
      Set stdout = ""
    }
    Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).RunCommand(pRoot, command,.stdout)
    $$$ThrowOnError(tSC)

    Do ..Log("requirements.txt SUCCESS")
  }
  Catch ex {
    Set tSC = ex.AsStatus()
    Do ..Log("requirements.txt FAILURE")
  }
  Quit tSC
}

Method ResolvePipCaller(ByRef pParams) As %List
{
	Set tUseStandalonePip = ##class(%ZPM.PackageManager.Client.Settings).GetValue("UseStandalonePip")
	Set tPipCaller = ##class(%ZPM.PackageManager.Client.Settings).GetValue("PipCaller")

	If tPipCaller '= "" {
		If tUseStandalonePip = 1 {
			Return $lb(tPipCaller)
		} ElseIf tUseStandalonePip = 0 {
			Return $lb(tPipCaller, "-m", "pip")
		} Else {
			Set msg = "Detected PipCaller=""" _ tPipCaller _ """ but UseStandalonePip is not properly set." _ $Char(13, 10)
			Set msg = msg _ "Please set UseStandalonePip to 1 (if using a pip executable) or 0 (if using a python executable)." _ $Char(13, 10)
			Set msg = msg _ "Example: zpm ""config set UseStandalonePip 1"""
			Throw ##class(%Exception.General).%New(msg)
		}
	}
	Return ..DetectPipCaller(tUseStandalonePip, $Get(pParams("Verbose"), 0))
}

Method DetectPipCaller(pUseStandalonePip As %Boolean, pVerbose As %Boolean = 0) As %List
{
	If pVerbose {
		Write !,"Detecting pip caller"
	}

	// First try to detect flexible python (in 2024.2 and later)
	// This is a hack that doesn't always work because the python interpreter may not be in the same directory as the so/dylib/dll.
	// In fact, the python interpreter executable, in theory, may not even exist at all!
	// What IRIS does it #include <Python.h> and then link against the dynamic library. This is independent of the python interpreter.
	If $System.CLS.IsMthd("%SYS.Python","GetPythonInfo") {
		If pVerbose {
			Write !, "Attempting to find flexible python... "
		}
		Do ##class(%SYS.Python).GetPythonInfo(.info)
		If $Data(info("CPF_PythonRuntimeLibrary"), tPyDylib) && tPyDylib {
			// TODO: try `../bin/python3` or `../bin/python` in case the .so is in subfolder `lib`
			// TODO: try to find `pip3` or `pip` if pUseStandalonePip is 1
			For filename = "python3", "python" {
				Set tInterpreter = ##class(%File).GetDirectory(tPyDylib, 1) _ filename
				If $$$isWINDOWS {
					Set tInterpreter = tInterpreter_".exe"
				}
				If ##class(%File).Exists(tInterpreter) {
					If pVerbose {
						Write "Success!"
					}
					Return $lb(tInterpreter, "-m", "pip")
				}
				If pVerbose {
					Write "Not Found"
				}
			}
		}
	}

	// For windows, try to find irispip.exe (in 2024.1 and earlier)
	If $$$isWINDOWS {
		If pVerbose {
			Write !, "Attempting to find irispip.exe..."
		}
		Set irispip = ##class(%File).NormalizeFilename("irispip.exe", $System.Util.BinaryDirectory())
		If ##class(%File).Exists(irispip) {
			If pVerbose {
				Write "Success!"
			}
			Return $lb(irispip)
		}
		If pVerbose {
			Write "Not Found"
		}
	}

	Set flags = "/SHELL/LOGCMD/STDOUT=""DetectPipCaller.log""/STDERR=""DetectPipCaller.err"""
	// Unless UseStandalonePip is set to 1, try to find python3 or python
	If pUseStandalonePip '= 1 {
		If pVerbose {
			Write !, "Attempting to find python3 or python..."
		}
		For cmd = "python3", "python" {
			If $$$isWINDOWS {
				Set cmd = cmd _ ".exe"
			}
			Kill args
			Set args($I(args)) = "-m"
			Set args($I(args)) = "pip"
			Set retCode = $ZF(-100, flags, cmd, .args)
			If retCode = 0 {
				If pVerbose {
					Write "Success!"
				}
				Return $lb(cmd, "-m", "pip")
			}
			If pVerbose {
				Write "Not Found"
			}
		}
	}

	// Unless UseStandalonePip is set to 0, try to find pip3 or pip
	If pUseStandalonePip '= 0 {
		If pVerbose {
			Write !, "Attempting to find pip3 or pip..."
		}
		For cmd = "pip3", "pip" {
			If $$$isWINDOWS { 
				Set cmd = cmd _ ".exe" 
			}
			Set retCode = $ZF(-100, flags, cmd)
			If retCode = 0 {
				Write "Success!"
				Return $lb(cmd)
			}
			If pVerbose {
				Write "Not Found"
			}
		}
	}

	Throw ##class(%Exception.General).%New("Could not find a suitable pip caller. Consider setting UseStandalonePip and PipCaller")
}

Method %Validate(ByRef pParams) As %Status
{
	// NOTE: Resource processor classes and their attributes are validated in OnBeforePhase,
	// so Validate isn't totally pointless.
	Quit $$$OK
}

Method %Compile(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tDevMode = $Get(pParams("DeveloperMode"),+..Module.DeveloperMode)
		
		// Setting $$$BuildFlag (a % variable) turns on storage checking, which will be handled/implemented by %SourceControl
		// if SourceControlCreate() defines it. (See OnAfterStorage method, which the composite extension passes along
		// to the primary source control class.)
		New $$$BuildFlag
		Set $$$BuildFlag = 1
		If tDevMode {
			// We only want to do this for the scope of the module in developer mode, so both variables are New'd here.
			New %SourceControl
			$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlCreate())
		}
		
		// Load dependencies correctly for the requested phases. (This will be a no-op in most cases.)
		Set tSC = ..Module.LoadDependencies(..PhaseList,.pParams)
		$$$ThrowOnError(tSC)
		
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
					$$$ThrowOnError(tSC)
					
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
					
					// Just copy the first level of subscripts (resource names), not all the gory details.
					Set tOneResourceKey = ""
					For {
						Set tOneResourceKey = $Order(tOneResourceList(tOneResourceKey))
						Quit:(tOneResourceKey="")
            Continue:('tDevMode)&&($Get(tOneResourceList(tOneResourceKey, "Deploy")))
						Set tCompileFlagMap(tFlags,tResource.Name,tOneResourceKey) = ""
					}
				}
			}
		}
		
		// Ensure there are no CompileAfter dependencies on resources absent from the module.
		Set tKey = ""
		For {
			Set tKey = $Order(tDependencyMap(tKey))
			Quit:tKey=""
			
			If '$Data(tCompilableMap(tKey)) {
				Set tCulprit = $Order(tDependencyMap(tKey,""))
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Resource '%1' cannot compile after nonexistent/non-compilable resource '%2'",tCulprit,tKey))
				$$$ThrowStatus(tSC)
			}
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
				
				Set tNoCompileLock = '$Get(pParams("NoLock"))
				If $$$IsISCWorker && 'tNoCompileLock {
					// Customized locking - takes out shared locks on dependencies to avoid conflicts between parallel module loads.
					Set tSC = ##class(%ZPM.PackageManager.Core.LockManager).LockClassesRecursive(.tLockManager,.tCompileArray,.tLockedClasses)
					$$$ThrowOnError(tSC)
					Set tNoCompileLock = 1
				}
				
				// Actually do the compile
				If $Data(tCompileArray)>1 {
					Set tCompiledSomething = 1
					Set tStruct = $Select(tVerbose:"d",1:"-d")_$Select(tNoCompileLock:"-l",1:"")_tFlags
					Set tSC = $System.OBJ.CompileList(.tCompileArray,.tStruct)
					$$$ThrowOnError(tSC)
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
			
			// Cycle detection
			If 'tCompiledSomething,'..HasDeployedResources {
				Set tFailedResources = ""
				Set tResource = ""
				For {
					Set tResource = $Order(tCompilableMap(tResource))
					Quit:tResource=""
					Set tFailedResources = tFailedResources_$ListBuild(tResource)
				}
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Failed to resolve compile order of module resources: %1",$ListToString(tFailedResources,", ")))
				$$$ThrowStatus(tSC)
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
		// Load dependencies correctly for the requested phases. (This will be a no-op in most cases.)
		Set tSC = ..Module.LoadDependencies(..PhaseList,.pParams)
		$$$ThrowOnError(tSC)
		
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
    Merge tParams = pParams

		Kill pDependencyGraph
		If ($Get(pTargetDirectory) = "") {
			Set pTargetDirectory = $$$lcase(..Module.Name_"-"_..Module.VersionString)
			Set pTargetDirectory = ##class(%File).NormalizeDirectory(pTargetDirectory, $$$FileTempDirSys)
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
    Set tParams("ModuleExportPath") = pTargetDirectory
		
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
			
			Set tFullPath = ##class(%File).NormalizeFilename(pTargetDirectory_tRelativePath)
			Set tFullPath = ##class(%File).NormalizeFilenameWithSpaces(tFullPath)
			
			#dim tProcessor As %ZPM.PackageManager.Developer.Processor.Abstract
			If $Data(tResourceArray(tFullResourceName,"Processor"),tProcessor) && $IsObject(tProcessor) {
				Kill tItemParams
				Merge tItemParams = tResourceArray(tFullResourceName)
				Set tItemHandled = 0
				Set tSC = tProcessor.OnExportItem(tFullPath,tFullResourceName,.tItemParams,.tParams,.tItemHandled)
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
				
				Set tSourcePath = ##class(%File).NormalizeFilename(tModule.Root_tFullResourceName)
				Set tSourcePath = ##class(%File).NormalizeFilenameWithSpaces(tSourcePath)
				Set tExportPath = ##class(%File).NormalizeFilename(tFullPath_tFullResourceName)
				Set tExportPath = ##class(%File).NormalizeFilenameWithSpaces(tExportPath)
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
					Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(tSourcePath,tExportPath, , tVerbose)
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
			} ElseIf (tExt = "CLS") || (tExt = "DFI") || (tExt = "PRJ") || ($ZConvert($Extract(tFullPath,$Length(tFullPath)-2,*),"l")="xml") || (##class(%RoutineMgr).UserType(tFullResourceName)) {
				If '##class(%File).Exists(tFullPath) {
					Do ##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(tFullPath))
				}
				Set tSC = $$Export^%occXMLExport(tFullPath,"-d /diffexport",tFullResourceName)
				$$$ThrowOnError(tSC)
				If tVerbose {
					Write !,"Exported to ",tFullPath
				}
			} Else {
				Set tSC = $$Export^%apiRTN(tFullResourceName,tFullPath,"","WNSK\UTF8\","-d /diffexport")
				$$$ThrowOnError(tSC)
				If tVerbose {
					Write !,"Exported to ",tFullPath
				}
			}
			$$$ThrowOnError(tSC)
		}

    /// Always keep these files
    Set staticFiles = $ListBuild(
      "readme.md",
      "license",
      "requirements.txt",
    )
    Set tRes = ##class(%File).FileSetFunc(..Module.Root)
    While tRes.%Next() {
      Continue:tRes.Type'="F"
      Continue:'$ListFind(staticFiles,$$$LOWER(tRes.ItemName))
      Set tSourcePath = tRes.Name
      Set tExportPath = ##class(%File).NormalizeFilename(tRes.ItemName, pTargetDirectory)
      Set tGood = ##class(%File).CopyFile(tSourcePath, tExportPath,1,.tReturn)
      If 'tGood {
        Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying file '%1' to '%2': %3",tSourcePath,tExportPath,tReturn))
        Quit
      }
      Write:tVerbose !,tSourcePath," -> ",tExportPath
    }
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %PrepareDeploy(ByRef pParams) As %Status [ Abstract ]
{
	Set tSC = $$$OK
	Try {
		// TODO: Implement
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
		Set tServer = ##class(%ZPM.PackageManager.Client.LocalServerDefinition).SingletonOpen(1,,.tSC)
		If $$$ISERR(tSC) {
      #; No local cache, ignoring
      Set tSC = $$$OK
			Quit
		}
		
		Set tIsApplication = ..%IsA("%ZPM.PackageManager.Developer.Lifecycle.Application")
		
		Set tPublishClient = tServer.GetPublishService()
		Set tModule = $Select(tIsApplication:##class(%ZPM.PackageManager.Core.Application).%New(),1:##class(%ZPM.PackageManager.Core.Module).%New())
		Set tModule.Name = ..Module.Name
		If (0 && '..Module.IsLocked()) {
			Set tSC = ..Module.Lock()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		Set tModule.VersionString = ..Module.VersionString
		Set tSC = ..Module.XMLExportToStream(tModule.Manifest)
		If $$$ISERR(tSC) {
			Quit
		}
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
    Set tInitNS = $Select($Namespace="%SYS": "USER", 1: $Namespace)
		Set tVerbose = $Get(pParams("Verbose"))
		
		If '$Get(pParams("Verify","InCurrentNamespace"),0) {
			Set tMustCreate = 1
			Set tMustLoad = 1
			Set tNewNamespace = tInitNS _ "-VERIFY"
      If $Get(pParams("Verify", "PreDeleteNamespace")) {
        Do ##class(%ZPM.PackageManager.Developer.Build).DeleteNamespace(tNewNamespace)
      }
			
			If $Get(pParams("Verify","Reuse"),0) || $Get(pParams("Verify","SkipLoad"),0) {
				Set tModuleExists = ##class(%ZPM.PackageManager.Developer.Utils).NamespaceHasModule(tNewNamespace,..Module.Name)
				If (tModuleExists) {
					// Permit the VERIFY namespace to be reused.
					Set tMustCreate = 0
					If $Get(pParams("Verify","SkipLoad"),0) {
						// Also, do not bother updating the module installed in the VERIFY namespace.
						Set tMustLoad = 0
					}
				}
			}
			
			If tMustCreate {
				// Create a new namespace and load the module in it.
				#dim tNSConfig As %ZPM.PackageManager.Developer.ModuleSetting.NamespaceConfig
				Set tNSConfig = ..Module.GetNamespaceConfig()
        Set tSysReqs = ..Module.SystemRequirements
        If $IsObject(tSysReqs), tSysReqs.Interoperability = "enabled" Set tNSConfig.EnableEnsemble = 1
				
				// Create namespace in which to run tests and switch to it.
				$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Build).InitializeNamespace("VERIFY",tVerbose,.tNewNamespace,tNSConfig))
				
				// Map ^UnitTest* from its home in the original namespace to the VERIFY namespace.
				$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Build).MapGlobalEquivalently("UnitTest*",tInitNS,tNewNamespace))
				
				// If the module being verified is not the package manager, map the package manager itself equivalently in the VERIFY namespace.
				If (..Module.Name '= "ZHSLIB") {
					$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Build).MapRoutineEquivalently("%ZPM*",tInitNS,,tNewNamespace))
					$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Build).MapPackageEquivalently("%ZPM",tInitNS,tNewNamespace))
				}
				
				// Map globals for %ZPM.PackageManager.Client.ServerDefinition and %ZPM.PackageManager.Client.Filesystem.Cache
				// from the original namespace to the VERIFY namespace
				For tClass = "%ZPM.PackageManager.Client.ServerDefinition","%ZPM.PackageManager.Client.Filesystem.Cache" {
					$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Build).MapClassDataEquivalently(tClass,tInitNS,tNewNamespace))
				}
				
				// Install this module artifact in the VERIFY namespace.
				Write:tVerbose !,"Installing ",..Module.Name," ",..Module.VersionString," in namespace ",tNewNamespace
				Merge tParams = pParams
				Set tParams("Reload","ForceLocalScope") = 1
				Set tParams("NoJournal") = 1 // Disable journaling (and therefore also transactions); the VERIFY namespace is a throwaway.
				// If we will enable Ensemble or HealthShare, default to single-threaded module load to avoid issues with mapping changes in parallel load.
				If tNSConfig.EnableEnsemble || tNSConfig.EnableHealthShare {
					Set tParams("Threads") = 1
				} Else {
					Merge tParams("Threads") = pParams("Verify","Threads")
				}
			}
			
			Set $Namespace = tNewNamespace
			
			If (tMustLoad) {
				Set tSC = ..OnBeforeVerifyLoad(.tParams)
				$$$ThrowOnError(tSC)
				If (..Payload.Size > 0) {
					// If we have a payload from the package phase, always use it.
					$$$ThrowOnError(..OnInstallFromPayload(.tParams))
				} Else {
					// Otherwise, try to install from the module root.
					Set tRoot = $Get(pParams("Verify","SourceDirectory"),..Module.Root)
					If (tRoot = "") {
						Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("No module root defined for module '%1'",..Module.Name))
						$$$ThrowStatus(tSC)
					}
					$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Utils).LoadModuleFromDirectory(tRoot,.tParams))
				}
			}
		}
		
		// Load dependencies correctly for the requested phases. (This will be a no-op in most cases.)
		Set tSC = ..Module.LoadDependencies(..PhaseList,.pParams)
		$$$ThrowOnError(tSC)
		
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

/// Allows for subclasses to do additional setup or modify pParams before the "verify" phase runs.
Method OnBeforeVerifyLoad(ByRef pParams) As %Status
{
	Quit $$$OK
}

Method OnInstallFromPayload(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tTmpStream = ##class(%Stream.FileBinary).%New()
		$$$ThrowOnError(tTmpStream.CopyFromAndSave(..Payload))
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Utils).LoadModuleFromArchive(..Module.Name,..Module.VersionString,tTmpStream,.pParams))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Publish(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tRelease = $Get(pParams("Release"),$Get(pParams("zpm","Release"),0))
		Set tPublishTo = $Get(pParams("PublishTo"),$Get(pParams("zpm","PublishTo"),""))
		Set tNewVersion = $Get(pParams("NewVersion"),$Get(pParams("zpm","NewVersion"),""))

		Set tServer =  ""
		If tPublishTo '= "" {
			Set tServer = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(tPublishTo,,.tSC)
		} Else {
			Set tRS = ##class(%ZPM.PackageManager.Client.RemoteServerDefinition).PublishingServerFunc()
			If (tRS.%SQLCODE = 0) && tRS.%Next() {
				Set tServer = ##class(%ZPM.PackageManager.Client.RemoteServerDefinition).%OpenId(tRS.ID)
			}
		}
		If $$$ISERR(tSC)||'$IsObject(tServer) {
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Not found server for publishing."))
		}
		If tVerbose {
			Write !,"Publish to: ", tServer.URL
		}
		
		If tNewVersion '= "" {
			Set tNewVersion = ##class(%ZPM.PackageManager.Core.SemanticVersion).FromString(tNewVersion)
		}
		
		Set tIsApplication = ..%IsA("%ZPM.PackageManager.Developer.Lifecycle.Application")
		
		Set tPublishClient = tServer.GetPublishService()
		If '$IsObject(tPublishClient) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' does not support publishing modules.",tServer.Name))
			$$$ThrowStatus(tSC)
		}
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
    If (..Module.Deployed) {
      Set tModule.Deployed = 1
      If $IsObject(..Module.SystemRequirements) {
        Set tModule.PlatformVersion = ..Module.SystemRequirements.VersionString
      }
    }
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
		
		// May need to update the version of the currently-installed module.
		If $Data(tNewVersion),$IsObject(tNewVersion) {
			Write:tVerbose !,"Version: ", tNewVersion.ToString()
			Set ..Module.Version = tNewVersion
			Set tSC = ##class(%ZPM.PackageManager.Developer.API).ExportDocumentForObject(..Module)
			$$$ThrowOnError(tSC)
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

Method %Document(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $Tlevel
	Try {
		Tstart
		// Clear out existing documentation for THIS module.
		Set tSC = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).EraseAnnotationDataForModule(..Module.Name)
		$$$ThrowOnError(tSC)
		
		// Recurse (unless told otherwise) to ensure documentation for dependencies is up to date.
		Set tModuleDependencies = ""
		If $Get(pParams("Document","Recurse"),1) {
			// Ensure that we only resolve dependencies once (to avoid duplicate effort)
			Set tSC = ..Module.BuildDependencyGraph(.tDependencyGraph)
			$$$ThrowOnError(tSC)
			
			// tDependencyGraph format:
			// tDependencyGraph(<module name>) = $ListBuild(<depth>, <server>, <version>)
			// tDependencyGraph(<module name>,<dependent module name>_" "_<version string>) = <required version expression>
			// <server> being empty means it's already installed.
			// All these modules need to already be installed.
			
			Set tModuleName = ""
			For {
				Set tModuleName = $Order(tDependencyGraph(tModuleName),1,tModuleInfo)
				If (tModuleName = "") {
					Quit
				}
				
				// Erase existing annotation data for the dependency, since we will later rebuild it (and there may be conflicts with existing data).
				Set tSC = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).EraseAnnotationDataForModule(tModuleName)
				$$$ThrowOnError(tSC)
				
				Set tDepth = $List(tModuleInfo)
				Set tServer = $List(tModuleInfo,2)
				If (tServer '= "") {
					Set tErrorMsg = $$$FormatText("Cannot build documentation for module '%1' because required module '%2' is not installed.",..Module.Name,tModuleName)
					$$$ThrowStatus($$$ERROR($$$GeneralError,tErrorMsg))
				}
				
				Set tDepthArray(tDepth) = $Get(tDepthArray(tDepth))_$ListBuild(tModuleName)
				
				Set tDependentModule = ""
				For {
					Set tDependentModule = $Order(tDependencyGraph(tModuleName,tDependentModule))
					If (tDependentModule = "") {
						Quit
					}
					
					Set tDependentModuleName = $Piece(tDependentModule," ") // Split out name from string with <name>_" "_<version>
					Set tModuleDependents(tModuleName) = $Get(tModuleDependents(tModuleName))_$ListBuild(tDependentModuleName)
					Set tModuleDependencies(tDependentModuleName,tModuleName) = ""
				}
			}
			
			// At this stage:
			// tModuleDependents(<module name>) has a $ListBuild list of names of module that depend on on <module name> directly
			// tModuleDependencies(<module name>) has subscripts with names of modules on which <module name> depends directly
			
			Set tDepth = ""
			For {
				Set tDepth = $Order(tDepthArray(tDepth),-1,tModuleList)
				If (tDepth = "") {
					Quit
				}
				
				// Ensure documentation is generated for dependency
				Set tPointer = 0
				While $ListNext(tModuleList,tPointer,tModuleName) {
					// Update modules dependent on tModuleName with their indirect dependencies
					// Because the outer loop starts with the lowest level of dependencies, this doesn't need to be recursive.
					Set tDependentPointer = 0
					Set tDependentList = $Get(tModuleDependents(tModuleName))
					While $ListNext(tDependentList,tDependentPointer,tDependentName) {
						// Modules dependent on this module also depend on things this module depends on.
						Merge tModuleDependencies(tDependentName) = tModuleDependencies(tModuleName)
					}
					
					// Build a list of all recursive dependencies for this module (just put array subscripts into a $ListBuild list)
					Set tSubDependencies = ""
					Set tSubDependency = ""
					For {
						Set tSubDependency = $Order(tModuleDependencies(tModuleName,tSubDependency))
						If (tSubDependency = "") {
							Quit
						}
						
						Set tSubDependencies = tSubDependencies_$ListBuild(tSubDependency)
					}
					
					// Kill tParams just in case a previous call to ExecutePhases modified it.
					Kill tParams
					Merge tParams = pParams
					Set tParams("Document","Recurse") = 0
					Set tParams("Document","Dependencies") = tSubDependencies
					Set tSC = ##class(%ZPM.PackageManager.Developer.Module).ExecutePhases(tModuleName,$ListBuild("Document"),,.tParams)
					$$$ThrowOnError(tSC)
					
					Set tModuleDependencies = tModuleDependencies_$ListBuild(tModuleName)
				}
			}
		} Else {
			Set tModuleDependencies = $Get(pParams("Document","Dependencies"))
		}
		
		// TODO: call ##class(%ZPM.PackageManager.Developer.Annotation.Utils).ProcessAnnotationsForModule directly and generate/update new document
		// (a subclass of %Studio.AbstractDocument)
		Set tSC = ..Module.UpdateAPIDocumentation(tModuleDependencies)
		$$$ThrowOnError(tSC)
		Tcommit
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($Tlevel > tInitTLevel) { Trollback 1 }
	Quit tSC
}

Method %MakeDeployed(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tDev = ..Module.DeveloperMode
		Set tVerbose = $Get(pParams("Verbose"))
		#; If tDev && tVerbose {
		#; 	Write !,"Module is in developer mode; will only report what WOULD be deployed."
		#; }
		
		// Default implementation: see which resources are expicitly flagged with Deploy = true.
		// Build an array of those, then mark them as deployed.
		$$$ThrowOnError(..Module.GetResolvedReferences(.tResourceArray,1,..PhaseList,1,.pDependencyGraph))
		If $$$ISERR(tSC) {
			Quit
		}

		Set tResourceKey = ""
		For {
			Set tResourceKey = $Order(tResourceArray(tResourceKey))
			Quit:(tResourceKey="")
			
			// Skip file resources - these are handled separately;
			// "deployment" is the responsibility of resource processor classes.
			If ($Extract(tResourceKey) = "/") {
				Continue
			}
			
			Kill tResourceInfo
			Merge tResourceInfo = tResourceArray(tResourceKey)
			// TODO: Refactor tResourceInfo to be an object.
			Set tResourceInfo("Name") = tResourceKey
			Set tSC = ..OnDetermineResourceDeployability(.pParams,.tResourceInfo,.tDeploy)
			$$$ThrowOnError(tSC)
			
			If tDeploy {
				Set tName = $Piece(tResourceKey,".",1,*-1)
				Set tExt = $$$ucase($Piece(tResourceKey,".",*))
				If (tExt = "CLS") {
					Set tDeployClassArray($Piece(tResourceKey,".",1,*-1)) = ""
				} ElseIf (tExt = "MAC") || (tExt = "INT") {
					Set tDeployRtnArray(tResourceKey) = ""
				} Else {
					// For other types, if deployment has meaning, the associated resource processor
					// class should handle it in OnBeforePhase/OnAfterPhase.
					Continue
				}
			}
		}
		
		If $Data(tDeployClassArray) {
			Set ..HasDeployedResources = 1
			If (tVerbose) {
				Set tClass = ""
				Write !,"The following classes are flagged for deployment:"
				#; Write !,"The following classes "_$Select(tDev:"would be flagged",1:"are flagged")_" for deployment:"
				For {
					Set tClass = $Order(tDeployClassArray(tClass))
					Quit:tClass=""
					Write !,$Char(9),tClass
				}
			}
			$$$ThrowOnError($System.OBJ.MakeClassDeployed(.tDeployClassArray))
		} ElseIf tVerbose {
			Write !,"No classes to mark as deployed."
		}
		If $Data(tDeployRtnArray) {
			Set ..HasDeployedResources = 1
      Set ..Module.Deployed = 1
      If '$IsObject(..Module.SystemRequirements) {
        Set ..Module.SystemRequirements = ##class(%ZPM.PackageManager.Developer.SystemRequirements).%New()
      }
      Set tSystemVersion = $System.Version.GetMajor() _ "." _ $System.Version.GetMinor()
      Set ..Module.SystemRequirements.VersionString = tSystemVersion
      $$$ThrowOnError(..Module.%Save())
			Set tRtn = ""
			If (tVerbose) {
				Write !,"The following routines are flagged for deployment:"
				#; Write !,"The following routines "_$Select(tDev:"would be flagged",1:"are flagged")_" for deployment:"
			}
			For {
				Set tRtn = $Order(tDeployRtnArray(tRtn))
				Quit:tRtn=""
				If tVerbose {
					Write !,$Char(9),tRtn
				}
				If 'tDev {
					$$$ThrowOnError(##class(%Routine).Delete(tRtn,2))
				}
			}
		} ElseIf tVerbose {
			Write !,"No routines to deploy."
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnDetermineResourceDeployability(ByRef pParams, ByRef pResourceInfo, Output pDeploy As %Boolean) As %Status
{
	Set tSC = $$$OK
	Try {
		If $Data(pParams("Deploy","Parameter"),tDeployParameter)#2 && (tDeployParameter '= "") {
			If ($Piece(pResourceInfo("Name"),".",*) = "CLS") {
				Set tClass = $Piece(pResourceInfo("Name"),".",1,*-1)
				If $$$comClassDefined(tClass) && $$$defMemberDefined(tClass,$$$cCLASSparameter,tDeployParameter) {
					// e.g., HSDEPLOY, HSAADEPLOY
					// This overrides the per-resource setting if defined, including if false.
					Set pDeploy = ($Parameter(tClass,tDeployParameter) = 1)
					Quit
				}
			}
		}
		
		// Note: if the Deploy setting is missing from the module manifest, pResourceInfo("Deploy") will be defined as ""
		If $Get(pResourceInfo("Deploy")) = "" {
			Set pDeploy = ..#DEPLOYBYDEFAULT
		} Else {
			Set pDeploy = pResourceInfo("Deploy")
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
		"X12":"i14y/",
		"HL7":"i14y/",
		"LUT":"i14y/",
		"ESD":"i14y/",
		"DTL":"cls/",
		"BPL":"cls/",
		: $$$lcase(tExtension)_"/"
		)
		
	Set tFile = $Case(tExtension,
		"ZPM":"module.xml",
		"LOC":$Translate(tName,".%","/")_".xml",
		"INC":$Translate(tName,".%","/_")_".inc",
		"MAC":$Translate(tName,".%","/_")_".mac",
		"CLS":$Translate(tName,".%","/")_".cls",
		"DTL":$Translate(tName,".%","/")_".cls",
		"BPL":$Translate(tName,".%","/")_".cls",
		"GBL":$Translate(tName,"%,("")","___")_".xml",
		"DFI":$Translate(tName,"-","/")_".dfi",
		: tName _ "." _$$$lcase(tExtension)
		)
	
	Quit tDirectory_tFile
}

ClassMethod GetBaseClassForPackaging(pPackaging As %String, Output pBaseClass As %Dictionary.Classname) As %Status [ Final ]
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
