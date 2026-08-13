Include %syPrompt

/// Database packaging lifecycle. Packages a module as an IRIS.DAT file inside a .tgz.
/// The .tgz contains IRIS.DAT, an enriched module.xml with SHA-256 checksum,
/// and a deps/ directory containing one manifest per dependency.
Class %IPM.Lifecycle.Database Extends %IPM.Lifecycle.Base
{

/// Binary stream holding the packaged .tgz file for the Publish phase.
Property Payload As %Stream.TmpBinary [ Private ];

Parameter PACKAGING As STRING [ Final ] = "database";

// =====================================================================
// Lifecycle overrides
// =====================================================================

/// Entry point for database packaging. Orchestrates the full pipeline:
/// 1. Validate IPM is externally mapped (not in routines DB) and routines DB is not mirrored
/// 2. Create a temp IRIS.DAT (or use the current DB with -use-current-db) and export Generated
///    resources from the source namespace (they become inaccessible after dismount)
/// 3. Remap the namespace routines to the temp DB
/// 4. Load and compile this module's resources plus all transitive dependencies into the temp DB
/// 5. Restore the namespace to its original routines DB
/// 6. Assemble staging dir (IRIS.DAT + module.xml with the staged IRIS.DAT's SHA-256 checksum
///    + deps/ manifests + non-compiled resources) and create the .tgz archive
///
/// On error during remap, a safety net restores the namespace.
/// Temp files and directories are cleaned up in all paths.
Method %Package(ByRef params) As %Status
{
    set sc = $$$OK
    set tempDBName = ""
    set tempDBPath = ""
    set oldDBName = ""
    set stagingDir = ""
    set dbRemapped = 0
    set generatedExports = ""
    set ns = $namespace
    new $namespace

    try {
        set verbose = $get(params("Verbose"))
        set includeTests = $get(params("DeveloperMode"), 0)
        set useCurrentDB = $get(params("UseCurrentDB"), 0)
        set dbName = $get(params("DatabaseName"), "")

        write:verbose !, "Starting database packaging: ", ..Module.Name, " v", ..Module.VersionString

        write:verbose !, "Validating IPM mapping..."
        do ..ValidateIPMNotInRoutinesDB()
        do ..ValidateRoutinesDatabaseNotMirrored(ns)

        do ..WarnUnrunnableInvokes()
        do ..WarnMappingsNotApplied()

        if useCurrentDB {
            set curDBName = ..GetRoutinesDBName(ns)
            set tempDBPath = ..GetDatabaseDirectory(curDBName)
        } else {
            write:verbose !, "Creating temporary database..."
            do ..CreateTempDatabase(.dbName, .tempDBPath)
            set tempDBName = dbName

            // Export Generated resources from source namespace BEFORE remapping.
            // Once the old DB is dismounted, compiled Generated classes are inaccessible.
            write:verbose !, "Exporting generated resources from source namespace..."
            do ..ExportGeneratedResources(includeTests, .generatedExports)

            write:verbose !, "Remapping namespace routines to temp database..."
            set dbRemapped = 1
            do ..RemapRoutinesDB(ns, tempDBName, .oldDBName)

            write:verbose !, "Loading resources into temp database..."
            do ..LoadResourcesIntoDatabase(ns, includeTests, .params)

            if $listlength(generatedExports) > 0 {
                write:verbose !, "Importing generated resources into temp database..."
                set ptr = 0
                while $listnext(generatedExports, ptr, tempFile) {
                    $$$ThrowOnError($system.OBJ.Load(tempFile, "ck"))
                    do ##class(%Library.File).Delete(tempFile)
                }
                set generatedExports = ""
            }

            write:verbose !, "Restoring namespace routines..."
            do ..RestoreRoutinesDB(ns, oldDBName, tempDBName, tempDBPath)
            set dbRemapped = 0
        }

        set irisDAT = tempDBPath _ "IRIS.DAT"

        if $get(params("ExportPythonDependencies"), 1) {
            do ..ExportPythonDependencies(..Module, .params)
        }

        // Assemble staging dir and create .tgz
        set stagingDir = ##class(%Library.File).NormalizeDirectory(##class(%IPM.Utils.File).CreateTempDirectory() _ "stage")
        set packageFile = ..AssemblePackage(irisDAT, stagingDir, .params, 'useCurrentDB)
        set params("PackageFile") = packageFile

        // Store in Payload for the Publish phase
        set srcStream = ##class(%Stream.FileBinary).%New()
        $$$ThrowOnError(srcStream.LinkToFile(packageFile))
        $$$ThrowOnError(..Payload.CopyFrom(srcStream))

    } catch ex {
        set sc = ex.AsStatus()
    }

    // Safety net: restore namespace if an error occurred mid-remap
    if dbRemapped && (oldDBName '= "") {
        set restoreSC = $$$OK
        try {
            do ..RestoreRoutinesDB(ns, oldDBName, tempDBName, tempDBPath)
        } catch restoreEx {
            set restoreSC = restoreEx.AsStatus()
        }
        if $$$ISERR(restoreSC) {
            write !, "ERROR: Failed to restore namespace routines DB — manual intervention required."
            write !, $system.Status.GetErrorText(restoreSC)
        }
    }

    // Clean up any generated resource export temp files not yet imported (error path)
    set ptr = 0
    while $listnext(generatedExports, ptr, tempFile) {
        if ##class(%Library.File).Exists(tempFile) {
            do ##class(%Library.File).Delete(tempFile)
        }
    }

    // Clean up staging directory
    if (stagingDir '= "") && ##class(%Library.File).DirectoryExists(stagingDir) {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(stagingDir)
    }

    // Clean up temp DB directory (IRIS.DAT was moved to staging by AssemblePackage — only the empty dir remains;
    // for -use-current-db, IRIS.DAT was copied not moved, so it still exists here but tempDBName="" skips this block)
    if (tempDBName '= "") && (tempDBPath '= "") && ##class(%Library.File).DirectoryExists(tempDBPath) {
        set $namespace = "%SYS"
        do ##class(%Library.File).RemoveDirectoryTree(tempDBPath)
    }

    quit sc
}

/// Dispatches to one of four contexts: installing a package, loading resources while building one,
/// the no-op Reload that precedes Package, or an ordinary source load. A package directory whose
/// IRIS.DAT a completed swap already moved away is refused rather than dispatched.
/// All install work happens here so %Validate, %Compile, and %Activate stay no-ops, and invokes
/// from "Reload.After" onward fire against the mounted database.
Method %Reload(ByRef params) As %Status
{
    if ..IsInstallContext() {
        quit ..DoDatabaseInstall(.params)
    }
    if $get(params("DatabasePackaging")) {
        quit ..LoadResourcesForPackaging(.params)
    }
    // Packaging phase chain on the source module (e.g. the Reload phase that precedes Package
    // during `package-database <name>`) has no source root to load from. %Package loads resources
    // into the temp DB itself, so this phase is a no-op. We must NOT delegate to ##super here:
    // Base.%Reload treats DeveloperMode as a signal to load from ..Module.Root even when no
    // RootDirectory is passed, which would reload source into the current namespace and mutate
    // it mid-package.
    if '$data(params("RootDirectory")) {
        quit $$$OK
    }
    // A packaged manifest with no IRIS.DAT beside it is what an install that already swapped leaves
    // behind: PerformDatabaseSwap moves IRIS.DAT into the database directory rather than copying it.
    // Loading as source from here would compile source into the swapped-in database, which is meant
    // to be sealed and is described by the checksum in its own manifest.
    if ..IsPackagedManifest(params("RootDirectory")) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "This directory holds a database package whose IRIS.DAT is no longer present (" _ params("RootDirectory") _ "). The swap that has already run moved it into the database directory. Re-run the install from the original .tgz rather than from this directory."))
    }
    // Loading a database-packaged module from a source directory (RootDirectory set) behaves
    // like a normal source load so delegate to Base.
    quit ##super(.params)
}

