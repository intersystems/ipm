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
    set tCodeStream = %code
    do ##class(%IPM.Utils.CodeGeneration).BuildRelationshipSorter(tCodeStream, "Resources", "GetSortKey()")
    quit $$$OK
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

Property LastModifiedTimestamp As %TimeStamp(ForceCodeGenerate = 0, XMLPROJECTION = "NONE") [ InitialExpression = {$zdatetime($horolog,3)} ];

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

/// This method iterates over resources of a module and returns a list of objects in the correct order that resources should be processed
/// Process document resources based on their package depth first, followed by the order things are defined in the module.xml for the rest
/// e.g. <Resource Name="Depth1.PKG"/> should be processed before <Resource Name="Depth1.Depth2.CLS"/>
Method GetOrderedResourceList() As %ListOfObjects
{
    set nonDocumentResourceList = ##class(%ListOfObjects).%New()
    set tKey = ""
    for {
        set tResource = ..Resources.GetNext(.tKey)
        quit:tKey=""
        if $isobject(tResource.Processor) && tResource.Processor.%Extends("%IPM.ResourceProcessor.Default.Document") {
            // Strip extension from resource name as that caused improper sorting (i.e. MyPackage.MyClass.CLS gets sorted before MyPackage.PKG)
            set tResourceName = $piece(tResource.Name,".",1,*-1)
            if ($get(documentResourceList(tResourceName)) = "") {
                set documentResourceList(tResourceName) = ##class(%ListOfObjects).%New()
            }
            do documentResourceList(tResourceName).Insert(tResource)
        }
        else {
            do nonDocumentResourceList.Insert(tResource)
        }
    }
    set orderedResourceList = ##class(%ListOfObjects).%New()

    // Combine all objects into one larger list
    // First document resources
    set tKey = ""
    for {
        set tKey = $order(documentResourceList(tKey))
        quit:tKey=""
        set tResourceList = documentResourceList(tKey)
        set tKey2 = ""
        for {
            set tResource = tResourceList.GetNext(.tKey2)
            quit:tKey2=""
            do orderedResourceList.Insert(tResource)
        }
    }
    // Then non-document resources
    set tKey = ""
    for {
        set tResource = nonDocumentResourceList.GetNext(.tKey)
        quit:tKey=""
        do orderedResourceList.Insert(tResource)
    }

    return orderedResourceList
}

Method HaveToDeploy() As %Boolean
{
    set deploy = 0
    set key = ""
    for {
        set ref = ..Resources.GetNext(.key)
        quit:key=""
        set deploy = +ref.Deploy
        quit:deploy
    }
    quit ''deploy
}

ClassMethod CheckSystemRequirements(pModuleName As %String) As %Status
{
    set tSC = $$$OK
    try {
        set pModuleName = $$$lcase(pModuleName)
        set tModule = ..NameOpen(pModuleName,,.tSC)
        if '$isobject(tModule) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Module '"_pModuleName_"' not found."))
        }
        $$$ThrowOnError(tSC)
        if ($isobject(tModule.SystemRequirements)) {
            $$$ThrowOnError(tModule.SystemRequirements.CheckRequirements())
        }
    } catch ex {
        set tSC = ex.AsStatus()
    }
    return tSC
}

Method WriteAfterInstallMessage()
{
    if ..AfterInstallMessage '= "" {
        write !,..%Evaluate(..AfterInstallMessage),!
    }
}

/// Calls <method>%CompareTo</method> on this object and also calls it on any relationships in the class
/// specifically <property>Mappings</property> and <property>Resources</property>. <br />
Method CompareWithRelationships(
	pModuleObj As %IPM.Storage.Module,
	pIgnorePropertyList As %Library.List = "",
	Output pDifferingPropertyArray As %Library.List) As %Boolean
{
    kill pDifferingPropertyArray
    set isEqual = ..%CompareTo(pModuleObj, pIgnorePropertyList, .pDifferingPropertyArray)
    // Mappings
    if '$listfind(pIgnorePropertyList, "Mappings") {
        set count1 = ..Mappings.Count()
        set count2 = pModuleObj.Mappings.Count()
        if (count1 '= count2) {
            set pDifferingPropertyArray("Mappings") = $listbuild(count1, count2)
        } else {
            for i=1:1:..Mappings.Count() {
                set item1 = ..Mappings.GetAt(i)
                set item2 = pModuleObj.Mappings.GetAt(i)
                set isEqual = item1.%CompareTo(item2, , .diffInfo)
                if 'isEqual {
                    merge pDifferingPropertyArray("Mappings", i) = diffInfo
                }
            }
        }
    }
    // Resources
    if '$listfind(pIgnorePropertyList, "Resources") {
        set count1 = ..Resources.Count()
        set count2 = pModuleObj.Resources.Count()
        if (count1 '= count2) {
            set pDifferingPropertyArray("Resources") = $listbuild(count1, count2)
        } else {
            for i=1:1:..Resources.Count() {
                set item1 = ..Resources.GetAt(i)
                set item2 = pModuleObj.Resources.GetAt(i)
                set isEqual = item1.%CompareTo(item2, , .diffInfo)
                if 'isEqual {
                    merge pDifferingPropertyArray("Resources", i) = diffInfo
                }
            }
        }
    }
    return isEqual
}

/// Returns a multidimensional array of custom phases defined by the module's invokes,
/// where the keys are the custom phase names and the values are empty strings.
/// Custom phases do not have corresponding %method implementation in the lifecycle class.
/// Return the phases in lower case for case-insensitive lookup.
Method GetCustomPhases(Output pPhases)
{
    kill pPhases
    set pPhases = ""
    set key = ""
    for {
        set tInvoke = ..Invokes.GetNext(.key)
        if key = "" {
            quit
        }
        if (tInvoke.CustomPhase '= "") {
            set pPhases($$$lcase(tInvoke.CustomPhase)) = tInvoke.CustomPhase
        }
    }
    set orderedResourceList = ..GetOrderedResourceList()
    for {
        set tResource = orderedResourceList.GetNext(.key)
        if key = "" {
            quit
        }
        set tProcessor = tResource.Processor
        // %IsA() only returns true if the class is the "primary" superclass, while %Extends() works for other superclasses (such as mixins).
        if $isobject(tProcessor) && tProcessor.%Extends("%IPM.ResourceProcessor.CustomPhaseMixin") {
            set cp = tProcessor.CustomPhase
            if cp '= "" {
                set pPhases($$$lcase(cp)) = cp
            }
        }
    }
}

