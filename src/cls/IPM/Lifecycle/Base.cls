Include (%occErrors, %syGluedef, %IPM.Common)

Class %IPM.Lifecycle.Base Extends %RegisteredObject [ Abstract ]
{

Property Module As %IPM.Storage.Module [ Private ];

Property PhaseList As %List;

/// $ListBuild list of phases in this lifecycle. <br />
/// For each phase name, an instance method named "%<phase name>" must be defined in the class with a return type of %Status.
Parameter PHASES = {$listbuild("Clean","Initialize", "Reload","*","Validate","ExportData","Compile","Activate","Document","MakeDeployed","Test","Package","Verify", "Publish", "Configure","Unconfigure","ApplyUpdateSteps")};

Property Payload As %Stream.Object [ Private ];

Property Installer As %Stream.TmpCharacter [ Private ];

Parameter EXPORTDEPENDENCIES As BOOLEAN = 0;

Parameter DEPLOYBYDEFAULT As BOOLEAN = 0;

Parameter PACKAGING [ Abstract ];

Property HasDeployedResources As %Boolean [ InitialExpression = 0 ];

Method %OnNew(pModule As %IPM.Storage.Module) As %Status [ Private, ServerOnly = 1 ]
{
    set ..Module = pModule
    quit $$$OK
}

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    quit $$$OK
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    quit $$$OK
}

/// This method can be overrided to include any action that needs to be executed
/// before the process of module's lifecycle, and also before notifying resource processors
Method OnBeforeResourceProcessing(
	pPhase As %String,
	ByRef pParams) As %Status
{
    quit $$$OK
}

/// This method can be overrided to include any action that needs to be executed
/// after the process of module's lifecycle, and also after notifying resource processors
Method OnAfterResourceProcessing(
	pPhase As %String,
	ByRef pParams) As %Status
{
    quit $$$OK
}

Method %DispatchMethod(
	pMethod As %String,
	ByRef pParams,
	pIsComplete As %Boolean = 1,
	Args...) [ ServerOnly = 1 ]
{
    // Match method name with CamelCased lifecycle method
    set convertedMethod = ..MatchSinglePhase(pMethod)

    if $listfind(..#PHASES,convertedMethod)=0 {
        do $zutil(96,3,$$$ERNOMETHOD,1,"","method "_convertedMethod_" of class "_$classname())
    }
    quit ..Module.ExecutePhases(..Module.Name,$listbuild(convertedMethod),pIsComplete,.pParams)
}

/// Merges default parameters into pParams
/// For now, just looks at ^SYS("PackageManager","DefaultParameters")
ClassMethod GetDefaultParameters(
	ByRef pParams,
	pPhases As %List)
{
    merge pParams = ^SYS("PackageManager","DefaultParameters")
}

/// Returns the default resource processor class to use for a given resource name.
ClassMethod GetDefaultResourceProcessor(pResourceName As %String) As %Dictionary.Classname
{
    if ($extract(pResourceName) = "/") {
        if pResourceName [ "/internal/testing/" {
            quit $$$DefaultProcessorPackageDot_"Test"
        }
        quit ""
    }
    set tExtension = $$$ucase($piece(pResourceName,".",*))
    set tShortName = $case(tExtension,
        "PKG":"Package",
        "CLS":"Class",
        "INC":"Include",
        "MAC":"Routine",
        "LOC":"LocalizedMessages",
        "GBL":"Global",
        "DFI":"DeepSeeItem",
        "LUT":"Interoperability",
        "X12":"Interoperability",
        "ESD":"Interoperability",
        "HL7":"Interoperability",
        "DTL":"Class",
        "BPL":"Class",
             :"Document")
    if (tShortName = "") {
        quit ""
    }
    quit $$$DefaultProcessorPackageDot_"Default."_tShortName
}

ClassMethod GetDefaultResourceProcessorProc(
	pLifecycleClass As %Dictionary.Classname,
	pResourceName As %String) As %String [ SqlName = GET_DEFAULT_RESOURCE_PROCESSOR, SqlProc ]
{
    // Fail gracefully (just say there is no default) if pLifecycleClass is empty/invalid.
    set tLifecycleClass = pLifecycleClass
    if (tLifecycleClass = "") {
        quit ""
    }
    if '$$$comClassDefined(tLifecycleClass) {
        // Try default package.
        set tLifecycleClass = $$$DefaultLifecyclePackageDot_tLifecycleClass
    }
    if '$$$comClassDefined(tLifecycleClass) {
        quit ""
    }
    quit $classmethod(tLifecycleClass,"GetDefaultResourceProcessor",pResourceName)
}

/// This method defines what a complete phase means for a given list of phases
ClassMethod GetCompletePhases(pPhases As %List) As %List
{
    // If there is only phase, and the phase is not found in standard phases, it is a custom phase. Return as-is.
    if ($listlength(pPhases) = 1) && ('$listfind(..#PHASES, ..MatchSinglePhase($list(pPhases,1)))) {
        return pPhases
    }
    for i=1:1:$listlength(pPhases) {
        set tPhasesList = ..GetCompletePhasesForOne($list(pPhases,i))
        for j=1:1:$listlength(tPhasesList) {
            set one = $list(tPhasesList,j)
            if one'="" {
                set tPhasesArray(one) = ""
            }
        }
    }
    set tResultingPhases = ""
    for i=1:1:$listlength(..#PHASES) {
        set one = $list(..#PHASES,i)
        if $data(tPhasesArray(one)) {
            set tResultingPhases = tResultingPhases_$listbuild(one)
        }
    }
    quit tResultingPhases
}

/// This method defines what a complete phase means for a given phase
ClassMethod GetCompletePhasesForOne(pOnePhase As %String) As %List
{
    set pOnePhase = $zconvert(pOnePhase, "L")
    quit $case(pOnePhase,
        "clean":            $listbuild("Clean"),
        "initialize":       $listbuild("Initialize"),
        "reload":           $listbuild("Initialize","Reload","*"),
        "validate":         $listbuild("Initialize","Reload","*","Validate"),
        "exportdata":       $listbuild("ExportData"),
        "compile":          $listbuild("Initialize","Reload","*","Validate","Compile"),
        "activate":         $listbuild("Initialize","Reload","*","Validate","Compile","Activate"),
        "document":         $listbuild("Document"),
        "makedeployed":     $listbuild("MakeDeployed"),
        "test":             $listbuild("Initialize","Reload","*","Validate","Compile","Activate","Test"),
        "package":          $listbuild("Initialize","Reload","*","Validate","Compile","Activate","Package"),
        "verify":           $listbuild("Initialize","Reload","*","Validate","Compile","Activate","Package","Verify"),
        "register":         $listbuild("Initialize","Reload","*","Validate","Compile","Activate","Package","Register"),
        "publish":          $listbuild("Initialize","Reload","*","Validate","Compile","Activate","Publish"),
        "applyupdatesteps": $listbuild("Initialize","Reload","*","Validate","Compile","Activate","ApplyUpdateSteps"),
        "configure":        $listbuild("Configure"),
        "unconfigure":      $listbuild("Unconfigure"),
        :                   ""
    )
}

/// Match single inputted phase to the correctly CamelCased lifecycle phase <br/>
ClassMethod MatchSinglePhase(pOnePhase As %String) As %String
{
    set phase = $zconvert(pOnePhase, "L")
    quit $case(phase,
        "clean":            "Clean",
        "initialize":       "Initialize",
        "reload":           "Reload",
        "validate":         "Validate",
        "exportdata":       "ExportData",
        "compile":          "Compile",
        "activate":         "Activate",
        "document":         "Document",
        "makedeployed":     "MakeDeployed",
        "test":             "Test",
        "package":          "Package",
        "verify":           "Verify",
        "register":         "Register",
        "publish":          "Publish",
        "configure":        "Configure",
        "unconfigure":      "Unconfigure",
        "applyupdatesteps": "ApplyUpdateSteps",
        :                   pOnePhase // return the phase as-is if it's a custom phase name
    )
}

