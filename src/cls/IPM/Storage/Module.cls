Include (%occErrors, %IPM.Common)

Class %IPM.Storage.Module Extends (%Persistent, %IPM.General.ModuleInfo, %IPM.Utils.ComparisonAdaptor) [ SqlTableName = ModuleItem, StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.Module";

Parameter DOMAIN = "ZPM";

Index Name On Name [ Unique ];

Property GlobalScope As %Boolean;

Property VersionString As %IPM.DataType.VersionString(XMLNAME = "Version") [ InitialExpression = "0.0.1+snapshot", Required ];

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

Property UpdatePackage As %Dictionary.Classname;

/// Iterates through all of a module's update step classes and tries to either execute or seed those steps.
/// seedSteps: (Default) 0 = Execute Steps | 1 = Seeds Steps
Method HandleAllUpdateSteps(
	logFile As %Library.File = "",
	seedSteps As %Boolean = 0,
	verbose As %Boolean = 0) As %Status
{
    set sc = $$$OK
    // Only need to acquire lock when applying the steps, not when seeding them
    if 'seedSteps {
        if verbose {
            write !, "Acquiring lock on ^IPM.UpdateLock("_..Name_")"
        }
        $$$LockUpdateModule(..Name)
        if ('$test) {
            return sc
        }
    }

    try {
        do ##class(%IPM.General.Update.VersionBase).GetUpdatePackageClassList(..UpdatePackage, .classList)
        set keyVersion = ""
        for {
            // Iterate over update package class list for steps to apply. Apply all of those up to and including this major version
            set keyVersion = $order(classList(keyVersion))
            if (keyVersion = "") {
                quit
            }
            set className = classList(keyVersion)
            if verbose {
                if seedSteps {
                    write !, "Starting seeding steps for module = "_..Name_" & class = "_className
                } else {
                    write !, "Starting to run update steps for module = "_..Name_" & class = "_className
                }
            }

            // Don't want newStepToApply (execution of all subsequent steps when encountering a new one) to persist across versions
            set newStepToApply = 0
            if $system.CLS.IsMthd(className, "GetOrderedMethods") {
                set orderedMethodNames = $classmethod(className, "GetOrderedMethods")
                do ..HandleUpdateStepsFromList(orderedMethodNames, className, 0, logFile, seedSteps, .newStepToApply, verbose)
            }
            if $system.CLS.IsMthd(className, "GetOrderedMethodsPrimaryOnly") {
                set primaryOnlyMethodNames = $classmethod(className, "GetOrderedMethodsPrimaryOnly")
                do ..HandleUpdateStepsFromList(primaryOnlyMethodNames, className, 1, logFile, seedSteps, .newStepToApply, verbose)
            }

            if verbose {
                if seedSteps {
                    write !, "Finished seeding steps for module = "_..Name_" & class = "_className
                }
                else {
                    write !, "Finished running update steps for module = "_..Name_" & class = "_className
                }
            }
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }

    if 'seedSteps {
        if verbose {
            write !, "Releasing lock on ^IPM.UpdateLock("_..Name_")"
        }
        $$$UnlockUpdateModule(..Name)
    }

    quit sc
}

/// For a given version, seed or execute update steps listed in the module's update package version class
/// 
/// If seeding: For only steps that don't have a TimeStampEnd value or have an errored status, set it's TimeStampEnd to the current time
/// 
/// If executing: Only start running steps at the first one found not to have a TimeStampEnd value or if an errored step is found
///               After finding this step, run it and all subsequent steps, regardless of if they have been run or not.
/// 
/// newStepToApply - Gets marked as true to tell us to run all remaining steps in the list, whether or not they have been run/seeded before
///                  Can carry this over to subsequent calls by passing the newStepToApply variable to those HandleUpdateStepsFromList() calls
Method HandleUpdateStepsFromList(
	methodList As %Library.DynamicArray,
	className As %String,
	primaryOnly As %Boolean,
	logFile As %Library.File,
	seedSteps As %Boolean = 0,
	ByRef newStepToApply As %Boolean = 0,
	verbose As %Boolean = 0) [ Internal, Private ]
{
    set iter = methodList.%GetIterator()
    while iter.%GetNext(, .methodName) {
        // Get update step object for this className + methodName. If one does not already exist, create a new one and use that
        set stepObj = ..GetAddUpdateStep(className, methodName, primaryOnly)
        if seedSteps {
            do ..SeedUpdateStep(stepObj, verbose)
        } else {
            // Once we come across a step that hasn't been run/seeded or failed on its last run, mark newStepToApply as true.
            // This indicates that we should run all subsequent steps, regardless of their current status
            if 'newStepToApply && ('stepObj.TimeStampEnd || $$$ISERR(stepObj.Status)) {
                set newStepToApply = 1
            }
            if newStepToApply {
                do ..ExecuteUpdateStep(stepObj, primaryOnly, verbose)
            }
        }
    }
}

