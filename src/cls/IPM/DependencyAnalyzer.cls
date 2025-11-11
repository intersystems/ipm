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
    set tSC = $$$OK
    set tOneSC = $$$OK
    try {
        set tRes = ##class(%SQL.Statement).%ExecDirect(,
            "select Name from %IPM_Storage.ModuleItem")
        if (tRes.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
        }
        while tRes.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            write !,"Processing: ",tRes.%Get("Name")
            set tOneSC = $$$ADDSC(tOneSC,..RunForInvalidReferences(tRes.%Get("Name"),,0))
        }
        $$$ThrowOnError(tSC)

        // Report aggregated errors.
        set tSC = tOneSC
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
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
ClassMethod RunForAllReferences(
	pName As %String,
	Output pReferences,
	pVerbose As %Boolean = 1,
	pSave As %Boolean = 1,
	pProgressListener = {$$$NULLOREF},
	Output pRunID As %String,
	pIgnoredStringRef As %String = "",
	pDirectDepsOnly As %Boolean = 0) As %Status
{
    set pRunID = ""
    set tSC = $$$OK
    try {
        // Now decide whether it's running for a module or just a single item
        set tIsModule = (($$$lcase($piece(pName,".",*)) '= "cls") && ($$$lcase($piece(pName,".",*)) '= "inc"))
        if tIsModule {
            $$$ThrowOnError($$$ERROR($$$GeneralError, "Finding all references of a module is not supported. Please either specify an item with cls/inc extension, or try finding invalid references for a module."))
        }

        do ..ValidateItemName(pName)
        set tModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule($$$ucase(pName))
        if '$isobject(tModule) {
            write !, "No home module found for item: " _ pName ,!
            // set a placeholder module name for %pkg.isc.dependencyAnalyzer.ModuleResults's required property - it will not be used other than indexing
            set tModuleName = $char(0)
        } else {
            set tModuleName = tModule.Name
            write !, "Found home module: "_tModuleName, !
        }

        // Find references for target item
        do ..FindReferenceHelper(tIsModule, pName, 0, pProgressListener, pIgnoredStringRef, pDirectDepsOnly, .pReferences)

        // Represent results as objects
        set tRun = $classmethod("%pkg.isc.dependencyAnalyzer.Utils", "PresentReferenceAsObject", tModuleName, 0, .pReferences)

        if pSave {
            $$$ThrowOnError(tRun.%Save())
            set pRunID = tRun.%Id()
        }

        if $isobject(pProgressListener) {
            do pProgressListener.PopStage()
        }

        if pVerbose {
            do tRun.Display()
        }
    } catch e {
        set tSC = e.AsStatus()
        if pVerbose {
            write !,$system.Status.GetErrorText(e.AsStatus())
        }
    }
    quit tSC
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
ClassMethod RunForInvalidReferences(
	pName As %String,
	Output pInvalidReferences,
	pVerbose As %Boolean = 1,
	pSave As %Boolean = 1,
	pProgressListener = {$$$NULLOREF},
	Output pRunID As %String,
	pIgnoredStringRef As %String = "",
	pDirectDepsOnly As %Boolean = 0) As %Status
{
    set pRunID = ""
    set tSC = $$$OK
    try {
        // Now decide whether it's running for a module or just a single item
        set tIsModule = (($$$lcase($piece(pName,".",*)) '= "cls") && ($$$lcase($piece(pName,".",*)) '= "inc"))
        set tModuleName = pName
        if 'tIsModule {
            do ..ValidateItemName(pName)
            set tModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule($$$ucase(pName))
            if '$isobject(tModule) {
                $$$ThrowOnError($$$ERROR($$$GeneralError, "To find invalid references in item "_pName_", it has to belong to an existing module."))
            }
            set tModuleName = tModule.Name
            write !, "Found home module: "_tModuleName ,!
        }

        // Find references for target module / item
        do ..FindReferenceHelper(tIsModule, pName, 1, pProgressListener, pIgnoredStringRef, pDirectDepsOnly, .pInvalidReferences)

        // Represent results as objects
        set tRun = $classmethod("%pkg.isc.dependencyAnalyzer.Utils","PresentReferenceAsObject", tModuleName, 1, .pInvalidReferences)

        if pSave {
            $$$ThrowOnError(tRun.%Save())
            set pRunID = tRun.%Id()
        }

        if $isobject(pProgressListener) {
            do pProgressListener.PopStage()
        }

        if pVerbose {
            do tRun.Display()
        }
    } catch e {
        set tSC = e.AsStatus()
        if pVerbose {
            write !,$system.Status.GetErrorText(e.AsStatus())
        }
    }
    quit tSC
}