Method OnBeforeArtifact(
	pExportDirectory As %String,
	pWorkingDirectory As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        // Notify resource processors
        set orderedResourceList = ..Module.GetOrderedResourceList()
        set tKey = ""
        for {
            #dim tResource As %IPM.Storage.ResourceReference
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:(tKey="")

            if $isobject(tResource.Processor) {
                set tSC = $method(tResource.Processor,"OnBeforeArtifact",pExportDirectory,pWorkingDirectory,.pParams)
                if $$$ISERR(tSC) {
                    quit
                }
            }
        }
        if $$$ISERR(tSC) {
            quit
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method Log(
	pMessage As %String = "",
	pValues...)
{
    if pMessage'="" {
        write !,"[", $namespace, "|", ..Module.Name, "]", $char(9), $$FormatText^%occMessages(pMessage, pValues...)
    }
}

Method CheckBeforeClean(
	ByRef pParams,
	Output pSkip As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        set tLevel = $get(pParams("Clean","Level"),0)
        set tRecurse = $get(pParams("Clean","Recurse"),1)

        if (..Module.GlobalScope && '$get(pParams("Clean","GlobalScope"))) {
            do ..Log("Clean SKIPPED - module has global scope.")
            set pSkip = 1
            quit
        }

        if '$get(pParams("Clean","Force")) {
            // Check to see if anything depends on this module and return an error status if it does.
            set tSC = ##class(%IPM.Utils.Module).GetDependentsList(.tList,,..Module.Name)
            if $$$ISERR(tSC) {
                quit
            }

            set tModList = ""
            for i=1:1:tList.Count() {
                set tName = tList.GetAt(i).Name
                if '$data(pParams("Clean","Cycle",tName)) {
                    set tModList = tModList_$listbuild(tName)
                }
            }

            if ($listlength(tModList) > 0) && (tLevel > 0) {
                do ..Log("Clean SKIPPED - required by " _ $listlength(tModList) _ " other module" _ $case($listlength(tModList),1:"",:"s") _ ". (" _ $listtostring(tModList,"; ") _ ")")
                set pSkip = 1
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if pSkip {
        set pParams("Clean","Skip",..Module.Name) = ""
    }
    quit tSC
}

Method %Clean(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set pParams("Clean","Cycle",..Module.Name) = ""

        set tVerbose = $get(pParams("Verbose"))
        set tLevel = $get(pParams("Clean","Level"),0)
        set tRecurse = $get(pParams("Clean","Recurse"),1)
        set tRemoveMapped = $get(pParams("Clean","GlobalScope"),0)

        // Create an instance of the repository manager singleton
        // This makes it available at lower stack levels, which helps
        // to avoid significant duplicate work in dependency resolution.
        set tRepositoryManager = ##class(%IPM.Repo.Manager).%Get(.tSC)
        $$$ThrowOnError(tSC)

        set tSC = ..CheckBeforeClean(.pParams,.tSkip)
        $$$ThrowOnError(tSC)
        if (tSkip) {
            quit
        }

        if (tLevel > 0) {
            set orderedResourceList = ..Module.GetOrderedResourceList()
            set tKey = ""
            for {
                #dim tResource As %IPM.Storage.ResourceReference
                set tResource = orderedResourceList.GetNext(.tKey)
                quit:tKey=""

                if $isobject(tResource.Processor) && tResource.IsInScope("Clean") {
                    set tSC = tResource.Processor.OnPhase("Clean",.pParams,.tResourceHandled)
                    $$$ThrowOnError(tSC)
                    if (tResourceHandled) {
                        continue
                    }
                }

                kill tResourceChildren
                do tResource.ResolveChildren(.tResourceChildren)
                set tChildKey = ""
                for {
                    set tChildKey = $order(tResourceChildren(tChildKey))
                    quit:tChildKey=""

                    if ($extract(tChildKey) = "/") {
                        continue
                    }

                    set tName = $piece(tChildKey,".",1,*-1)
                    set tExt = $zconvert($piece(tChildKey,".",*),"U")
                    continue:tExt=""
                    continue:tName=""
                    set tDeleteArray(tExt,tName) = ""
                }
            }

            // Pass 1: non-projection classes
            // Pass 2: projection classes (extending %Projection.AbstractProjection)
            // This gives RemoveProjection a decent chance of working if other classes in the module define projections of that type.
            for tPass = 1,2 {
                if $data(tDeleteArray("CLS")) {
                    kill tClassArray,tDeferArray
                    merge tClassArray = tDeleteArray("CLS")
                    set tClassKey = ""
                    for {
                        set tClassKey = $order(tClassArray(tClassKey))
                        quit:tClassKey=""

                        if 'tRemoveMapped && ##class(%Library.RoutineMgr).IsMapped(tClassKey_".CLS") {
                            write !,"WARNING: Skipping mapped resource ",tClassKey,".CLS"
                            continue
                        }

                        set tComClassDefined = $$$comClassDefined(tClassKey)
                        if tComClassDefined || $$$defClassDefined(tClassKey) {
                            // Test for (primary super) [ "~%Projection.AbstractProjection~" rather than $classmethod/%Extends to avoid <CLASS DOES NOT EXIST>
                            if (tPass = 1) && tComClassDefined && ($$$comClassKeyGet(tClassKey,$$$cCLASSprimarysuper) [ "~%Projection.AbstractProjection~") {
                                set tDeferArray(tClassKey) = ""
                                continue
                            }
                            set tDelSC = $system.OBJ.Delete(tClassKey,$select(tVerbose:"d",1:"-d"))
                            if $$$ISERR(tDelSC) {
                                write !,"WARNING: ",$system.Status.GetErrorText(tDelSC)
                            }
                        }
                    }
                    kill tDeleteArray("CLS")
                    merge tDeleteArray("CLS") = tDeferArray
                }
            }

            kill tDeleteArray("PKG") // Handled above due to ResolveChildren

            // Clean up other items individually.
            if $data(tDeleteArray) {
                set tType = ""
                for {
                    set tType = $order(tDeleteArray(tType))
                    quit:tType=""

                    set tItem = ""
                    for {
                        set tItem = $order(tDeleteArray(tType,tItem))
                        quit:tItem=""

                        set tFullName = tItem_"."_tType

                        if 'tRemoveMapped && ##class(%Library.RoutineMgr).IsMapped(tFullName) {
                            write !,"WARNING: Skipping mapped resource ",tFullName
                            continue
                        }

                        if tVerbose {
                            write !,"Deleting ",tFullName
                        }
                        set tDelSC = ##class(%Library.RoutineMgr).Delete(tFullName)
                        if $$$ISERR(tDelSC) {
                            write !,"WARNING: "_$system.Status.GetErrorText(tDelSC)
                        }
                    }
                }
            }
        }

        if tRecurse {
            for i=1:1:..Module.Dependencies.Count() {
                set tModName = ..Module.Dependencies.GetAt(i).Name
                if $data(pParams("Clean","Cycle",tModName)) {
                    continue
                }
                zkill pParams("Clean","Skip",tModName)
                if ##class(%IPM.Storage.Module).NameExists(tModName) {
                    set tModObj = ##class(%IPM.Storage.Module).NameOpen(tModName,,.tModSC)
                    if $$$ISERR(tModSC) {
                        write !,"WARNING: "_$system.Status.GetErrorText(tModSC)
                        continue
                    }
                    kill tParams
                    merge tParams = pParams
                    zkill:'tRecurse tParams("Clean","Force")
                    set tParams("Clean","Level") = tLevel + 1
                    set tParams("Clean","Nested") = 1
                    set tSC = tModObj.Lifecycle.Clean(.tParams)
                    if $$$ISERR(tSC) {
                        quit
                    }
                    if '$data(tParams("Clean","Skip",tModName)) {
                        set tSC = ##class(%IPM.Storage.Module).NameDelete(tModName)
                        if $$$ISERR(tSC) {
                            quit
                        }
                        write:tVerbose !,"Deleted ",tModName
                    }
                }
            }
            if $$$ISERR(tSC) {
                quit
            }
        }

        if (tLevel > 0) && '$get(pParams("Clean","Nested"),0) {
            set tSC = ##class(%IPM.StudioDocument.Module).Delete(..Module.Name_".ZPM")
            if $$$ISERR(tSC) {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %ExportData(ByRef pParams) As %Status
{
    quit $$$OK
}

Method %Configure(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {

        if (..Module.InstallerClass '= "") {
            set tVerbose = $get(pParams("Verbose"),0)
            // getting custom parameters from command line or <Default> element
            do ##class(%IPM.Storage.ModuleSetting.Default).GetCustomParameters(.customParams,..Module, .pParams)
            set tDeveloperMode = $get(pParams("DeveloperMode"),0)
            set tDatabaseName = $get(pParams("Configure","DatabaseName"))
            set tIsUpgrade = $get(pParams("Configure","IsUpgrade"),0)
            merge tVars = pParams
            merge tVars = pParams("Configure","Parameters")
            kill tVars("Configure","Parameters")
            set tVars("PackageManager","Lifecycle") = $this
            set tVars("InstallDir") = ..Module.Root

            // Call OnInstallComponent
            set tSC = $classmethod(..Module.InstallerClass,"OnInstallComponent",tDatabaseName,tVerbose,tDeveloperMode,tIsUpgrade)
            if $$$ISERR(tSC) {
                quit
            }

            // Call OnConfigureComponent
            set tSC = $classmethod(..Module.InstallerClass,"OnConfigureComponent",$namespace,tVerbose,.tVars)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Unconfigure(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        if (..Module.InstallerClass '= "") {
            set tVerbose = $get(pParams("Verbose"),0)
            set tDeveloperMode = $get(pParams("DeveloperMode"),0)
            set tDatabaseName = $get(pParams("Configure","DatabaseName"))
            set tIsUpgrade = $get(pParams("Configure","IsUpgrade"),0)
            set tPurge = $get(pParams("Configure","Purge"),0)
            merge tVars = pParams
            merge tVars = pParams("Configure","Parameters")
            kill tVars("Configure","Parameters")
            set tVars("PackageManager","Lifecycle") = $this

            // Call OnUnconfigureComponent
            set tSC = $classmethod(..Module.InstallerClass,"OnUnconfigureComponent",$namespace,tVerbose,tPurge,.tVars)
            if $$$ISERR(tSC) {
                quit
            }

            // Call OnUnInstallComponent
            set tSC = $classmethod(..Module.InstallerClass,"OnUnInstallComponent",tDatabaseName,tVerbose)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Initialize(ByRef pParams) As %Status
{
    set status = $$$OK
    try {
        set orderedResourceList = ..Module.GetOrderedResourceList()
        set key = ""
        for {
            set resource = orderedResourceList.GetNext(.key)
            quit:key=""
            if $isobject(resource.Processor) {
                set status = $$$ADDSC(status,resource.Processor.OnPhase("Initialize",.pParams))
            }
        }

        set preloadRoot = $get(pParams("RootDirectory"))_"preload"
        set verbose = $get(pParams("Verbose"))
        if ##class(%File).DirectoryExists(preloadRoot) {
            set tSC = $system.OBJ.ImportDir(preloadRoot, "*", $select(verbose:"d",1:"-d")_$select($tlevel:"/multicompile=0", 1: ""), , 1, .tImported)
            if $$$ISERR(tSC) { quit }
            set tSC = ##class(%IPM.Utils.LegacyCompat).UpdateSuperclassAndCompile(.tImported)
            if $$$ISERR(tSC) { quit }
        } elseif verbose {
            write !,"Skipping preload - directory does not exist."
        }
    } catch ex {
        set status = ex.AsStatus()
    }
    quit status
}

Method %Reload(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        // If %SourceControl has been set up by the caller (e.g., ^build), ensure that it does not interfere with resource reload.
        // (Sometimes %Studio.SourceControl.ISC will complain about files not being checked out.)
        new %SourceControl

        set tModuleName = ..Module.Name
        set tDeveloperMode = +$get(pParams("DeveloperMode"),..Module.DeveloperMode)
        set tSkipScoped = 'tDeveloperMode
        set tVerbose = $get(pParams("Verbose"))
        set tRoot = $get(pParams("RootDirectory"))
        if (tRoot = "") && tDeveloperMode {
            set tRoot = ..Module.Root
        }
        do ..LoadEnvironmentConfig($get(pParams("EnvFiles")))

        // For now, no-op if no root is configured.
        quit:tRoot=""

        set tRoot = ##class(%File).NormalizeDirectory("",tRoot)
        set tSC = $system.OBJ.Import(tRoot_"module.xml","/nodisplay",,.error,.tLoadedList) quit:$$$ISERR(tSC)

        // If publishing deployed code in a new namespace, also need to load dependencies
        set deployOriginalNS = $get(pParams("PackageDeployOriginalNamespace"))
        if deployOriginalNS '= "" {
            new $namespace
            set currentNamespace = $namespace
            set deps = ..Module.Dependencies
            for i=1:1:deps.Count() {
                set depName = deps.GetAt(i).Name
                // switch to old namespace to grab dependency root
                set $namespace = deployOriginalNS
                if ##class(%IPM.Storage.Module).NameExists(depName) {
                    set depModule = ##class(%IPM.Storage.Module).NameOpen(depName,,.tSC)
                    if $$$ISERR(tSC) {
                        quit
                    }
                    set depRoot = depModule.Root
                    if (depRoot'="") {
                        set depRoot = ##class(%File).NormalizeDirectory("",depRoot)
                        if tVerbose {
                            write !,"Loading dependency " _ depName _ " from "_depRoot _ " into " _ currentNamespace
                        }
                        // switch to current namespace to import dependency
                        set $namespace = currentNamespace
                        set tSC = $system.OBJ.Import(depRoot_"module.xml","/nodisplay",,.error,.tDepLoadedList) quit:$$$ISERR(tSC)

                        // set root of dependency module to the one we just loaded from
                        set newDepModule = ##class(%IPM.Storage.Module).NameOpen(depName,,.tSC)
                        if $$$ISERR(tSC) {
                            quit
                        }
                        if (newDepModule.Root '= depRoot) {
                            if tVerbose {
                                write !,"Changing module root from '"_newDepModule.Root_"' to '"_depRoot_"'"
                            }
                            set newDepModule.Root = depRoot
                            $$$ThrowOnError(newDepModule.%Save())
                        }
                    }
                }
            }
            // make sure we end up back in the current namespace
            set $namespace = currentNamespace
        }


        // Validate loaded module
        set first = $$$lcase($order(tLoadedList("")))
        if (first = "") {
            set tSC = $$$ERROR($$$GeneralError,"No module definition found.")
            quit
        }
        if ($order(tLoadedList("")) '= $order(tLoadedList(""),-1)) {
            set tSC = $$$ERROR($$$GeneralError,"module.xml is malformed; it may only contain one document.")
            quit
        }
        if ($piece($$$ucase(first),".",*) '= "ZPM") {
            set tSC = $$$ERROR($$$GeneralError,"No module definition found.")
            quit
        }
        if (tModuleName '= $piece(first,".",1,*-1)) {
            set tSC = $$$ERROR($$$GeneralError,"Module name mismatch.") quit
        }

        #; Reopen, useful in Packaging deployed modules
        set ..Module = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
        $$$ThrowOnError(tSC)

        // Set up mappings
        set tKey = ""
        for {
            #dim tMapping As %IPM.Storage.MappingReference
            set tMapping = ..Module.Mappings.GetNext(.tKey)
            quit:tKey=""

            set tName = $piece(tMapping.Name,".",1,*-1)
            set tExtension = $piece(tMapping.Name,".",*)
            set tSource = tMapping.SourceResolved

            set tSC = $case(tExtension,
                "GBL":##class(%IPM.Utils.Module).AddGlobalMapping($namespace,tName,tSource),
                "INC":##class(%IPM.Utils.Module).AddRoutineMapping($namespace,tName,,tSource),
                "MAC":##class(%IPM.Utils.Module).AddRoutineMapping($namespace,tName,"MAC",tSource),
                "PKG":##class(%IPM.Utils.Module).AddPackageMapping($namespace,tName,tSource),
                "":##class(%IPM.Utils.Module).AddRoutineMapping($namespace,tName,"ALL",tSource))
            if $$$ISERR(tSC) {
                quit
            }
            if (tVerbose) {
                write !, "Added "_tExtension_" mapping "_tName_" from database "_tSource
            }
        }
        if $$$ISERR(tSC) {
            quit
        }

        $$$ThrowOnError(..InstallPythonRequirements(tRoot, .pParams))

        // Reload the module definition
        set tSC = ..Module.%Reload()
        if $$$ISERR(tSC) {
            quit
        }

        if (..Module.Root '= tRoot) {
            if tVerbose {
                write !,"Changing module root from '"_..Module.Root_"' to '"_tRoot_"'"
            }
            set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnChangeModuleRoot(..Module)
            $$$ThrowOnError(tSC)
        }

        set ..Module.DeveloperMode = tDeveloperMode
        set ..Module.Root = tRoot
        $$$ThrowOnError(..Module.%Save())

        set tGlobalScope = ..Module.GlobalScope && '$get(pParams("Reload","ForceLocalScope"),0)
        set tAbsolutePrefix = $char($parameter("%IPM.ExtensionBase.SourceControl.Interface","NOPREFIXCHARCODE"))

        // Ensures, for example, that HS.PM isn't mapped to ^Sources("MODULE","HS.PM")_"HS/module.xml"
        if tDeveloperMode {
            set ^Sources = $get(^Sources)
            set ^Sources("MODULE","*","NoFolders")=1
            set ^Sources("MODULE",..Module.Name) = tAbsolutePrefix_tRoot
        }

        // Resource processing
        set orderedResourceList = ..Module.GetOrderedResourceList()
        set tSC = $$$OK
        set tKey = ""
        for {
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:tKey=""
            if $isobject(tResource.Processor) && tResource.IsInScope("Reload") {
                set tSC = $$$ADDSC(tSC,tResource.Processor.OnPhase("Reload",.pParams))
            }
        }
        // If publishing deployed code in a new namespace, also process resources for dependencies
        if deployOriginalNS '= "" {
            set deps = ..Module.Dependencies
            for i=1:1:deps.Count() {
                set depName = deps.GetAt(i).Name
                set depMod = ##class(%IPM.Storage.Module).NameOpen(depName,,.tSC)
                if $$$ISERR(tSC) {
                    quit
                }
                set depResourceList = depMod.GetOrderedResourceList()
                for j=1:1:depResourceList.Count() {
                    set depResource = depResourceList.GetAt(j)
                    if $isobject(depResource.Processor) && depResource.IsInScope("Reload") {
                        set tSC = $$$ADDSC(tSC,depResource.Processor.OnPhase("Reload",.pParams))
                    }
                }
            }
        }
        if $$$ISERR(tSC) {
            quit
        }

        // call %OnModifyResources to let the source control class do any other mapping it needs to
        set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnModifyResources(..Module)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method InstallPythonRequirements(
	pRoot As %String = "",
	ByRef pParams)
{
    set cmd = $get(pParams("cmd"))
    if '$listfind($listbuild("install", "load"), cmd) {
        quit $$$OK
    }
    set tVerbose = $get(pParams("Verbose"))
    if $get(pParams("BypassPyDeps"), 0) {
        if tVerbose {
        write !, "Skipping installation of Python dependencies because -bypass-py-deps is set."
        }
        quit $$$OK
    }
    set tExtraPipFlags = $zstrip($get(pParams("ExtraPipFlags"), ""), "<>WC")
    set pythonRequirements = ##class(%File).NormalizeFilename("requirements.txt", pRoot)
    if '##class(%File).Exists(pythonRequirements) {
        quit $$$OK
    }
    set tSC = $$$OK
    try {
        do ..Log("requirements.txt START")
        write:tVerbose !

        set target = ##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
        if '$system.CLS.IsMthd("%SYS.Python", "Import") {
            throw ##class(%Exception.General).%New("Embedded Python is not available in this instance.")
        }
        set tSysModule = ##class(%SYS.Python).Import("sys")
        set tPyMajor = tSysModule."version_info".major
        set tPyMinor = tSysModule."version_info".minor
        set tPyMicro = tSysModule."version_info".micro
        set tPyVersion = tPyMajor_"."_tPyMinor_"."_tPyMicro
        set command = ..ResolvePipCaller(.pParams) _ $listbuild("install", "-r", "requirements.txt", "-t", target, "--python-version", tPyVersion, "--only-binary=:all:") _ $listfromstring(tExtraPipFlags, " ")
        if tVerbose {
            write !, "Running "
            zwrite command
        } else {
            set stdout = ""
        }
        set tSC = ##class(%IPM.Utils.Module).RunCommand(pRoot, command,.stdout)
        $$$ThrowOnError(tSC)

        do ..Log("requirements.txt SUCCESS")
    } catch ex {
        set tSC = ex.AsStatus()
        do ..Log("requirements.txt FAILURE")
    }
    quit tSC
}

ClassMethod ResolvePipCaller(ByRef pParams) As %List
{
    set tUseStandalonePip = ##class(%IPM.Repo.UniversalSettings).GetValue("UseStandalonePip")
    set tPipCaller = ##class(%IPM.Repo.UniversalSettings).GetValue("PipCaller")

    if tPipCaller '= "" {
        if tUseStandalonePip = 1 {
            return $listbuild(tPipCaller)
        } elseif tUseStandalonePip = 0 {
            return $listbuild(tPipCaller, "-m", "pip")
        } else {
            set msg = "Detected PipCaller=""" _ tPipCaller _ """ but UseStandalonePip is not properly set." _ $char(13, 10)
            set msg = msg _ "Please set UseStandalonePip to 1 (if using a pip executable) or 0 (if using a python executable)." _ $char(13, 10)
            set msg = msg _ "Example: zpm ""config set UseStandalonePip 1"""
            throw ##class(%Exception.General).%New(msg)
        }
    }
    return ..DetectPipCaller(tUseStandalonePip, $get(pParams("Verbose"), 0))
}

