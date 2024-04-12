Include %IPM.Common

Class %IPM.DependencyAnalyzer
{

/// Prefix to indentify .inc files.
Parameter INCPREFIX = "!!!INC.";

// Suffix for supported item types: .inc, .cls

Parameter INCSUFFIX = ".INC";

Parameter CLSSUFFIX = ".CLS";

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod RunForAllModules() As %Status
{
	Set tSC = $$$OK
	Set tOneSC = $$$OK
	Try {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,
			"select Name from %IPM_Storage.ModuleItem")
		If (tRes.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
		}
		While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Write !,"Processing: ",tRes.%Get("Name")
			Set tOneSC = $$$ADDSC(tOneSC,..RunForInvalidReferences(tRes.%Get("Name"),,0))
		}
		$$$ThrowOnError(tSC)
		
		// Report aggregated errors.
		Set tSC = tOneSC
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
/// pName: Name of the item that you want to run the dependency analyzer on to find all its references.
/// pReferences: multi-dim array of references in the input item, including  class/include files + module references
/// pVerbose: default to 1. If set to 1, references will be written to terminal / Studio output window
/// pProgressListener: Dependency analyzer socket for running deps
/// pRunID: ID of ModuleResults persistent class
/// pIgnoredStringRef: comma-separated string of string references that will be ignored. If set to $char(0), then will ignore all string references including classes.
/// pDirectDepsOnly: Include only direct dependencies rather than transitive ones as well.
ClassMethod RunForAllReferences(pName As %String, Output pReferences, pVerbose As %Boolean = 1, pSave As %Boolean = 1, pProgressListener = {$$$NULLOREF}, Output pRunID As %String, pIgnoredStringRef As %String = "", pDirectDepsOnly As %Boolean = 0) As %Status
{
	Set pRunID = ""
	Set tSC = $$$OK
	Try {
		// Now decide whether it's running for a module or just a single item
		Set tIsModule = (($$$lcase($Piece(pName,".",*)) '= "cls") && ($$$lcase($Piece(pName,".",*)) '= "inc"))
		If tIsModule {
			$$$ThrowOnError($$$ERROR($$$GeneralError, "Finding all references of a module is not supported. Please either specify an item with cls/inc extension, or try finding invalid references for a module."))
		}
		
		Do ..ValidateItemName(pName)
		Set tModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule($$$ucase(pName))
		If '$IsObject(tModule) {
			Write !, "No home module found for item: " _ pName ,!
			// set a placeholder module name for %pkg.isc.dependencyAnalyzer.ModuleResults's required property - it will not be used other than indexing
			Set tModuleName = $c(0)		
		} Else {
			Set tModuleName = tModule.Name
			Write !, "Found home module: "_tModuleName, !
		}
		
		// Find references for target item
		Do ..FindReferenceHelper(tIsModule, pName, 0, pProgressListener, pIgnoredStringRef, pDirectDepsOnly, .pReferences)
		
		// Represent results as objects
		Set tRun = $ClassMethod("%pkg.isc.dependencyAnalyzer.Utils", "PresentReferenceAsObject", tModuleName, 0, .pReferences)
		
		If pSave {
			$$$ThrowOnError(tRun.%Save())
			Set pRunID = tRun.%Id()
		}
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.PopStage()
		}
		
		If pVerbose {
			Do tRun.Display()
		}
	} Catch e {
		Set tSC = e.AsStatus()
		If pVerbose {
			Write !,$System.Status.GetErrorText(e.AsStatus())
		}
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
/// pName: Name of the module / item that you want to run the dependency analyzer on, to find all invalid references. If no extension is specified, it will be recognized as a module
/// pInvalidReferences: multi-dim array of invalid references in the input module / item, including missing class/include files + missing module references
/// pVerbose: default to 1. If set to 1, invalid references will be written to terminal / Studio output window
/// pProgressListener: Dependency analyzer socket for running deps
/// pRunID: ID of ModuleResults persistent class
/// pIgnoredStringRef: comma-separated string of string references that will be ignored. If set to $char(0), then will ignore all string references including classes.
/// pDirectDepsOnly: Include only direct dependencies rather than transitive ones as well.
ClassMethod RunForInvalidReferences(pName As %String, Output pInvalidReferences, pVerbose As %Boolean = 1, pSave As %Boolean = 1, pProgressListener = {$$$NULLOREF}, Output pRunID As %String, pIgnoredStringRef As %String = "", pDirectDepsOnly As %Boolean = 0) As %Status
{
	Set pRunID = ""
	Set tSC = $$$OK
	Try {
		// Now decide whether it's running for a module or just a single item
		Set tIsModule = (($$$lcase($Piece(pName,".",*)) '= "cls") && ($$$lcase($Piece(pName,".",*)) '= "inc"))
		Set tModuleName = pName
		If 'tIsModule {
			Do ..ValidateItemName(pName)
			Set tModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule($$$ucase(pName))
			If '$IsObject(tModule) {
				$$$ThrowOnError($$$ERROR($$$GeneralError, "To find invalid references in item "_pName_", it has to belong to an existing module."))
			}
			Set tModuleName = tModule.Name
			Write !, "Found home module: "_tModuleName ,!
		}
 
		// Find references for target module / item
		Do ..FindReferenceHelper(tIsModule, pName, 1, pProgressListener, pIgnoredStringRef, pDirectDepsOnly, .pInvalidReferences)
		
		// Represent results as objects
		Set tRun = $ClassMethod("%pkg.isc.dependencyAnalyzer.Utils","PresentReferenceAsObject", tModuleName, 1, .pInvalidReferences)
		
		If pSave {
			$$$ThrowOnError(tRun.%Save())
			Set pRunID = tRun.%Id()
		}
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.PopStage()
		}
		
		If pVerbose {
			Do tRun.Display()
		}
	} Catch e {
		Set tSC = e.AsStatus()
		If pVerbose {
			Write !,$System.Status.GetErrorText(e.AsStatus())
		}
	}
	Quit tSC
}