/// Execute multiple lifecycle phases in sequence. Execution is terminated if one fails.
/// Example: $ListBuild("Clean","Test") or $ListBuild("Test","Install")
/// @API.Method
ClassMethod ExecutePhases(
	pModuleName As %String,
	pPhases As %List,
	pIsComplete As %Boolean = 0,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"),0)
        set tModule = ..NameOpen(pModuleName,,.tSC)
        if '$isobject(tModule) {
            set tModule = ..ExternalNameOpen(pModuleName,,.tSC)
        }
        if '$isobject(tModule) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Module '%1' not found.", pModuleName)))
        }
        $$$ThrowOnError(tSC)

        // Regardless of whether the module was opened by name or external name, we want to use the name for the rest of the method.
        set pModuleName = tModule.Name

        // Ensure we reload and reinitialize transient properties.
        // For example, prevents reuse of a previous OverrideLifecycleClass if the module object is in memory in the caller.
        set tSC = tModule.%Reload()
        $$$ThrowOnError(tSC)

        // Allow per-command customization of root directory
        // Useful primarily for non-module packaging installation
        if $data(pParams("RootDirectory"),tRoot) {
            set tModule.Root = tRoot
        }

        // Permit override of lifecycle class as either a class name or a file containing a lifecycle class (and possibly other bundled/related resources)
        if $data(pParams("LifecycleObject"), tLifeCycle) # 2 {
            set tModule.Lifecycle = tLifeCycle
        } elseif $data(pParams("Lifecycle"),tLifecycle) && ($get(tLifecycle) '= "") {
            if $$$comClassDefined(tLifecycle) {
                set tModule.OverrideLifecycleClass = tLifecycle
            } elseif $$$comClassDefined($$$DefaultLifecyclePackageDot_tLifecycle) {
                set tModule.OverrideLifecycleClass = $$$DefaultLifecyclePackageDot_tLifecycle
            } elseif ##class(%Library.File).Exists(tLifecycle) {
                set tSC = $system.OBJ.Load(tLifecycle,"k"_$select(tVerbose:"d",1:"-d"),,.tLoadedList)
                $$$ThrowOnError(tSC)
                set tSC = ##class(%IPM.Utils.LegacyCompat).UpdateSuperclassAndCompile(.tLoadedList)
                $$$ThrowOnError(tSC)
                set tLoadedList = $listfromstring(tLoadedList)
                set tLifecycleClassFound = 0
                set tPointer = 0
                while $listnext(tLoadedList,tPointer,tLoadedItem) {
                    set tClass = $piece(tLoadedItem,".cls",1,*-1)
                    if (tClass '= "") && $$$comClassDefined(tClass) && $classmethod(tClass,"%Extends",$$$DefaultLifecyclePackageDot_"Base") {
                        set tLifecycleClassFound = 1
                        set tModule.OverrideLifecycleClass = tClass
                    }
                }
                if 'tLifecycleClassFound {
                    set tSC = $$$ERROR($$$GeneralError,$$$FormatText("File '%1' did not contain a valid lifecycle class.",tLifecycle))
                    $$$ThrowStatus(tSC)
                }
            } else {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("'%1' is neither a valid filename nor a valid lifecycle class name.",tLifecycle))
                $$$ThrowStatus(tSC)
            }

            // Note: this is used later if the module object is reloaded.
            set tOverrideClass = $classname(tModule.Lifecycle)
            if tVerbose {
                write !,"Using lifecycle class ",tOverrideClass,"; override class is "_tModule.OverrideLifecycleClass
            }
        }

        set tLifecycle = tModule.Lifecycle

        if pIsComplete {
            set tPhases = tLifecycle.GetCompletePhases(pPhases)
            if (($listfind(tPhases, "Package") || $listfind(tPhases, "Publish")) && tModule.HaveToDeploy() && tModule.DeveloperMode) {
                set tPhases = $listbuild("PrepareDeploy") _ tPhases
            }
        } else {
            set tPhases = $listbuild(##class(%IPM.Lifecycle.Base).MatchSinglePhase($listtostring(pPhases)))
        }

        // Lifecycle-provided default parameters
        do tLifecycle.GetDefaultParameters(.tParams, tPhases)

        // Module manifest Defaults/Parameter default parameters
        do tModule.GetDefaultParameters(.tModuleParams)
        merge tParams = tModuleParams

        // Overwrite with actual specified parameters
        merge tParams = pParams

        // Move back to pParams
        kill pParams
        merge pParams = tParams

        // Report timing subject to parameter; overall timing if only one phase has yet been tracked in context
        // (e.g., set up in multithreaded load) and more than one phase is to be executed.
        set tTiming = $get(pParams("Timing"),0)
        set tOverallTiming = tTiming && ($listlength(tPhases) > 1) && ($listlength($get($$$ZPMHandledModules($namespace,pModuleName))) < 2)

        // Subscript by namespace to handle application build and integration testing processes, which may
        // load a module in a different namespace (and call ExecutePhases there) at a lower stack level than the
        // initial call to ExecutePhases
        if '$data($$$ZPMHandledModules($namespace)) {
            new $$$ZPMHandledModules
        } else {
            set $$$ZPMHandledModules($namespace,pModuleName) = $get($$$ZPMHandledModules($namespace,pModuleName))_tPhases
        }

        // Execute resolved phases in sequence
        set tLifecycle.PhaseList = tPhases
        set tPointer = 0
        set tFullStart = $zhorolog
        do tModule.GetCustomPhases(.tCustomPhases)
        while $listnext(tPhases,tPointer,tOnePhase) {
            set tIsCustomPhase = $data(tCustomPhases($$$lcase(tOnePhase)), tNormalizedPhaseName) # 2
            if tIsCustomPhase {
                set tOnePhase = tNormalizedPhaseName
            }
            set tStart = $zhorolog
            if tOnePhase="*" {
                kill tModule,tLifecycle
                set tModule = ..NameOpen(pModuleName,,.tSC)
                $$$ThrowOnError(tSC)
                if ($get(tOverrideClass) '= "") {
                    set tModule.OverrideLifecycleClass = tOverrideClass
                }
                set tLifecycle = tModule.Lifecycle
                set tLifecycle.PhaseList = tPhases
                write !,"["_tModule.DisplayName_"]",$char(9),"Module object refreshed."
                continue
            }

            set tSC = $$$OK
            try {
                write !,"["_$namespace_"|"_tModule.DisplayName_"]",$char(9),tOnePhase," START"
                // for the reload phase, print root from which module is being loaded
                if tOnePhase = "Reload" {
                    write " ("_tModule.Root_")"
                }

                // Notify source control (no-op if not configured)
                set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnBeforePhase(tModule,tOnePhase,.pParams)
                $$$ThrowOnError(tSC)
                $$$ThrowOnError(tLifecycle.OnBeforeResourceProcessing(tOnePhase, .pParams))
                // Notify resource processors
                set orderedResourceList = tModule.GetOrderedResourceList()
                set tKey = ""
                for {
                    #dim tResource As %IPM.Storage.ResourceReference
                    set tResource = orderedResourceList.GetNext(.tKey)
                    if (tKey = "") {
                        quit
                    }
                    if $isobject(tResource.Processor) && tResource.IsInScope(tOnePhase) {
                        do tResource.Processor.SetParams(.pParams)
                        set tSC = $method(tResource.Processor,"OnBeforePhase",tOnePhase,.pParams)
                        $$$ThrowOnError(tSC)
                    }
                }

                #; Call Invoke Methods Before Phase
                set tKey = ""
                for {
                    set tInvoke = tModule.Invokes.GetNext(.tKey)
                    quit:(tKey = "")
                    set tSC = tInvoke.OnBeforePhase(tOnePhase,.pParams)
                    quit:$$$ISERR(tSC)
                }
                quit:$$$ISERR(tSC)

                if tIsCustomPhase {
                    set tKey = ""
                    for {
                        set tResource = orderedResourceList.GetNext(.tKey)
                        if tKey = "" {
                            quit
                        }
                        set tProcessor = tResource.Processor
                        // %IsA() only returns true if the class is the "primary" superclass, while %Extends() works for other superclasses (such as mixins).
                        if $isobject(tProcessor) && tProcessor.%Extends("%IPM.ResourceProcessor.CustomPhaseMixin") && tResource.IsInScope(tOnePhase) {
                            $$$ThrowOnError(tProcessor.OnCustomPhase(tOnePhase, .pParams))
                        }
                    }
                } else {
                    // Lifecycle before / (phase) / after
                    new $$$DeployedProjectInstalled
                    $$$ThrowOnError(tLifecycle.OnBeforePhase(tOnePhase,.pParams))
                    $$$ThrowOnError($method(tLifecycle,"%"_tOnePhase,.pParams))
                    $$$ThrowOnError(tLifecycle.OnAfterPhase(tOnePhase,.pParams))
                }

                #; Call Invoke Methods After Phase
                set tKey = ""
                for {
                set tInvoke = tModule.Invokes.GetNext(.tKey)
                if (tKey = "") || '$isobject(tInvoke) {
                    quit // '$IsObject can happen reasonably after namespace changes
                }
                set tSC = tInvoke.OnAfterPhase(tOnePhase,.pParams)
                quit:$$$ISERR(tSC)
                }
                quit:$$$ISERR(tSC)

                // Notify resource processors
                set orderedResourceList = tModule.GetOrderedResourceList()
                set tKey=""
                for {
                    set tResource = orderedResourceList.GetNext(.tKey)
                    if (tKey = "") {
                        quit
                    }
                    if $isobject(tResource.Processor) && tResource.IsInScope(tOnePhase) {
                        do tResource.Processor.SetParams(.pParams)
                        set tSC = $method(tResource.Processor,"OnAfterPhase",tOnePhase,.pParams)
                        $$$ThrowOnError(tSC)
                    }
                }
                ///Works after resource processing
                $$$ThrowOnError(tLifecycle.OnAfterResourceProcessing(tOnePhase, .pParams))
                // Notify source control (no-op if not configured)
                set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnAfterPhase(tModule,tOnePhase,.pParams)
                $$$ThrowOnError(tSC)
            } catch e {
                set tSC = e.AsStatus()
            }

            if $$$ISERR(tSC) {
                write !,"["_tModule.DisplayName_"]",$char(9),tOnePhase," FAILURE"
            } else {
                write !,"["_$namespace_"|"_tModule.DisplayName_"]",$char(9),tOnePhase," SUCCESS"
            }
            if tTiming {
                write " ("_($zhorolog-tStart)_" s)"
            }
            $$$ThrowOnError(tSC)
        }
        if tOverallTiming {
            write !,"["_tModule.DisplayName_"]",$char(9),"(total time: ",($zhorolog-tFullStart)," s)"
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if $$$ISERR(tSC) && $data(pParams("PackageDeployNamespace"),tPackageDeployNamespace) &&(tPackageDeployNamespace'="") {
        set $namespace = $get(pParams("InitNamespace"))
        do ##class(%IPM.Utils.Build).DeleteNamespace(tPackageDeployNamespace, tVerbose)
        kill pParams("PackageDeployNamespace"), pParams("InitNamespace")
    }
    quit tSC
}