/// Find all references for all resources in module / for the specified item. If pInvalidOnly = 1 (default), then only look for invalid references. Else look for all references
/// pIsModule: Whether or not we are running for a whole module or for a single item
/// pName: When pIsModule = 0, specifies the name of the target item. Else, specifies the name of the module
/// pInvalidOnly: Whether or not only look for invalid references. Default to 1
/// pIgnoredStringRef: Comma-separated string of string references that will be ignored. If set to $char(0), then will ignore all string references including classes.
/// pDirectDepsOnly: Include only direct dependencies rather than transitive ones as well.
/// pReferences: Output multidim references
ClassMethod FindReferenceHelper(
	pIsModule As %Boolean,
	pName As %String = "",
	pInvalidOnly As %Boolean = 1,
	pProgressListener = {$$$NULLOREF},
	pIgnoredStringRef As %String,
	pDirectDepsOnly As %Boolean = 0,
	Output pReferences) [ Internal ]
{
  #dim tModule As %IPM.Storage.Module
    set tModuleName = pName
    // tModule will only be used when running for a module, or running to find invalid references
    if 'pIsModule {
        set tModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule($$$ucase(pName))
        if '$isobject(tModule) {
            write !, "No home module found for item: " _ pName_". Non-module item should have item-type extension.", !
            if pInvalidOnly {
                $$$ThrowOnError($$$ERROR($$$GeneralError, "To find invalid references in item "_pName_", it has to belong to an existing module."))
            }
        } else {
            set tModuleName = tModule.Name
        }
    } else {
        set tModule = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
        $$$ThrowOnError(tSC)
    }

    // Build dependency graph only when looking for invalid references,
    // so that we can test if resources are coming from a dependent module.
    if pInvalidOnly {
        if $isobject(pProgressListener) {
            do pProgressListener.PushStage("Collecting Dependencies")
        }
        do ..GetDependenciesForModule(tModule, pDirectDepsOnly, .tDependencies)
        // Include this module in the list
        set tDependencies(tModuleName) = ""
        if $isobject(pProgressListener) {
            do pProgressListener.PopStage()
      }
  }

    // Get packages in %SYS
    do ..GetSysPackageNames(.tSYSPackages)
    // Accumulate package names in current namespace into a temp global
    // Do accumulation once for performance rather than repeating accumulation
    do $classmethod("%pkg.isc.dependencyAnalyzer.Utils", "AccumulatePackageNamesInCurrentNamespace")

    // Parallelize search
    #dim tQueue As %SYSTEM.WorkMgr
    set tQueue = $system.WorkMgr.Initialize(,.tSC)
    $$$ThrowOnError(tSC)

    // Aggregate results from workers in IRISTEMP
    set tNextCounter = $$$ZPMDependencyTempDataNext
    kill $$$ZPMDependencyTempData(tNextCounter)

    if $isobject(pProgressListener) {
        do pProgressListener.PushStage("Scanning classes in module")
    }
    set tClassCount = 0

    // If we are running for a module, get references for all module resources
    if pIsModule {
        set orderedResourceList = tModule.GetOrderedResourceList()
        set tResourceKey = ""
        for {
            #dim tResource As %IPM.Storage.ResourceReference
            set tResource = orderedResourceList.GetNext(.tResourceKey)
            if (tResourceKey = "") {
                quit
            }

            kill tResourceArray
            set tSC = tResource.ResolveChildren(.tResourceArray)
            $$$ThrowOnError(tSC)

            set tChildKey = ""
            for {
                set tChildKey = $order(tResourceArray(tChildKey))
                if (tChildKey = "") {
                    quit
                }
                // Skips generated classes, stub classes
                if $get(tResourceArray(tChildKey,"Generated"),0) {
                    continue
                }
                set tExt = $$$ucase($piece(tChildKey,".",*))
                if (tExt = "CLS") {
                    set tClass = $piece(tChildKey,".",1,*-1)
                    // Queue search of class
                    set tSC = tQueue.QueueCallback("##class(%pkg.isc.dependencyAnalyzer.Utils).ExtractClassReferencesToName","##class(%pkg.isc.dependencyAnalyzer.Utils).ClassExtractionComplete",tClass,tNextCounter,pProgressListener,pIgnoredStringRef)
                    $$$ThrowOnError(tSC)
                    set tClassCount = tClassCount + 1
                } elseif (tExt = "INC") {
                    set tClass = $piece(tChildKey,".",1,*-1)
                    // Queue search of include file
                    set tSC = tQueue.QueueCallback("##class(%pkg.isc.dependencyAnalyzer.Utils).ExtractIncludeReferencesToName","##class(%pkg.isc.dependencyAnalyzer.Utils).ClassExtractionComplete",tClass,tNextCounter,pProgressListener,pIgnoredStringRef)
                    $$$ThrowOnError(tSC)
                    set tClassCount = tClassCount + 1
                }
            }
        }
    // else if running for only one item (Class or Include file), simple run that this specific one
    } else {
        set tExt = $$$ucase($piece(pName,".",*))
        if (tExt = "CLS") {
            set tClass = $piece(pName,".",1,*-1)
            // Queue search of class
            set tSC = tQueue.QueueCallback("##class(%pkg.isc.dependencyAnalyzer.Utils).ExtractClassReferencesToName","##class(%pkg.isc.dependencyAnalyzer.Utils).ClassExtractionComplete",tClass,tNextCounter,pProgressListener, pIgnoredStringRef)
            $$$ThrowOnError(tSC)
            set tClassCount = 1
        } elseif (tExt = "INC") {
            set tClass = $piece(pName,".",1,*-1)
            // Queue search of include file
            set tSC = tQueue.QueueCallback("##class(%pkg.isc.dependencyAnalyzer.Utils).ExtractIncludeReferencesToName","##class(%pkg.isc.dependencyAnalyzer.Utils).ClassExtractionComplete",tClass,tNextCounter,pProgressListener, pIgnoredStringRef)
            $$$ThrowOnError(tSC)
            set tClassCount = 1
        }
    }

    if $isobject(pProgressListener) {
        do pProgressListener.SetStageTotalUnits(tClassCount)
    }
    set tSC = tQueue.WaitForComplete()
    $$$ThrowOnError(tSC)
    if $isobject(pProgressListener) {
        do pProgressListener.PopStage()
        do pProgressListener.PushStage("Checking module/item references.")
        set tClassCount = 0
        set tReferenceKey = ""
        for {
            set tReferenceKey = $order($$$ZPMDependencyTempData(tNextCounter,tReferenceKey))
            if (tReferenceKey = "") {
                quit
            }
            set tClassCount = tClassCount + 1
        }
        do pProgressListener.SetStageTotalUnits(tClassCount)
    }
    // iterate through classes/include files detected and find home modules (or omit if it's a library class/library include file)
    set tReferenceKey = ""
    for {
        set tReferenceKey = $order($$$ZPMDependencyTempData(tNextCounter,tReferenceKey))
        if (tReferenceKey = "") {
            quit
        }
        // Track this beforehand because of all the "continue"s.
        if $isobject(pProgressListener) {
            do pProgressListener.NotifyUnitCompleted(tReferenceKey)
        }
        // tRawFileName is the file name without file type suffix
        // Keep tReferenceKey untouched since it is used in $Order
        set tRawFileName = tReferenceKey
        set tTopPackage = $piece(tRawFileName,".")
        set tIsCLSFile = 1
        set tIsINCFile = 0
        set tFileType = ..#CLSSUFFIX
        if (tTopPackage = $piece(..#INCPREFIX, ".")) {
            set tIsCLSFile = 0
            set tIsINCFile = 1
            set tFileType = ..#INCSUFFIX
            //remove prefix from include files
            set tTopPackage = $piece(tReferenceKey, ".", 2)
            set tRawFileName = $piece(tReferenceKey, ".", 2, *)
        }
        // If tTopPackage happens to be empty, skip it rather than hitting <SUBSCRIPT> below. (Some weird code using macros for package names causes this right now.)
        if (tTopPackage = "") {
            continue
        }

        // Special cases: skip packages in %SYS assuming methods using them run in %SYS or they are % packages always available.
        if (tIsCLSFile && $data(tSYSPackages(tTopPackage))) {
            continue
        }

        set tMissingInc = tIsINCFile && '##class(%Library.Routine).Exists(tRawFileName)
        set tMissingClass = tIsCLSFile && '##class(%Dictionary.CompiledClass).%ExistsId(tRawFileName) && '##class(%Dictionary.ClassDefinition).%ExistsId(tRawFileName)
        if (tMissingInc || tMissingClass)  {
            // This is its own sort of issue - the class doesn't exist!
            merge pReferences($char(0),tRawFileName, tFileType) = $$$ZPMDependencyTempData(tNextCounter,tReferenceKey)
            continue
        }

        // Do not flag references to non-%Z* % classes (making an exception for %ZEN), %IPM or Ens* package classes.
        // For class file, we check for the presence of at least one "."
        if (tIsCLSFile && $match(tRawFileName,"^(%([^Z]|IPM|ZEN)|Ens([^.])*)\.(.)*$")) {
            continue
        }

        // For include file, no need to check for the presence of at least one "." For instance, %IPM(.inc), EnsUI(.inc), %ZHS.OAuth2(.inc)
        if (tIsINCFile && $match(tRawFileName,"^(%([^Z]|IPM|ZEN)|Ens([^.])*)(.)*$")) {
            continue
        }

        set tHomeModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule(tRawFileName_tFileType)

        // Skipping files whose home module is presented in the module dependency graph.
        // If looking for all references, tDependencies will only contain nothing so will not skip any reference
        if $isobject(tHomeModule) && $data(tDependencies(tHomeModule.Name)) {
            continue
        }

        if tIsCLSFile {
            // The class may also be generated by another class in the module.
            // Example: HS.Data.OIDMapIdentityCodeAliases generated by HS.Data.OIDMap
            set tGeneratedBy = $$$comClassKeyGet(tRawFileName,$$$cCLASSgeneratedby)
            if (tGeneratedBy '= "") && ($$$comClassKeyGet(tRawFileName,$$$cCLASSdeployed) = 2) {
                set tHomeModule = ##class(%IPM.ExtensionBase.Utils).FindHomeModule(tGeneratedBy)
                if $isobject(tHomeModule) && $data(tDependencies(tHomeModule.Name)) {
                    continue
                }
            }
        }

        set tHomeModuleName = $char(0)
        if $isobject(tHomeModule) {
            set tHomeModuleName = tHomeModule.Name
        }
        if pIsModule || ('pIsModule && ($zconvert(tRawFileName_tFileType,"U") '= $zconvert(pName,"U"))) {
            // For non modules, need to ensure references to class itself aren't output
            merge pReferences(tHomeModuleName,tRawFileName,tFileType) = $$$ZPMDependencyTempData(tNextCounter,tReferenceKey)
        }
    }

    if $isobject(pProgressListener) {
        do pProgressListener.PopStage()
        do pProgressListener.PushStage("Saving Results.")
    }
}