/// Validate, swap the DB, register metadata, and run post-swap steps.
/// Injects IsInstallContext into params before the swap so downstream phases can check it without
/// re-examining the filesystem. Rollback is performed only on swap-mechanics failures; post-swap
/// failures are reported forward because the swap is the state to keep.
Method DoDatabaseInstall(ByRef params) As %Status [ Private ]
{
    set params("IsInstallContext") = 1
    set sc = $$$OK
    set dbDir = ""
    set backupPath = ""
    set swapCompleted = 0
    set staleModules = ""
    try {
        if $get(params("DeveloperMode")) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Database packages cannot be installed in developer mode."))
        }

        set ns = $namespace
        set packageDir = ..Module.Root

        do ..ValidateBeforeSwap(packageDir, .params, .staleModules)

        if '$get(params("SwapDB")) {
            do ..PromptForSwapConfirmation(ns, staleModules)
        }

        // Runs before the swap, while these modules' code is still mounted: undoes the part of
        // their installation the swap cannot reach (web apps, copied files, installer classes).
        do ..UnconfigureStaleModules(staleModules, .params)

        do ..PerformDatabaseSwap(packageDir, ns, .dbDir, .backupPath)
        // Past this point the swap is the state to keep, not to undo: a rollback would discard a
        // good swap and could not reverse the side effects of the steps that follow.
        set swapCompleted = 1

        do ##class(%IPM.Lifecycle.Database).RegisterDependencyMetadata(packageDir)

        // Dependencies get their phases here rather than in a chain of their own: at this point the
        // swap has landed, so their compiled code is mounted and their staged files are reachable.
        do ..ApplyDependencyResources(packageDir, .params, .depInitClasses)
        do ..ReassertRootInitializeResources(.depInitClasses, .params)

        // Only once the swap and metadata registration have both succeeded: the code behind these
        // modules is gone, so their records would otherwise linger in 'list' with nothing behind
        // them. Doing this earlier would leave the metadata deleted if a rollback restored the code.
        do ..RemoveStaleModuleMetadata(staleModules)

        // Seed all update steps as already-run on a fresh install so a subsequent 'update'
        // only executes steps introduced after this version. Same logic as Module.cls:%Activate.
        // Skipped when params("Update") is set since we're actually running an update, not a fresh install.
        if '$get(params("Update")) {
            $$$ThrowOnError(..Module.HandleAllUpdateSteps(, 1, $get(params("Verbose"))))
        }

        write !, "Database swap complete for namespace ", ns
        write !, "  Backup: ", backupPath

    } catch ex {
        set sc = ex.AsStatus()
        if swapCompleted {
            do ..ReportPostSwapFailure(sc, $get(ns, $namespace), backupPath)
        } elseif dbDir '= "" {
            write !, "ERROR: encountered an error: ", $system.Status.GetErrorText(sc)
            write !, "Attempting to roll back system state..."
            do ..RollbackDatabaseSwap(dbDir, backupPath)
            write !, "Finished rollback attempt. Please verify whether namespace state is as expected prior to performing the DB swap."
            if staleModules '= "" {
                write !, "WARNING: the rollback restored the previous IRIS.DAT, but it cannot restore what was already"
                write !, "  unconfigured before the swap. These modules had their web applications, copied files and"
                write !, "  installer-class effects removed and are now only partially installed: ", $listtostring(staleModules, ", ")
                write !, "  Reinstall them to return the namespace to a working state."
            }
        }
    }
    quit sc
}