/// Uninstalls a named module (<var>pModuleName</var>).
/// May optionally force installation (uninstalling even if required by other modules) if <var>pForce</var> is 1.
/// May optionally recurse to also uninstall dependencies that are not required by other modules if <var>pRecurse</var> is 1.
/// If both <var>pForce</var> and <var>pRecurse</var> are 1, then dependencies will also be uninstalled forcibly.
/// @API.Method
ClassMethod Uninstall(
	pModuleName As %String,
	pForce As %Boolean = 0,
	pRecurse As %Boolean = 0,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        merge tParams = pParams
        set tParams("Clean","Level") = 1 // Simulate clean of module as dependency.
        set tParams("Clean","Force") = pForce
        set tParams("Clean","Recurse") = pRecurse
        set tSC = ##class(%IPM.Storage.Module).ExecutePhases(pModuleName,$listbuild("Clean"),,.tParams)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method GetNamespaceConfig(ByRef pCheckedModules) As %IPM.Storage.ModuleSetting.NamespaceConfig
{
    set tNSConfig = ##class(%IPM.Storage.ModuleSetting.NamespaceConfig).%New()

    // See if this module has any settings.
    set tCount = ..Defaults.Count()
    for tDefaultIndex = 1:1:tCount {
        set tDefault = ..Defaults.GetAt(tDefaultIndex)
        if (tDefault.%IsA("%IPM.Storage.ModuleSetting.NamespaceConfig")) {
            set tNSConfig = tDefault
            quit
        }
    }

    // Recursively merge in settings from installed dependencies.
    set tDependencyKey = ""
    for {
        #dim tDependency As %IPM.Storage.ModuleReference
        set tDependency = ..Dependencies.GetNext(.tDependencyKey)
        if (tDependencyKey = "") {
            quit
        }

        if $data(pCheckedModules(tDependency.Name)) {
            continue
        }
        set pCheckedModules(tDependency.Name) = ""

        // If installed...
        if ..NameExists(tDependency.Name,.tID) {
            set tModule = ..%OpenId(tID,,.tSC)
            $$$ThrowOnError(tSC)

            do tNSConfig.MergeFrom(tModule.GetNamespaceConfig(.pCheckedModules))
        }
    }
    quit tNSConfig
}

Method GetDefaultParameters(Output pParams)
{
    set tReferenceLifecycle = $classname(..Lifecycle)
    set tDefaultKey = ""
    for {
        set tDefault = ..Defaults.GetNext(.tDefaultKey)
        if (tDefaultKey = "") {
            quit
        }
        if tDefault.%IsA("%IPM.Storage.ModuleSetting.Parameter") {
            #dim tDefault As %IPM.Storage.ModuleSetting.Parameter

            // Filter out defaults for other lifecycle classes
            if (tDefault.LifecycleClass '= "") {
                if '((tDefault.LifecycleClass = tReferenceLifecycle) || ($$$DefaultLifecyclePackageDot_tDefault.LifecycleClass = tReferenceLifecycle)) {
                    continue
                }
            }

            // Convert "."-delimited pieces to subscripts in pParams
            set tPieces = $listfromstring(tDefault.Name,".")
            kill tValue
            set tValue = tDefault.Value
            for tSubscript=$listlength(tPieces):-1:1 {
                kill tData
                merge tData($listget(tPieces,tSubscript)) = tValue
                kill tValue
                merge tValue = tData
            }
            merge pParams = tValue
        }
    }
}

/// Returns whether pScope is in the list of pPhases <br />
ClassMethod HasScope(
	pPhases As %List,
	pScope As %String) [ Private ]
{
    if (pScope = "") {
        quit 1
    }
    set tPhases = $zconvert(pPhases, "L")
    if $listvalid(pScope) {
        // Iterate through each item in pScope list
        set pointer = 0
        while $listnext(pScope, pointer, scopeItem) {
            if $listfind(tPhases, $zconvert(scopeItem, "L")) {
                return 1
            }
        }
        quit 0
    }
    // Single string
    set scopeItem = $zconvert(pScope, "L")
    quit $listfind(tPhases, scopeItem) > 0
}