ClassMethod DetectPipCaller(
	pUseStandalonePip As %Boolean,
	pVerbose As %Boolean = 0) As %List
{
    if pVerbose {
        write !,"Detecting pip caller"
    }

    // First try to detect flexible python (in 2024.2 and later)
    // This is a hack that doesn't always work because the python interpreter may not be in the same directory as the so/dylib/dll.
    if $system.CLS.IsMthd("%SYS.Python","GetPythonInfo") {
        if pVerbose {
            write !, "Attempting to find flexible python... "
        }
        do ##class(%SYS.Python).GetPythonInfo(.info)
        if $data(info("CPF_PythonRuntimeLibrary"), tPyDylib) && (tPyDylib '= "") {
            // TODO: try `../bin/python3` or `../bin/python` in case the .so is in subfolder `lib`
            // TODO: try to find `pip3` or `pip` if pUseStandalonePip is 1
            for filename = "python3", "python" {
                set tInterpreter = ##class(%File).GetDirectory(tPyDylib, 1) _ filename
                if $$$isWINDOWS {
                    set tInterpreter = tInterpreter_".exe"
                }
                if ##class(%File).Exists(tInterpreter) {
                    if pVerbose{
                        write "Success!"
                    }
                    return $listbuild(tInterpreter, "-m", "pip")
                }
                if pVerbose {
                    write "Not Found"
                }
            }
        }
    }

    // For windows, try to find irispip.exe (in 2024.1 and earlier)
    if $$$isWINDOWS {
        if pVerbose {
            write !, "Attempting to find irispip.exe..."
        }
        set irispip = ##class(%File).NormalizeFilename("irispip.exe", $system.Util.BinaryDirectory())
        if ##class(%File).Exists(irispip) {
            if pVerbose {
                write "Success!"
            }
            return $listbuild(irispip)
        }
        if pVerbose {
            write "Not Found"
        }
    }

    // Unless UseStandalonePip is set to 1, try to find python3 or python
    if pUseStandalonePip '= 1 {
        if pVerbose {
            write !, "Attempting to find python3 or python..."
        }
        for cmd = "python3", "python" {
            if $$$isWINDOWS {
                set cmd = cmd _ ".exe"
            }
            set cmd = $listbuild(cmd, "-m", "pip")
            set cwd = ##class(%SYSTEM.Util).InstallDirectory()
            set tSC = ##class(%IPM.Utils.Module).RunCommand(cwd, cmd, "")
            if $$$ISOK(tSC) {
                if pVerbose {
                    write "Success!"
                }
                return cmd
            }
            if pVerbose {
                write "Not Found"
            }
        }
    }

    // Unless UseStandalonePip is set to 0, try to find pip3 or pip
    if pUseStandalonePip '= 0 {
        if pVerbose {
            write !, "Attempting to find pip3 or pip..."
        }
        for cmd = "pip3", "pip" {
            if $$$isWINDOWS {
                set cmd = cmd _ ".exe"
            }
            set cmd = $listbuild(cmd)
            set cwd = ##class(%SYSTEM.Util).InstallDirectory()
            set tSC = ##class(%IPM.Utils.Module).RunCommand(cwd, cmd, "")
            if $$$ISOK(tSC) {
                if pVerbose {
                    write "Success!"
                }
                return cmd
            }
            if pVerbose {
                write "Not Found"
            }
        }
    }

    throw ##class(%Exception.General).%New("Could not find a suitable pip caller. Consider setting UseStandalonePip and PipCaller")
}