/// Loads this module's resources plus all transitive dependencies into the current (temp) DB.
/// Cannot delegate to ##super: Base.%Reload applies package/routine mappings from module.xml,
/// which are inappropriate for a fresh isolated DB. If Base.%Reload gains new loading logic,
/// this branch must be updated to match.
Method LoadResourcesForPackaging(ByRef params) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        // Load this module's own resources followed by all transitive dependencies.
        // The resulting IRIS.DAT must be self-contained. Dependency code must be compiled in
        // because at install time only IPM metadata is registered from deps/ manifests.
        set modulesToLoad = ..GetSelfAndDependencyModules()

        set mKey = ""
        for {
            #dim loadModule As %IPM.Storage.Module
            set loadModule = modulesToLoad.GetNext(.mKey)
            quit:mKey=""

            set orderedResourceList = loadModule.GetOrderedResourceList()
            set key = ""
            for {
                #dim resource As %IPM.Storage.ResourceReference
                set resource = orderedResourceList.GetNext(.key)
                quit:key=""

                // Type A: regular resources with Scope="test" or Scope="verify" — skip unless in dev mode
                if '$get(params("DeveloperMode")) && resource.IsTestScoped() {
                    continue
                }

                // Type B: <UnitTest> parent resources have Scope="" and a Test processor.
                // OnPhase("Reload") is a no-op for this processor; loading is done via LoadTestDirectory.
                if $isobject(resource.Processor) && resource.Processor.%IsA("%IPM.ResourceProcessor.Test") && ($extract(resource.Name, *) = "/") {
                    if $get(params("DeveloperMode")) {
                        set testDir = ##class(%Library.File).NormalizeDirectory(resource.Module.Root _ resource.Name)
                        set format = resource.Processor.Format
                        set loadSC = ##class(%IPM.Test.Manager).LoadTestDirectory(testDir, $get(params("Verbose")), , format)
                        $$$ThrowOnError(loadSC)
                    }
                    continue
                }

                if $isobject(resource.Processor) {
                    set reloadPhase = $select(resource.Scope '= "": resource.Scope, 1: "Reload")
                    $$$ThrowOnError(resource.Processor.OnPhase(reloadPhase, .params))
                }
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

/// During a database package install, there is no source to validate.
/// In all other contexts, delegate to ##super.
Method %Validate(ByRef pParams) As %Status
{
    if $get(pParams("IsInstallContext")) {
        quit $$$OK
    }
    quit ##super(.pParams)
}

/// During a database package install, there is no source to compile.
/// During database packaging, compile all transitive dependencies into the temp DB
/// before this module's own resources. %Reload loaded the dependency source but
/// Base.%Compile only handles this module's resources, so dependency code would
/// otherwise never be compiled into the self-contained IRIS.DAT.
/// In all other contexts, delegate to ##super.
Method %Compile(ByRef pParams) As %Status
{
    if $get(pParams("IsInstallContext")) {
        quit $$$OK
    }
    set sc = $$$OK
    try {
        if $get(pParams("DatabasePackaging")) {
            // Compile each dependency via its own lifecycle (which compiles that module's
            // resources). Definitions for all dependencies are already loaded by %Reload, so
            // the class compiler resolves cross-module compile order regardless of iteration order.
            // Strip DatabasePackaging from the params passed down so a Database-lifecycle dependency
            // does not re-enter this branch and recurse; each dependency only compiles its own resources.
            merge depParams = pParams
            kill depParams("DatabasePackaging")
            set deps = ..GetDependencyModules(..Module)
            set mKey = ""
            for {
                #dim depModule As %IPM.Storage.Module
                set depModule = deps.GetNext(.mKey)
                quit:mKey=""
                $$$ThrowOnError(depModule.Lifecycle.%Compile(.depParams))
            }
        }
        // Compile this module's own resources.
        set sc = ##super(.pParams)
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

/// During a database package install, the DB swap and all setup already completed in %Reload.
/// In all other contexts, delegate to ##super.
Method %Activate(ByRef params) As %Status
{
    if $get(params("IsInstallContext")) {
        quit $$$OK
    }
    quit ##super(.params)
}

// =====================================================================
// Packaging helpers
// =====================================================================

/// Warns that <Mapping> elements are not applied by a database install.
/// Mappings are applied by Base.%Reload, which this path does not run. Applying them here instead
/// deadlocks against a <CPF> merge: the config locks Config.Map* takes are held until the install's
/// transaction commits, and the merge shells out to 'iris merge', which cannot wait that out.
/// Source installs are unaffected — they merge at Initialize, before mappings apply at Reload.
Method WarnMappingsNotApplied()
{
    set modules = ..GetSelfAndDependencyModules()

    set mKey = ""
    for {
        #dim module As %IPM.Storage.Module
        set module = modules.GetNext(.mKey)
        quit:mKey=""
        continue:'module.Mappings.Count()

        set isRoot = (module.Name = ..Module.Name)
        write !, "WARNING: ", module.Mappings.Count(), " <Mapping> element(s) in "
        write $select(isRoot: "this module", 1: "dependency '" _ module.Name _ "'")
        write " will not be applied during database install."
        write !, "  Globals, packages and routines these map from another database will resolve locally instead."
        write !, "  Apply them manually after install, or install this module from source."
    }
}

/// Warns about <Invoke> elements that no phase of a database install will reach.
/// Root: the DB swap runs inside %Reload, so anything before it (the whole Initialize phase and
/// Reload.Before) runs while the old database is still mounted and cannot see the packaged code.
/// Dependencies: phases in GetDependencyExcludedPhases never run for them, so an invoke on one of
/// those phases is unreachable in both When positions.
/// Custom phases are excluded as they are on-demand operations, never part of a standard install.
Method WarnUnrunnableInvokes()
{
    set modules = ..GetSelfAndDependencyModules()

    set mKey = ""
    for {
        #dim module As %IPM.Storage.Module
        set module = modules.GetNext(.mKey)
        quit:mKey=""

        set isRoot = (module.Name = ..Module.Name)
        set key = ""
        for {
            #dim invoke As %IPM.Storage.InvokeReference
            set invoke = module.Invokes.GetNext(.key)
            quit:(key = "")
            if invoke.CustomPhase '= "" {
                continue
            }

            set unreachable = 0
            if isRoot {
                set unreachable = (invoke.Phase = "Initialize") || ((invoke.Phase = "Reload") && (invoke.When = "Before"))
            } else {
                // Same source of truth as the dependency pass, so the two cannot drift apart.
                set unreachable = $listfind(..GetDependencyExcludedPhases(), invoke.Phase) > 0
            }
            if 'unreachable {
                continue
            }

            write !, "WARNING: <Invoke Class="""_invoke.Class_""" Method="""_invoke.Method_""" Phase="""_invoke.Phase_""" When="""_invoke.When_""">"
            write " in ", $select(isRoot: "this module", 1: "dependency '" _ module.Name _ "'"), " will not run during database install."
            if isRoot {
                write !, "  The DB swap runs inside %Reload, so Initialize and Reload.Before both fire before the packaged DB is mounted."
                write !, "  Use Phase=""Reload"" When=""After"" or a later phase for install-time setup."
            } else {
                // An update install runs one extra phase per dependency, so name both sets.
                write !, "  Dependencies run ", $listtostring(..GetDependencyInstallPhases(0), ", "), " after the swap"
                write !, "  (plus ApplyUpdateSteps when the install is an update); their code is already compiled into IRIS.DAT."
                write !, "  Use one of those phases for install-time setup in a dependency."
            }
        }
    }
}

/// Throws if IPM classes are in the local routines database. IPM must be mapped so it survives the swap.
ClassMethod ValidateIPMNotInRoutinesDB()
{
    if ##class(%Dictionary.ClassDefinition).%ExistsId("%IPM.Main") && '##class(%Library.RoutineMgr).IsMapped("%IPM.Main.CLS") {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"IPM must be mapped from another namespace. %IPM classes were found in the current routines database. Map IPM from a non-system code namespace before packaging."))
    }
}

/// Throws if the namespace's routines DB is mirrored. Dismounting a mirrored DB breaks the mirror.
ClassMethod ValidateRoutinesDatabaseNotMirrored(ns As %String)
{
    new $namespace
    set $namespace = "%SYS"
    set dbName = ..GetRoutinesDBName(ns)
    set dbDir = ..GetDatabaseDirectory(dbName)
    set db = ##class(SYS.Database).%OpenId(dbDir, , .sc)
    $$$ThrowOnError(sc)
    if db.Mirrored {
        set msg = "Database packaging is not currently supported for mirrored databases (namespace: " _ ns _ ", database: " _ dbName _ ")."
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
}

/// Throws if any other namespace uses the same routines database. The swap replaces the IRIS.DAT
/// behind that database, so every namespace pointing at it silently gets the packaged code too.
/// Matches on directory rather than database name: two Config.Databases entries can name the same
/// directory, and only the directory identifies the file the swap actually replaces.
ClassMethod ValidateRoutinesDatabaseNotShared(ns As %String)
{
    set dbDir = ..GetDatabaseDirectory(..GetRoutinesDBName(ns))
    new $namespace
    set $namespace = "%SYS"

    set dbResult = ##class(%SQL.Statement).%ExecDirect(, "select Name, Server, Directory from Config.Databases_List()")
    if dbResult.%SQLCODE < 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error listing configured databases: " _ dbResult.%Message))
    }
    while dbResult.%Next(.sc) {
        $$$ThrowOnError(sc)
        // Remote databases are distinct files even when the path matches.
        continue:dbResult.Server'=""
        if ##class(%Library.File).NormalizeDirectory(dbResult.Directory) = dbDir {
            set sameDir($zconvert(dbResult.Name, "U")) = ""
        }
    }
    $$$ThrowOnError(sc)

    set sharing = ""
    set nsResult = ##class(%SQL.Statement).%ExecDirect(, "select Namespace, Routines from Config.Namespaces_List()")
    if nsResult.%SQLCODE < 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error listing configured namespaces: " _ nsResult.%Message))
    }
    while nsResult.%Next(.sc) {
        $$$ThrowOnError(sc)
        continue:$zconvert(nsResult.Namespace,"U")=$zconvert(ns,"U")
        if $data(sameDir($zconvert(nsResult.Routines, "U"))) {
            set sharing = sharing _ $listbuild(nsResult.Namespace)
        }
    }
    $$$ThrowOnError(sc)

    if sharing '= "" {
        set msg = "The routines database of namespace " _ ns _ " (" _ dbDir _ ") is also the routines database of: " _ $listtostring(sharing, ", ") _ ". Swapping it would replace the code of those namespaces as well. Give " _ ns _ " a routines database of its own before installing a database package."
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
}

/// Creates an empty IRIS.DAT, registers it in Config.Databases, and mounts it.
/// dbName is auto-generated if empty. dbPath (output): directory path containing IRIS.DAT.
ClassMethod CreateTempDatabase(
	ByRef dbName As %String,
	Output dbPath As %String)
{
    new $namespace
    set $namespace = "%SYS"

    if dbName = "" {
        set dbName = "IPMDBPKG" _ $translate(
            $system.Encryption.Base64Encode($system.Encryption.GenCryptRand(6)), "+/=", "")
    }

    set dbPath = ..GetDatabaseDirectory(dbName)

    if '##class(%Library.File).CreateDirectory(dbPath, .result) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to create temp database directory: " _ dbPath _ " - " _ result))
    }

    $$$ThrowOnError(##class(SYS.Database).CreateDatabase(dbPath))

    set dbProps("Directory") = dbPath
    set dbProps("MountRequired") = 0
    $$$ThrowOnError(##class(Config.Databases).Create(dbName, .dbProps))

    set mountSC = ##class(SYS.Database).MountDatabase(dbPath)
    if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
        $$$ThrowOnError(mountSC)
    }
}

/// Exports each Generated resource of this module and its transitive dependencies from the source
/// namespace to a temp XML file for later import.
/// Must run before RemapRoutinesDB: once the old DB is dismounted the compiled classes are gone.
///
/// Carries Generated resources that no lifecycle phase recreates, e.g. classes built by external
/// tools. Resources that packaging does regenerate are exported too; re-importing them is
/// redundant but harmless.
/// includeTestResources: if 1, test- and verify-scoped resources are also exported.
/// generatedExports (output): $list of temp XML file paths, one per exported class.
Method ExportGeneratedResources(
	includeTestResources As %Boolean,
	Output generatedExports As %List) [ Private ]
{
    set generatedExports = ""

    // Dependency resources are compiled into the same IRIS.DAT, so their Generated resources must
    // be carried over as well.
    set modules = ..GetSelfAndDependencyModules()

    set mKey = ""
    for {
        #dim module As %IPM.Storage.Module
        set module = modules.GetNext(.mKey)
        quit:mKey=""

        set orderedList = module.GetOrderedResourceList()
        set rKey = ""
        for {
            #dim resource As %IPM.Storage.ResourceReference
            set resource = orderedList.GetNext(.rKey)
            quit:rKey=""

            if 'includeTestResources && resource.IsTestScoped() {
                continue
            }

            if 'resource.Generated {
                continue
            }

            set tempFile = ##class(%Library.File).TempFilename("xml")
            set exportSC = $system.OBJ.Export(resource.Name, tempFile, "-d")
            if $$$ISERR(exportSC) {
                do ##class(%IPM.General.LogManager).Warning("Generated resource '" _ resource.Name _ "' could not be exported and will be missing from this package: " _ $system.Status.GetErrorText(exportSC))
            } elseif ##class(%Library.File).GetFileSize(tempFile) > 0 {
                set generatedExports = generatedExports _ $listbuild(tempFile)
                continue
            }
            // Nothing usable was written: an empty export means the resource matched no compiled
            // classes, which is expected for resources this namespace never generated.
            if ##class(%Library.File).Exists(tempFile) {
                do ##class(%Library.File).Delete(tempFile)
            }
        }
    }
}

/// Remaps the namespace's routines to newDBName, then dismounts the old one.
/// oldDBName (output): previous routines DB name for later restoration.
ClassMethod RemapRoutinesDB(
	ns As %String,
	newDBName As %String,
	Output oldDBName As %String)
{
    new $namespace
    set $namespace = "%SYS"

    $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
    set oldDBName = $get(nsProps("Routines"))

    set oldPath = ..GetDatabaseDirectory(oldDBName)

    // Remap before dismounting so the namespace never briefly has no routines DB
    set nsProps("Routines") = newDBName
    $$$ThrowOnError(##class(Config.Namespaces).Modify(ns, .nsProps))
    $$$ThrowOnError(##class(SYS.Database).DismountDatabase(oldPath))
}

/// Restores the namespace routines to oldDBName and dismounts the temp DB.
/// Logs warnings on partial failures but always attempts full restoration.
ClassMethod RestoreRoutinesDB(
	ns As %String,
	oldDBName As %String,
	tempDBName As %String,
	tempDBPath As %String)
{
    new $namespace
    set $namespace = "%SYS"

    set dismountSC = ##class(SYS.Database).DismountDatabase(tempDBPath)
    if $$$ISERR(dismountSC) {
        write !, "WARNING: failed to dismount temp DB: ", $system.Status.GetErrorText(dismountSC)
    }

    // Remap namespace back to original DB
    $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
    set nsProps("Routines") = oldDBName
    $$$ThrowOnError(##class(Config.Namespaces).Modify(ns, .nsProps))

    // Remount original DB
    set mountSC = ##class(SYS.Database).MountDatabase(..GetDatabaseDirectory(oldDBName))
    if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
        $$$ThrowOnError(mountSC)
    }

    // Remove temp DB config entry only — caller cleans up the directory
    // after it is done reading IRIS.DAT (e.g. after AssemblePackage).
    if ##class(Config.Databases).Exists(tempDBName) {
        $$$ThrowOnError(##class(Config.Databases).Delete(tempDBName))
    }
}

/// Runs %Reload and %Compile in ns (which maps to the temp DB) to load and compile resources into it.
Method LoadResourcesIntoDatabase(
	ns As %String,
	includeTestResources As %Boolean,
	ByRef params)
{
    new $namespace
    set $namespace = ns

    set loadParams("Verbose") = $get(params("Verbose"))
    set loadParams("DatabasePackaging") = 1
    set loadParams("DeveloperMode") = includeTestResources

    $$$ThrowOnError(..%Reload(.loadParams))
    $$$ThrowOnError(..%Compile(.loadParams))
}

/// Computes the SHA-256 hash of a file and returns it as a lowercase hex string (64 chars).
ClassMethod ComputeSHA256Hex(filePath As %String) As %String
{
    set stream = ##class(%Stream.FileBinary).%New()
    $$$ThrowOnError(stream.LinkToFile(filePath))

    set binHash = ##class(%SYSTEM.Encryption).SHAHashStream(256, stream, .sc)
    $$$ThrowOnError(sc)

    // %xsd.hexBinary.LogicalToXSD returns uppercase hex; lowercase to match the on-disk convention.
    quit $zconvert(##class(%xsd.hexBinary).LogicalToXSD(binHash), "L")
}

/// Assembles staging dir and creates the final .tgz. Returns path to .tgz.
/// moveFile=0 copies IRIS.DAT instead of renaming; required for -use-current-db.
Method AssemblePackage(
	irisDAT As %String,
	stagingDir As %String,
	ByRef params,
	moveFile As %Boolean = 1) As %String
{
    if '##class(%Library.File).CreateDirectoryChain(stagingDir, .result) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot create staging dir: " _ result))
    }

    if moveFile {
        // Move IRIS.DAT into staging avoids copying potentially multi-GB files.
        // Safe because the temp DB is already dismounted before AssemblePackage runs.
        if '##class(%Library.File).Rename(irisDAT, stagingDir _ "IRIS.DAT") {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot move IRIS.DAT to staging dir"))
        }
    } else {
        // -use-current-db: copy instead as irisDAT is the live routines DB and must not be moved
        if '##class(%Library.File).CopyFile(irisDAT, stagingDir _ "IRIS.DAT", 1, .result) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot copy IRIS.DAT: " _ result))
        }
    }

    // Checksum the file actually in staging — the exact bytes shipped in the .tgz.
    // Hashing here (not the source) closes a race where the live
    // routines DB could change between hashing and copying.
    write:$get(params("Verbose")) !, "Computing SHA-256 checksum..."
    set checksumHex = ..ComputeSHA256Hex(stagingDir _ "IRIS.DAT")
    write !, "  Checksum: ", checksumHex

    // Stage non-compiled resource files so processors can find them during install
    set includeTestResources = $get(params("DeveloperMode"), 0)
    set exportPythonDeps = $get(params("ExportPythonDependencies"), 1)
    do ..CopyNonCompiledResources(stagingDir, includeTestResources, exportPythonDeps)
    kill depWheels
    if exportPythonDeps {
        do ..StageDependencyWheels(stagingDir, .params, .depWheels)
    }

    // Bare "<major>.<minor>" is an exact-match semver expression, not a floor, so the package will
    // only install on the IRIS version that built it.
    set irisVersion = $system.Version.GetMajor() _ "." _ $system.Version.GetMinor()
    set existingVersion = ""
    if $isobject(..Module.SystemRequirements) {
        set existingVersion = ..Module.SystemRequirements.VersionString
    }
    if (existingVersion '= "") && (existingVersion '= irisVersion) {
        write !, "WARNING: Overwriting existing SystemRequirements Version '", existingVersion, "' with '", irisVersion, "'"
    }
    do ..WritePackageModuleXML(stagingDir, checksumHex, irisVersion)
    do ..WriteDependencies(stagingDir, .depWheels)

    set outputDir = $get(params("Path"))
    if outputDir = "" {
        set outputDir = ##class(%Library.File).NormalizeDirectory(##class(%IPM.Utils.File).CreateTempDirectory())
    } else {
        set outputDir = ##class(%Library.File).NormalizeDirectory(outputDir)
        if '##class(%Library.File).DirectoryExists(outputDir) {
            if '##class(%Library.File).CreateDirectoryChain(outputDir, .reason) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Cannot create output directory " _ outputDir _ ": " _ reason))
            }
        }
    }

    set packageFile = outputDir _ ..Module.Name _ "-" _ ..Module.VersionString _ "-database.tgz"
    $$$ThrowOnError(##class(%IPM.General.Archive).Create(stagingDir, packageFile, .archiveOutput))

    set verbose = $get(params("Verbose"))
    for i=1:1:$get(archiveOutput) {
        write:verbose !, archiveOutput(i)
    }
    write !, "Database package generated:", !, $char(9), packageFile

    quit packageFile
}

/// Returns the staging subdirectory holding one dependency's non-compiled files.
/// Becomes that dependency's Root during the install-time dependency pass.
ClassMethod GetDependencyStagingDir(
	stagingDir As %String,
	depName As %String) As %String
{
    quit ##class(%Library.File).NormalizeDirectory(stagingDir _ "deps-files/" _ depName)
}

/// Copies non-compiled resource files (FileCopy, PythonWheel, CPF) for this module and each
/// transitive dependency into stagingDir. Dependency files go under deps-files/<depname>/ so the
/// install-time dependency pass can point that dependency's Root at them.
/// The per-dependency directory is created even when empty: install always sets Root to it, and a
/// Root pointing at a nonexistent directory would resolve paths on the packaging machine instead.
/// WebApplication is configuration-only and has no file to stage.
Method CopyNonCompiledResources(
	stagingDir As %String,
	includeTestResources As %Boolean,
	exportPythonDeps As %Boolean = 1)
{
    do ..StageModuleResources(..Module, stagingDir, includeTestResources, exportPythonDeps)

    set deps = ..GetDependencyModules(..Module)
    set mKey = ""
    for {
        #dim depModule As %IPM.Storage.Module
        set depModule = deps.GetNext(.mKey)
        quit:mKey=""

        set depDir = ..GetDependencyStagingDir(stagingDir, depModule.Name)
        set result = ""
        if '##class(%Library.File).CreateDirectoryChain(depDir, .result) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot create dependency staging dir: " _ depDir _ " - " _ result))
        }
        do ..StageModuleResources(depModule, depDir, includeTestResources, exportPythonDeps)
    }
}

/// Stages one module's non-compiled resource files into targetDir, mirroring the relative layout
/// the resource processors expect under a module root.
Method StageModuleResources(
	module As %IPM.Storage.Module,
	targetDir As %String,
	includeTestResources As %Boolean,
	exportPythonDeps As %Boolean = 1)
{
    set orderedResourceList = module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""

        // Skip test-scoped resources unless requested
        if 'includeTestResources && resource.IsTestScoped() {
            continue
        }

        if '$isobject(resource.Processor) {
            continue
        }

        if resource.Processor.%IsA("%IPM.ResourceProcessor.FileCopy") {
            set name = resource.Processor.Name
            set sourcePath = ##class(%Library.File).NormalizeFilename(name, module.Root)
            set destPath = ##class(%Library.File).NormalizeFilename(name, targetDir)
            do ..StageResourceFile(resource.Name, sourcePath, destPath)

        } elseif exportPythonDeps && resource.Processor.%IsA("%IPM.ResourceProcessor.PythonWheel") {
            set wheelDir = resource.Processor.Directory
            set wheelName = resource.Processor.Name
            set sourcePath = ##class(%Library.File).NormalizeFilename(wheelName, ##class(%Library.File).NormalizeDirectory(module.Root _ wheelDir))
            set destPath = ##class(%Library.File).NormalizeDirectory(targetDir _ wheelDir) _ wheelName
            do ..StageResourceFile(resource.Name, sourcePath, destPath)

        } elseif resource.Processor.%IsA("%IPM.ResourceProcessor.CPF") {
            set cpfName = resource.Processor.Name
            set cpfSubdir = resource.Processor.Directory
            set sourcePath = ##class(%Library.File).NormalizeFilename(cpfName, ##class(%Library.File).NormalizeDirectory(module.Root _ module.SourcesRoot _ "/" _ cpfSubdir))
            set destPath = ##class(%Library.File).NormalizeDirectory(targetDir _ module.SourcesRoot _ "/" _ cpfSubdir) _ cpfName
            do ..StageResourceFile(resource.Name, sourcePath, destPath)

        }
        // Compiled resources (Class, Routine, Include, etc.) are handled via IRIS.DAT so no file staging needed.
        // WebApplication is configuration-only so no file staging needed.
    }
}

/// Downloads each dependency's requirements.txt wheels and stages them under
/// deps-files/<depname>/wheels/. Returns depWheels(depName, wheelName) = "" for each wheel that is
/// not already an explicit <PythonWheel> resource; WriteDependencies injects those into the
/// dependency's exported manifest so the install-time dependency pass installs them.
/// Injecting into the export rather than the installed .ZPM keeps the packaging machine unmodified.
Method StageDependencyWheels(
	stagingDir As %String,
	ByRef params,
	Output depWheels) [ Private ]
{
    kill depWheels

    set deps = ..GetDependencyModules(..Module)
    set mKey = ""
    for {
        #dim depModule As %IPM.Storage.Module
        set depModule = deps.GetNext(.mKey)
        quit:mKey=""

        set depRoot = ##class(%Library.File).NormalizeDirectory("", depModule.Root)
        if '##class(%Library.File).Exists(##class(%Library.File).NormalizeFilename("requirements.txt", depRoot)) {
            continue
        }

        $$$ThrowOnError(..InstallOrDownloadPythonRequirements(depRoot, .params, 1))

        set wheelsDir = ##class(%Library.File).NormalizeDirectory("wheels", depRoot)
        if '##class(%Library.File).DirectoryExists(wheelsDir) {
            write !, "WARNING: No wheels directory for dependency '", depModule.Name, "': ", wheelsDir, " not found"
            continue
        }

        // Wheels already declared as <PythonWheel> are staged by StageModuleResources; injecting
        // them again would give the dependency two resources for one file.
        kill declared
        set declaredList = depModule.GetOrderedResourceList()
        set rKey = ""
        for {
            #dim depResource As %IPM.Storage.ResourceReference
            set depResource = declaredList.GetNext(.rKey)
            quit:rKey=""
            set declared($zconvert(depResource.Name, "L")) = ""
        }

        set destWheelDir = ##class(%Library.File).NormalizeDirectory(..GetDependencyStagingDir(stagingDir, depModule.Name) _ "wheels")

        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ItemName FROM %Library.File_FileSet(?, ?, ?, ?)",
            wheelsDir, "*.whl", "", 0)
        if rs.%SQLCODE < 0 {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Error listing wheels for dependency '" _ depModule.Name _ "': " _ rs.%Message))
        }
        set sc = $$$OK
        while rs.%Next(.sc) {
            $$$ThrowOnError(sc)
            set wheelName = rs.%Get("ItemName")
            continue:wheelName=""
            do ..StageResourceFile(
                depModule.Name _ "/" _ wheelName,
                ##class(%Library.File).NormalizeFilename(wheelName, wheelsDir),
                destWheelDir _ wheelName)
            if '$data(declared($zconvert(wheelName, "L"))) {
                set depWheels(depModule.Name, wheelName) = ""
            }
        }
        $$$ThrowOnError(sc)
    }
}

/// Stages a resource's file, warning if it doesn't exist. A missing file would ship silently
/// and only surface at install time on the user's system.
ClassMethod StageResourceFile(
	resourceName As %String,
	sourcePath As %String,
	destPath As %String)
{
    if '..StageFile(sourcePath, destPath) {
        do ##class(%IPM.General.LogManager).Warning("Resource '" _ resourceName _ "' will be missing from this package: " _ sourcePath _ " not found")
    }
}

/// Copies a file to a destination path, creating parent directories as needed.
/// Throws on failure. Returns 1 if the file was copied, 0 if the source did not exist.
ClassMethod StageFile(
	sourcePath As %String,
	destPath As %String) As %Boolean
{
    if '##class(%Library.File).Exists(sourcePath) {
        quit 0
    }
    set destDir = ##class(%Library.File).GetDirectory(destPath)
    if '##class(%Library.File).CreateDirectoryChain(destDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot create directory: " _ destDir))
    }
    if '##class(%Library.File).CopyFile(sourcePath, destPath, 1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot copy file: " _ sourcePath _ " to " _ destPath))
    }
    quit 1
}

/// Exports the module manifest, applies the database packaging XSLT transform
/// (injecting Packaging, Checksum, and SystemRequirements elements), and writes to targetDir/module.xml.
Method WritePackageModuleXML(
	targetDir As %String,
	checksumHex As %String,
	irisVersion As %String)
{
    set srcPath = ##class(%Library.File).NormalizeFilename("module.xml", ..Module.Root)
    set baseStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(baseStream.LinkToFile(srcPath))
    $$$ThrowOnError(baseStream.Rewind())

    set compiled = ..CompilePackagingTransform(checksumHex, irisVersion)
    $$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(baseStream, compiled, .transformed))

    set outPath = ##class(%Library.File).NormalizeFilename("module.xml", targetDir)
    set outStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(outStream.LinkToFile(outPath))
    $$$ThrowOnError(outStream.CopyFrom(transformed))
    $$$ThrowOnError(outStream.%Save())
}

/// XSLT to inject <Packaging>database</Packaging>, <Checksum Algorithm="SHA-256">...</Checksum>,
/// and <SystemRequirements Version="..."/> into a module XML stream.
/// REPLACECHECKSUM and REPLACEIRISVERSION are substituted with real values before XSLT compilation.
XData InjectDatabasePackagingTransform
{
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="no"/>
  <xsl:strip-space elements="*"/>

  <!-- Identity transform -->
  <xsl:template match="@*|node()">
    <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
  </xsl:template>

  <!-- Export: each child on its own line, 2-space indent -->
  <xsl:template match="*[local-name()='Export']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select="*">
        <xsl:text>&#10;  </xsl:text>
        <xsl:apply-templates select="."/>
      </xsl:for-each>
      <xsl:text>&#10;</xsl:text>
    </xsl:copy>
  </xsl:template>

  <!-- Document: each child on its own line, 4-space indent -->
  <xsl:template match="*[local-name()='Document']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select="*">
        <xsl:text>&#10;    </xsl:text>
        <xsl:apply-templates select="."/>
      </xsl:for-each>
      <xsl:text>&#10;  </xsl:text>
    </xsl:copy>
  </xsl:template>

  <!-- Module: each child on its own line, 6-space indent.
       Skip any existing Packaging/Checksum/SystemRequirements (will be re-injected).
       Inject Packaging + Checksum immediately after Version.
       Inject SystemRequirements (with current IRIS version) after Checksum. -->
  <xsl:template match="*[local-name()='Module']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select="*[local-name()!='Packaging' and local-name()!='Checksum' and local-name()!='SystemRequirements']">
        <xsl:text>&#10;      </xsl:text>
        <xsl:apply-templates select="."/>
        <xsl:if test="local-name()='Version'">
          <xsl:text>&#10;      </xsl:text>
          <xsl:element name="Packaging" namespace="{namespace-uri(..)}">database</xsl:element>
          <xsl:text>&#10;      </xsl:text>
          <xsl:element name="Checksum" namespace="{namespace-uri(..)}">
            <xsl:attribute name="Algorithm">SHA-256</xsl:attribute>REPLACECHECKSUM</xsl:element>
          <xsl:text>&#10;      </xsl:text>
          <xsl:element name="SystemRequirements" namespace="{namespace-uri(..)}">
            <xsl:attribute name="Version">REPLACEIRISVERSION</xsl:attribute>
            <!-- Carry all non-Version attributes from any existing SystemRequirements element -->
            <xsl:for-each select="../*[local-name()='SystemRequirements']/@*[local-name()!='Version']">
              <xsl:copy/>
            </xsl:for-each>
          </xsl:element>
        </xsl:if>
      </xsl:for-each>
      <xsl:text>&#10;    </xsl:text>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
}

/// Compiles InjectDatabasePackagingTransform with the real checksum and IRIS version substituted in.
ClassMethod CompilePackagingTransform(checksumHex As %String, irisVersion As %String) As %XML.XSLT.CompiledStyleSheet
{
    set xData = ##class(%Dictionary.CompiledXData).IDKEYOpen(
        $classname(), "InjectDatabasePackagingTransform", , .sc)
    $$$ThrowOnError(sc)

    set raw = ""
    while 'xData.Data.AtEnd {
        set raw = raw _ xData.Data.Read()
    }
    set raw = $replace(raw, "REPLACECHECKSUM", checksumHex)
    set raw = $replace(raw, "REPLACEIRISVERSION", irisVersion)

    set stream = ##class(%Stream.TmpCharacter).%New()
    $$$ThrowOnError(stream.Write(raw))
    $$$ThrowOnError(stream.Rewind())

    $$$ThrowOnError(##class(%XML.XSLT.CompiledStyleSheet).CreateFromStream(stream, .compiled))
    quit compiled
}

/// Writes each dependency's IPM metadata to deps/<name>.xml as a standalone IRIS export,
/// loadable at install time with $system.OBJ.Load.
/// depWheels(depName, wheelName) entries are injected as <PythonWheel> elements into that
/// dependency's exported manifest.
Method WriteDependencies(
	targetDir As %String,
	ByRef depWheels)
{
    set depsDir = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).NormalizeFilename("deps", targetDir))
    if '##class(%Library.File).CreateDirectoryChain(depsDir) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot create deps directory: " _ depsDir))
    }

    set depNames = ..GetDependencyNames(..Module)
    set ptr = 0
    while $listnext(depNames, ptr, depName) {
        set depFile = ##class(%Library.File).NormalizeFilename(depName _ ".xml", depsDir)
        set fileStream = ##class(%Stream.FileCharacter).%New()
        $$$ThrowOnError(fileStream.LinkToFile(depFile))
        set exportStream = ##class(%Stream.TmpCharacter).%New()
        $$$ThrowOnError($system.OBJ.ExportToStream(depName _ ".ZPM", .exportStream, "-d"))

        set wheelName = ""
        for {
            set wheelName = $order(depWheels(depName, wheelName))
            quit:wheelName=""
            $$$ThrowOnError(exportStream.Rewind())
            set transform = ##class(%IPM.StudioDocument.Module).CompileAppendWheelUnderModuleXSLT(wheelName)
            $$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(exportStream, transform, .injected))
            set exportStream = injected
        }

        $$$ThrowOnError(exportStream.Rewind())
        $$$ThrowOnError(fileStream.CopyFrom(exportStream))
        $$$ThrowOnError(fileStream.%Save())
    }
}

/// Recursively builds depMap(lowercased name) = module oref (or "" if not installed).
/// Sets the entry before recursing so circular dependencies terminate.
ClassMethod CollectAllDependencies(
	module As %IPM.Storage.Module,
	ByRef depMap)
{
    for i=1:1:module.Dependencies.Count() {
        set depName = module.Dependencies.GetAt(i).Name
        set depKey = $zconvert(depName, "L")
        if $data(depMap(depKey)) {
            continue
        }
        if '##class(%IPM.Storage.Module).NameExists(depName) {
            set depMap(depKey) = ""
            continue
        }
        set depModule = ##class(%IPM.Storage.Module).NameOpen(depName, , .sc)
        $$$ThrowOnError(sc)
        set depMap(depKey) = depModule
        do ..CollectAllDependencies(depModule, .depMap)
    }
}

/// Returns installed transitive dependency modules in name order.
ClassMethod GetDependencyModules(module As %IPM.Storage.Module) As %ListOfObjects
{
    do ..CollectAllDependencies(module, .depMap)
    set deps = ##class(%ListOfObjects).%New()
    set depKey = ""
    for {
        set depKey = $order(depMap(depKey), 1, depModule)
        quit:depKey=""
        continue:'$isobject(depModule)
        do deps.Insert(depModule)
    }
    quit deps
}

/// Returns this module followed by its installed transitive dependencies.
/// The root comes first because every caller needs its resources considered before its dependencies'.
Method GetSelfAndDependencyModules() As %ListOfObjects [ Private ]
{
    set modules = ..GetDependencyModules(..Module)
    do modules.InsertAt(..Module, 1)
    quit modules
}

/// Returns the installed transitive dependency names in name order.
ClassMethod GetDependencyNames(module As %IPM.Storage.Module) As %List
{
    set deps = ..GetDependencyModules(module)
    set names = ""
    for i=1:1:deps.Count() {
        set names = names _ $listbuild(deps.GetAt(i).Name)
    }
    quit names
}

/// Returns installed transitive dependency names with dependencies before dependents.
/// Unlike GetDependencyNames (name order), this ordering is required when running lifecycle phases:
/// a dependency's phase may rely on a deeper dependency's files already being in place.
/// Resolves entirely from locally registered metadata — no repository access.
ClassMethod GetTopologicalDependencyNames(module As %IPM.Storage.Module) As %List
{
    kill visited
    set ordered = ""
    do ..VisitDependencies(module, .visited, .ordered)
    quit ordered
}

/// Depth-first post-order helper for GetTopologicalDependencyNames.
/// Marks each module visited before recursing so dependency cycles terminate.
ClassMethod VisitDependencies(
	module As %IPM.Storage.Module,
	ByRef visited,
	ByRef ordered) [ Private ]
{
    for i=1:1:module.Dependencies.Count() {
        set depName = module.Dependencies.GetAt(i).Name
        if $data(visited($zconvert(depName, "L"))) {
            continue
        }
        set visited($zconvert(depName, "L")) = ""
        if '##class(%IPM.Storage.Module).NameExists(depName) {
            continue
        }
        set depModule = ##class(%IPM.Storage.Module).NameOpen(depName, , .sc)
        $$$ThrowOnError(sc)
        do ..VisitDependencies(depModule, .visited, .ordered)
        set ordered = ordered _ $listbuild(depModule.Name)
    }
}

// =====================================================================
// Install helpers
// =====================================================================

/// Returns 1 if the module is database-packaged and IRIS.DAT is present in the module root.
/// Both conditions are required: Packaging alone could mean a source load with a Database lifecycle.
Method IsInstallContext() As %Boolean [ Private ]
{
    set irisDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", ..Module.Root)
    quit (..Module.Packaging = "database") && ##class(%Library.File).Exists(irisDAT)
}

/// Returns 1 if the module.xml in dir was produced by database packaging.
/// Detected by the <Checksum> element InjectDatabasePackagingTransform adds. Checksum is not a
/// property of %IPM.Storage.Module, so it appears only in packaged manifests and never in one
/// written by hand. Reads the file rather than the installed record: a first install whose
/// metadata was rolled back leaves no record to consult.
ClassMethod IsPackagedManifest(dir As %String) As %Boolean
{
    if dir = "" {
        quit 0
    }
    set moduleXML = ##class(%Library.File).NormalizeFilename("module.xml", dir)
    if '##class(%Library.File).Exists(moduleXML) {
        quit 0
    }
    set xmlStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(xmlStream.LinkToFile(moduleXML))
    // A file that does not parse is not a packaged manifest; let the source path report on it.
    if $$$ISERR(##class(%XML.XPATH.Document).CreateFromStream(xmlStream, .xpathDoc)) {
        quit 0
    }
    $$$ThrowOnError(xpathDoc.EvaluateExpression("/Export/Document/Module/Checksum", "text()", .results))
    quit (results.Count() > 0)
}

/// Pre-install validation. Throws on any failure; does not modify state.
/// staleModules (output): modules the previous version carried that the incoming one drops.
Method ValidateBeforeSwap(
	packageDir As %String,
	ByRef params,
	Output staleModules As %List) [ Private ]
{
    set staleModules = ""
    set irisDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", packageDir)
    if '##class(%Library.File).Exists(irisDAT) {
        set msg = "Database package is missing IRIS.DAT in: " _ packageDir
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
    set moduleXML = ##class(%Library.File).NormalizeFilename("module.xml", packageDir)
    if '##class(%Library.File).Exists(moduleXML) {
        set msg = "Database package is missing module.xml in: " _ packageDir
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }

    set xmlStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(xmlStream.LinkToFile(moduleXML))
    $$$ThrowOnError(##class(%XML.XPATH.Document).CreateFromStream(xmlStream, .xpathDoc))

    $$$ThrowOnError(xpathDoc.EvaluateExpression("/Export/Document/Module/Packaging", "text()", .packagingResults))
    set packagingValue = $select(packagingResults.Count() > 0: packagingResults.GetAt(1).Value, 1: "")
    if packagingValue '= "database" {
        set msg = "module.xml does not declare <Packaging>database</Packaging>. Got: " _ packagingValue
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }

    set depsDir = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).NormalizeFilename("deps", packageDir))
    if '##class(%Library.File).DirectoryExists(depsDir) {
        set msg = "Database package is missing deps/ directory in: " _ packageDir
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }

    $$$ThrowOnError(xpathDoc.EvaluateExpression("/Export/Document/Module/Checksum", "text()", .checksumResults))
    if checksumResults.Count() = 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "module.xml is missing <Checksum> element."))
    }

    // Only one database package per namespace is allowed
    set conflictRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %IPM_Storage.ModuleItem WHERE Packaging = 'database' AND Name != ?",
        ..Module.Name)
    if conflictRS.%SQLCODE < 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error checking for conflicting database packages: " _ conflictRS.%Message))
    }
    if conflictRS.%Next() {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "A database package ('" _ conflictRS.%Get("Name") _ "') is already installed in this namespace. Only one database package per namespace is allowed."))
    }

    do ..ValidateNoOrphanedModules(depsDir, $get(params("PreviousDependencies")), .staleModules)

    // Validate IPM is not in the target namespace's routines DB
    do ..ValidateIPMNotInRoutinesDB()
    do ..ValidateRoutinesDatabaseNotMirrored($namespace)
    do ..ValidateRoutinesDatabaseNotShared($namespace)

    // Hashing reads the whole IRIS.DAT, so it runs last: every cheaper reason to reject should
    // already have reported instead of making the user wait on a multi-gigabyte read.
    set expectedChecksum = checksumResults.GetAt(1).Value
    set actualChecksum = ..ComputeSHA256Hex(irisDAT)
    if $zconvert(actualChecksum, "L") '= $zconvert(expectedChecksum, "L") {
        set msg = "IRIS.DAT SHA-256 mismatch. Expected: " _ expectedChecksum _ " Actual: " _ actualChecksum
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
}

/// Throws if any installed module has code in the routines database that the swap would destroy.
/// Exempt: modules in this package, modules whose code is mapped from elsewhere, modules with no
/// code, and modules the previous version carried but the incoming one drops (their code leaves with
/// the old DAT). The last group is returned in staleModules for the caller to unconfigure and remove.
/// previousDeps: installed version's dependency names, captured before its manifest was overwritten.
Method ValidateNoOrphanedModules(
	depsDir As %String,
	previousDeps As %List = "",
	Output staleModules As %List) [ Private ]
{
    set staleModules = ""
    set packagedNames = ..GetPackagedDependencyNames(depsDir)

    // Module names are stored as declared, so normalize the captured set for comparison.
    set previousNames = ""
    set ptr = 0
    while $listnext(previousDeps, ptr, prevName) {
        set previousNames = previousNames _ $listbuild($zconvert(prevName, "L"))
    }

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %IPM_Storage.ModuleItem WHERE Name != ?",
        ..Module.Name)
    if rs.%SQLCODE < 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error listing installed modules: " _ rs.%Message))
    }

    set orphaned = ""
    while rs.%Next() {
        set moduleName = rs.%Get("Name")
        if $listfind(packagedNames, $zconvert(moduleName, "L")) {
            continue
        }
        // Carried by the outgoing version but not the incoming one: the swap replaces its code
        // rather than orphaning it, so the record is stale and must be removed, not protected.
        if $listfind(previousNames, $zconvert(moduleName, "L")) {
            set staleModules = staleModules _ $listbuild(moduleName)
            continue
        }
        set installedModule = ##class(%IPM.Storage.Module).NameOpen(moduleName, , .sc)
        $$$ThrowOnError(sc)
        if ..HasCodeInLocalRoutinesDB(installedModule) {
            set orphaned = orphaned _ $listbuild(moduleName)
        }
    }
    if orphaned = "" {
        quit
    }

    set plural = ($listlength(orphaned) > 1)
    set msg = "Installing this database package would replace the routines database for namespace " _ $namespace
    set msg = msg _ ", destroying the code of " _ $select(plural: "these already-installed modules", 1: "this already-installed module")
    set msg = msg _ ": " _ $listtostring(orphaned, ", ")
    set msg = msg _ ". Uninstall " _ $select(plural: "them", 1: "it") _ " first, or run 'uninstall -all -force' to clear the namespace."
    $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
}

/// Removes records of modules the previous package version carried but the incoming one drops.
/// Deletes directly rather than running Clean: Clean deletes by resource name, which after the swap
/// would also delete same-named resources belonging to the newly installed package.
ClassMethod RemoveStaleModuleMetadata(staleModules As %List = "")
{
    set ptr = 0
    while $listnext(staleModules, ptr, moduleName) {
        continue:moduleName=""
        if '##class(%IPM.Storage.Module).NameExists(moduleName) {
            continue
        }
        // Deletes the ModuleStream alongside the Module record; deleting the record alone would
        // leave an orphaned <name>.ZPM studio document behind.
        $$$ThrowOnError(##class(%IPM.StudioDocument.Module).Delete(moduleName _ ".ZPM"))
        write !, "Removed module no longer carried by this package: ", moduleName
    }
}

/// Runs the Unconfigure phase for each module the incoming package drops, so the parts of their
/// installation that live outside the routines database (web applications, copied files, installer
/// class side effects) are undone rather than orphaned by the swap.
///
/// Must be called before the swap, while these modules' own code is still mounted and runnable.
/// Failures are reported and skipped: a module that cannot unconfigure cleanly must not abort an
/// install that has already been confirmed, and the swap will remove its code regardless.
ClassMethod UnconfigureStaleModules(
	staleModules As %List = "",
	ByRef params)
{
    set ptr = 0
    while $listnext(staleModules, ptr, moduleName) {
        continue:moduleName=""
        if '##class(%IPM.Storage.Module).NameExists(moduleName) {
            continue
        }
        // Run the phase rather than calling %Unconfigure directly: resource processors do their
        // teardown in OnBeforePhase("Unconfigure"), which only ExecutePhases invokes.
        // Only Verbose carries over — this module's install params (root directory, forced
        // lifecycle class, install context) all describe the incoming package, not this module.
        kill unconfigureParams
        set unconfigureParams("Verbose") = $get(params("Verbose"))
        set sc = ##class(%IPM.Storage.Module).ExecutePhases(moduleName, $listbuild("Unconfigure"), 0, .unconfigureParams)
        if $$$ISERR(sc) {
            write !, "WARNING: could not unconfigure ", moduleName, ": ", $system.Status.GetErrorText(sc)
        }
    }
}

/// Returns lowercased names of dependencies carried in deps/ (one .xml per dependency).
ClassMethod GetPackagedDependencyNames(depsDir As %String) As %List
{
    set names = ""
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ItemName FROM %Library.File_FileSet(?, ?, ?, ?)",
        depsDir, "*.xml", "", 0)
    if rs.%SQLCODE < 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error listing deps: " _ rs.%Message))
    }
    while rs.%Next() {
        set itemName = rs.%Get("ItemName")
        continue:itemName=""
        set names = names _ $listbuild($zconvert($piece(itemName, ".", 1, *-1), "L"))
    }
    quit names
}

/// Returns 1 if any of the module's code resources exist locally in the routines database
/// (not mapped from elsewhere). Only CLS/PKG/MAC/INT/INC are checked; other types don't live there.
ClassMethod HasCodeInLocalRoutinesDB(module As %IPM.Storage.Module) As %Boolean
{
    set found = 0
    set orderedResourceList = module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""

        if '$listfind($listbuild("CLS", "PKG", "MAC", "INT", "INC"), $zconvert($piece(resource.Name, ".", *), "U")) {
            continue
        }

        kill children
        $$$ThrowOnError(resource.ResolveChildren(.children))
        set docName = ""
        for {
            set docName = $order(children(docName))
            quit:docName=""
            continue:'##class(%Library.RoutineMgr).Exists(docName)
            if '##class(%Library.RoutineMgr).IsMapped(docName) {
                set found = 1
                quit
            }
        }
        quit:found
    }
    quit found
}

/// Shows swap details and prompts for y/N confirmation. Throws if the user declines.
Method PromptForSwapConfirmation(
	ns As %String,
	staleModules As %List = "") [ Private ]
{
    set routinesDBName = ..GetRoutinesDBName(ns)
    set dbDir = ..GetDatabaseDirectory(routinesDBName)

    write !, "WARNING: This will replace the routines database for namespace ", ns
    write !, "  Current database: ", dbDir _ "IRIS.DAT"
    write !, "  The current IRIS.DAT will be renamed to a timestamped backup before the swap."
    if staleModules '= "" {
        write !, "  These modules are no longer part of this package and will be removed: ", $listtostring(staleModules, ", ")
    }
    write !

    set confirmed = 0
    set response = ##class(%Library.Prompt).GetYesNo("Proceed with database swap? [y/N] ", .confirmed)
    if (response '= $$$SuccessResponse) || 'confirmed {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Database swap cancelled by user."))
    }
}

/// Dismounts the current routines DB, renames IRIS.DAT to a timestamped backup, moves the new one
/// in, and remounts. The namespace is briefly without a routines DB; it should be idle during swap.
/// dbDir and backupPath (output) are used by RollbackDatabaseSwap on failure.
Method PerformDatabaseSwap(
	packageDir As %String,
	ns As %String,
	Output dbDir As %String,
	Output backupPath As %String) [ Private ]
{
    set dbDir = ""
    set backupPath = ""

    new $namespace
    set $namespace = "%SYS"

    set routinesDBName = ..GetRoutinesDBName(ns)
    set dbDir = ..GetDatabaseDirectory(routinesDBName)

    $$$ThrowOnError(##class(SYS.Database).DismountDatabase(dbDir))

    // Rename current IRIS.DAT to timestamped backup: IRIS_<dbname>_YYYYMMDDHHmmss.DAT.
    // Timestamp is second-resolution, so append a counter suffix if that name already exists
    set h = $horolog
    set timestamp = $translate($zdate(h, 8), "-", "") _ $translate($ztime($piece(h, ",", 2), 2), ":", "")
    set backupBase = dbDir _ "IRIS_" _ routinesDBName _ "_" _ timestamp
    set backupPath = backupBase _ ".DAT"
    set suffix = 0
    while ##class(%Library.File).Exists(backupPath) {
        set suffix = suffix + 1
        set backupPath = backupBase _ "_" _ suffix _ ".DAT"
    }
    if '##class(%Library.File).Rename(dbDir _ "IRIS.DAT", backupPath) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to rename IRIS.DAT to backup: " _ backupPath))
    }

    // Move (rename) packaged IRIS.DAT into the database directory
    set srcDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", packageDir)
    if '##class(%Library.File).Rename(srcDAT, dbDir _ "IRIS.DAT") {
        set tMsg = "Failed to move IRIS.DAT from " _ srcDAT _ " to " _ dbDir
        $$$ThrowStatus($$$ERROR($$$GeneralError, tMsg))
    }

    $$$ThrowOnError(##class(SYS.Database).MountDatabase(dbDir))
}

/// Loads deps/ export files to register dependency metadata in IPM storage.
/// The dependency code is already in the swapped-in DB; this only makes it visible to `zpm list`.
ClassMethod RegisterDependencyMetadata(packageDir As %String)
{
    set depsDir = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).NormalizeFilename("deps", packageDir))
    if '##class(%Library.File).DirectoryExists(depsDir) {
        quit
    }

    // Each file in deps/ is a standalone IRIS export XML, one per dependency.
    // Load them directly — no XML parsing required.
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %Library.File_FileSet(?, ?, ?, ?)",
        depsDir, "*.xml", "", 0)
    if rs.%SQLCODE < 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error listing deps: " _ rs.%Message))
    }
    while rs.%Next() {
        $$$ThrowOnError($system.OBJ.Load(rs.%Get("Name"), "ck"))
    }
}

/// Phases a dependency must not run during a database install, with the reason for each.
/// Reload: no source ships for a dependency, and Base.%Reload early-exits without a root.
/// Compile: the code is already compiled into IRIS.DAT.
/// "*": the module-refresh checkpoint, meaningful only for the module being installed.
/// Edit here — not in GetDependencyInstallPhases — when this judgment changes.
ClassMethod GetDependencyExcludedPhases() As %List
{
    quit $listbuild("Reload", "Compile", "*")
}

/// Derives the phases each dependency runs from the canonical install chain, minus the exclusions.
/// Derived rather than hardcoded so a phase added to GetCompletePhasesForOne is not silently
/// skipped for dependencies; TestDependencyPhasesCoverCanonicalChain fails if a new canonical phase
/// is neither run nor explicitly excluded.
ClassMethod GetDependencyInstallPhases(isUpdate As %Boolean = 0) As %List
{
    // Mirrors the entry point the install itself picks (%IPM.Utils.Module:LoadNewModule).
    set entryPhase = $select(isUpdate: "ApplyUpdateSteps", 1: "Activate")
    set canonical = ##class(%IPM.Lifecycle.Base).GetCompletePhasesForOne(entryPhase)
    set excluded = ..GetDependencyExcludedPhases()

    set phases = ""
    set ptr = 0
    while $listnext(canonical, ptr, onePhase) {
        continue:onePhase=""
        continue:$listfind(excluded, onePhase)
        set phases = phases _ $listbuild(onePhase)
    }
    quit phases
}

/// Runs each transitive dependency's install phases after the swap, so dependency-owned
/// non-compiled resources (FileCopy, CPF, PythonWheel, WebApplication) and <Invoke> elements are
/// applied rather than silently dropped.
/// Topological order: a dependency's phases may rely on a deeper dependency's files.
/// Each dependency's Root points at its deps-files/<name>/ staging directory inside the package.
/// depInitClasses (output): processor class names a dependency used at Initialize. The root's
/// Initialize already ran before the swap, so ReassertRootInitializeResources uses this to
/// re-apply only the affected root resources.
Method ApplyDependencyResources(
	packageDir As %String,
	ByRef params,
	Output depInitClasses) [ Private ]
{
    kill depInitClasses

    set depNames = ..GetTopologicalDependencyNames(..Module)
    if depNames = "" {
        quit
    }

    set verbose = $get(params("Verbose"))
    set isUpdate = $get(params("Update"), 0)
    set depPhases = ..GetDependencyInstallPhases(isUpdate)
    set ptr = 0
    while $listnext(depNames, ptr, depName) {
        continue:depName=""
        if '##class(%IPM.Storage.Module).NameExists(depName) {
            continue
        }

        set depModule = ##class(%IPM.Storage.Module).NameOpen(depName, , .sc)
        $$$ThrowOnError(sc)
        do ..CollectInitializePhaseClasses(depModule, .depInitClasses)

        write:verbose !, "Applying resources for dependency ", depName

        // Only Verbose, cmd and Update carry over: the root's remaining install params (install
        // context, root directory, swap flag, previous dependency set) describe the incoming
        // package. Update decides whether Activate seeds update steps or ApplyUpdateSteps runs them.
        kill depParams
        set depParams("Verbose") = verbose
        set depParams("cmd") = $get(params("cmd"))
        set depParams("Update") = isUpdate
        set depParams("RootDirectory") = ..GetDependencyStagingDir(packageDir, depName)

        set phasePtr = 0
        while $listnext(depPhases, phasePtr, depPhase) {
            // isComplete = 0: expanding the chain again would reintroduce the excluded phases.
            set sc = ##class(%IPM.Storage.Module).ExecutePhases(depName, $listbuild(depPhase), 0, .depParams)
            if $$$ISERR(sc) {
                write !, "ERROR: dependency '", depName, "' failed during ", depPhase, ": ", $system.Status.GetErrorText(sc)
                $$$ThrowStatus(sc)
            }
        }
    }
}

/// Re-applies the root module's Initialize-phase resources after the dependency pass.
/// The root's Initialize completed before the swap, so a dependency's Initialize resources land
/// afterwards and take precedence. Re-asserting restores the root's intended precedence.
/// Scoped to processor classes a dependency actually used at Initialize: with no dependency CPF or
/// wheel there is nothing to correct, and a CPF merge costs a subprocess call. Both affected
/// processors are safe to repeat — a merge applies file values, a present wheel is a no-op.
Method ReassertRootInitializeResources(
	ByRef depInitClasses,
	ByRef params) [ Private ]
{
    if '$data(depInitClasses) {
        quit
    }

    kill rootInitClasses
    do ..CollectInitializePhaseClasses(..Module, .rootInitClasses)

    set orderedResourceList = ..Module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""
        continue:'$isobject(resource.Processor)

        do resource.Processor.SetParams(.params)

        if resource.Processor.%IsA("%IPM.ResourceProcessor.CPF") && $data(depInitClasses("%IPM.ResourceProcessor.CPF")) && $data(rootInitClasses("%IPM.ResourceProcessor.CPF")) {
            if (resource.Processor.CustomPhase '= "") || (resource.Processor.Phase '= "Initialize") {
                continue
            }
            write !, "Re-applying CPF merge '", resource.Name, "' — a dependency merged a CPF after this module's Initialize phase."
            if resource.Processor.When = "After" {
                $$$ThrowOnError(resource.Processor.OnAfterPhase("Initialize", .params))
            } else {
                $$$ThrowOnError(resource.Processor.OnBeforePhase("Initialize", .params))
            }

        } elseif resource.Processor.%IsA("%IPM.ResourceProcessor.PythonWheel") && $data(depInitClasses("%IPM.ResourceProcessor.PythonWheel")) {
            write !, "Re-installing Python wheel '", resource.Name, "' — a dependency installed a wheel after this module's Initialize phase."
            set handled = 0
            $$$ThrowOnError(resource.Processor.OnPhase("Initialize", .params, .handled))
        }
    }
}

/// Records the processor class of each resource that acts during the Initialize phase.
/// CPF is phase-configurable, so only count it when it actually targets Initialize.
ClassMethod CollectInitializePhaseClasses(
	module As %IPM.Storage.Module,
	ByRef initClasses)
{
    set orderedResourceList = module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""
        continue:'$isobject(resource.Processor)

        if resource.Processor.%IsA("%IPM.ResourceProcessor.PythonWheel") {
            set initClasses("%IPM.ResourceProcessor.PythonWheel") = ""
        } elseif resource.Processor.%IsA("%IPM.ResourceProcessor.CPF") {
            if (resource.Processor.CustomPhase = "") && (resource.Processor.Phase = "Initialize") {
                set initClasses("%IPM.ResourceProcessor.CPF") = ""
            }
        }
    }
}

/// Reports a failure that happened after the swap already succeeded, without rolling back.
/// A rollback here would discard a working swap and could not reverse what the post-swap steps
/// already did (dependency CPF merges, installed wheels, copied files), leaving old code paired
/// with new configuration. These failures are normally fixable forward and the install re-run.
Method ReportPostSwapFailure(
	sc As %Status,
	ns As %String,
	backupPath As %String) [ Private ]
{
    write !, "ERROR: the database swap succeeded but a later step failed: ", $system.Status.GetErrorText(sc)
    write !, "  Namespace ", ns, " is running on the newly installed IRIS.DAT. It was NOT rolled back."
    write !, "  Rolling back would discard a successful swap and could not undo the side effects of the steps"
    write !, "  that already ran (CPF merges, installed Python wheels, copied files, web applications)."
    // Reported only with a transaction open: under -DNoTransaction or -DNoJournal the metadata
    // is already committed, so there is no split to warn about.
    if $tlevel > 0 {
        write !, "  Module metadata is in globals and will be rolled back; the swapped IRIS.DAT is a file"
        write !, "  rename and stays. 'list' will then report the previous version, whose code has been"
        write !, "  replaced by the newly installed code."
        write !, "  Fix the error reported above, then re-run the same install to commit the metadata against"
        write !, "  the already-mounted code. Do not uninstall first: it would delete resources by the"
        write !, "  previous version's names, which are not what is now mounted."
    }
    if backupPath '= "" {
        write !, "  To revert manually instead, restore the previous database from: ", backupPath
    }
}

/// Best-effort rollback after a failed swap. Never throws; all failures are logged.
/// Restores the backup IRIS.DAT if one exists; otherwise leaves the original in place.
Method RollbackDatabaseSwap(
	dbDir As %String,
	backupPath As %String)
{
    if dbDir = "" {
        quit
    }

    new $namespace
    set $namespace = "%SYS"

    set sc = ##class(SYS.Database).DismountDatabase(dbDir)
    if $$$ISERR(sc) {
        write !, "Rollback warning — could not dismount database at ", dbDir
    }

    // Only touch dbDir/IRIS.DAT when a backup exists to restore. If no backup exists,
    // the swap failed before the original was renamed out — the file still in place is
    // the original routines DB and must not be deleted.
    if (backupPath '= "") && ##class(%Library.File).Exists(backupPath) {
        set newDAT = dbDir _ "IRIS.DAT"
        if ##class(%Library.File).Exists(newDAT) {
            if '##class(%Library.File).Delete(newDAT) {
                write !, "Rollback warning — could not delete swapped-in IRIS.DAT at ", newDAT
            }
        }
        if '##class(%Library.File).Rename(backupPath, dbDir _ "IRIS.DAT") {
            write !, "Rollback warning — could not restore backup from ", backupPath
            write !, "  Manual intervention required to restore IRIS.DAT."
        }
    }

    set mountSC = ##class(SYS.Database).MountDatabase(dbDir)
    if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
        write !, "Rollback warning — could not remount database at ", dbDir
        write !, "  Namespace routines may be unavailable — manual remount required."
    }
}

// =====================================================================
// Database utilities
// =====================================================================

/// Returns the normalized directory path for a database.
/// Falls back to <ManagerDirectory>/<dbName> for unregistered databases.
ClassMethod GetDatabaseDirectory(dbName As %String) As %String
{
    new $namespace
    set $namespace = "%SYS"
    if ##class(Config.Databases).Exists(dbName) {
        $$$ThrowOnError(##class(Config.Databases).Get(dbName, .dbProps))
        quit ##class(%Library.File).NormalizeDirectory($get(dbProps("Directory")))
    }
    quit ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).ManagerDirectory() _ dbName)
}

/// Returns the Config.Databases key for a namespace's routines database.
ClassMethod GetRoutinesDBName(ns As %String) As %String
{
    new $namespace
    set $namespace = "%SYS"
    $$$ThrowOnError(##class(Config.Namespaces).Get(ns, .nsProps))
    quit $get(nsProps("Routines"))
}

}