/// Seeds an update step by setting TimeStampEnd to current time and status to $$$OK
/// Seeding steps mark the steps as having been successfully run so will not be run on subsequent 'update' calls
/// Only seed steps that have no TimeStampEnd defined (not already been run/seeded) or errored on their last run
Method SeedUpdateStep(
	updateStep As %IPM.Storage.UpdateStep.Base,
	verbose As %Boolean = 0)
{
    if 'updateStep.TimeStampEnd || $$$ISERR(updateStep.Status) {
        if verbose {
            write !, $char(9)_"Seeding "_updateStep.MethodName_"()"
        }
        set updateStep.TimeStampEnd = $zdatetime($horolog,3)
        set updateStep.Status = $$$OK
        $$$ThrowOnError(updateStep.%Save())
    }
    else {
        if verbose {
            write !, $char(9)_"Skipping seeding "_updateStep.MethodName_"() (already run or seeded)"
        }
    }
}

/// Executes an update step
Method ExecuteUpdateStep(
	updateStep As %IPM.Storage.UpdateStep.Base,
	primaryOnly As %Boolean,
	verbose As %Boolean = 0)
{
    if primaryOnly && $system.Mirror.IsMember() && '$system.Mirror.IsPrimary() {
        if verbose {
            write !, $char(9)_"Skipping "_updateStep.MethodName_"(). This step is to be run on the mirror primary only."
        }
        quit
    }
    if verbose {
        write !, $char(9)_"Running "_updateStep.MethodName_"()"
    }
    set updateStep.TimeStampStart = $zdatetime($horolog,3)
    set sc = $$$OK
    try {
        do $classmethod(updateStep.ClassName, updateStep.MethodName)
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    set updateStep.TimeStampEnd = $zdatetime($horolog,3)
    set updateStep.Status = sc
    set sc = updateStep.%Save()
    $$$ThrowOnError(sc)
    $$$ThrowOnError(updateStep.Status)
    if verbose {
        write !, $char(9)_updateStep.MethodName_"() Finished"
    }
}