Method LoadDependencies(
	pPhaseList As %List,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))

        if '$data(pParams("qstruct")) {
            set qstruct = "ck"_$select(tVerbose:"d",1:"-d")
        } else {
            merge qstruct = pParams("qstruct")
        }

        // Resolve and validate dependencies
        set tReloadSnapshots = +$get(pParams("UpdateSnapshots"))
        set tPermitDowngrade = +$get(pParams("PermitDowngrade"))
        set tSC = ..BuildDependencyGraph(.tDependencyGraph,,tReloadSnapshots,.qstruct,pPhaseList,,,,,,tPermitDowngrade)
        if $$$ISERR(tSC) {
            quit
        }

        if $data(tDependencyGraph) {
            set tOptimizeInstalled = 'tReloadSnapshots
            write:tVerbose !,"Dependencies:"
            set tModuleLoop = ""
            for {
                set tModuleLoop = $order(tDependencyGraph(tModuleLoop),1,tValue)
                quit:tModuleLoop=""

                if (tOptimizeInstalled) && '$data($$$ZPMHandledModules($namespace,tModuleLoop)) {
                    // Optimize for exact version matches that are already installed.
                    if ##class(%IPM.Storage.Module).NameExists(tModuleLoop) {
                        set tMod = ##class(%IPM.Storage.Module).NameOpen(tModuleLoop,,.tSC)
                        $$$ThrowOnError(tSC)
                        if (tMod.VersionString = $listget(tValue,3)) {
                            set $list(tValue,2) = ""
                            set $list(tDependencyGraph(tModuleLoop),2) = ""
                        }
                    }
                }

                set tServer = $case($listget(tValue,2),"":" (installed)",:" @ "_$listget(tValue,2))
                write:tVerbose !,tModuleLoop," ",$listget(tValue,3),tServer
            }

            // Download dependencies.
            kill tParams
            merge tParams("qstruct") = qstruct
            merge tParams = pParams
            set tSC = ##class(%IPM.Utils.Module).LoadDependencies(.tDependencyGraph,.tParams)
            if $$$ISERR(tSC) {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method BuildDependencyGraph(
	ByRef pDependencyGraph,
	pDepth As %Integer = 1,
	pForceSnapshotReload As %Boolean = 0,
	ByRef qstruct,
	pPhases As %String = "",
	ByRef pSubModules,
	pPass As %Integer = 1,
	pModulePath As %List = {$listbuild(..Name)},
	pIgnoreInstalledModules As %Boolean = 0,
	pKnownDependencies As %List = {..GetKnownDependencies(..Name)},
	pPermitDowngrade As %Boolean = 0,
	pCheckNestedScoped As %Boolean = 0,
	ByRef pSearchList,
	pIncludeDisplayName As %Boolean = 0) As %Status
{
    #define EXACT 1
    #define FUZZY 2
    #define SCOPE "Scope"

    set tSC = $$$OK
    try {
        kill tSubModules
        // Create an instance of the repository manager singleton (or get the existing one)
        // This makes it available at lower stack levels, which helps
        // to avoid significant duplicate work in dependency resolution.
        set tRepositoryManager = ##class(%IPM.Repo.Manager).%Get(.tSC)
        $$$ThrowOnError(tSC)

        // Disregard violation of dependencies of pending modules
        set tInstallContext = ##class(%IPM.General.InstallContext).%Get(.tSC)
        $$$ThrowOnError(tSC)

        // May want to pass phases to subsequent calls
        set tPhases = $case(pCheckNestedScoped, 1: pPhases, : "")
        for i=1:1:..Dependencies.Count() {
            #dim tDep As %IPM.Storage.ModuleReference
            set tDep = ..Dependencies.GetAt(i)
            set tModulePath = pModulePath
            if '..HasScope(pPhases,tDep.Scope) {
                continue
            } elseif (tDep.Scope '= "") && (pModulePath = $listbuild(..Name)) {
                // Exclude the root module from cyclic dependency checking if the dependency is scoped.
                set tModulePath = ""
            }

            // Ensure this dependency is not an ancestor in the chain of dependencies getting to this point
            if $listfind(tModulePath,tDep.Name) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Cyclic dependency detected in module '%1': %2",..Name,$listtostring(tModulePath_$listbuild(tDep.Name)," -> ")))
                quit
            }

            // Test whether dependency version is a valid semantic version. These are handled in the first pass only.
            // Other cases are handled in the second pass only.
            set tIsExactVersion = +##class(%IPM.General.SemanticVersion).IsValid(tDep.VersionString) kill %objlasterror
            if ((pPass = $$$EXACT) && 'tIsExactVersion) || ((pPass = $$$FUZZY) && tIsExactVersion) {
                continue
            }

            // Build cumulative version requirement string
            #dim tSearchExpr As %IPM.General.SemanticVersionExpression
            set tSearchExpr = tDep.Version.%ConstructClone(1)
            set tConstraintList = $listbuild(..Name_": "_tDep.VersionString)
            set tSourcePath = ""
            for {
                set tSourcePath = $order(pDependencyGraph(tDep.Name,tSourcePath),1,tOtherReq)
                quit:tSourcePath=""

                set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tOtherReq,.tExpr)
                if $$$ISERR(tSC) {
                    quit
                }
                set tSearchExpr = tSearchExpr.And(tExpr)
                set tConstraintList = tConstraintList_$listbuild(tSourcePath_": "_tOtherReq)
            }
            if $$$ISERR(tSC) {
                quit
            }

            if 'pIgnoreInstalledModules {
                // Also apply requirements presented by other installed modules, with the exception of those that are:
                //	* Known as dependencies of the root module being installed (and thus eligible for upgrade)
                //	* Pending (re)installation
                //  * Already in the dependency graph
                set tOtherDeps = pKnownDependencies_tInstallContext.GetPendingModuleList()
                set tExistingDepKey = ""
                for {
                    set tExistingDepKey = $order(pDependencyGraph(tExistingDepKey))
                    if (tExistingDepKey = "") {
                        quit
                    }
                    set tOtherDeps = tOtherDeps_$listbuild(tExistingDepKey)
                }

                set tSC = ##class(%IPM.Utils.Module).GetRequiredVersionExpression(tDep.Name,tOtherDeps,.tInstalledReqExpr,.tInstalledConstraintList)
                if $$$ISERR(tSC) {
                    quit
                }
                set tSearchExpr = tSearchExpr.And(tInstalledReqExpr)
                set tConstraintList = tConstraintList_tInstalledConstraintList
            }

            // See if we already have a version that satisfies the dependency:
            set tDepFound = $data(pDependencyGraph(tDep.Name),tDepInfo)
            set tPreviousDepth = 0
            set tServerName = ""
            set tVersion = ""
            if tDepFound {
                set $listbuild(tPreviousDepth,tServerName,tVersion) = tDepInfo
            }

            // See if a satisfactory version already exists in the current namespace.
            // If it does, always use it
            // Particularly relevant for compilation of dependencies
            // The "clean" phase can be used to bypass this (by removing modules from the current namespace)
            // Forcing an update from disk can also override this, although we ensure that the same module is
            // not loaded multiple times in a given operation.
            set tForceSnapshotReload = pForceSnapshotReload
            if tForceSnapshotReload && $data($$$ZPMHandledModules($namespace,tDep.Name),tHandled) {
                if $listfind(tHandled,"Activate") {
                    // If we have already activated the given module, don't do so again.
                    set tForceSnapshotReload = 0
                }
            }
            if ('pIgnoreInstalledModules) && ..NameExists(tDep.Name) {
                set tLocalObj = ..NameOpen(tDep.Name,,.tSC)
                if $$$ISERR(tSC) {
                    quit
                }

                set tInstalledVersionValid = tLocalObj.Version.Satisfies(tSearchExpr) && ((tVersion = "") || (tVersion = tLocalObj.VersionString))
                if tInstalledVersionValid && '(tLocalObj.Version.IsSnapshot() && tForceSnapshotReload) {
                    set tLocalMod = 1
                    set tDepth = $select(tPreviousDepth=0:pDepth,tPreviousDepth>pDepth:tPreviousDepth,1:pDepth)
                    set pDependencyGraph(tDep.Name) = $listbuild(pDepth,"",tLocalObj.VersionString)
                    if (pIncludeDisplayName) {
                        set pDependencyGraph(tDep.Name) = pDependencyGraph(tDep.Name)_$listbuild(tDep.DisplayName)
                    }
                    set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
                    set pSubModules(tDepth,tDep.Name) = tLocalObj
                    set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope
                    continue
                }

                if 'pPermitDowngrade {
                    // Add a minimum of the currently-installed version as a constraint.
                    set tRangeString = ">="_tLocalObj.VersionString
                    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tRangeString,.tCurrentlyInstalledExpr)
                    $$$ThrowOnError(tSC)
                    set tSearchExpr = tSearchExpr.And(tCurrentlyInstalledExpr)
                    set tConstraintList = tConstraintList_$listbuild(tLocalObj.Name_": "_tRangeString_" (currently installed, downgrade not permitted)")
                }
            }

            set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
            set tSearchCriteria.Name = tDep.Name
            set searchExprStr = tSearchExpr.ToString()
            set tSearchCriteria.VersionExpression = searchExprStr
            // If the dependencyname has not been visited, actually do the search;
            // otherwise, see if the stored search expression contains the current search expression or the other way
            // If former, then use the stored qualifiedref; if latter, then need to do new search

            if ($data(pSearchList(tDep.Name)) '= 10) {
                set tSC = tRepositoryManager.SearchRepositoriesForModule(tSearchCriteria,.tQualifiedReferences,pForceSnapshotReload)
                if $$$ISERR(tSC) {
                    quit
                }
                set pSearchList(tDep.Name, tSearchExpr) = tQualifiedReferences
                set pSearchList(tDep.Name, tSearchExpr, "SearchString") = searchExprStr
            } else {
                set key = ""
                while 1 {
                    set key = $order(pSearchList(tDep.Name, key))
                    if (key = "") {
                        quit
                    }
                    if (pSearchList(tDep.Name, key, "SearchString") = searchExprStr) {
                        set tQualifiedReferences = pSearchList(tDep.Name, key)
                        quit
                    }
                }
                if (key = "") {
                    // no satisfied searchExpr found
                    set tSC = tRepositoryManager.SearchRepositoriesForModule(tSearchCriteria,.tQualifiedReferences,pForceSnapshotReload)
                    if $$$ISERR(tSC) {
                        quit
                    }
                    set pSearchList(tDep.Name, tSearchExpr) = tQualifiedReferences
                    set pSearchList(tDep.Name, tSearchExpr, "SearchString") = searchExprStr
                }
            }
            if (tQualifiedReferences.Count() = 0) {
                set tMsg = $$$FormatText("Could not find satisfactory version of %1 in any repositories. Required by: %2",tDep.Name,$listtostring(tConstraintList,"; "))
                set tSC = $$$ERROR($$$GeneralError,tMsg)
                quit
            } else {
                set tResultFound = 0
                for j=1:1:tQualifiedReferences.Count() {
                    kill tDependencyGraph,tSubModules
                    merge tDependencyGraph = pDependencyGraph
                    merge tSubModules = pSubModules
                    set tQualifiedReference = tQualifiedReferences.GetAt(j)
                    set tSC = tRepositoryManager.RetrieveModuleManifest(tQualifiedReference,.tManifest)
                    if $$$ISERR(tSC) {
                        quit
                    }

                    // Recursively process dependencies.
                    set tMsg = "Error reading module manifest for %1 %2 from repository %3"
                    set tOuterSC = $$$ERROR($$$GeneralError,$$$FormatText(tMsg,tQualifiedReference.Name,tQualifiedReference.VersionString,tQualifiedReference.ServerName))

                    #dim tModule As %IPM.Storage.Module
                    set tReader = ##class(%XML.Reader).%New()
                    set tSC = tReader.OpenStream(tManifest)
                    if $$$ISERR(tSC) {
                        set tSC = $system.Status.EmbedStatus(tOuterSC,tSC)
                        quit
                    }
                    do tReader.Correlate("Module","%IPM.Storage.Module")
                    do tReader.Next(.tModule,.tSC)
                    if $$$ISERR(tSC) {
                        set tSC = $system.Status.EmbedStatus(tOuterSC,tSC)
                        quit
                    }

                    set tDepth = $select(tPreviousDepth=0:pDepth,tPreviousDepth>pDepth:tPreviousDepth,1:pDepth)

                    if (pPass = $$$EXACT) {
                        set pDependencyGraph(tDep.Name) = $listbuild(pDepth, tQualifiedReference.ServerName, tModule.VersionString, tQualifiedReference.Deployed, tQualifiedReference.PlatformVersion)
                        if (pIncludeDisplayName) {
                            set pDependencyGraph(tDep.Name) = pDependencyGraph(tDep.Name)_$listbuild(tDep.DisplayName)
                        }
                        set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
                        set pSubModules(tDepth,tDep.Name) = tModule
                        set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope

                        // If we have an exact match, attempt to resolve exact dependencies recursively.
                        set tSC = tModule.BuildDependencyGraph(.pDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,tPhases,.pSubModules,,tModulePath_$listbuild(tDep.Name),pIgnoreInstalledModules,pKnownDependencies,pPermitDowngrade,,.pSearchList,pIncludeDisplayName)

                        // Failure to resolve any of these dependencies is an immediate failure, and can be descriptive.
                        if $$$ISERR(tSC) {
                            quit
                        }

                        set tResultFound = 1
                        quit
                    }

                    if (pPass = $$$FUZZY) {
                        set tDependencyGraph(tDep.Name) = $listbuild(tDepth,tQualifiedReference.ServerName,tModule.VersionString)
                        if (pIncludeDisplayName) {
                            set tDependencyGraph(tDep.Name) = tDependencyGraph(tDep.Name)_$listbuild(tDep.DisplayName)
                        }
                        set tDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString

                        set tSubModules(tDepth,tDep.Name) = tModule

                        // For fuzzy version matching, preview the next graph step; move to the next version if it would lead to failure.
                        // If not, update.
                        set tPossibleSC = tModule.BuildDependencyGraph(.tDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,tPhases,.tSubModules,,tModulePath_$listbuild(tDep.Name),pIgnoreInstalledModules,pKnownDependencies,pPermitDowngrade,,.pSearchList,pIncludeDisplayName)
                        if $$$ISOK(tPossibleSC) {
                            // We have a match - let's go with it. Actually dependency resolution will be done later, breadth-first.
                            // TODO: Caching of results to avoid duplicate web service calls.
                            set tResultFound = 1
                            quit
                        }
                    }
                }
                if $$$ISERR(tSC) {
                    quit
                }

                if (pPass = $$$FUZZY) {
                    // We don't actually care if a valid result was found.
                    // There will always be something in here, it just might lead to a descriptive error later on in the case of fuzzy matching with no valid option.
                    set pDependencyGraph(tDep.Name) = $listbuild(pDepth,tQualifiedReference.ServerName,tModule.VersionString)
                    if (pIncludeDisplayName) {
                        set pDependencyGraph(tDep.Name) = pDependencyGraph(tDep.Name)_$listbuild(tDep.DisplayName)
                    }
                    set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
                    set pSubModules(tDepth,tDep.Name) = tModule
                    set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope
                }
            }
        }
        if $$$ISERR(tSC) {
            quit
        }

        if (pPass = $$$EXACT) {
            // Call for second pass (fuzzy version matching)
            set tSC = ..BuildDependencyGraph(.pDependencyGraph,pDepth,pForceSnapshotReload,.qstruct,pPhases,.pSubModules,$$$FUZZY,pModulePath,pIgnoreInstalledModules,pKnownDependencies,pPermitDowngrade,,.pSearchList,pIncludeDisplayName)
            if $$$ISERR(tSC) {
                quit
            }
        }

        // Breadth-first dependency resolution for depth 1, pass 1.
        // Things to resolve have been accumulated in previous passes and/or will continue to be accumulated.
        if (pDepth = 1) && (pPass = $$$EXACT) {
             while $data(pSubModules(pDepth)) {
                set tModName = ""
                for {
                    set tModName = $order(pSubModules(pDepth,tModName),1,tModule)
                    quit:tModName=""
                    set tModulePath = $case(pSubModules(pDepth,tModName,$$$SCOPE),"":pModulePath,:"")
                    set tSC = tModule.BuildDependencyGraph(.pDependencyGraph,pDepth+1,pForceSnapshotReload,.qstruct,tPhases,.pSubModules,,tModulePath_$listbuild(tModName),pIgnoreInstalledModules,pKnownDependencies,pPermitDowngrade,,.pSearchList,pIncludeDisplayName)
                    if $$$ISERR(tSC) {
                        quit
                    }
                }
                if $$$ISERR(tSC) {
                    quit
                }
                set pDepth = pDepth + 1
            }
            if $$$ISERR(tSC) {
                quit
            }

            // Ensure cyclic dependencies (possible with scopes) are removed from the graph; otherwise, not everything will be installed.
            kill pDependencyGraph(..Name)
            set tDependencyKey = ""
            for {
                set tDependencyKey = $order(pDependencyGraph(tDependencyKey))
                if (tDependencyKey = "") {
                    quit
                }

                set tDependencySource = $order(pDependencyGraph(tDependencyKey,..Name))
                if ($piece(tDependencySource," ") = ..Name) {
                    kill pDependencyGraph(tDependencyKey,tDependencySource)
                }
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// This method builds a list of any direct/indirect dependencies of the module named <var>pModuleName</var> in a breadth-first manner.
ClassMethod GetKnownDependencies(pModuleName As %String) As %List
{
    set tStatement = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(tStatement.%Prepare("select Dependencies_Name as ModuleName from %IPM_Storage.ModuleItem_Dependencies where ModuleItem->Name = ?"))

    set tKnownDependencyList = ""
    set tSearchList = $listbuild(pModuleName)

    // For each tree level (starting out at the top level node)...
    while (tSearchList '= "") {
        set tNewSearchList = ""
        set tPointer = 0

        // Iterate over modules at the current tree level.
        while $listnext(tSearchList,tPointer,tModule) {
            // If we have already seen the module at this level (earlier in the list), skip it.
            if $data(tKnownDependencies(tModule)) {
                continue
            }
            set tKnownDependencyList = tKnownDependencyList_$listbuild(tModule)
            set tKnownDependencies(tModule) = ""

            // Find all dependencies of the module.
            set tResult = tStatement.%Execute(tModule)
            if (tResult.%SQLCODE < 0) {
                throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
            }
            while tResult.%Next(.tSC) {
                $$$ThrowOnError(tSC)
                if $data(tKnownDependencies(tResult.%Get("ModuleName"))) {
                    // If we have already seen the module at a higher level in the tree, skip it.
                    continue
                }
                // Flag this module so its dependencies are checked (and it is added to the list itself) in the iteration for the next tree level.
                set tNewSearchList = tNewSearchList_$listbuild(tResult.%Get("ModuleName"))
            }
            $$$ThrowOnError(tSC)
        }
        set tSearchList = tNewSearchList
    }
    quit tKnownDependencyList
}

/// Builds a module's immediate dependency graph and array of resources.<br />
/// Optionally loads uninstalled dependency modules and recurses over each module in the dependency graph.<br />
/// @Argument	pReferenceArray		Array of all module's resources (including resources that compose a resource) that contain the appropriate phase scope.<br />
/// @Argument	pLockedDependencies	Whether method should be recursively applied to the module's dependencies (true = yes).<br />
/// @Argument	pPhases				List of IPM lifecycle phases to be applied to the current module.<br />
/// @Argument	pSkipDependencies	Whether to skip loading uninstalled dependency modules.<br />
/// @Argument	pDependencyGraph 	Tree of module's dependencies.<br />
Method GetResolvedReferences(
	Output pReferenceArray,
	pLockedDependencies As %Boolean = 0,
	pPhases As %List = "",
	pSkipDependencies As %Boolean = 0,
	ByRef pDependencyGraph) As %Status
{
    set tSC = $$$OK
    try {
        if '$data(pDependencyGraph) {
            set tSC = ..BuildDependencyGraph(.pDependencyGraph,,,,pPhases)
            if $$$ISERR(tSC) {
                quit
            }
        }

        if 'pSkipDependencies {
            kill tParams
            set tParams("Verbose") = 0
            set tParams("qstruct") = "k"
            set tSC = ##class(%IPM.Utils.Module).LoadDependencies(.pDependencyGraph,.tParams)
            if $$$ISERR(tSC) {
                quit
            }
        }

        set pReferenceArray(..Name, ..Name_".ZPM") = ""

        set orderedResourceList = ..GetOrderedResourceList()
        set tKey = ""
        for {
            #dim tResource As %IPM.Storage.ResourceReference
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:tKey=""
            if '..HasScope(pPhases,tResource.Scope) {
                continue
            }

            kill tempArray
            set tSC = tResource.ResolveChildren(.tempArray)
            set resourceScope = tResource.Scope
            set attrScope = $get(tempArray("Scope"))
            if ..HasScope(pPhases, resourceScope) && ..HasScope(pPhases, attrScope) {
                merge pReferenceArray(..Name) = tempArray
            }
            if $$$ISERR(tSC) {
                quit
            }
        }
        if $$$ISERR(tSC) {
            quit
        }

        if pLockedDependencies {
            set tModName = ""
            for {
                set tModName = $order(pDependencyGraph(tModName))
                quit:tModName=""

                set tModule = ##class(%IPM.Storage.Module).NameOpen(tModName,,.tSC)
                if $$$ISERR(tSC) {
                    quit
                }

                // Don't pass along the phase
                set pReferenceArray(tModName, tModName_".ZPM") = ..Name

                // pLockedDependencies=0 to avoid duplicating effort on nested dependencies;
                // this loop will already get all of them.
                set tSC = tModule.GetResolvedReferences(.pReferenceArray,0,,1)
                if $$$ISERR(tSC) {
                    quit
                }
            }
            if $$$ISERR(tSC) {
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method LifecycleGet() As %IPM.Lifecycle.Base
{
    if $isobject(r%Lifecycle) {
        quit r%Lifecycle
    }
    for tBasis = ..OverrideLifecycleClass,..LifecycleClass {
        if (tBasis '= "") && ($length(tBasis,".") = 1) {
            set tLifecycleClass = $$$DefaultLifecyclePackageDot_tBasis
        } else {
            set tLifecycleClass = tBasis
        }
        if (tLifecycleClass '= "") && $$$comClassDefined(tLifecycleClass) {
            quit
        }
    }
    if (tLifecycleClass = "") || '$$$comClassDefined(tLifecycleClass) {
        set ..LifecycleClass = "Module"
        set tLifecycleClass = $$$DefaultLifecyclePackageDot_..LifecycleClass
    }
    set r%Lifecycle = $classmethod(tLifecycleClass,"%New",$this)
    quit r%Lifecycle
}

Method OverrideLifecycleClassSet(pValue As %Dictionary.Classname) As %Status
{
    if (..OverrideLifecycleClass '= pValue) && $isobject(..Lifecycle) {
        set ..Lifecycle = ""
        set i%OverrideLifecycleClass = pValue
    }
    quit $$$OK
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
    set ..Version = ##class(%IPM.General.SemanticVersion).FromString(i%VersionString)
    quit $$$OK
}

/// This callback method is invoked by the <METHOD>%Open</METHOD> method to
/// provide notification that the object specified by <VAR>oid</VAR> is being opened.
/// 
/// <P>If this method returns an error then the object will not be opened.
Method %OnOpen() As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = $$$OK
    try {
        // In Studio, use the existing %SourceControl object.
        // From other contexts, create a new one.
        if '$isobject($get(%SourceControl)) {
            new %SourceControl
            do ##class(%Studio.SourceControl.Interface).SourceControlCreate()
        }
        set tExternalName = ##class(%Studio.SourceControl.Interface).ExternalName(..Name_".ZPM")
        if (tExternalName '= "") {
            set tDirectory = ##class(%File).GetDirectory(tExternalName, 0)
            if (tDirectory '= "") {
                set ..Root = tDirectory
            }
        }
        if ..Deployed,..DeveloperMode {
            set ..DeveloperMode = 0
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = $$$OK
    try {
        // Ensure packaging property is set to the correct value.
        // This validation only runs if the lifecycle class exists.
        if (..LifecycleClass '= "") && $$$comClassDefined(..LifecycleClass) {
            set tBaseClass = "%IPM.Lifecycle.Base"
            set legacyBaseClass = "%ZPM.PackageManager.Developer.Lifecycle.Base"
            if '$classmethod(..LifecycleClass,"%Extends",tBaseClass) && '$classmethod(..LifecycleClass,"%Extends",legacyBaseClass) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid lifecycle class '%1' - must extend %2",..LifecycleClass,tBaseClass))
                quit
            }
            set tPackaging = $parameter(..LifecycleClass,"PACKAGING")
            if (..Packaging = "") {
                set ..Packaging = tPackaging
            } elseif (..Packaging '= tPackaging) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Module's packaging is set to '%1', but lifecycle class '%2' has packaging '%3'.",..Packaging,..LifecycleClass,tPackaging))
                quit
            }
        } elseif (..LifecycleClass = "") && (..Packaging '= "") {
              set ..LifecycleClass = $case(..Packaging,"application": "Application", : "Module")
        } elseif (..Packaging = "") {
            // Default to "module"
            set ..Packaging = "module"
        }

        // Can have only one NamespaceConfig module setting.
        set tNSConfigCount = 0
        set tDefaultCount = ..Defaults.Count()
        for tDefaultIndex=1:1:tDefaultCount {
            set tDefault = ..Defaults.GetAt(tDefaultIndex)
            if tDefault.%IsA("%IPM.Storage.ModuleSetting.NamespaceConfig") {
                set tNSConfigCount = tNSConfigCount + 1
            }
        }
        if (tNSConfigCount > 1) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Only one NamespaceConfig may be specified per module."))
            quit
        }

        // Pre-check for uniqueness among resources (make sure there are no collisions and report descriptive errors if there are).
        // This is simpler than trying to interpret a unique index violation later, and will work in all cases where we're updating modules.
        set tInstallContext = ##class(%IPM.General.InstallContext).%Get(.tSC)
        $$$ThrowOnError(tSC)

        set tSC = $$$OK
        set orderedResourceList = ..GetOrderedResourceList()
        set tKey = ""
        for {
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:(tKey="")

            // If it hasn't been saved yet (to account for module renames)...
            if (tResource.%Id() = "") && (tResource.UniqueName '= "") {
                // ... see if some other resource exists with the same name.
                if ##class(%IPM.Storage.ResourceReference).ResourceNameExists(tResource.UniqueName,.tResourceId) {
                    set tOtherResource = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceId,0,.tSC)
                    if $$$ISERR(tSC) {
                        quit
                    }
                    if tInstallContext.ModuleIsPending(tOtherResource.Module.Name) {
                        // %OnAddToSaveSet will correct for this condition.
                        continue
                    }
                    if (tResource.Name = tResource.UniqueName) {
                        // Common case: classes, packages, include files, etc.
                        set tMsg = $$$FormatText("Resource '%1' is already defined as part of module '%2'; cannot also be listed in module '%3'",tResource.Name,tOtherResource.Module.Name,..Name)
                    } else {
                        // Handle the case where resources with different names are uniquely identified the same way.
                        set tResourceName = tResource.Name_" ("_tResource.UniqueName_")"
                        set tMsg = $$$FormatText("Resource '%1' is already defined as part of module '%2' as '%4'; cannot also be listed in module '%3'",tResourceName,tOtherResource.Module.Name,..Name,tOtherResource.Name)
                    }
                    set tSC = $$$ERROR($$$GeneralError,tMsg)
                    quit
                }
            }
            if $$$ISERR(tSC) {
                quit
            }
        }
        set query = "SELECT COUNT(*) AS Conflict FROM %IPM_Storage.ModuleItem WHERE Name = ? AND Name <> ?"
        set rs = ##class(%SQL.Statement).%ExecDirect(,query, ..ExternalName, ..Name)
        if rs.%Next() && (rs.%Get("Conflict") > 0) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("External name '%1' conflicts with the real name of another module", ..ExternalName)))
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// This callback method is invoked when the current object is added to the SaveSet,
/// either because %Save() was invoked on this object or on an object that references this object.
/// %OnAddToSaveSet can modify the current object. It can also add other objects to the current
/// SaveSet by invoking %AddToSaveSet or remove objects by calling %RemoveFromSaveSet.
/// 
/// <P>If this method returns an error status then %Save() will fail and the transaction
/// will be rolled back.
Method %OnAddToSaveSet(
	depth As %Integer = 3,
	insert As %Integer = 0,
	callcount As %Integer = 0) As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = $$$OK
    try {
        // Ensure Version serial object is up to date.
        if (..VersionString '= ..Version.ToString()) {
            set ..Version = ##class(%IPM.General.SemanticVersion).FromString(..VersionString)
        }
        set tSC = ..XMLExportToStream(.tStream)
        if $$$ISERR(tSC) {
            quit
        }

        // See if the module definition has actually changed
        set tHash = $system.Encryption.SHA1HashStream(tStream,.tSC)
        if $$$ISERR(tSC) {
            quit
        }
        if (..Hash '= tHash) {
            set ..Hash = tHash
            set ..LastModifiedTimestamp = $zdatetime($horolog,3)
        }

        // Deal with resources moving from a module dependent on the current module that hasn't been reloaded yet
        set tInstallContext = ##class(%IPM.General.InstallContext).%Get(.tSC)
        $$$ThrowOnError(tSC)

        set tSC = $$$OK
        set orderedResourceList = ..GetOrderedResourceList()
        set tKey = ""
        for {
            set tResource = orderedResourceList.GetNext(.tKey)
            quit:(tKey="")

            // If it hasn't been saved yet (to account for module renames)...
            if (tResource.%Id() = "") && (tResource.UniqueName '= "") {
                // ... see if some other resource exists with the same name.
                if ##class(%IPM.Storage.ResourceReference).ResourceNameExists(tResource.UniqueName,.tResourceId) {
                    set tOtherResource = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceId,,.tSC)
                    $$$ThrowOnError(tSC)

                    if tInstallContext.ModuleIsPending(tOtherResource.Module.Name) {
                        // Delete the resource. If the pending module still contains it, there will be an error when that module is loaded.
                        set tSC = ##class(%IPM.Storage.ResourceReference).%DeleteId(tResourceId)
                        $$$ThrowOnError(tSC)
                    }
                }
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
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
ClassMethod XMLNew(
	document As %XML.Document,
	node As %Integer,
	containerOref As %RegisteredObject = "") As %RegisteredObject [ ServerOnly = 1 ]
{
    // Coupled with %IPM.StudioDocument.Module to allow editing of the current module rather than matching an existing one.
    quit $get($$$ZPMStudioDocumentModule,..%New())
}

/// Validates the module manifest in <var>pManifest</var> - both that it can be interpreted properly as XML, and also that the module it contains (returned in <var>pModule</var>) has
/// a name and version matching the supplied <var>pModuleReference</var>.
ClassMethod ValidateStream(
	pManifest As %Stream.Object,
	pModuleReference As %IPM.Storage.QualifiedModuleInfo,
	Output pModule As %IPM.Storage.Module) As %Status
{
    set pModule = $$$NULLOREF
    set tSC = $$$OK
    try {
        set tModName = pModuleReference.Name
        set tModVersion = pModuleReference.VersionString
        set tModSource = pModuleReference.ServerName

        set pModule = ##class(%IPM.Utils.Module).GetModuleObjectFromStream(pManifest, .tModuleFound)
        set tCorrSC = $$$OK
        if tModuleFound {
            // Ensure that module name and version match.
            if (tModName '= pModule.Name) {
                set tCorrSC = $$$ERROR($$$GeneralError,$$$FormatText("Incorrect module name in manifest: %1",pModule.Name))
            }
            if (tModVersion '= pModule.VersionString) {
                // Append the status in case neither matches.
                set tCorrSC = $$$ADDSC(tCorrSC,$$$ERROR($$$GeneralError,$$$FormatText("Incorrect module version in manifest: %1",pModule.Name)))
            }
        } else {
            // Treat as an error if no element is found.
            set tCorrSC = $$$ERROR($$$GeneralError,"No root <Module> element found in manifest.")
        }
        $$$ThrowOnError(tCorrSC)
    } catch e {
        set pModule = $$$NULLOREF
        set tMsg = $$$FormatText("Error parsing module manifest for '%1 %2' from repository '%3'",$get(tModName),$get(tModVersion),$get(tModSource))
        set tOuterSC = $$$ERROR($$$GeneralError,tMsg)
        set tSC = $system.Status.EmbedStatus(tOuterSC,e.AsStatus())
    }
    quit tSC
}

/// By default (first byref argument only), creates a Studio project containing all of the module's resources.
/// If <var>pDeployedCode</var> is non-empty, only includes code that should be deployed (if true) or not deployed (if false).
/// <var>pDefaultDeployedValue</var> specifies the default behavior for resources with the Deploy attribute left null.
/// <var>pProjectSuffix</var> is appended to the project name (which defaults to the module name, with periods replaced by underscores).
/// The project suffix may be used (for example) to distinguish between projects for deployed and undeployed code.
Method GetStudioProject(
	Output pProject As %Studio.Project,
	pDeployedCode As %Boolean = "",
	pDefaultDeployedValue As %Boolean = "",
	pProjectSuffix As %String = "") As %Status
{
    set tSC = $$$OK
    try {
        set tProjectName = $replace(..DisplayName,".","_")_$case(pProjectSuffix,"":"",:"_"_pProjectSuffix)
        if ##class(%Studio.Project).%ExistsId(tProjectName) {
            set pProject = ##class(%Studio.Project).%OpenId(tProjectName,,.tSC)
            $$$ThrowOnError(tSC)
        } else {
            set pProject = ##class(%Studio.Project).%New()
            set pProject.Name = tProjectName
        }

        do pProject.Items.Clear()

        if (pDeployedCode = 0) {
            // Include module manifest in project with non-deployed code. Caller will call once with pDeployedCode = 1,
            // once with pDeployedCode = 0 to get separate Studio projects; only want this in one of them.
            do pProject.AddItem(..Name_".ZPM")
        }

        set orderedResourceList = ..GetOrderedResourceList()
        set tResourceKey = ""
        for {
            #dim tResource As %IPM.Storage.ResourceReference
            set tResource = orderedResourceList.GetNext(.tResourceKey)
            if (tResourceKey = "") {
                quit
            }

            if (pDeployedCode '= "") {
                if (tResource.Deploy '= "") && (tResource.Deploy '= pDeployedCode) {
                    continue
                }
                if (tResource.Deploy = "") && (pDefaultDeployedValue '= pDeployedCode) {
                    continue
                }
            }

            if $isobject(tResource.Processor) {
                do tResource.Processor.OnGetStudioProject(pProject,.handled)
                continue:handled
            }

            kill tResourceArray
            $$$ThrowOnError(tResource.ResolveChildren(.tResourceArray))

            set tChildResourceKey = ""
            for {
                set tChildResourceKey = $order(tResourceArray(tChildResourceKey))
                if (tChildResourceKey = "") {
                    quit
                }

                // Add object code for deployed items, since source is unavailable.
                $$$ThrowOnError(..AddItemToProject(pProject,tChildResourceKey))
            }
        }
        $$$ThrowOnError(pProject.%Save())
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod AddItemToProject(
	tProject As %Studio.Project,
	pResourceName As %String) As %Status [ Internal ]
{
    set tSC = $$$OK
    try {
        set tName = $piece(pResourceName,".",1,*-1)
        set tExt = $piece(pResourceName,".",*)
        if ((tExt = "MAC") || (tExt = "INT")) && '##class(%Library.Routine).Exists(pResourceName) {
            do tProject.AddItem(tName_".OBJ")
        } else {
            do tProject.AddItem(pResourceName)
        }
        $$$ThrowOnError(tProject.Check())
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method %Compile(ByRef qstruct As %String) As %Status
{
    quit ..Lifecycle.Compile(.qstruct)
}

Method IsLocked() As %Boolean
{
    quit ($zconvert(..Version.Build,"L") '= "snapshot")
}

Method Lock() As %Status
{
    if '..IsLocked() {
        set ..Version.Build = ""
    }
    quit $$$OK
}

Query VersionRequirements(
	pOfModuleName As %String,
	pExcludeModuleNames As %List = "") As %SQLQuery [ SqlProc ]
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
Method %Evaluate(
	pAttrValue As %String,
	ByRef pParams) As %String [ Internal ]
{
    set tAttrValue = pAttrValue
    if (tAttrValue '[ "{") {
        return tAttrValue
    }
    merge tParams = pParams
    do ##class(%IPM.Storage.ModuleSetting.Default).GetCustomParameters(.customParams, $this, .tParams)
    set root = ..Root
    if (root '= "") {
        set root = ##class(%Library.File).NormalizeDirectory(root)
    }
    set customParams("root") = root
    set customParams("packagename") = ..Name
    set customParams("version") = ..VersionString
    set customParams("verbose") = +$get(pParams("Verbose"))
    set tAttrValue = ##class(%IPM.Utils.Module).%EvaluateMacro(tAttrValue)
    set tAttrValue = ##class(%IPM.Storage.ModuleSetting.Default).EvaluateAttribute(tAttrValue,.customParams)
    set attrValue = ##class(%IPM.Utils.Module).%EvaluateSystemExpression(tAttrValue)

    // {name} expression does not contain dollar sign; handle separately
    set name = ..Name
    set attrValue = ##class(%Regex.Matcher).%New("(?i)\{name\}", attrValue).ReplaceAll($replace(name,"\","\\"))

    set regex = ##class(%Regex.Matcher).%New("#\{([^}]+)\}", attrValue)
    while regex.Locate() {
        set expr = regex.Group(1)
        set value = ..%EvaluateExpression(expr)
        set $extract(attrValue, regex.Start, regex.End - 1) = value
        set regex.Text = attrValue
    }

    return attrValue
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
    set ..LastUpdated = $zdatetime($horolog, 3)
    quit $$$OK
}

Method %EvaluateExpression(pExpr) As %String [ Internal ]
{
    try {
        // Remove leading whitespace because there can only be 1 whitespace between "return" and its argument
        set pExpr = $zstrip(pExpr, "<W")
        return @pExpr
    } catch ex {
    }
    return ""
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