/// Find all references for all resources in module / for the specified item. If pInvalidOnly = 1 (default), then only look for invalid references. Else look for all references
/// pIsModule: Whether or not we are running for a whole module or for a single item
/// pName: When pIsModule = 0, specifies the name of the target item. Else, specifies the name of the module
/// pInvalidOnly: Whether or not only look for invalid references. Default to 1
/// pIgnoredStringRef: Comma-separated string of string references that will be ignored. If set to $char(0), then will ignore all string references including classes.
/// pDirectDepsOnly: Include only direct dependencies rather than transitive ones as well.
/// pReferences: Output multidim references
ClassMethod FindReferenceHelper(pIsModule As %Boolean, pName As %String = "", pInvalidOnly As %Boolean = 1, pProgressListener = {$$$NULLOREF}, pIgnoredStringRef As %String, pDirectDepsOnly As %Boolean = 0, Output pReferences) [ Internal ]
{
  #dim tModule As %IPM.Storage.Module
	Set tModuleName = pName
	// tModule will only be used when running for a module, or running to find invalid references
	If 'pIsModule {
		Set tModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule($$$ucase(pName))
		If '$IsObject(tModule) {
			Write !, "No home module found for item: " _ pName_". Non-module item should have item-type extension.", !
			If pInvalidOnly {
				$$$ThrowOnError($$$ERROR($$$GeneralError, "To find invalid references in item "_pName_", it has to belong to an existing module."))
			}
		} Else {
			Set tModuleName = tModule.Name
		}
	} Else {
		Set tModule = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
		$$$ThrowOnError(tSC)
	}
	
	// Build dependency graph only when looking for invalid references, 
	// so that we can test if resources are coming from a dependent module.
	If pInvalidOnly {
		If $IsObject(pProgressListener) {
			Do pProgressListener.PushStage("Collecting Dependencies")
		}
    Do ..GetDependenciesForModule(tModule, pDirectDepsOnly, .tDependencies)
		// Include this module in the list
		Set tDependencies(tModuleName) = ""
		If $IsObject(pProgressListener) {
			Do pProgressListener.PopStage()
	  }
  }
	
	// Get packages in %SYS
	Do ..GetSysPackageNames(.tSYSPackages)
	// Accumulate package names in current namespace into a temp global
	// Do accumulation once for performance rather than repeating accumulation
	Do $ClassMethod("%pkg.isc.dependencyAnalyzer.Utils", "AccumulatePackageNamesInCurrentNamespace")
 
	// Parallelize search
	#dim tQueue As %SYSTEM.WorkMgr
	Set tQueue = $System.WorkMgr.Initialize(,.tSC)
	$$$ThrowOnError(tSC)
	
	// Aggregate results from workers in IRISTEMP
	Set tNextCounter = $$$ZPMDependencyTempDataNext
	Kill $$$ZPMDependencyTempData(tNextCounter)
	
	If $IsObject(pProgressListener) {
		Do pProgressListener.PushStage("Scanning classes in module")
	}
	Set tClassCount = 0
	
	// If we are running for a module, get references for all module resources
	If pIsModule {
		Set tResourceKey = ""
		For {
			#dim tResource As %IPM.Storage.ResourceReference
			Set tResource = tModule.Resources.GetNext(.tResourceKey)
			If (tResourceKey = "") {
				Quit
			}
			
			Kill tResourceArray
			Set tSC = tResource.ResolveChildren(.tResourceArray)
			$$$ThrowOnError(tSC)
			
			Set tChildKey = ""
				For {
					Set tChildKey = $Order(tResourceArray(tChildKey))
					
					If (tChildKey = "") {
						Quit
					}
					
					// Skips generated classes, stub classes
					If $Get(tResourceArray(tChildKey,"Generated"),0) {
						Continue
					}
					Set tExt = $$$ucase($Piece(tChildKey,".",*))
					If (tExt = "CLS") {
						Set tClass = $Piece(tChildKey,".",1,*-1)
						// Queue search of class
						Set tSC = tQueue.QueueCallback("##class(%pkg.isc.dependencyAnalyzer.Utils).ExtractClassReferencesToName","##class(%pkg.isc.dependencyAnalyzer.Utils).ClassExtractionComplete",tClass,tNextCounter,pProgressListener,pIgnoredStringRef)
						$$$ThrowOnError(tSC)
						Set tClassCount = tClassCount + 1
					} ElseIf (tExt = "INC") {
						Set tClass = $Piece(tChildKey,".",1,*-1)
						// Queue search of include file
						Set tSC = tQueue.QueueCallback("##class(%pkg.isc.dependencyAnalyzer.Utils).ExtractIncludeReferencesToName","##class(%pkg.isc.dependencyAnalyzer.Utils).ClassExtractionComplete",tClass,tNextCounter,pProgressListener,pIgnoredStringRef)
						$$$ThrowOnError(tSC)
						Set tClassCount = tClassCount + 1
					}
				}
		}
	// else if running for only one item (Class or Include file), simple run that this specific one
	} Else {
			Set tExt = $$$ucase($Piece(pName,".",*))
			If (tExt = "CLS") {
				Set tClass = $Piece(pName,".",1,*-1)
				// Queue search of class
				Set tSC = tQueue.QueueCallback("##class(%pkg.isc.dependencyAnalyzer.Utils).ExtractClassReferencesToName","##class(%pkg.isc.dependencyAnalyzer.Utils).ClassExtractionComplete",tClass,tNextCounter,pProgressListener, pIgnoredStringRef)
				$$$ThrowOnError(tSC)
				Set tClassCount = 1
			} ElseIf (tExt = "INC") {
				Set tClass = $Piece(pName,".",1,*-1)
				// Queue search of include file
				Set tSC = tQueue.QueueCallback("##class(%pkg.isc.dependencyAnalyzer.Utils).ExtractIncludeReferencesToName","##class(%pkg.isc.dependencyAnalyzer.Utils).ClassExtractionComplete",tClass,tNextCounter,pProgressListener, pIgnoredStringRef)
				$$$ThrowOnError(tSC)
				Set tClassCount = 1
			}
	}
 
	If $IsObject(pProgressListener) {
		Do pProgressListener.SetStageTotalUnits(tClassCount)
	}
	Set tSC = tQueue.WaitForComplete()
	$$$ThrowOnError(tSC)
	If $IsObject(pProgressListener) {
		Do pProgressListener.PopStage()
		Do pProgressListener.PushStage("Checking module/item references.")
		Set tClassCount = 0
		Set tReferenceKey = ""
		For {
			Set tReferenceKey = $Order($$$ZPMDependencyTempData(tNextCounter,tReferenceKey))
			If (tReferenceKey = "") {
				Quit
			}
			Set tClassCount = tClassCount + 1
		}
		Do pProgressListener.SetStageTotalUnits(tClassCount)
	}
	// iterate through classes/include files detected and find home modules (or omit if it's a library class/library include file)
	Set tReferenceKey = ""
	For {
		Set tReferenceKey = $Order($$$ZPMDependencyTempData(tNextCounter,tReferenceKey))
		If (tReferenceKey = "") {
			Quit
		}
		// Track this beforehand because of all the "continue"s.
		If $IsObject(pProgressListener) {
			Do pProgressListener.NotifyUnitCompleted(tReferenceKey)
		}
		// tRawFileName is the file name without file type suffix
		// Keep tReferenceKey untouched since it is used in $Order
		Set tRawFileName = tReferenceKey
		Set tTopPackage = $Piece(tRawFileName,".")	
		Set tIsCLSFile = 1
		Set tIsINCFile = 0
		Set tFileType = ..#CLSSUFFIX
		If (tTopPackage = $Piece(..#INCPREFIX, ".")) {
			Set tIsCLSFile = 0
			Set tIsINCFile = 1
			Set tFileType = ..#INCSUFFIX
			//remove prefix from include files
			Set tTopPackage = $Piece(tReferenceKey, ".", 2)
			Set tRawFileName = $Piece(tReferenceKey, ".", 2, *)
		}
		// If tTopPackage happens to be empty, skip it rather than hitting <SUBSCRIPT> below. (Some weird code using macros for package names causes this right now.)
		If (tTopPackage = "") {
			Continue
		}
		
		// Special cases: skip packages in %SYS assuming methods using them run in %SYS or they are % packages always available.
		If (tIsCLSFile && $Data(tSYSPackages(tTopPackage))) {
			Continue
		}	
 
		Set tMissingInc = tIsINCFile && '##class(%Library.Routine).Exists(tRawFileName)
		Set tMissingClass = tIsCLSFile && '##class(%Dictionary.CompiledClass).%ExistsId(tRawFileName) && '##class(%Dictionary.ClassDefinition).%ExistsId(tRawFileName)
		If (tMissingInc || tMissingClass)  {	
			// This is its own sort of issue - the class doesn't exist!
			Merge pReferences($Char(0),tRawFileName, tFileType) = $$$ZPMDependencyTempData(tNextCounter,tReferenceKey)
			Continue
		}
 
		// Do not flag references to non-%Z* % classes (making an exception for %ZEN), %IPM or Ens* package classes.
		// For class file, we check for the presence of at least one "."
		If (tIsCLSFile && $Match(tRawFileName,"^(%([^Z]|IPM|ZEN)|Ens([^.])*)\.(.)*$")) {
			Continue
		}
		
		// For include file, no need to check for the presence of at least one "." For instance, %IPM(.inc), EnsUI(.inc), %ZHS.OAuth2(.inc)
		If (tIsINCFile && $Match(tRawFileName,"^(%([^Z]|IPM|ZEN)|Ens([^.])*)(.)*$")) {
			Continue
		}	
		
		Set tHomeModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule(tRawFileName_tFileType)
			
		// Skipping files whose home module is presented in the module dependency graph.
		// If looking for all references, tDependencies will only contain nothing so will not skip any reference
		If $IsObject(tHomeModule) && $Data(tDependencies(tHomeModule.Name)) {
			Continue
		}
 
		If tIsCLSFile {
			// The class may also be generated by another class in the module.
			// Example: HS.Data.OIDMapIdentityCodeAliases generated by HS.Data.OIDMap
			Set tGeneratedBy = $$$comClassKeyGet(tRawFileName,$$$cCLASSgeneratedby)
			If (tGeneratedBy '= "") && ($$$comClassKeyGet(tRawFileName,$$$cCLASSdeployed) = 2) {
				Set tHomeModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule(tGeneratedBy)
				If $IsObject(tHomeModule) && $Data(tDependencies(tHomeModule.Name)) {
					Continue
				}
			}
		}
		
			
		Set tHomeModuleName = $Char(0)
		If $IsObject(tHomeModule) {
			Set tHomeModuleName = tHomeModule.Name
		}
		If pIsModule || ('pIsModule && ($ZConvert(tRawFileName_tFileType,"U") '= $ZConvert(pName,"U"))) {
			// For non modules, need to ensure references to class itself aren't output
			Merge pReferences(tHomeModuleName,tRawFileName,tFileType) = $$$ZPMDependencyTempData(tNextCounter,tReferenceKey)
		}
	}
 
	If $IsObject(pProgressListener) {
		Do pProgressListener.PopStage()
		Do pProgressListener.PushStage("Saving Results.")
	}
}