/// Get or Add an update step for this current module based on className + methodName index
/// If an update step already exists, this method behaves like a Get()
/// If an update step does not exist, this method behaves like an Add()
/// In both cases, this method will return the update step object
/// primaryOnly - set to 1 if this update step is one that runs on the primaryOnly
Method GetAddUpdateStep(
	className As %String,
	methodName As %String,
	primaryOnly As %Boolean) As %IPM.Storage.UpdateStep.Base
{
    if primaryOnly {
        set stepObj = ##class(%IPM.Storage.UpdateStep.PrimaryOnly).GetUpdateStep(className, methodName)
    } else {
        set stepObj = ##class(%IPM.Storage.UpdateStep.AnyMember).GetUpdateStep(className, methodName)
    }
    set stepObj.HomeModule = $this
    $$$ThrowOnError(stepObj.%Save())
    return stepObj
}

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
	ByRef pParams,
	pLog As %IPM.General.AbstractHistory = "") As %Status
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
        set tOverallTiming = tTiming && ($listlength(tPhases) > 1)

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
            // history logging for phases
            if pLog '= "" {
                do pLog.InitPhase(tOnePhase)
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
                if pLog '= "" {
                    do pLog.FinalizePhase(tOnePhase, e.AsStatus())
                }
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

            if pLog '= "" {
                do pLog.FinalizePhase(tOnePhase, $$$OK)
            }
        }
        if tOverallTiming {
            write !,"["_tModule.DisplayName_"]",$char(9),"(total time: ",($zhorolog-tFullStart)," s)"
        }
    } catch e {
        set tSC = e.AsStatus()
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
	set log = ##class(%IPM.General.HistoryTemp).UninstallInit(pModuleName)
	set module = ..NameOpen(pModuleName,,.tSC)
	if $isobject(module) {
		$$$ThrowOnError(log.SetVersion(module.Version))
	}

    try {
        merge tParams = pParams
        set tParams("Clean","Level") = 1 // Simulate clean of module as dependency.
        set tParams("Clean","Force") = pForce
        set tParams("Clean","Recurse") = pRecurse
        set tSC = ##class(%IPM.Storage.Module).ExecutePhases(pModuleName,$listbuild("Clean"),,.tParams, log)
    } catch e {
        set tSC = e.AsStatus()
    }
	set devMode = $get(pParams("DeveloperMode", 0))
	set tSC = $$$ADDSC(tSC, log.Finalize(tSC, devMode))
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

/// Builds a dependency graph using a fully iterative breadth-first algorithm
/// with no recursive calls (which result in massive slowdowns in ObjectScript).
/// <p>
/// <b>Algorithm:</b> This method processes dependencies level-by-level using a work queue, avoiding function call overhead:
/// <ol>
/// <li><b>Initialization:</b> Creates work queue with root module at depth 1</li>
/// <li><b>Level Processing:</b> While work queue has modules at current depth, processes each module:
///   <ul>
///   <li><b>Classification:</b> Separates module's dependencies into exact and fuzzy categories</li>
///   <li><b>Exact Processing:</b> Processes exact dependencies with fail-fast behavior</li>
///   <li><b>Fuzzy Processing:</b> Processes fuzzy dependencies with backtracking and quick validation</li>
///   <li><b>Queue Addition:</b> Adds resolved dependencies to work queue at next depth level</li>
///   </ul>
/// </li>
/// <li><b>Depth Advancement:</b> Moves to next depth when current level is exhausted</li>
/// <li><b>Cleanup:</b> Removes cyclic dependencies from final graph</li>
/// </ol>
/// This approach reduces module visits for heavily-reused dependencies.
/// <p>
/// <b>Output:</b> <var>pDependencyGraph</var> is an array where keys are module names and values are lists containing:
/// <ul>
/// <li>Depth in the dependency tree (1 for direct dependencies, 2 for transitive, etc.)</li>
/// <li>Repository from which the module will be obtained (empty if already installed)</li>
/// <li>Version string of the module to be installed</li>
/// </ul>
/// <p>
/// <b>Parameters:</b><br>
/// <var>pDependencyGraph</var> - Output array of resolved dependencies<br>
/// <var>pForceSnapshotReload</var> - If true, reload cached snapshots from repositories.<br>
/// <var>pPhases</var> - Lifecycle phases to execute; determines which scoped dependencies are considered. Empty=all<br>
/// <var>pIgnoreInstalledModules</var> - If true, don't use already-installed modules.<br>
/// <var>pPermitDowngrade</var> - If true, allow downgrading installed modules.<br>
/// <var>pCheckNestedScoped</var> - If true, check scoped dependencies against root module phases.<br>
/// NOTE: Other parameters are placeholders to match signature of original BuildDependencyGraph method for backward compatibility.
Method BuildDependencyGraph(
	ByRef pDependencyGraph,
	pIgnore1,
	pForceSnapshotReload As %Boolean = 0,
	ByRef pIgnore2,
	pPhases As %String = "",
	ByRef pIgnore3,
	pIgnore4,
	pIgnore5,
	pIgnoreInstalledModules As %Boolean = 0,
	pIgnore6,
	pPermitDowngrade As %Boolean = 0,
	pCheckNestedScoped As %Boolean = 0,
	ByRef pIgnore7,
	pIgnore8) As %Status [ Internal ]
{
    set sc = $$$OK
    try {
        if $data(^IPMTest("BuildDependencyGraphCount")) {
            do $increment(^IPMTest("BuildDependencyGraphCount"))
        }

        // Initialize internal variables
        kill manifestCache, repoSearchCache, moduleCache, workQueue
        set knownDependencies = ..GetKnownDependencies(..Name)

        // Initialize work queue with root module
        // Queue structure: workQueue(depth, moduleName) = $listbuild(modulePath, scope)
        // Store module objects separately in moduleCache: moduleCache(moduleName) = moduleObject
        set workQueue(1, ..Name) = $listbuild($listbuild(..Name), "")
        set moduleCache(..Name) = $this
        set phases = $case(pCheckNestedScoped, 1: pPhases, : "")

        // ===== ITERATIVE BREADTH-FIRST PROCESSING =====
        set currentDepth = 1
        while $data(workQueue(currentDepth)) {
            set modName = ""
            for {
                set modName = $order(workQueue(currentDepth, modName), 1, queueData)
                quit:modName=""

                // Unpack queue data and retrieve module object
                set $listbuild(modulePath, scope) = queueData
                set moduleObj = moduleCache(modName)

                // Adjust module path for scoped dependencies
                if (scope '= "") && ($listlength(modulePath) = 1) {
                    set modulePath = ""
                }

                // ===== Process this module's dependencies =====
                kill exactDeps, fuzzyDeps

                // Classify dependencies - store MODULE NAME and dependency INDEX
                for i=1:1:moduleObj.Dependencies.Count() {
                    #dim dep As %IPM.Storage.ModuleReference
                    set dep = moduleObj.Dependencies.GetAt(i)
                    set depModulePath = modulePath

                    // Skip out-of-scope dependencies
                    if '..HasScope(pPhases, dep.Scope) {
                        continue
                    } elseif (dep.Scope '= "") && ($listlength(modulePath) <= 1) {
                        set depModulePath = ""
                    }

                    // Check for cycles
                    if $listfind(depModulePath, dep.Name) {
                        set msg = $$$FormatText("Cyclic dependency detected in module '%1': %2",modName,$listtostring(depModulePath_$listbuild(dep.Name)," -> "))
                        $$$ThrowStatus($$$ERROR($$$GeneralError,msg))
                    }

                    // Classify as exact or fuzzy - store dependency index, module name, module path
                    set isExactVersion = +##class(%IPM.General.SemanticVersion).IsValid(dep.VersionString)
                    kill %objlasterror

                    if isExactVersion {
                        set exactDeps($increment(exactDeps)) = $listbuild(i, depModulePath)
                    } else {
                        set fuzzyDeps($increment(fuzzyDeps)) = $listbuild(i, depModulePath)
                    }
                }

                // This is how this module will be referenced in the dep graph
                set moduleReferenceInGraph = moduleObj.Name _ " " _ moduleObj.VersionString

                // Process exact dependencies (fail-fast)
                set idx = ""
                for {
                    set idx = $order(exactDeps(idx), 1, depData)
                    quit:idx=""

                    set $listbuild(depIndex, depModulePath) = depData
                    set dep = moduleObj.Dependencies.GetAt(depIndex)
                    set sc = ..ProcessSingleDependencyIterative(1 /* Exact */,
                        // Local parameters
                        dep, depModulePath, currentDepth, knownDependencies, phases, moduleReferenceInGraph,
                        // External parameters
                        pForceSnapshotReload, pIgnoreInstalledModules, pPermitDowngrade,
                        // Working data
                        .pDependencyGraph, .workQueue,
                        // Caches
                        .repoSearchCache, .manifestCache, .moduleCache)
                    $$$ThrowOnError(sc)
                }

                // Process fuzzy dependencies (with backtracking)
                set idx = ""
                for {
                    set idx = $order(fuzzyDeps(idx), 1, depData)
                    quit:idx=""

                    set $listbuild(depIndex, depModulePath) = depData
                    set dep = moduleObj.Dependencies.GetAt(depIndex)
                    set sc = ..ProcessSingleDependencyIterative(0 /* Fuzzy */,
                        // Local parameters
                        dep, depModulePath, currentDepth, knownDependencies, phases, moduleReferenceInGraph,
                        // External parameters
                        pForceSnapshotReload, pIgnoreInstalledModules, pPermitDowngrade,
                        // Working data
                        .pDependencyGraph, .workQueue,
                        // Caches
                        .repoSearchCache, .manifestCache, .moduleCache)
                    // For fuzzy, continue even if one fails
                    if $$$ISERR(sc) {
                        // Error will surface later if unresolvable
                    }
                }
            }

            // Move to next depth level
            kill workQueue(currentDepth)
            set currentDepth = currentDepth + 1
        }

        // Clean up cyclic dependencies from graph
        kill pDependencyGraph(..Name)
        set depKey = ""
        for {
            set depKey = $order(pDependencyGraph(depKey))
            if (depKey = "") {
                quit
            }

            set depSource = $order(pDependencyGraph(depKey,..Name))
            if ($piece(depSource," ") = ..Name) {
                kill pDependencyGraph(depKey,depSource)
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Helper for iterative breadth-first processing. Processes a single dependency,
/// updating the dependency graph and work queue as needed.
/// <p>
/// <b>Parameters:</b><br>
/// <var>pIsExact</var> - If true, dependency has exact semantic version; else fuzzy version expression<br>
/// <var>pDep</var> - Dependency module reference object<br>
/// <var>pModulePath</var> - Path of modules leading to this dependency (for cycle detection)<br>
/// <var>pDepth</var> - Current depth in the dependency tree<br>
/// <var>pKnownDependencies</var> - Known dependencies to exclude from installed check<br>
/// <var>pPhases</var> - Lifecycle phases to execute; determines which scoped dependencies are considered<br>
/// <var>pParentInfo</var> - String identifying the parent module and version requiring this dependency<br>
/// <var>pForceSnapshotReload</var> - If true, reload cached snapshots from repositories<br>
/// <var>pIgnoreInstalledModules</var> - If true, don't use already-installed modules<br>
/// <var>pPermitDowngrade</var> - If true, allow downgrading installed modules<br>
/// <var>pDependencyGraph</var> - Working dependency graph array<br>
/// <var>pWorkQueue</var> - Working work queue array<br>
/// <var>pRepoSearchCache</var> - Cache of repository search results<br>
/// <var>pManifestCache</var> - Cache of retrieved module manifests<br>
/// <var>pModuleCache</var> - Cache of loaded module objects<br>
Method ProcessSingleDependencyIterative(
	pIsExact As %Boolean,
	pDep As %IPM.Storage.ModuleReference,
	pModulePath As %List,
	pDepth As %Integer,
	pKnownDependencies As %List,
	pPhases As %String,
	pParentInfo As %String,
	pForceSnapshotReload As %Boolean,
	pIgnoreInstalledModules As %Boolean,
	pPermitDowngrade As %Boolean,
	ByRef pDependencyGraph,
	ByRef pWorkQueue,
	ByRef pRepoSearchCache,
	ByRef pManifestCache,
	ByRef pModuleCache) As %Status [ Internal, Private ]
{
    set sc = $$$OK
    try {
        // Initialize caches and repository manager
        #dim repoManager As %IPM.Repo.Manager
        set repoManager = ##class(%IPM.Repo.Manager).%Get(.sc)
        $$$ThrowOnError(sc)

        // Build cumulative version requirement string
        #dim searchExpr As %IPM.General.SemanticVersionExpression
        set searchExpr = pDep.Version.%ConstructClone(1)
        set constraintList = $listbuild(pParentInfo_": "_pDep.VersionString)
        set sourcePath = ""
        for {
            set sourcePath = $order(pDependencyGraph(pDep.Name,sourcePath),1,otherReq)
            quit:sourcePath=""

            set sc = ##class(%IPM.General.SemanticVersionExpression).FromString(otherReq,.tExpr)
            $$$ThrowOnError(sc)
            set searchExpr = searchExpr.And(tExpr)
            set constraintList = constraintList_$listbuild(sourcePath_": "_otherReq)
        }

        if 'pIgnoreInstalledModules {
            // Apply requirements from other installed modules
            set otherDepsList = pKnownDependencies
            set existingDepKey = ""
            for {
                set existingDepKey = $order(pDependencyGraph(existingDepKey))
                if (existingDepKey = "") {
                    quit
                }
                set otherDepsList = otherDepsList_$listbuild(existingDepKey)
            }

            set sc = ##class(%IPM.Utils.Module).GetRequiredVersionExpression(
                pDep.Name,otherDepsList,.installedReqExpr,.installedConstraintList
            )
            $$$ThrowOnError(sc)
            set searchExpr = searchExpr.And(installedReqExpr)
            set constraintList = constraintList_installedConstraintList
        }

        // Check if we already have a satisfactory version
        set previousDepth = 0
        set serverName = ""
        set version = ""
        if $data(pDependencyGraph(pDep.Name),depInfo) {
            set $listbuild(previousDepth,serverName,version) = depInfo
        }

        // Check if installed version satisfies requirements
        if ('pIgnoreInstalledModules) && ..NameExists(pDep.Name) {
            set localObj = ..NameOpen(pDep.Name,,.sc)
            $$$ThrowOnError(sc)

            set installedVersionValid =
                localObj.Version.Satisfies(searchExpr) &&
                ((version = "") || (version = localObj.VersionString))
            if installedVersionValid && '(localObj.Version.IsSnapshot() && pForceSnapshotReload) {
                set pDependencyGraph(pDep.Name) = $listbuild(pDepth,"",localObj.VersionString,pDep.DisplayName)
                set pDependencyGraph(pDep.Name,pParentInfo) = pDep.VersionString

                // Add to work queue for next depth
                set pWorkQueue(pDepth + 1, pDep.Name) = $listbuild(pModulePath_$listbuild(pDep.Name), pDep.Scope)
                set pModuleCache(pDep.Name) = localObj
                // Success
                quit
            }

            if 'pPermitDowngrade {
                set rangeString = ">="_localObj.VersionString
                set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(rangeString,.currentlyInstalledExpr)
                $$$ThrowOnError(tSC)
                set searchExpr = searchExpr.And(currentlyInstalledExpr)
                set constraintList = constraintList_$listbuild(localObj.Name_": "_rangeString_" (currently installed, downgrade not permitted)")
            }
        }

        // Repository search with caching
        set searchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
        set searchCriteria.Name = pDep.Name
        set searchExprStr = searchExpr.ToResolvedString()
        set searchCriteria.VersionExpression = searchExprStr

        if '$data(pRepoSearchCache(pDep.Name, searchExprStr), qualifiedReferences) {
            // Cache miss so search
            set sc = repoManager.SearchRepositoriesForModule(searchCriteria,.qualifiedReferences,pForceSnapshotReload)
            $$$ThrowOnError(sc)
            set pRepoSearchCache(pDep.Name, searchExprStr) = qualifiedReferences
        }

        if (qualifiedReferences.Count() = 0) {
            set msg = $$$FormatText("Could not find satisfactory version of %1 in any repositories. Required by: %2",pDep.Name,$listtostring(constraintList,"; "))
            $$$ThrowStatus($$$ERROR($$$GeneralError,msg))
        }

        // Process based on exact vs fuzzy
        if pIsExact {
            // EXACT: Take first match
            #dim qualifiedReference As %IPM.Storage.QualifiedModuleInfo
            set qualifiedReference = qualifiedReferences.GetAt(1)

            // Retrieve and cache manifest
            set manifestKey = qualifiedReference.ServerName_"^"_qualifiedReference.Name_"^"_qualifiedReference.VersionString
            if '$data(pManifestCache(manifestKey), moduleObj) {
                // Cache miss so retrieve
                set sc = repoManager.RetrieveModuleManifest(qualifiedReference,.manifest)
                $$$ThrowOnError(sc)

                #dim moduleObj As %IPM.Storage.Module
                set moduleObj = ##class(%IPM.Utils.Module).GetModuleObjectFromStream(manifest,.found)
                if 'found {
                    $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Failed to construct module object for %1 %2 from repository %3",qualifiedReference.Name,qualifiedReference.VersionString,qualifiedReference.ServerName)))
                }
                set pManifestCache(manifestKey) = moduleObj
            }

            set pDependencyGraph(pDep.Name) = $listbuild(
                pDepth, qualifiedReference.ServerName, moduleObj.VersionString, qualifiedReference.Deployed, qualifiedReference.PlatformVersion,pDep.DisplayName
            )
            set pDependencyGraph(pDep.Name,pParentInfo) = pDep.VersionString

            // Add to work queue for processing at next depth
            set pWorkQueue(pDepth + 1, pDep.Name) = $listbuild(pModulePath_$listbuild(pDep.Name), pDep.Scope)
            set pModuleCache(pDep.Name) = moduleObj
        } else {
            // FUZZY: Try candidates with backtracking
            set resultFound = 0
            for j=1:1:qualifiedReferences.Count() {
                kill dependencyGraph
                merge dependencyGraph = pDependencyGraph
                set qualifiedReference = qualifiedReferences.GetAt(j)

                // Retrieve and cache manifest
                set manifestKey = qualifiedReference.ServerName_"^"_qualifiedReference.Name_"^"_qualifiedReference.VersionString
                if '$data(pManifestCache(manifestKey), moduleObj) {
                    // Cache miss so retrieve
                    set tSC = repoManager.RetrieveModuleManifest(qualifiedReference,.manifest)
                    if $$$ISERR(tSC) {
                        quit
                    }

                    set moduleObj = ##class(%IPM.Utils.Module).GetModuleObjectFromStream(manifest,.found)
                    if 'found {
                        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Failed to construct module object for %1 %2 from repository %3",qualifiedReference.Name,qualifiedReference.VersionString,qualifiedReference.ServerName)))
                    }
                    set pManifestCache(manifestKey) = moduleObj
                }

                // During fuzzy matching, we need to use the higher depth to ensure further processing
                // occurs if needed.
                set depth = $select(previousDepth=0:pDepth,previousDepth>pDepth:previousDepth,1:pDepth)
                set dependencyGraph(pDep.Name) = $listbuild(
                    depth,qualifiedReference.ServerName,moduleObj.VersionString,pDep.DisplayName
                )
                set dependencyGraph(pDep.Name,pParentInfo) = pDep.VersionString

                // For fuzzy: quick validation check without full recursion
                // Just verify the module's immediate dependencies don't conflict
                set validCandidate = 1
                for k=1:1:moduleObj.Dependencies.Count() {
                    #dim subDep As %IPM.Storage.ModuleReference
                    set subDep = moduleObj.Dependencies.GetAt(k)

                    // Check if this dependency conflicts with what we already have
                    if $data(dependencyGraph(subDep.Name), existingInfo) {
                        set existingVersion = $listget(existingInfo, 3)
                        if (existingVersion '= "") {
                            // Quick version compatibility check
                            set subVer = ##class(%IPM.General.SemanticVersion).FromString(existingVersion)
                            if '$isobject(subVer) || 'subVer.Satisfies(subDep.Version) {
                                set validCandidate = 0
                                quit
                            }
                        }
                    }
                }

                if validCandidate {
                    // Accept this candidate
                    merge pDependencyGraph = dependencyGraph
                    set pWorkQueue(pDepth + 1, pDep.Name) = $listbuild(pModulePath_$listbuild(pDep.Name), pDep.Scope)
                    set pModuleCache(pDep.Name) = moduleObj
                    set resultFound = 1
                    quit
                }
            }

            // If no candidate worked, use last one and let errors surface later
            if 'resultFound {
                merge pDependencyGraph = dependencyGraph
                set pWorkQueue(pDepth + 1, pDep.Name) = $listbuild(pModulePath_$listbuild(pDep.Name), pDep.Scope)
                set pModuleCache(pDep.Name) = moduleObj
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Retrieves all known dependencies for a module, including transitive dependencies.
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
/// @Argument	pDependencyGraph 	Tree of module's dependencies.<br />
Method GetResolvedReferences(
	Output pReferenceArray,
	pLockedDependencies As %Boolean = 0,
	pPhases As %List = "",
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
                set tSC = tModule.GetResolvedReferences(.pReferenceArray,0)
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
                    if $$$ISERR(tSC) {
                        quit
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
    quit '..DeveloperMode
}

Method Lock() As %Status
{
    if '..IsLocked() {
        set ..DeveloperMode = 0
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
<Value name="29">
<Value>UpdatePackage</Value>
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