Method %Validate(ByRef pParams) As %Status
{
    // NOTE: Resource processor classes and their attributes are validated in OnBeforePhase,
    // so Validate isn't totally pointless.
    quit $$$OK
}

Method %Compile(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        set tDevMode = $get(pParams("DeveloperMode"),+..Module.DeveloperMode)
        set isKitBuild = $get(pParams("IsKitBuild"),0)

        // Setting $$$BuildFlag (a % variable) turns on storage checking, which will be handled/implemented by %SourceControl
        // if SourceControlCreate() defines it. (See OnAfterStorage method, which the composite extension passes along
        // to the primary source control class.)
        new $$$BuildFlag
        set $$$BuildFlag = 1
        if tDevMode {
            // We only want to do this for the scope of the module in developer mode, so both variables are New'd here.
            new %SourceControl
            $$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlCreate())
        }

        // Load dependencies correctly for the requested phases. (This will be a no-op in most cases.)
        set tSC = ..Module.LoadDependencies(..PhaseList,.pParams)
        $$$ThrowOnError(tSC)

        // Compile items within the module that are compilable using OnPhase
        set orderedResourceList = ..Module.GetOrderedResourceList()
        set tKey = ""
        for {
            #dim tResource As %IPM.Storage.ResourceReference
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:tKey=""

            set tHandled = 0
            if $isobject(tResource.Processor) && tResource.IsInScope("Compile") {
                do tResource.Processor.OnPhase("Compile",.pParams,.tHandled)
                if (tHandled) {
                    set tHandledMap(tResource.Name) = ""
                    continue
                }
            }
        }

        // Build maps of other compilable things
        set tKey = ""
        for {
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:tKey=""

            if '$data(tHandledMap(tResource.Name)) && $isobject(tResource.Processor) {
                if tResource.Processor.%IsA("%IPM.ResourceProcessor.AbstractCompilable") && tResource.Processor.CompileFromProject {
                    if tVerbose {
                        write !, tResource.Name_" was loaded as deployed code, so compilation isn't needed."
                    }
                } elseif tResource.Processor.%IsA("%IPM.ResourceProcessor.AbstractCompilable") {
                    kill tOneResourceList
                    set tOneResourceList(tResource.Name) = ""
                    set tSC = tResource.ResolveChildren(.tOneResourceList)
                    $$$ThrowOnError(tSC)

                    set tCompilableMap(tResource.Name) = ""

                    // Prerequisites
                    // Builds two maps:
                    // tDependencyMap("<thing to compile first>","<thing dependent on it>") = ""
                    // tDependentMap("<dependent thing>","<thing to compile first>") = ""
                    set tCompileAfterList = $listfromstring(tResource.Processor.CompileAfter)
                    if (tCompileAfterList '= "") {
                        set tPointer = 0
                        while $listnext(tCompileAfterList,tPointer,tDependency) {
                            if '$data(tHandledMap(tDependency)) {
                                set tDependencyMap(tDependency,tResource.Name) = ""
                                set tDependentMap(tResource.Name,tDependency) = ""
                            }
                        }
                    }

                    // Compile Flags (second grouping)
                    set tFlags = tResource.Processor.Flags
                    set tFlags = $case(tFlags,"":"<none>",:tFlags)

                    // Just copy the first level of subscripts (resource names), not all the gory details.
                    set tOneResourceKey = ""
                    for {
                        set tOneResourceKey = $order(tOneResourceList(tOneResourceKey))
                        quit:(tOneResourceKey="")
                        if (('tDevMode) && ($get(tOneResourceList(tOneResourceKey, "Deploy"))) && ('isKitBuild) && (..Module.Deployed)) {
                            continue
                        }
                        set tCompileFlagMap(tFlags,tResource.Name,tOneResourceKey) = ""
                    }
                }
            }
        }

        // Ensure there are no CompileAfter dependencies on resources absent from the module.
        set tKey = ""
        for {
            set tKey = $order(tDependencyMap(tKey))
            quit:tKey=""

            if '$data(tCompilableMap(tKey)) {
                set tCulprit = $order(tDependencyMap(tKey,""))
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Resource '%1' cannot compile after nonexistent/non-compilable resource '%2'",tCulprit,tKey))
                $$$ThrowStatus(tSC)
            }
        }
        // Compile in multiple passes, grouped by compile flags.
        set tCompiledSomething = 0
        for {
            if '$data(tCompilableMap) {
                quit
            }

            set tCompiledSomething = 0
            set tFlags = ""
            for {
                set tFlags = $order(tCompileFlagMap(tFlags))
                quit:tFlags=""

                // Build array of classes to compile with a given set of compile flags
                kill tFlagSet
                merge tFlagSet = tCompileFlagMap(tFlags)
                set tResourceKey = ""
                kill tCompileArray
                set tCompileList = ""
                for {
                    set tResourceKey = $order(tFlagSet(tResourceKey))
                    quit:tResourceKey=""

                    if '$data(tDependentMap(tResourceKey)) {
                        merge tCompileArray = tFlagSet(tResourceKey)
                        set tCompileList = tCompileList_$listbuild(tResourceKey)
                        kill tCompileFlagMap(tFlags,tResourceKey)
                        kill tCompilableMap(tResourceKey)
                    }
                }

                set tNoCompileLock = '$get(pParams("NoLock"))
                if $$$IsISCWorker && 'tNoCompileLock {
                    // Customized locking - takes out shared locks on dependencies to avoid conflicts between parallel module loads.
                    set tSC = ##class(%IPM.Utils.LockManager).LockClassesRecursive(.tLockManager,.tCompileArray,.tLockedClasses)
                    $$$ThrowOnError(tSC)
                    set tNoCompileLock = 1
                }

                // Actually do the compile
                if $data(tCompileArray)>1 {
                    set tCompiledSomething = 1
                    set tStruct = $select(tVerbose:"d",1:"-d")_$select(tNoCompileLock:"-l",1:"")_tFlags
                    set tSC = ##class(%IPM.Utils.LegacyCompat).UpdateSuperclassAndCompile(.tCompileArray, .tStruct)
                    $$$ThrowOnError(tSC)
                }

                // Update dependency tracking to reflect that things were compiled.
                // Reminder:
                // tDependencyMap("<thing to compile first>","<thing dependent on it>") = ""
                // tDependentMap("<dependent thing>","<thing to compile first>") = ""
                set tPointer = 0
                while $listnext(tCompileList,tPointer,tCompiledResource) {
                    set tDependent = ""
                    for {
                        set tDependent = $order(tDependencyMap(tCompiledResource,tDependent))
                        quit:tDependent=""

                        kill tDependentMap(tDependent,tCompiledResource)
                    }
                    kill tDependencyMap(tCompiledResource)
                }
            }

            // Cycle detection
            if ('tCompiledSomething && '..HasDeployedResources) {
                set tFailedResources = ""
                set tResource = ""
                for {
                    set tResource = $order(tCompilableMap(tResource))
                    quit:tResource=""
                    set tFailedResources = tFailedResources_$listbuild(tResource)
                }
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Failed to resolve compile order of module resources: %1",$listtostring(tFailedResources,", ")))
                $$$ThrowStatus(tSC)
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Activate(ByRef pParams) As %Status
{
    quit $$$OK
}

Method %Test(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        // Load dependencies correctly for the requested phases. (This will be a no-op in most cases.)
        set tSC = ..Module.LoadDependencies(..PhaseList,.pParams)
        $$$ThrowOnError(tSC)

        set orderedResourceList = ..Module.GetOrderedResourceList()
        set tKey = ""
        for {
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:tKey=""
            if $isobject(tResource.Processor) && tResource.IsInScope("Test") {
                set tSC = $$$ADDSC(tSC,tResource.Processor.OnPhase("Test",.pParams))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Note: This is a utility method, and not a full lifecycle phase at this point.
/// This method exports the module's resources, based on the mappings defined in ^Sources (by %Reload), to the specified directory.
/// If no directory is provided, a new temp directory is created (returned by reference).
/// If dependencies are to be exported, <var>pDependencyGraph</var> is augmented with a "Location" subscript
/// with the relative path within <var>pTargetDirectory</var> in which the module's contents have been exported.
Method %Export(
	ByRef pParams,
	ByRef pTargetDirectory As %String,
	Output pDependencyGraph) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        merge tParams = pParams

        kill pDependencyGraph
        if ($get(pTargetDirectory) = "") {
            set pTargetDirectory = $$$lcase(..Module.Name_"-"_..Module.VersionString)
            set pTargetDirectory = ##class(%File).NormalizeDirectory(pTargetDirectory, $$$FileTempDirSys)
        }

        if '##class(%File).DirectoryExists(pTargetDirectory) {
            kill %objlasterror
            set tCreated = ##class(%File).CreateDirectoryChain(pTargetDirectory,.tReturnValue)
            if 'tCreated {
                set tLastErr = $get(%objlasterror)
                set tSC = $$$EMBEDSC($$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",pTargetDirectory,tReturnValue)),tLastErr)
                quit
            }
        }

        set tExportDependencies = $get(pParams("ExportDependencies"), ..#EXPORTDEPENDENCIES)
        set tSC = ..Module.GetResolvedReferences(.tResourceArray, tExportDependencies,..PhaseList,1,.pDependencyGraph)
        if $$$ISERR(tSC) {
            quit
        }

        // First pass: if we're exporting dependencies, build an array of modules from which we are deriving things.
        if tExportDependencies {
            set tModuleName = ""
            for {
                set tModuleName = $order(tResourceArray(tModuleName))
                quit:(tModuleName="")
                set tFullResourceName = ""
                for {
                    set tFullResourceName = $order(tResourceArray(tModuleName, tFullResourceName))
                    quit:(tFullResourceName="")

                    set tExt = $piece(tFullResourceName,".",*)
                    set tName = $piece(tFullResourceName,".",1,*-1)
                    if ($$$ucase(tExt) = "ZPM") {
                        if (tName '= ..Module.Name) {
                            set pDependencyGraph(tName,"Location") = ".modules/m"_$increment(dependencyCount)_"/"
                        }
                    }
                }
            }
        }

        // Deployed items should be exported as a studio project to a designated directory
        set tDeployedProjectName = ##class(%IPM.Utils.Module).GetDeployedProjectName(..Module.Name)
        set tDeployedProject = ##class(%Studio.Project).%OpenId(tDeployedProjectName)
        if '$isobject(tDeployedProject) {
            set tDeployedProject = ##class(%Studio.Project).%New()
            set tDeployedProject.Name = tDeployedProjectName
        }
        do tDeployedProject.Items.Clear()
        set tParams($$$DeployedProjectIndex) = tDeployedProject

        set tModuleName = ""
        for {
            set tModuleName = $order(tResourceArray(tModuleName))
            if (tModuleName = "") {
                quit
            }
            kill tSingleModuleArray
            merge tSingleModuleArray = tResourceArray(tModuleName)
            do ..ExportSingleModule(.tSingleModuleArray, pTargetDirectory, .pDependencyGraph, .tParams, tVerbose)
        }

        // Export the deployed project to the target directory, if it's non-empty
        if tDeployedProject.Items.Count() > 0 {
            // Intentionally not calling .%Save() on the project; we don't want to persist it.
            set tDeployedProjectPath = ##class(%IPM.Utils.Module).GetDeployedProjectPath(pTargetDirectory)
            $$$ThrowOnError(tDeployedProject.DeployToFile(tDeployedProjectPath, $select(tVerbose:"d",1:"-d")_"/createdirs"))
        }

        /// Always keep these files
        set staticFiles = $listbuild(
            "readme.md",
            "changelog.md",
            "license",
            "requirements.txt",
        )
        set tRes = ##class(%File).FileSetFunc(..Module.Root)
        while tRes.%Next() {
            continue:tRes.Type'="F"
            continue:'$listfind(staticFiles,$$$LOWER(tRes.ItemName))
            set tSourcePath = tRes.Name
            set tExportPath = ##class(%File).NormalizeFilename(tRes.ItemName, pTargetDirectory)
            set tGood = ##class(%File).CopyFile(tSourcePath, tExportPath,1,.tReturn)
            if 'tGood {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying file '%1' to '%2': %3",tSourcePath,tExportPath,tReturn))
                quit
            }
            write:tVerbose !,tSourcePath," -> ",tExportPath
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %PrepareDeploy(ByRef pParams) As %Status [ Abstract ]
{
    set tSC = $$$OK
    try {
        // TODO: Implement
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Package(ByRef pParams) As %Status [ Abstract ]
{
    set tSC = $$$OK
    try {
        // TODO: Implement
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Verify(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        new $namespace
        set tInitNS = $select($namespace="%SYS": "USER", 1: $namespace)
        set tVerbose = $get(pParams("Verbose"))

        if '$get(pParams("Verify","InCurrentNamespace"),0) {
            set tMustCreate = 1
            set tMustLoad = 1
            set tNewNamespace = tInitNS _ "-VERIFY"
            set pParams("verifyNamespace") = tNewNamespace
            if $get(pParams("Verify", "PreDeleteNamespace")) {
                do ##class(%IPM.Utils.Build).DeleteNamespace(tNewNamespace)
            }

            if $get(pParams("Verify","Reuse"),0) || $get(pParams("Verify","SkipLoad"),0) {
                set tModuleExists = ##class(%IPM.Utils.Module).NamespaceHasModule(tNewNamespace,..Module.Name)
                if (tModuleExists) {
                    // Permit the VERIFY namespace to be reused.
                    set tMustCreate = 0
                    if $get(pParams("Verify","SkipLoad"),0) {
                        // Also, do not bother updating the module installed in the VERIFY namespace.
                        set tMustLoad = 0
                    }
                }
            }

            if tMustCreate {
                // Create a new namespace and load the module in it.
                #dim tNSConfig As %IPM.Storage.ModuleSetting.NamespaceConfig
                set tNSConfig = ..Module.GetNamespaceConfig()
                set tSysReqs = ..Module.SystemRequirements
                if $isobject(tSysReqs) && (tSysReqs.Interoperability = "enabled") {
                    set tNSConfig.EnableEnsemble = 1
                }

                // Create namespace in which to run tests and switch to it.
                $$$ThrowOnError(##class(%IPM.Utils.Build).InitializeNamespace("VERIFY",tVerbose,.tNewNamespace,tNSConfig))

                // Map ^UnitTest* from its home in the original namespace to the VERIFY namespace.
                $$$ThrowOnError(##class(%IPM.Utils.Build).MapGlobalEquivalently("UnitTest*",tInitNS,tNewNamespace))

                // Map the package manager itself equivalently in the VERIFY namespace.
                $$$ThrowOnError(##class(%IPM.Utils.Build).MapRoutineEquivalently("%IPM.*",tInitNS,,tNewNamespace))
                $$$ThrowOnError(##class(%IPM.Utils.Build).MapPackageEquivalently("%IPM",tInitNS,tNewNamespace))

                // Map globals for %IPM.Repo.Definition and %IPM.Repo.Filesystem.Cache
                // from the original namespace to the VERIFY namespace
                for tClass = "%IPM.Repo.Definition","%IPM.Repo.Filesystem.Cache" {
                    $$$ThrowOnError(##class(%IPM.Utils.Build).MapClassDataEquivalently(tClass,tInitNS,tNewNamespace))
                }

                // Install this module artifact in the VERIFY namespace.
                write:tVerbose !,"Installing ",..Module.Name," ",..Module.VersionString," in namespace ",tNewNamespace
                merge tParams = pParams
                set tParams("Reload","ForceLocalScope") = 1
                set tParams("NoJournal") = 1 // Disable journaling (and therefore also transactions); the VERIFY namespace is a throwaway.
                // If we will enable Ensemble or HealthShare, default to single-threaded module load to avoid issues with mapping changes in parallel load.
                if tNSConfig.EnableEnsemble || tNSConfig.EnableHealthShare {
                    set tParams("Threads") = 1
                } else {
                    merge tParams("Threads") = pParams("Verify","Threads")
                }
            }

            set $namespace = tNewNamespace

            if (tMustLoad) {
                set tSC = ..OnBeforeVerifyLoad(.tParams)
                $$$ThrowOnError(tSC)
                if (..Payload.Size > 0) {
                    // If we have a payload from the package phase, always use it.
                    $$$ThrowOnError(..OnInstallFromPayload(.tParams))
                } else {
                    // Otherwise, try to install from the module root.
                    set tRoot = $get(pParams("Verify","SourceDirectory"),..Module.Root)
                    if (tRoot = "") {
                        set tSC = $$$ERROR($$$GeneralError,$$$FormatText("No module root defined for module '%1'",..Module.Name))
                        $$$ThrowStatus(tSC)
                    }
                    $$$ThrowOnError(##class(%IPM.Utils.Module).LoadModuleFromDirectory(tRoot,.tParams))
                }
            }
        }

        // Load dependencies correctly for the requested phases. (This will be a no-op in most cases.)
        set tSC = ..Module.LoadDependencies(..PhaseList,.pParams)
        $$$ThrowOnError(tSC)

        set orderedResourceList = ..Module.GetOrderedResourceList()
        set tKey = ""
        for {
            #dim tResource As %IPM.Storage.ResourceReference
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:tKey=""

            set tHandled = 0
            if $isobject(tResource.Processor) && tResource.IsInScope("Verify") {
                set tSC = $$$ADDSC(tSC,tResource.Processor.OnPhase("Verify",.pParams,.tHandled))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Publish(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        // Perform the "Package" phase to prepare the module for publishing
        // ..Payload is populated by %Package. So need to make sure it's using the same lifecycle object.
        set pParams("LifecycleObject") = $this
        // The call to `..Package` will be routed to %IPM.Lifecycle.Base:%DispatchMethod() since `Package` is not a known method of this class.
        $$$ThrowOnError(..Package(.pParams, 0))

        set tVerbose = $get(pParams("Verbose"))
        set tRelease = $get(pParams("Release"),$get(pParams("zpm","Release"),0))
        set tPublishTo = $get(pParams("PublishTo"),$get(pParams("zpm","PublishTo"),""))
        set tNewVersion = $get(pParams("NewVersion"),$get(pParams("zpm","NewVersion"),""))
        set tUseExternalName = $get(pParams("UseExternalName"),$get(pParams("zpm","UseExternalName"),0))

        // Determine which server/registry to publish to
        set tServer =  ""
        if tPublishTo '= "" {
            set tServer = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tPublishTo,,.tSC)
        }

        if '$isobject(tServer) {
            set tRS = ##class(%IPM.Repo.Http.Definition).PublishingServerFunc()
            if (tRS.%SQLCODE = 0) && tRS.%Next() {
                set tServer = $classmethod(tRS.Class,"%OpenId", tRS.ID)
            }
        }

        if $$$ISERR(tSC)||'$isobject(tServer) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "No server found to publish to."))
        }
        if tVerbose {
            write !,"Publish to: ", tServer.URL
        }
        if tNewVersion '= "" {
            set tNewVersion = ##class(%IPM.General.SemanticVersion).FromString(tNewVersion)
        }

        set tPublishClient = tServer.GetPublishService()
        if '$isobject(tPublishClient) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' does not support publishing modules.",tServer.Name))
            $$$ThrowStatus(tSC)
        }
        set tModule = ##class(%IPM.Repo.Remote.ModuleInfo).%New()
        set tModule.Name = $select(tUseExternalName: ..Module.ExternalName, 1: ..Module.Name)
        // Apparently, an empty name can pass the %IPM.DataType.ModuleName:IsValid check
        if tModule.Name = "" {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot publish module with empty name."))
        }
        if '##class(%IPM.DataType.ModuleName).IsValid(tModule.Name) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Module name '%1' is invalid for publishing",tModule.Name)))
        }
        if tRelease && ('..Module.IsLocked()) {
            set tSC = ..Module.Lock()
            if $$$ISERR(tSC) {
                quit
            }
        }
        set tSC = ..%Installer(.pParams)
        if $$$ISERR(tSC) {
            quit
        }
        set tModule.VersionString = ..Module.VersionString
        if (..Module.Deployed) {
            set tModule.Deployed = 1
            if $isobject(..Module.SystemRequirements) {
                set tModule.PlatformVersion = ..Module.SystemRequirements.VersionString
            }
        }
        set tSC = ..Module.XMLExportToStream(tModule.Manifest)
        if $$$ISERR(tSC) {
            quit
        }
        set tSC = tModule.Payload.CopyFrom(..Payload)
        if $$$ISERR(tSC) {
            quit
        }
        set tSC = tModule.Installer.CopyFrom(..Installer)
        if $$$ISERR(tSC) {
            quit
        }

        $$$ThrowOnError(tPublishClient.PublishModule(tModule))

        // May need to update the version of the currently-installed module.
        if $data(tNewVersion),$isobject(tNewVersion) {
            write:tVerbose !,"Version: ", tNewVersion.ToString()
            set ..Module.Version = tNewVersion
            set tSC = ##class(%IPM.Utils.Module).ExportDocumentForObject(..Module)
            $$$ThrowOnError(tSC)
        }
    } catch e {
        if (e.Name["ZSOAP") {
            set tSC = $get(%objlasterror,e.AsStatus())
        } else {
            set tSC = e.AsStatus()
        }
    }
    quit tSC
}

/// Allows for subclasses to do additional setup or modify pParams before the "verify" phase runs.
Method OnBeforeVerifyLoad(ByRef pParams) As %Status
{
    quit $$$OK
}

Method OnInstallFromPayload(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tTmpStream = ##class(%Stream.FileBinary).%New()
        $$$ThrowOnError(tTmpStream.CopyFromAndSave(..Payload))
        $$$ThrowOnError(##class(%IPM.Utils.Module).LoadModuleFromArchive(..Module.Name,..Module.VersionString,tTmpStream,.pParams))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Installer(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        if (..Module.Name = $$$IPMModuleName) {
            write !,"Build Installer for ", ..Module.Name
            set tSC = ##class(IPM.Installer).Make(..Payload, ..Installer)
            if $$$ISERR(tSC) {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }

    quit tSC
}

Method %Document(ByRef pParams) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        tstart

        // Recurse (unless told otherwise) to ensure documentation for dependencies is up to date.
        set tModuleDependencies = ""
        if $get(pParams("Document","Recurse"),1) {
            // Ensure that we only resolve dependencies once (to avoid duplicate effort)
            set tSC = ..Module.BuildDependencyGraph(.tDependencyGraph)
            $$$ThrowOnError(tSC)

            // tDependencyGraph format:
            // tDependencyGraph(<module name>) = $ListBuild(<depth>, <server>, <version>)
            // tDependencyGraph(<module name>,<dependent module name>_" "_<version string>) = <required version expression>
            // <server> being empty means it's already installed.
            // All these modules need to already be installed.

            set tModuleName = ""
            for {
                set tModuleName = $order(tDependencyGraph(tModuleName),1,tModuleInfo)
                if (tModuleName = "") {
                    quit
                }

                set tDepth = $list(tModuleInfo)
                set tServer = $list(tModuleInfo,2)
                if (tServer '= "") {
                    set tErrorMsg = $$$FormatText("Cannot build documentation for module '%1' because required module '%2' is not installed.",..Module.Name,tModuleName)
                    $$$ThrowStatus($$$ERROR($$$GeneralError,tErrorMsg))
                }

                set tDepthArray(tDepth) = $get(tDepthArray(tDepth))_$listbuild(tModuleName)

                set tDependentModule = ""
                for {
                    set tDependentModule = $order(tDependencyGraph(tModuleName,tDependentModule))
                    if (tDependentModule = "") {
                        quit
                    }

                    set tDependentModuleName = $piece(tDependentModule," ") // Split out name from string with <name>_" "_<version>
                    set tModuleDependents(tModuleName) = $get(tModuleDependents(tModuleName))_$listbuild(tDependentModuleName)
                    set tModuleDependencies(tDependentModuleName,tModuleName) = ""
                }
            }

            // At this stage:
            // tModuleDependents(<module name>) has a $ListBuild list of names of module that depend on on <module name> directly
            // tModuleDependencies(<module name>) has subscripts with names of modules on which <module name> depends directly

            set tDepth = ""
            for {
                set tDepth = $order(tDepthArray(tDepth),-1,tModuleList)
                if (tDepth = "") {
                    quit
                }

                // Ensure documentation is generated for dependency
                set tPointer = 0
                while $listnext(tModuleList,tPointer,tModuleName) {
                    // Update modules dependent on tModuleName with their indirect dependencies
                    // Because the outer loop starts with the lowest level of dependencies, this doesn't need to be recursive.
                    set tDependentPointer = 0
                    set tDependentList = $get(tModuleDependents(tModuleName))
                    while $listnext(tDependentList,tDependentPointer,tDependentName) {
                        // Modules dependent on this module also depend on things this module depends on.
                        merge tModuleDependencies(tDependentName) = tModuleDependencies(tModuleName)
                    }

                    // Build a list of all recursive dependencies for this module (just put array subscripts into a $ListBuild list)
                    set tSubDependencies = ""
                    set tSubDependency = ""
                    for {
                        set tSubDependency = $order(tModuleDependencies(tModuleName,tSubDependency))
                        if (tSubDependency = "") {
                            quit
                        }

                        set tSubDependencies = tSubDependencies_$listbuild(tSubDependency)
                    }

                    // Kill tParams just in case a previous call to ExecutePhases modified it.
                    kill tParams
                    merge tParams = pParams
                    set tParams("Document","Recurse") = 0
                    set tParams("Document","Dependencies") = tSubDependencies
                    set tSC = ##class(%IPM.Storage.Module).ExecutePhases(tModuleName,$listbuild("Document"),,.tParams)
                    $$$ThrowOnError(tSC)

                    set tModuleDependencies = tModuleDependencies_$listbuild(tModuleName)
                }
            }
        } else {
            set tModuleDependencies = $get(pParams("Document","Dependencies"))
        }
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) { trollback 1 }
    quit tSC
}

Method %MakeDeployed(ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tDev = ..Module.DeveloperMode
        set tVerbose = $get(pParams("Verbose"))

        // If the recurse parameter is set, then this lifecycle method should recursively deploy all of the
        // module's dependencies marked for deployment
        set tLockedDependencies = $get(pParams("Recurse"),0) // Indicates whether entire dependency graph should be traversed and deployed

        if tDev && tVerbose {
            write !,"Module is in developer mode; will only report what WOULD be deployed unless packaging, in which case items WILL be deployed."
        }

        // Default implementation: see which resources are expicitly flagged with Deploy = true.
        // Build an array of those, then mark them as deployed.
        $$$ThrowOnError(..Module.GetResolvedReferences(.tResourceArray,tLockedDependencies,..PhaseList,1,.pDependencyGraph))

        set tModuleKey = ""
        for {
            set tModuleKey = $order(tResourceArray(tModuleKey))
            quit:(tModuleKey="")
            set tResourceKey = ""
            for {
                set tResourceKey = $order(tResourceArray(tModuleKey, tResourceKey))
                quit:(tResourceKey="")

                // Skip file resources - these are handled separately;
                // "deployment" is the responsibility of resource processor classes.
                if ($extract(tResourceKey) = "/") {
                    continue
                }

                kill tResourceInfo
                merge tResourceInfo = tResourceArray(tModuleKey, tResourceKey)
                // TODO: Refactor tResourceInfo to be an object.
                set tResourceInfo("Name") = tResourceKey
                set tSC = ..OnDetermineResourceDeployability(.pParams,.tResourceInfo,.tDeploy)
                $$$ThrowOnError(tSC)

                if tDeploy {
                    set tName = $piece(tResourceKey,".",1,*-1)
                    set tExt = $$$ucase($piece(tResourceKey,".",*))
                    if (tExt = "CLS") {
                        set tDeployClassArray($piece(tResourceKey,".",1,*-1)) = ""
                    } elseif (tExt = "MAC") || (tExt = "INT") {
                        set tDeployRtnArray(tResourceKey) = ""
                    } else {
                        // For other types, if deployment has meaning, the associated resource processor
                        // class should handle it in OnBeforePhase/OnAfterPhase.
                        continue
                    }
                }
            }
        }
        if ($data(tDeployRtnArray) || $data(tDeployClassArray)) {
            set ..HasDeployedResources = 1
            set ..Module.Deployed = 1
            if '$isobject(..Module.SystemRequirements) {
                set ..Module.SystemRequirements = ##class(%IPM.Storage.SystemRequirements).%New()
            }
            set tSystemVersion = $system.Version.GetMajor() _ "." _ $system.Version.GetMinor()
            set ..Module.SystemRequirements.VersionString = tSystemVersion
            $$$ThrowOnError(..Module.%Save())
            if $data(tDeployClassArray) {
                if (tVerbose) {
                    set tClass = ""
                    write !,"The following classes are flagged for deployment:"
                    for {
                        set tClass = $order(tDeployClassArray(tClass))
                        quit:tClass=""
                        write !,$char(9),tClass
                    }
                }
                $$$ThrowOnError($system.OBJ.MakeClassDeployed(.tDeployClassArray))
            }
            if $data(tDeployRtnArray) {
                if (tVerbose) {
                    write !,"The following routines are flagged for deployment:"
                }
                set tRtn = ""
                for {
                    set tRtn = $order(tDeployRtnArray(tRtn))
                    quit:tRtn=""
                    if tVerbose {
                        write !,$char(9),tRtn
                    }
                    if 'tDev {
                        $$$ThrowOnError(##class(%Routine).Delete(tRtn,2))
                    }
                }
            }
        } elseif tVerbose {
            write !,"No routines or classes to deploy."
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %ApplyUpdateSteps(ByRef pParams) As %Status
{
    set sc = $$$OK
    try {
        if $system.Mirror.IsMember() && $system.Mirror.IsPrimary() {
            write !,"WARNING: You are running update steps on the primary member of a mirror. It is recommended to start the update process on a backup instance to minimize downtime."
        }
        set verbose = $get(pParams("Verbose"))
        // TODO: Add log file param after logging meeting discussion
        $$$ThrowOnError(..Module.HandleAllUpdateSteps(,,verbose))
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

Method OnDetermineResourceDeployability(
	ByRef pParams,
	ByRef pResourceInfo,
	Output pDeploy As %Boolean) As %Status
{
    set tSC = $$$OK
    try {
        if $data(pParams("Deploy","Parameter"),tDeployParameter)#2 && (tDeployParameter '= "") {
            if ($zconvert($piece(pResourceInfo("Name"),".",*), "U") = "CLS") {
                set tClass = $piece(pResourceInfo("Name"),".",1,*-1)
                if $$$comClassDefined(tClass) && $$$defMemberDefined(tClass,$$$cCLASSparameter,tDeployParameter) {
                    // e.g., HSDEPLOY, HSAADEPLOY
                    // This overrides the per-resource setting if defined, including if false.
                    set pDeploy = ($parameter(tClass,tDeployParameter) = 1)
                    quit
                }
            }
        }

        // Note: if the Deploy setting is missing from the module manifest, pResourceInfo("Deploy") will be defined as ""
        if $get(pResourceInfo("Deploy")) = "" {
            set pDeploy = ..#DEPLOYBYDEFAULT
        } else {
            set pDeploy = pResourceInfo("Deploy")
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Helper method to get the relative path to the *file* corresponding to a resource (used in %Reload/%Export).
/// If <var>pExtension</var> is empty, then <var>pResource</var> is interpreted as having an extension.
/// If <var>pExtension</var> is specified, then <var>pResource</var> is intrepreted as not having an extension.
/// Note: does not support .PKG
/// Note: does not yet support CSP/static files resources
Method GetResourceRelativePath(
	pResource As %String,
	pExtension As %String) As %String
{
    if ($get(pExtension) = "") {
        set tName = $piece(pResource,".",1,*-1)
        set tExtension = $piece(pResource,".",*)
    } else {
        set tName = pResource
        set tExtension = pExtension
    }

    // For static/CSP resources, this is handled separately.
    if ($extract(pResource_pExtension) = "/") {
        quit ""
    }

    // Intentionally does not support PKG - classes must be exported individually.
    set tDirectory = $case(tExtension,
        "ZPM":"",
        "LOC":"localize/",
        "INC":"inc/",
        "MAC":"rtn/",
        "CLS":"cls/",
        "GBL":"gbl/",
        "X12":"i14y/",
        "HL7":"i14y/",
        "LUT":"i14y/",
        "ESD":"i14y/",
        "DTL":"cls/",
        "BPL":"cls/",
        : ""
    )

    set tFile = $case(tExtension,
        "ZPM":"module.xml",
        "LOC":$translate(tName,".%","/")_".xml",
        "INC":$translate(tName,".%","/_")_".inc",
        "MAC":$translate(tName,".%","/_")_".rtn",
        "CLS":$translate(tName,".%","/")_".cls",
        "DTL":$translate(tName,".%","/")_".cls",
        "BPL":$translate(tName,".%","/")_".cls",
        "GBL":$translate(tName,"%,("")","___")_".xml",
        "DFI":$translate(tName,"-","/")_".dfi",
        : tName _ "." _$$$lcase(tExtension)
    )

    quit tDirectory_tFile
}

Method ExportSingleModule(
	ByRef pResourceArray,
	ByRef pTargetDirectory As %String,
	ByRef pDependencyGraph,
	ByRef pParams,
	pVerbose As %Boolean = 0)
{
    merge tParams = pParams

    set tFullResourceName = ""
    for {
        set tFullResourceName = $order(pResourceArray(tFullResourceName),1,tSrcModule)
        if (tFullResourceName = "") {
            quit
        }

        if $get(pResourceArray(tFullResourceName,"Generated")) continue

        set tName = $piece(tFullResourceName,".",1,*-1)
        set tExt = $piece(tFullResourceName,".",*)
        if '$data(pResourceArray(tFullResourceName,"RelativePath"),tRelativePath) {
            set tRelativePath = ..GetResourceRelativePath(tName,tExt)
        }

        // Set full path for exporting module.xml
        if (tExt = "ZPM") && (tName '= ..Module.Name) {
            set tRelativePath = pDependencyGraph(tName,"Location")_tRelativePath
        } elseif (tSrcModule '= "") && (tSrcModule '= ..Module.Name) {
            set tRelativePath = pDependencyGraph(tSrcModule,"Location")_tRelativePath
        }
        set tFullPath = ##class(%File).NormalizeFilename(pTargetDirectory_tRelativePath)
        set tFullPath = ##class(%File).NormalizeFilenameWithSpaces(tFullPath)

        // Set path for exporting resource
        if ($extract(tName_tExt) = "/") {
            set tRelativePath = tFullResourceName
        }
        set tNode = tSrcModule
        if (tExt = "ZPM") {
            set tNode = tName
        }
        set pParams("ModuleExportPath") = pTargetDirectory_$get(pDependencyGraph(tNode, "Location"))_tRelativePath

        #dim tProcessor As %IPM.ResourceProcessor.Abstract
        if $data(pResourceArray(tFullResourceName,"Processor"),tProcessor) && $isobject(tProcessor) {
            kill tItemParams
            merge tItemParams = pResourceArray(tFullResourceName)
            set tItemHandled = 0
            set tSC = tProcessor.OnExportItem(tFullPath,tFullResourceName,.tItemParams,.pParams,.tItemHandled)
            $$$ThrowOnError(tSC)
            if tItemHandled {
                continue
            }
        }
        if ($extract(tFullResourceName) = "/") {
            // Resources with paths are relative to the module root and are simply copied to the export directory.
            set tModule = ##class(%IPM.Storage.Module).NameOpen(tSrcModule,,.tSC)
            $$$ThrowOnError(tSC)

            if (tModule.Root = "") {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("No module root configured for '%1'",tSrcModule))
                $$$ThrowOnError(tSC)
            }

            if '##class(%File).DirectoryExists(tModule.Root) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Directory %2, listed as root for module '%1', does not exist.",tSrcModule,tModule.Root))
                $$$ThrowOnError(tSC)
            }

            set tSourcePath = ##class(%File).NormalizeFilename(tModule.Root_tFullResourceName)
            set tSourcePath = ##class(%File).NormalizeFilenameWithSpaces(tSourcePath)
            set tExportPath = ##class(%File).NormalizeFilename(tFullPath_tFullResourceName)
            set tExportPath = ##class(%File).NormalizeFilenameWithSpaces(tExportPath)
            set tSC = $$$OK
            set tDirectory = ##class(%File).GetDirectory(tExportPath,1)
            if '##class(%File).DirectoryExists(tDirectory) {
                set tGood = ##class(%File).CreateDirectoryChain(tDirectory,.tReturn)
                if 'tGood {
                    set tLastErr = $get(%objlasterror)
                    set tSC = $$$EMBEDSC($$$ERROR($$$GeneralError,$$$FormatText("Error creating directory '%1': %2",tDirectory,tReturn)),tLastErr)
                    $$$ThrowOnError(tSC)
                }
                write:pVerbose !,"Created ",tDirectory
            }
            if ##class(%File).DirectoryExists(tSourcePath) {
                // NOTE: Does not overlay directories.
                set tSourcePath = ##class(%File).NormalizeDirectory(tSourcePath)
                set tExportPath = ##class(%File).NormalizeDirectory(tExportPath)
                set tSC = ##class(%IPM.Utils.File).CopyDir(tSourcePath,tExportPath, , pVerbose)
                $$$ThrowOnError(tSC)
                write:pVerbose !,tSourcePath," -> ",tExportPath
            } elseif ##class(%File).Exists(tSourcePath) {
                set tGood = ##class(%File).CopyFile(tSourcePath,tExportPath,1,.tReturn)
                if 'tGood {
                    set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying file '%1' to '%2': %3",tSourcePath,tExportPath,tReturn))
                    $$$ThrowOnError(tSC)
                }
                write:pVerbose !,tSourcePath," -> ",tExportPath
            }
        } elseif (tExt = "CLS") || (tExt = "DFI") || (tExt = "PRJ") || ($zconvert($extract(tFullPath,$length(tFullPath)-2,*),"l")="xml") || (##class(%RoutineMgr).UserType(tFullResourceName)) {
            if '##class(%File).Exists(tFullPath) {
                do ##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(tFullPath))
            }
            set tSC = $$Export^%occXMLExport(tFullPath,"-d /diffexport/createdirs",tFullResourceName)
            $$$ThrowOnError(tSC)
            if pVerbose {
                write !,"Exported to ",tFullPath
            }
        } else {
            set tSC = $$Export^%apiRTN(tFullResourceName,tFullPath,"","WNSK\UTF8\","-d /diffexport/createdirs")
            $$$ThrowOnError(tSC)
            if pVerbose {
                write !,"Exported to ",tFullPath
            }
        }
        $$$ThrowOnError(tSC)
    }
}

ClassMethod GetBaseClassForPackaging(
	pPackaging As %String,
	Output pBaseClass As %Dictionary.Classname) As %Status [ Final ]
{
    set tSC = $$$OK
    set pBaseClass = ""
    try {
        set tRes = ##class(%SQL.Statement).%ExecDirect(,
            "select BaseClass from %IPM_Lifecycle.Base_Packaging(?)",
            pPackaging)
        if (tRes.%SQLCODE < 0) {
            $$$ThrowStatus($$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message))
        }

        if tRes.%Next(.tSC) {
            set pBaseClass = tRes.%Get("BaseClass")
        }
        $$$ThrowOnError(tSC)

        // TODO: Error if no results?
    } catch e {
        set pBaseClass = ""
        set tSC = e.AsStatus()
    }
    quit tSC
}

Query Packaging(pPackaging As %String = "") As %SQLQuery [ Final, SqlProc ]
{
    select cp._default as Packaging, cd.Name as BaseClass
    from %Dictionary.CompiledClass cd
    join %Dictionary.CompiledParameter cp
    on cp.Parent = cd.Name
        and cp.Name = 'PACKAGING'
    where cd.Name %STARTSWITH '%IPM.Lifecycle' -- This is a critical assumption for performance reasons. Full ^oddCOM scans are expensive!
        and cd.PrimarySuper [ '~%IPM.Lifecycle.Base~'
        and cp.Final = 1
        and cp.Origin = cd.Name
        and (:pPackaging is null or cp._default = :pPackaging)
}

ClassMethod LoadEnvironmentConfig(paths As %String)
{
    #dim config As %IPM.General.EnvironmentConfig
    set config = ##class(%IPM.General.EnvironmentConfig).%Get()
    do config.Clear()
    set paths = $listfromstring(paths, ";")
    set ptr = 0
    while $listnext(paths, ptr, file) {
        set file = $zstrip(file, "<>WC")
        do config.Load(file)
    }
}

}