ClassMethod GetDependenciesForModule(pModule As %IPM.Storage.Module, pDirectDepsOnly As %Boolean, Output pDependencies) [ Internal, Private ]
{
  Kill pDependencies
	If (pDirectDepsOnly) {
		For i = 1:1:pModule.Dependencies.Count() {
			#dim dep As %IPM.Storage.ModuleReference
			Set dep = pModule.Dependencies.GetAt(i)
			Set pDependencies(dep.Name) = ""
		}
	} Else {
		Set dependencyList = ##class(%IPM.Storage.Module).GetKnownDependencies(pModule.Name)
		Set ptr = 0
		While $ListNext(dependencyList,ptr,dep) {
			Set pDependencies(dep) = ""
		}
	}
}

/// Get the names of all non % packages in %SYS as keys of the output
/// subscripted array.
ClassMethod GetSysPackageNames(Output pSysPackageNameArray) [ Internal ]
{
	Kill pSysPackageNameArray
	New $Namespace
	Set $Namespace = "%SYS"
	Set query = "SELECT DISTINCT $Piece(Name, '.') As Package FROM %Dictionary.CompiledClass"
	Set statement = ##class(%SQL.Statement).%New()
	$$$ThrowOnError(statement.%Prepare(query))
	Set resultSet = statement.%Execute()
	If (resultSet.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(resultSet.%SQLCODE, resultSet.%Message)
	}
	While resultSet.%Next(.sc) {
		$$$ThrowOnError(sc)
		Set pSysPackageNameArray(resultSet.%Get("Package")) = ""
	}
	$$$ThrowOnError(sc)
}

/// Validate item name is an existing class or include file
ClassMethod ValidateItemName(pItemName As %String) [ Internal, Private ]
{
	If ('##class(%Dictionary.CompiledClass).%ExistsId($Piece(pItemName,".",1, *-1)) && '##class(%Library.Routine).Exists(pItemName)) {
		$$$ThrowOnError($$$ERROR($$$GeneralError, pItemName_" is not an existing .cls or .inc item."))
	}
}

}

