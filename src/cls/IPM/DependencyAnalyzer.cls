Include %IPM.Common

Class %IPM.DependencyAnalyzer
{

/// Prefix to indentify .inc files
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
			// set a placeholder module name for %IPM.DependencyAnalyzer.ModuleResults's required property - it will not be used other than indexing
			Set tModuleName = $c(0)		
		} Else {
			Set tModuleName = tModule.Name
			Write !, "Found home module: "_tModuleName, !
		}
		
		// Find references for target item
		Do ..FindReferenceHelper(tIsModule, pName, 0, pProgressListener, pIgnoredStringRef, pDirectDepsOnly, .pReferences)
		
		// Represent results as objects
		Set tRun = ..PresentReferenceAsObject(tModuleName, 0, .pReferences)
		
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
		Set tRun = ..PresentReferenceAsObject(tModuleName, 1, .pInvalidReferences)
		
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
	Do ..AccumulatePackageNamesInCurrentNamespace()
 
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
						Set tSC = tQueue.QueueCallback("##class("_$classname()_").ExtractClassReferencesToName","##class("_$classname()_").ClassExtractionComplete",tClass,tNextCounter,pProgressListener,pIgnoredStringRef)
						$$$ThrowOnError(tSC)
						Set tClassCount = tClassCount + 1
					} ElseIf (tExt = "INC") {
						Set tClass = $Piece(tChildKey,".",1,*-1)
						// Queue search of include file
						Set tSC = tQueue.QueueCallback("##class("_$classname()_").ExtractIncludeReferencesToName","##class("_$classname()_").ClassExtractionComplete",tClass,tNextCounter,pProgressListener,pIgnoredStringRef)
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
				Set tSC = tQueue.QueueCallback("##class("_$classname()_").ExtractClassReferencesToName","##class("_$classname()_").ClassExtractionComplete",tClass,tNextCounter,pProgressListener, pIgnoredStringRef)
				$$$ThrowOnError(tSC)
				Set tClassCount = 1
			} ElseIf (tExt = "INC") {
				Set tClass = $Piece(pName,".",1,*-1)
				// Queue search of include file
				Set tSC = tQueue.QueueCallback("##class("_$classname()_").ExtractIncludeReferencesToName","##class("_$classname()_").ClassExtractionComplete",tClass,tNextCounter,pProgressListener, pIgnoredStringRef)
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

/// Based on multi-dim array, construct and return an ModuleResults object where info of the reference is stored
/// pModuleName: Name of the module itself / home module for the item
/// pInvalidOnly: Whether or not only look for invalid references. Default to 1
/// pReferences: multi-dim references
ClassMethod PresentReferenceAsObject(pModuleName As %String, pInvalidOnly As %Boolean = 1, ByRef pReferences) As %IPM.DependencyAnalyzer.ModuleResults [ Internal ]
{
	Set tRun = ##class(%IPM.DependencyAnalyzer.ModuleResults).%New()
	Set tRun.TargetModule = pModuleName
 
	Set tModuleKey = ""
	For {
		Set tModuleKey = $Order(pReferences(tModuleKey))
		If (tModuleKey = "") {
			Quit
		}
		
		Set tReferencedClassKey = ""
		For {
			Set tReferencedClassKey = $Order(pReferences(tModuleKey,tReferencedClassKey))
			If (tReferencedClassKey = "") {
				Quit
			}
			
			Set tFileTypeKey = ""
			For {
				Set tFileTypeKey = $Order(pReferences(tModuleKey,tReferencedClassKey,tFileTypeKey))
				If (tFileTypeKey = "")  {
					Quit
				}
				Set tReferencingClassKey = ""
				For {
					Set tReferencingClassKey = $Order(pReferences(tModuleKey,tReferencedClassKey,tFileTypeKey, tReferencingClassKey))
					If (tReferencingClassKey = "") {
						Quit
					}
					If (tReferencedClassKey = tReferencingClassKey) {
						// This sometimes happens if the class is not compiled.
						Continue
					}
					
					Set tMemberKey = ""
					For {
						Set tMemberKey = $Order(pReferences(tModuleKey,tReferencedClassKey,tFileTypeKey, tReferencingClassKey,tMemberKey))
						If (tMemberKey = "") {
							Quit
						}
						
						Set tLineKey = ""
						For {
							Set tLineKey = $Order(pReferences(tModuleKey,tReferencedClassKey,tFileTypeKey, tReferencingClassKey,tMemberKey,tLineKey),1,tLine)
							If (tLineKey = "") {
								Quit
							}
							
							Set tProblem = ##class(%IPM.DependencyAnalyzer.Problem).%New()
							Set tProblem.ReferencedFileType = tFileTypeKey
							Set tProblem.ReferencedModule = $Case(tModuleKey,$c(0):"",:tModuleKey)
							Set tProblem.ReferencedItemExists = (tModuleKey '= $c(0))
							Set tProblem.ReferencedItem = tReferencedClassKey
							Set tProblem.ProblemItem = tReferencingClassKey
							Set tProblem.ProblemMember = tMemberKey
							Set tProblem.ProblemLine = tLineKey
							Set tProblem.ProblemCode = tLine
							Set tProblem.InvalidOnly = pInvalidOnly
							Set tSC = tProblem.%ValidateObject()
							If $$$ISOK(tSC) {
								Do tRun.Problems.Insert(tProblem)
							} Else {
								Do ##class(%IPM.General.LogManager).Warning("Could not save problem: "_tProblem.ToString()_$c(13,10,9)_"Error: "_$System.Status.GetErrorText(tSC),1)
							}
						}
					}
				}
			}
		}
	}
	Return tRun
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

/// Get names of all packages in the current namespace and store output in a temp
/// global.
ClassMethod AccumulatePackageNamesInCurrentNamespace()
{
	Do ..AccumulatePackageNamesInNamespace($Namespace, .packages)
	Merge $$$ZPMDependencyNsPackages = packages
}

ClassMethod AccumulatePackageNamesInNamespace(pNamespace As %String, Output pPackages) [ Internal, Private ]
{
	Kill pPackages
	New $Namespace
	Set $Namespace = pNamespace
	Set query = "SELECT DISTINCT $Piece(Name, '.') As Package FROM %Dictionary.CompiledClass"
	Set statement = ##class(%SQL.Statement).%New()
	$$$ThrowOnError(statement.%Prepare(query))
	Set resultSet = statement.%Execute()
	If (resultSet.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(resultSet.%SQLCODE, resultSet.%Message)
	}
	While resultSet.%Next(.sc) {
		$$$ThrowOnError(sc)
		Set pPackages(resultSet.%Get("Package")) = ""
	}
	$$$ThrowOnError(sc)
}

/// @API.Query
/// @Modifier Availability InterSystems
Query LatestResults(pProblemModule As %String) As %SQLQuery [ SqlProc ]
{
	select Run->TargetModule,ProblemItem,ReferencedModule,ReferencedItem,ProblemMember,ProblemLine,ProblemCode
	from %IPM_DependencyAnalyzer.Problem
	where :pProblemModule is null or :pProblemModule = Run->TargetModule
	having Run->ID = MAX(Run->ID %FOREACH (Run->TargetModule))
}

ClassMethod ClassExtractionComplete(pSourceClass As %String, pTargetSubscript As %String) As %Status
{
	Quit $$$OK
}

// ////////////////////// Extraction methods called on FILES /////////////////////////////////

/// Called directly by RunforAllReferences() / RunforInvalidReferences() on .inc files
ClassMethod ExtractIncludeReferencesToName(pSourceClass As %String, pTargetSubscript As %String, pProgressListener = {$$$NULLOREF}, pIgnoredStringRef As %String) As %Status
{
	Set tSC = ..ExtractFileReferencesFromIncludeFile(pSourceClass,.tResults, pIgnoredStringRef)
	$$$ThrowOnError(tSC)
	Merge $$$ZPMDependencyTempData(pTargetSubscript) = tResults
	Quit tSC
}

/// Called directly by RunforAllReferences() / RunforInvalidReferences() on .cls files
ClassMethod ExtractClassReferencesToName(pSourceClass As %String, pTargetSubscript As %String, pProgressListener = {$$$NULLOREF}, pIgnoredStringRef As %String) As %Status
{
	Set tSC = ..ExtractFileReferencesFromClass(pSourceClass,.tResults, pIgnoredStringRef)
	$$$ThrowOnError(tSC)
	Merge $$$ZPMDependencyTempData(pTargetSubscript) = tResults
	Quit tSC
}

/// This method extracts all referenced classes from a give .inc file
ClassMethod ExtractFileReferencesFromIncludeFile(pSourceIncludeFile As %String, ByRef pRefArray, pIgnoredStringRef As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		#dim rtn As %Library.Routine
		Set rtn = ##class(%Library.Routine).%OpenId(pSourceIncludeFile)
		#dim stream As %Stream.TmpCharacter
		Set stream = ##class(%Stream.TmpCharacter).%New()
		While 'rtn.AtEnd {
			Set tDocLine = rtn.ReadLine()
			Do stream.WriteLine(tDocLine)
		}
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(stream,"COS","A",.tSCReader)
		$$$ThrowOnError(tSC)
		Do rtn.Rewind()
		Set tLine = 0
		While tSCReader.NextLine(.tLineTokenList) {
			Set tLine = tLine + 1
			Set tDocLine = rtn.ReadLine()
			Do ..ExtractReferencesFromIncludeFileLine(pSourceIncludeFile," ",tLine,tLineTokenList,.pRefArray,tDocLine, pIgnoredStringRef)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// This method extracts all referenced classes from a given .cls file
/// calls ExtractIncludeFileReferencesFromLine() to handle line with include file,
/// calls ExtractClassReferencesFromLine() to handle other lines
ClassMethod ExtractFileReferencesFromClass(pSourceClass As %String, ByRef pRefArray, pIgnoredStringRef As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		// Get references in UDL
		$$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsStream(,pSourceClass,.tSourceStream))
		
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"CLS","A",.tSCReader)
		$$$ThrowOnError(tSC)
		
		// Get references in COS
		$$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsArray(,pSourceClass,.tDocumentText))
		// tDocumentText: an array, each line is a line in the class
		Set tDocumentText = $Order(tDocumentText(""),-1) //Set top level node to # of lines.
		
		// Iterate to find all class references and include file references
		Set tMember = ""
		// tInMember will be set to query or method
		Set tInMember = ""
		Set tMemberStarted = 0
		Set tIncludeFileChecked = 0
		For tDocLine=1:1:tDocumentText {
			Set tLine = tDocumentText(tDocLine)
			Do tSCReader.NextLine(.tLineTokenList)
			If (tInMember = "") {
				Set pExecutableFlags(tDocLine) = 0
				// Extract line offset of method in class
				Set tStart = $Extract(tLine,1,6)
				// Check for include files only once, since all refer to inc files should be on the same line
				If ('tIncludeFileChecked && (tStart = "Includ")) {
					Set tIncludeFileChecked = 1
					Do ..ExtractIncludeFileReferencesFromLine(pSourceClass," ",tDocLine,tLineTokenList,.pRefArray,.tDocumentText)
					Continue
				}
				If (tStart = "ClassM") || (tStart = "Method") || (tStart = "Query ") {
					Set tMember = $Piece($Piece(tLine,"(")," ",2)
					Kill tMemberCode
					Set tInMember = $Case(tStart,"Query ":"query",:"method")
				}
				
				// Look at the next line of tokens from UDL.
				Do ..ExtractClassReferencesFromLine(pSourceClass," ",tDocLine,tLineTokenList,.pRefArray,.tDocumentText, pIgnoredStringRef)
			} Else {
				If $Extract(tLine) = "{" {
					Set tMemberStarted = 1
					Set tMethodMap(tMember) = tDocLine + 1
				} ElseIf ($Extract(tLine) = "}") {
					If (tMember '= "") {
						If (tInMember = "method") {
							Set tSC = ..ExtractClassReferencesFromMethod(pSourceClass,tMember,.tMemberCode,.tMethodMap,.pRefArray, pIgnoredStringRef)
							$$$ThrowOnError(tSC)
						} ElseIf (tInMember = "query") {
							Set tSC = ..ExtractClassReferencesFromQuery(pSourceClass,tMember,.tMemberCode,.tMethodMap,.pRefArray, pIgnoredStringRef)
							$$$ThrowOnError(tSC)
						}
					}
					Set tInMember = ""
					Set tMemberStarted = 0
				} Else {
					// Aggregate lines from the method body to look at later.
					Set tMemberCode($i(tMemberCode)) = tLine
				} 
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Helper method called by ExtractFileReferencesFromClass().
/// Handles lines inside a method by calling ExtractClassReferencesFromLine()
ClassMethod ExtractClassReferencesFromMethod(pSourceClass As %String, pMethod As %String, ByRef pMethodCode, ByRef pMethodMap, ByRef pRefArray, pIgnoredStringRef As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tCodeMode = $$$defMemberKeyGet(pSourceClass,$$$cCLASSmethod,pMethod,$$$cMETHcodemode)
		If (tCodeMode = $$$cMETHCODEMODEGENERATOR) || (tCodeMode = $$$cMETHCODEMODEOBJECTGENERATOR) || '$Data(^rMAP(pSourceClass,"CLS","INT",pMethod)) {
			Quit
		}
		Set tSourceStream = ##class(%Stream.GlobalCharacter).%New()
		Set tSourceStream.LineTerminator = $c(13,10)
		For tMethodLine=1:1:$Get(pMethodCode) {
			Do tSourceStream.WriteLine(pMethodCode(tMethodLine))
		}
		
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"COS","A",.tSCReader)
		$$$ThrowOnError(tSC)
		
		Set tOffset = pMethodMap(pMethod)
		Set tLine = 1
		While tSCReader.NextLine(.tLineTokenList) {
			If (tLine = 0) && (tCodeMode = $$$cMETHCODEMODEEXPRESSION) {
				// Simulate a normal method.
				Set tLineTokenList = $ListBuild($ListBuild("COS","Command","Quit"))_tLineTokenList
			}
			Do ..ExtractClassReferencesFromLine(pSourceClass,pMethod,tLine,tLineTokenList,.pRefArray,.pMethodCode, pIgnoredStringRef)
			Set tLine = tLine + 1
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Helper method called by ExtractFileReferencesFromClass().
/// Handles lines inside a query by calling ExtractClassReferencesFromLine()
ClassMethod ExtractClassReferencesFromQuery(pSourceClass As %String, pQuery As %String, ByRef pMethodCode, ByRef pMethodMap, ByRef pRefArray, pIgnoredStringRef As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSourceStream = ##class(%Stream.GlobalCharacter).%New()
		Set tSourceStream.LineTerminator = $c(13,10)
		For tMethodLine=1:1:$Get(pMethodCode) {
			Do tSourceStream.WriteLine(pMethodCode(tMethodLine))
		}
		
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"SQL","A",.tSCReader)
		$$$ThrowOnError(tSC)
		
		Set tOffset = pMethodMap(pQuery)
		Set tLine = 1
		While tSCReader.NextLine(.tLineTokenList) {
			Do ..ExtractClassReferencesFromLine(pSourceClass,pQuery,tLine,tLineTokenList,.pRefArray,.pMethodCode, pIgnoredStringRef)
			Set tLine = tLine + 1
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

// ////////////////////// END OF Extraction methods called on FILES /////////////////////////

// ////////////////////// Extraction methods called on LINES ////////////////////////////////

/// Called by ExtractFileReferencesFromClass(), FromMethod() and FromQuery()
ClassMethod ExtractClassReferencesFromLine(pSourceClass As %String, pMethod As %String, pLine As %Integer, pLineTokenList As %List, ByRef pRefArray, ByRef pMethodCode, pIgnoredStringRef As %String)
{
	/*
	// Like $$$NormalizeClassname from %occClassname.inc, but relative to another class (for references to the same package)
	#define NormalizeClassname(%class,%source) $s(%class="":"",%class[".":%class,$e(%class)'="%":$$$ClassPackageName(%source)_"."_%class,1:"%Library."_$e(%class,2,*))
	#define AddReference(%classname) Set pRefArray($$$NormalizeClassname(%classname,pSourceClass),pSourceClass,pMethod,pLine) = $ZStrip(pMethodCode(pLine),"<>W")
	*/
	#define AddReference(%classname) $$$NormalizeClassnameByDef(%classname,pSourceClass) Set pRefArray(%classname,pSourceClass_..#CLSSUFFIX,pMethod,pLine) = $ZStrip(pMethodCode(pLine),"<>W")
	Set tInClassname = 0
	Set tInTableName = 0
	Set tClassName = ""
	Set tTableName = ""
	Set tPointer = 0
	Set tTableState = 0
	Set tIgnoreAllStr = 0
	Set tIgnoreStrList = ""
	If pIgnoredStringRef = $char(0) {
		Set tIgnoreAllStr = 1
	} Else {
		Set tIgnoreStrList = $ListFromString(pIgnoredStringRef, ",")
	}
	While $ListNext(pLineTokenList,tPointer,tLineToken) {
		Set $ListBuild(tLanguage,tType,tValue) = tLineToken
		If tInTableName {
			// Table name has format:
			// Identifier Delimiter (.) Identifier
			// With possible intervening whitespace.
			
			// Values of tTableState:
			// 1: just saw something indicating that a table name might be about to appear (e.g., from, join), and expect an identifier.
			// 2: just saw first identifier (schema), and expect a delimiter.
			// 3: just saw delimiter (.), and expect a table name
			If (tType = "White Space") {
			} ElseIf (tType = "Delimiter") && (tValue = ".") && (tTableState = 2) {
				Set tTableName = tTableName_tValue
				Set tTableState = 3
			} ElseIf (tType = "Identifier") && ((tTableState = 1) || (tTableState = 3)) {
				Set tTableName = tTableName_$Translate(tValue,"""")
				Set tTableState = tTableState + 1
			} Else {
				If (tTableName '= "") {
					Set tSC = ..GetClassNameFromTableName(pSourceClass,tTableName,.tClassName)
					$$$ThrowOnError(tSC)
					If (tClassName '= "") {
						$$$AddReference(tClassName)
					}
				}
				Set tTableName = ""
				Set tInTableName = 0
				Set tTableState = 0
			}
		}
		If (tLanguage = "COS") {
			// ##class(Some.Class)
			If (tType = "Object (Class)") {
				Set tInClassname = 1
				Set tClassName = ""
			} ElseIf (tType = "Object name") {
				If ($Extract(tValue) = """") {
					// Quoted classname.
					Set tValue = $Extract(tValue,2,*-1)
				}
				Set tClassName = tClassName_tValue
			} ElseIf tInClassname && (tType = "Delimiter") && (tValue = ")") {
				// Avoid <SUBSCRIPT> in cases where the full class name is a macro (for example)
				If (tClassName '= "") {
					$$$AddReference(tClassName)
				}
				Set tClassName = ""
				Set tInClassname = 0
			} ElseIf (tType = "String") {
				// Dynamic class call. Can have classname as a string.
				If tIgnoreAllStr {
					Continue
				}
				If ($Extract(tValue) = """") {
					// Quoted classname so remove additional quotes
					Set tValue = $Extract(tValue,2,*-1)
					Set tIsValidClassname = ##class(%Dictionary.Classname).IsValid(tValue)
					If tIsValidClassname {
						Set tPackageExists = $Data($$$ZPMDependencyNsPackages($Piece(tValue, ".", 1)))
						Set tIsFullClassname = $Piece(tValue, ".", 2) '= ""
						If (tPackageExists && tIsFullClassname) {
							// The package name already exists in the namespace. Can
							// safely assume no non-existent packages are being referenced.
							// This check is to prevent red herrings such as simple
							// strings like "POS" or "Hello" getting flagged as invalid
							// references.
							If ($Extract($ZConvert(tValue, "U"), *-3, *) = ".CLS") {
								// If reference ends in ".cls", strip it so that class's module can be detected
								Set tValue = $Extract(tValue, 1, *-4)
							}
							If '$ListFind(tIgnoreStrList, tValue) {
								$$$AddReference(tValue)
							}
						}
					}
				}
			}
		} ElseIf (tLanguage = "CLS") {
			If (tType = "Class Name") {
				Set tInClassname = 1
				Set tClassName = tClassName_tValue
			} ElseIf tInClassname {
				$$$AddReference(tClassName)
				Set tClassName = ""
				Set tInClassname = 0
			}
		} ElseIf (tLanguage = "SQL") {
			If 'tInTableName {
				Set tLowerValue = $ZConvert(tValue,"L")
				If (tType = "Qualifier keyword") && ((tLowerValue = "from") || (tLowerValue = "join")) {
					Set tInTableName = 1
					Set tTableState = 1
				}
			}
		}
	}
	// If we ended with the classname being the last element, for example, <Class A> extends <Class B>
	If (tInClassname && (tClassName '= "")) {
		$$$AddReference(tClassName)
	}
	
	// If we ended a table name on the line.
	If (tInTableName && (tTableName '= "")) {
		Set tSC = ..GetClassNameFromTableName(pSourceClass,tTableName,.tClassName)
		$$$ThrowOnError(tSC)
		If (tClassName '= "") {
			$$$AddReference(tClassName)
		}
	}
}

/// Extracts include file referenced in a class by an Include tag
/// We assume that this method will only be called with the line starts with "Include"
ClassMethod ExtractIncludeFileReferencesFromLine(pSourceClass As %String, pMethod As %String, pLine As %Integer, pLineTokenList As %List, ByRef pRefArray, ByRef pMethodCode)
{
	#define AddReference(%classname) $$$NormalizeClassnameByDef(%classname,pSourceClass) Set pRefArray(%classname,pSourceClass_..#CLSSUFFIX,pMethod,pLine) = $ZStrip(pMethodCode(pLine),"<>W")
	Set tRoutineName = ..#INCPREFIX
	Set tPointer = 0
	While $ListNext(pLineTokenList,tPointer,tLineToken) {
		Set $ListBuild(tLanguage,tType,tValue) = tLineToken	
		If (tLanguage = "CLS") {
			If (tType = "Routine Name") {
				Set tRoutineName = tRoutineName_tValue
			} ElseIf (tType = "Delimiter") {
				If (tValue = ".") {
					Set tRoutineName = tRoutineName_tValue
				} ElseIf (tValue = ",") {
					// add the include file as a reference
					$$$AddReference(tRoutineName)
					Set tRoutineName = ..#INCPREFIX
				}
			}
		}
	}
	If (tRoutineName '= ..#INCPREFIX) {
		$$$AddReference(tRoutineName)
	}
}

/// Called by ExtractFileReferencesFromIncludeFile, will only process lines in an include file
ClassMethod ExtractReferencesFromIncludeFileLine(pSourceClass As %String, pMethod As %String, pLine As %Integer, pLineTokenList As %List, ByRef pRefArray, pLineCode As %String, pIgnoredStringRef As %String)
{
	#define AddReference(%classname) $$$NormalizeClassnameByDef(%classname,pSourceClass) Set pRefArray(%classname,pSourceClass_..#INCSUFFIX,pMethod,pLine) = $ZStrip(pLineCode,"<>W")
	Set tPointer = 0
	// looking for a line starting with #define
	Set tHasPoundSign = 0
	Set tHasDefineTag = 0
	Set tHasIncludeTag = 0
	Set tReferencedClassName = ""
	Set tReferencedIncludeFileName = ""
	// this flag checks whether we are within the parentheses of #define ... ##class( <...> )
	Set tInMember = 0
	Set tPrevValue = ""
	Set tIgnoreAllStr = 0
	Set tIgnoreStrList = ""
	If pIgnoredStringRef = $char(0) {
		Set tIgnoreAllStr = 1
	} Else {
		Set tIgnoreStrList = $ListFromString(pIgnoredStringRef, ",")
	}
	While $ListNext(pLineTokenList,tPointer,tLineToken) {
		Set $ListBuild(tLanguage,tType,tValue) = tLineToken
		If (tLanguage = "COS") {
			If (tType = "Pre-Processor Command") {
				If (tValue = "#") {
					Set tHasPoundSign = 1
				} ElseIf (tHasPoundSign && ($ZConvert(tValue,"L") = "include")) {
					Set tHasIncludeTag = 1
				} ElseIf (tHasPoundSign && ($ZConvert(tValue,"L") = "define")) {
					Set tHasDefineTag = 1
				}
			} ElseIf (tType = "Pre-Processor Function") {
				If (tInMember && (tValue '= "(")) {
					If tValue = ")" {
						// get the closing parenthesis, record the class name
						$$$AddReference(tReferencedClassName)
						Set tInMember = 0
						Set tReferencedClassName = ""
					} Else {
						// in between two parentheses, keep constructing the class name
						Set tReferencedClassName = tReferencedClassName_tValue
					}
				} Else {
					If tHasDefineTag {
						// get a "##" and a "class", indicating that we are about to touch a referenced class
						If (($ZConvert(tValue, "L") = "class") && (tPrevValue = "##"))  {
							Set tInMember = 1
						}
					} 
				}
			} ElseIf (tType = "Name") {
				// #include HS.HC, or, #include %ZHSLIB, for instance.
				// it will be displayed as <$lb("COS","Name","HS"),$lb("COS","White Space",".HC"))> / <$lb("COS","Name","%ZHSLIB")>
				// it is not valid to have #include (A, B) in .inc file, so we only consider this situation
				If tHasIncludeTag {
					Set tReferencedIncludeFileName = ..#INCPREFIX_$ZStrip(tValue, "<>WC")
				}
			} ElseIf (tType = "White Space") {
				If (tReferencedIncludeFileName '= "") {
					Set tReferencedIncludeFileName = tReferencedIncludeFileName_$ZStrip(tValue, "<>WC")
				}
			} ElseIf (tType = "String") {
				// Dynamic class call. Can have classname as a string.
				If tIgnoreAllStr {
					Continue
				}
				If ($Extract(tValue) = """") {
					// Quoted classname so remove additional quotes
					Set tValue = $Extract(tValue,2,*-1)
					Set tIsValidClassname = ##class(%Dictionary.Classname).IsValid(tValue)
					If tIsValidClassname {
						Set tPackageExists = $Data($$$ZPMDependencyNsPackages($Piece(tValue, ".", 1)))
						Set tIsFullClassname = $Piece(tValue, ".", 2) '= ""
						If (tPackageExists && tIsFullClassname) {
							// The package name already exists in the namespace. Can
							// safely assume no non-existent packages are being referenced.
							// This check is to prevent red herrings such as simple
							// strings like "POS" or "Hello" getting flagged as invalid
							// references.
							If ($Extract($ZConvert(tValue, "U"), *-3, *) = ".CLS") {
								// If reference ends in ".cls", strip it so that class's module can be detected
								Set tValue = $Extract(tValue, 1, *-4)
							}
							If '$ListFind(tIgnoreStrList, tValue) {
								$$$AddReference(tValue)
							}
						}
					}
				}
			}
			Set tPrevValue = tValue
		}
	}
	If tReferencedClassName '= "" {
		$$$AddReference(tReferencedClassName)
	}
	If tReferencedIncludeFileName '= "" {
		$$$AddReference(tReferencedIncludeFileName)
	}
}

// ////////////////////// END of Extraction methods called on LINES /////////////////////////

ClassMethod GetClassNameFromTableName(pSourceClass As %String, pFullTableName As %String, Output pClassName) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pClassName = ""
		
		// Default: same SQL schema
		If ($Length(pFullTableName,".") > 1) {
			Set tSchemaName = $Piece(pFullTableName,".")
		} Else {
			Set tSchemaName = $$$comClassKeyGet(pSourceClass,$$$cCLASSsqlschemaname)
		}
		Set tTableName = $Piece(pFullTableName,".",*)
		
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,
			"select NVL(NVL("_
			"(select CLASSNAME from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA = ? and TABLE_NAME = ?),"_
			"(select CLASSNAME from INFORMATION_SCHEMA.ROUTINES where SPECIFIC_SCHEMA = ? and SPECIFIC_NAME = ?)),"_
			"(select CLASSNAME from INFORMATION_SCHEMA.VIEWS where TABLE_SCHEMA = ? and TABLE_NAME = ?))",
			tSchemaName,tTableName,tSchemaName,tTableName,tSchemaName,tTableName)
		If (tResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
		}
		If tResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set pClassName = tResult.%GetData(1)
		} Else {
			$$$ThrowOnError(tSC)
		}
		If (pClassName = "") {
			Do ##class(%IPM.General.LogManager).Warning("Table name not found: "_pFullTableName,1)
			Set pClassName = ""
		}
	} Catch e {
		Set pClassName = ""
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Validate item name is an existing class or include file
ClassMethod ValidateItemName(pItemName As %String) [ Internal, Private ]
{
	If ('##class(%Dictionary.CompiledClass).%ExistsId($Piece(pItemName,".",1, *-1)) && '##class(%Library.Routine).Exists(pItemName)) {
		$$$ThrowOnError($$$ERROR($$$GeneralError, pItemName_" is not an existing .cls or .inc item."))
	}
}

/// Left in as a tool for developers working to enhance this class in the future.
/// This shows all the tokens for a given class.
ClassMethod Test(pClass As %String) [ Internal ]
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsStream(,pClass,.tSourceStream))
		
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"CLS","A",.tSCReader)
		$$$ThrowOnError(tSC)
		
		While tSCReader.NextLine(.tLineTokenList) {
			zw tLineTokenList
		}
	} Catch e {
		Set tSC = e.AsStatus()
		Write !,$System.Status.GetErrorText(e)
	}
	Quit tSC
}

}