ClassMethod GetDependenciesForModule(
	pModule As %IPM.Storage.Module,
	pDirectDepsOnly As %Boolean,
	Output pDependencies) [ Internal, Private ]
{
    kill pDependencies
    if (pDirectDepsOnly) {
        for i = 1:1:pModule.Dependencies.Count() {
            #dim dep As %IPM.Storage.ModuleReference
            set dep = pModule.Dependencies.GetAt(i)
            set pDependencies(dep.Name) = ""
        }
    } else {
        set dependencyList = ##class(%IPM.Storage.Module).GetKnownDependencies(pModule.Name)
        set ptr = 0
        while $listnext(dependencyList,ptr,dep) {
            set pDependencies(dep) = ""
        }
    }
}

/// Get the names of all non % packages in %SYS as keys of the output
/// subscripted array.
ClassMethod GetSysPackageNames(Output pSysPackageNameArray) [ Internal ]
{
    kill pSysPackageNameArray
    new $namespace
    set $namespace = "%SYS"
    set query = "SELECT DISTINCT $Piece(Name, '.') As Package FROM %Dictionary.CompiledClass"
    set statement = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(statement.%Prepare(query))
    set resultSet = statement.%Execute()
    if (resultSet.%SQLCODE < 0) {
        throw ##class(%Exception.SQL).CreateFromSQLCODE(resultSet.%SQLCODE, resultSet.%Message)
    }
    while resultSet.%Next(.sc) {
        $$$ThrowOnError(sc)
        set pSysPackageNameArray(resultSet.%Get("Package")) = ""
    }
    $$$ThrowOnError(sc)
}

/// Validate item name is an existing class or include file
ClassMethod ValidateItemName(pItemName As %String) [ Internal, Private ]
{
    if ('##class(%Dictionary.CompiledClass).%ExistsId($piece(pItemName,".",1, *-1)) && '##class(%Library.Routine).Exists(pItemName)) {
        $$$ThrowOnError($$$ERROR($$$GeneralError, pItemName_" is not an existing .cls or .inc item."))
    }
}

}
