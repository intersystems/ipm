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

/// Entry point for database packaging. The package is a snapshot of the namespace it runs in:
/// 1. Validate that IPM is mapped in rather than living in the routines DB, and that the routines DB
///    is not mirrored
/// 2. Warn about anything the snapshot cannot carry, cannot run, or will carry unexpectedly
/// 3. Under -include-tests, load and compile the root module's test resources so the snapshot has them
/// 4. Dismount the namespace's routines database, copy its IRIS.DAT into a staging dir, remount it
/// 5. Enrich the staging dir (module.xml with the staged IRIS.DAT's SHA-256 checksum, deps/
///    manifests, non-compiled resources, Python wheels) and create the .tgz
///
/// Step 3 is the only step here that loads or compiles anything, so what ships is what the namespace
/// already holds. Note that the Compile phase runs ahead of this method and does compile the module's
/// own resources into the namespace, so the snapshot picks those up too.
/// The staging dir is removed on every path.
Method %Package(ByRef params) As %Status
{
    set sc = $$$OK
    set stagingDir = ""
    set ns = $namespace
    new $namespace

    try {
        set verbose = $get(params("Verbose"))
        set includeTests = $get(params("IncludeTests"), ..Module.IncludeTests)

        write:verbose !, "Starting database packaging: ", ..Module.Name, " v", ..Module.VersionString
        write:verbose !, "Validating..."
        do ..ValidateIPMNotInRoutinesDB()
        do ..ValidateRoutinesDatabaseNotMirrored(ns)

        do ..WarnUnrunnableInvokes()
        do ..WarnMappingsNotApplied()
        do ..WarnMissingDependencyCode()
        do ..WarnOtherModulesInDatabase()
        if 'includeTests {
            do ..WarnTestCodeAlreadyInDatabase()
        }
        do ..WarnRoutinesDatabaseSharedForPackaging(ns)
        do ..WarnPackagingRoutinesDatabaseIsGlobalsDatabase(ns)

        if includeTests {
            write:verbose !, "Loading test resources into the namespace..."
            do ..LoadTestResources(.params)
        }

        if $get(params("ExportPythonDependencies"), 1) {
            do ..ExportPythonDependencies(..Module, .params)
        }

        set stagingDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).Construct(##class(%IPM.Utils.File).CreateTempDirectory(), "stage"))
        $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(stagingDir))

        write:verbose !, "Snapshotting the routines database..."
        do ..SnapshotRoutinesDatabase(ns, stagingDir)

        set packageFile = ..AssemblePackage(stagingDir, .params)
        set params("PackageFile") = packageFile

        // Store in Payload for the Publish phase
        set srcStream = ##class(%Stream.FileBinary).%New()
        $$$ThrowOnError(srcStream.LinkToFile(packageFile))
        $$$ThrowOnError(..Payload.CopyFrom(srcStream))

    } catch ex {
        set sc = ex.AsStatus()
    }

    if (stagingDir '= "") && ##class(%Library.File).DirectoryExists(stagingDir) {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(stagingDir)
    }

    quit sc
}

/// Loads and compiles the root module's test resources into the current namespace so the snapshot
/// that follows contains them. Dependencies' tests are not loaded, since a database package ships
/// its dependencies as installed code and nothing at install time runs their tests.
///
/// Both halves are driven by hand. A Scope="test" resource is out of scope in every phase of a
/// package run, so its processor is invoked with its own scope as the phase, which is what makes
/// Document.OnPhase take its load branch. <UnitTest> directory resources have Scope="" and a Test
/// processor whose OnPhase does nothing at Reload, so they load via LoadTestDirectory. Neither path
/// compiles and Base.%Compile skips test-scoped resources, hence the explicit compile at the end.
Method LoadTestResources(ByRef params)
{
    if ..Module.Root = "" {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "-include-tests needs the module's source, but '" _ ..Module.Name _ "' has no root directory registered. Load it from source in this namespace first, or package without -include-tests."))
    }
    if '##class(%Library.File).DirectoryExists(..Module.Root) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "-include-tests needs the module's source, but the root directory of '" _ ..Module.Name _ "' is not readable: " _ ..Module.Root))
    }

    set verbose = $get(params("Verbose"))
    // Document.OnPhase configures package mappings unless told not to and packaging must not leave
    // Config.MapPackages entries behind in the namespace it snapshots.
    merge loadParams = params
    set loadParams("NoMapping") = 1

    kill toCompile
    set orderedResourceList = ..Module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""
        continue:'$isobject(resource.Processor)

        set isTestDirectory = resource.Processor.%IsA("%IPM.ResourceProcessor.Test") && ($extract(resource.Name, *) = "/")
        if isTestDirectory {
            // Construct joins the two, then the one-arg NormalizeDirectory only fixes separators.
            // The two-arg NormalizeDirectory(name, root) would not work: a <UnitTest> resource name
            // carries a leading slash ("/tests/"), which it reads as an absolute path, so it drops
            // the root and returns "/tests/".
            set testDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).Construct(resource.Module.Root, resource.Name))
            write:verbose !, "  Loading test directory ", testDir
            $$$ThrowOnError(##class(%IPM.Test.Manager).LoadTestDirectory(testDir, verbose, , resource.Processor.Format))
        } elseif resource.IsTestScoped() {
            write:verbose !, "  Loading test resource ", resource.Name
            do resource.Processor.SetParams(.loadParams)
            $$$ThrowOnError(resource.Processor.OnPhase(resource.Scope, .loadParams))
        } else {
            continue
        }

        kill children
        $$$ThrowOnError(resource.ResolveChildren(.children))
        set docName = ""
        for {
            set docName = $order(children(docName))
            quit:docName=""
            // Skip names that are not documents, like the "Scope" key a Test processor reports. The
            // test is on the extension rather than on whether the document exists: a test document
            // that failed to load has none, and skipping it here would let the compile pass without it.
            continue:'..IsCodeResourceName(docName)
            set toCompile(docName) = ""
        }
    }

    quit:'$data(toCompile)

    // CompileList rather than Compile, because the item names carry their extension (Foo.Bar.CLS).
    set compileItems = ""
    set docName = ""
    for {
        set docName = $order(toCompile(docName))
        quit:docName=""
        set compileItems = compileItems _ $select(compileItems="": "", 1: ",") _ docName
    }
    write:verbose !, "  Compiling test documents: ", compileItems
    $$$ThrowOnError($system.OBJ.CompileList(compileItems, "ck-d"))
}

/// Dispatches to one of three contexts: installing a package, the no-op Reload that precedes
/// Package, or an ordinary source load. A package directory whose IRIS.DAT a completed swap already
/// moved away is refused rather than dispatched.
/// All install work happens here so %Validate, %Compile, and %Activate stay no-ops, and invokes
/// from "Reload.After" onward fire against the mounted database.
Method %Reload(ByRef params) As %Status
{
    if ..IsDatabaseInstall() {
        quit ..DoDatabaseInstall(.params)
    }
    // The packaging phase chain on the source module (the Reload phase that precedes Package during
    // `package-database <name>`) has no source root to load from, and packaging snapshots what the
    // namespace already holds, so this phase is a no-op. Do not delegate to ##super here:
    // Base.%Reload treats DeveloperMode as a signal to load from ..Module.Root even when no
    // RootDirectory is passed, which would reload source into the current namespace mid-package.
    if '$data(params("RootDirectory")) {
        quit $$$OK
    }
    // A packaged manifest with no IRIS.DAT beside it is what an install that already swapped leaves
    // behind: PerformDatabaseSwap moves IRIS.DAT into the database directory rather than copying it.
    // Loading as source from here would compile source into the swapped-in database, which is meant
    // to be sealed and is described by the checksum in its own manifest.
    if ..IsDatabasePackagedManifest(params("RootDirectory")) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "This directory holds a database package whose IRIS.DAT is no longer present (" _ params("RootDirectory") _ "). The swap that has already run moved it into the database directory. Re-run the install from the original .tgz rather than from this directory."))
    }
    // Loading a database-packaged module from a source directory (RootDirectory set) behaves
    // like a normal source load so delegate to Base.
    quit ##super(.params)
}

/// Validate, swap the DB, register metadata, and run post-swap steps.
/// Injects a DatabaseInstall flag into params before the swap so downstream phases can check it without
/// re-examining the filesystem. Rollback is performed only on swap-mechanics failures; post-swap
/// failures are reported forward because the swap is the state to keep.
Method DoDatabaseInstall(ByRef params) As %Status [ Private ]
{
    set params("DatabaseInstall") = 1
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

        // Runs before the swap, while these modules' code is still in the routines database: undoes
        // the part of their installation the swap cannot reach (web apps, installer classes).
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
                write !, "  unconfigured before the swap. These modules had their web applications removed and their"
                write !, "  installer-class teardown run, so they are now only partially installed: ", $listtostring(staleModules, ", ")
                write !, "  Reinstall them to return the namespace to a working state."
            }
        }
    }
    quit sc
}

/// During a database package install, there is no source to validate.
/// In all other contexts, delegate to ##super.
Method %Validate(ByRef pParams) As %Status
{
    if $get(pParams("DatabaseInstall")) {
        quit $$$OK
    }
    quit ##super(.pParams)
}

/// During a database package install, there is no source to compile.
/// In all other contexts, delegate to ##super. Packaging is one of those: the package phase chain
/// includes Compile, so Base.%Compile compiles the module's resources into the namespace just before
/// %Package snapshots it.
Method %Compile(ByRef pParams) As %Status
{
    if $get(pParams("DatabaseInstall")) {
        quit $$$OK
    }
    quit ##super(.pParams)
}

/// During a database package install, the DB swap and all setup already completed in %Reload.
/// In all other contexts, delegate to ##super.
Method %Activate(ByRef params) As %Status
{
    if $get(params("DatabaseInstall")) {
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
                write !, "  Initialize and Reload.Before run before the swap mounts the packaged database."
                write !, "  Use Phase=""Reload"" When=""After"" or a later phase instead."
            } else {
                // An update install runs one extra phase per dependency, so name both sets.
                write !, "  Dependencies only run ", $listtostring(..GetDependencyInstallPhases(0), ", "), " after the swap, plus ApplyUpdateSteps on an update."
                write !, "  Use one of those phases instead."
            }
        }
    }
}

/// Warns when a dependency declares code resources but none of that code is in the local routines
/// database, so the snapshot will ship without it. Nothing at install time compiles a dependency's
/// source, so a dependency missing from the snapshot is missing from the installation.
/// The root module needs no equivalent warning: the Compile phase runs ahead of packaging and fails
/// outright when the root module's code cannot be compiled into the namespace.
Method WarnMissingDependencyCode()
{
    set modules = ..Module.GetDependencyModules()
    set mKey = ""
    for {
        #dim module As %IPM.Storage.Module
        set module = modules.GetNext(.mKey)
        quit:mKey=""
        set hasCode = ..HasCodeInLocalRoutinesDB(module, .declaresCode)
        // A module of purely non-compiled resources has nothing to find.
        continue:'declaresCode
        continue:hasCode

        write !!, "WARNING: no code from dependency '", module.Name, "' was found in this namespace's routines database."
        write !, "  The package is a snapshot of that database, so ", module.Name, " ", module.VersionString, " will not be in it."
        write !, "  Load or install ", module.Name, " into this namespace before packaging."
    }
}

/// Warns when the snapshot ships code from other installed modules, which this module did not ask for.
Method WarnOtherModulesInDatabase()
{
    kill expected
    set expected($zconvert(..Module.Name, "U")) = ""
    set deps = ..Module.GetDependencyModules()
    set mKey = ""
    for {
        #dim depModule As %IPM.Storage.Module
        set depModule = deps.GetNext(.mKey)
        quit:mKey=""
        set expected($zconvert(depModule.Name, "U")) = ""
    }

    set extra = ""
    set rs = ##class(%SQL.Statement).%ExecDirect(, "select Name from %IPM_Storage.ModuleItem")
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    while rs.%Next(.sc) {
        $$$ThrowOnError(sc)
        set name = rs.%Get("Name")
        continue:$data(expected($zconvert(name, "U")))
        #dim otherModule As %IPM.Storage.Module
        set otherModule = ##class(%IPM.Storage.Module).NameOpen(name)
        continue:'$isobject(otherModule)
        continue:'..HasCodeInLocalRoutinesDB(otherModule)
        set extra = extra _ $listbuild(name)
    }
    $$$ThrowOnError(sc)

    quit:extra=""

    write !!, "WARNING: this namespace's routines database also holds code from: ", $listtostring(extra, ", "), "."
    write !, "  The package is a snapshot of the whole database, so that code ships too."
    write !, "  Package from a namespace holding only ", ..Module.Name, " and its dependencies to avoid this."
}

/// Warns when test code is already compiled into the routines database and -include-tests was not
/// passed. That flag controls whether packaging adds test code, not whether it is absent. Anything
/// already in the database ships either way.
Method WarnTestCodeAlreadyInDatabase()
{
    set present = ""
    set orderedResourceList = ..Module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""
        continue:'resource.IsTestScoped()

        kill children
        $$$ThrowOnError(resource.ResolveChildren(.children))
        set docName = ""
        for {
            set docName = $order(children(docName))
            quit:docName=""
            continue:'..IsLocalDocument(docName)
            set present = present _ $listbuild(docName)
        }
    }

    quit:present=""

    write !!, "WARNING: test code is already in the routines database and will ship in the package: ", $listtostring(present, ", "), "."
    write !, "  -include-tests was not passed, but the package is a snapshot and excludes nothing."
    write !, "  Delete it from this namespace or package from one where it was never compiled."
}

/// Returns the shared database directory when a namespace's routines and globals are the same
/// database, or "" when they differ. Compares directories rather than names, since two
/// Config.Databases entries can name one directory and only the directory identifies the file.
ClassMethod GetSharedRoutinesAndGlobalsDirectory(ns As %String) As %String
{
    set routinesDir = ##class(%IPM.Utils.Module).GetRoutineDatabaseDir(ns)
    set globalsDir = ##class(%IPM.Utils.Module).GetGlobalDatabaseDir(ns)
    quit $select(routinesDir=globalsDir: routinesDir, 1: "")
}

/// Warns when a namespace's routines and globals are the same database during packaging.
/// The snapshot copies the whole IRIS.DAT, so every global in that namespace ships in the package,
/// including application data and ^IPM.Storage.*, the packaging machine's own module registry.
ClassMethod WarnPackagingRoutinesDatabaseIsGlobalsDatabase(ns As %String)
{
    set sharedDir = ..GetSharedRoutinesAndGlobalsDirectory(ns)
    quit:sharedDir=""

    write !!, "WARNING: globals in namespace ", ns, " will ship inside this package."
    write !, "  ", ns, " uses one database for both routines and globals (", sharedDir, "), and the snapshot copies it whole."
    write !, "  Give ", ns, " a globals database of its own to avoid shipping that data."
}

/// Warns when another namespace shares the routines database being snapshotted. Packaging dismounts
/// that database for the length of the copy, so every namespace pointing at it is down until the
/// remount, not just the one being packaged.
ClassMethod WarnRoutinesDatabaseSharedForPackaging(ns As %String)
{
    set sharing = ..GetNamespacesSharingRoutinesDatabase(ns)
    quit:sharing=""

    write !!, "WARNING: packaging will briefly take down these namespaces as well: ", $listtostring(sharing, ", "), "."
    write !, "  They share the routines database of ", ns, ", which is dismounted for the copy."
    write !, "  Package from a namespace with a routines database of its own to avoid this."
}

/// Throws if IPM classes are in the local routines database. IPM must be mapped so it survives the swap.
ClassMethod ValidateIPMNotInRoutinesDB()
{
    if ##class(%Dictionary.ClassDefinition).%ExistsId("%IPM.Main") && '##class(%Library.RoutineMgr).IsMapped("%IPM.Main.CLS") {
        set msg = "%IPM classes live in the routines database of namespace " _ $namespace _ ", so packaging would ship IPM itself and the swap would replace it. "
        set msg = msg _ "Install IPM in another namespace, run zpm ""uninstall zpm"" here, then map it in from that namespace with zpm ""enable -map -ns " _ $namespace _ """."
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
}

/// Throws if the namespace's routines DB is mirrored. Dismounting a mirrored DB breaks the mirror.
ClassMethod ValidateRoutinesDatabaseNotMirrored(ns As %String)
{
    // Look the database up before switching: %IPM.* classes cannot be dispatched from %SYS.
    set dbName = ##class(%IPM.Utils.Module).GetRoutineDatabase(ns)
    set dbDir = ##class(%IPM.Utils.Module).GetDatabaseDirectory(dbName)

    new $namespace
    set $namespace = "%SYS"
    set db = ##class(SYS.Database).%OpenId(dbDir, , .sc)
    $$$ThrowOnError(sc)
    if db.Mirrored {
        set msg = "Database packaging is not currently supported for mirrored databases (namespace: " _ ns _ ", database: " _ dbName _ ")."
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
}

/// Returns the names of other namespaces whose routines database is the same database as this
/// namespace's, as a $list, or "" when none share it.
/// Matches on directory rather than database name: two Config.Databases entries can name the same
/// directory, and only the directory identifies the file being swapped or dismounted.
ClassMethod GetNamespacesSharingRoutinesDatabase(ns As %String) As %List
{
    set dbDir = ##class(%IPM.Utils.Module).GetRoutineDatabaseDir(ns)
    new $namespace
    set $namespace = "%SYS"

    set dbResult = ##class(%SQL.Statement).%ExecDirect(, "select Name, Server, Directory from Config.Databases_List()")
    $$$ThrowSQLIfError(dbResult.%SQLCODE, dbResult.%Message)
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
    $$$ThrowSQLIfError(nsResult.%SQLCODE, nsResult.%Message)
    while nsResult.%Next(.sc) {
        $$$ThrowOnError(sc)
        continue:$zconvert(nsResult.Namespace,"U")=$zconvert(ns,"U")
        if $data(sameDir($zconvert(nsResult.Routines, "U"))) {
            set sharing = sharing _ $listbuild(nsResult.Namespace)
        }
    }
    $$$ThrowOnError(sc)

    quit sharing
}

/// Throws if any other namespace uses the same routines database. The swap replaces the IRIS.DAT
/// behind that database, so every namespace pointing at it silently gets the packaged code too.
ClassMethod ValidateRoutinesDatabaseNotShared(ns As %String)
{
    set sharing = ..GetNamespacesSharingRoutinesDatabase(ns)
    quit:sharing=""

    set dbDir = ##class(%IPM.Utils.Module).GetRoutineDatabaseDir(ns)
    set msg = "The routines database of namespace " _ ns _ " (" _ dbDir _ ") is also the routines database of: " _ $listtostring(sharing, ", ") _ ". Swapping it would replace the code of those namespaces as well. Give " _ ns _ " a routines database of its own before installing a database package."
    $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
}

/// Warns when a namespace's routines and globals are the same database. The swap replaces that
/// database wholesale, so the namespace's globals are replaced by the package's, including
/// ^IPM.Storage.*, the module registry recording the install being performed.
ClassMethod WarnRoutinesDatabaseIsGlobalsDatabase(ns As %String)
{
    set sharedDir = ..GetSharedRoutinesAndGlobalsDirectory(ns)
    quit:sharedDir=""

    write !!, "WARNING: namespace ", ns, " uses the same database for routines and globals (", sharedDir, ")."
    write !, "  The swap replaces that database, so this namespace's globals, including IPM's module registry, will be replaced by the package's."
    write !, "  Give ", ns, " a globals database of its own before installing a database package."
}

/// Copies the routines database of ns into stagingDir as IRIS.DAT. This is the whole of what
/// database packaging produces: the package is a snapshot of a namespace, not a build.
/// The database is dismounted for the copy and remounted afterwards, so ns cannot run code while the
/// copy runs. The dismount is not an optimization to skip: a copy of a mounted IRIS.DAT reads only
/// what is on disk, and blocks written since the write daemon last ran are still in the buffer pool,
/// so code compiled shortly before packaging would be missing from the snapshot. Dismounting flushes.
/// The caller must have validated that the database is not mirrored, since dismounting a mirrored
/// database breaks the mirror (see ValidateRoutinesDatabaseNotMirrored).
ClassMethod SnapshotRoutinesDatabase(
	ns As %String,
	stagingDir As %String)
{
    set dbName = ##class(%IPM.Utils.Module).GetRoutineDatabase(ns)
    set dbDir = ##class(%IPM.Utils.Module).GetDatabaseDirectory(dbName)
    set srcDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", dbDir)
    if '##class(%Library.File).Exists(srcDAT) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "The routines database of namespace " _ ns _ " has no IRIS.DAT: " _ dbDir))
    }
    set destDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", stagingDir)

    // DismountDatabase neither checks for nor waits on other users of the database. It succeeds while
    // another process is writing, and that process then takes <PROTECT> on ^ZBUSY2 until the remount.
    // This is an outage the caller chooses, not a check that the namespace is idle.
    write !, "Dismounting ", dbName, " for the copy. ", ns, " cannot run code until the copy finishes."
    set copySC = ..CopyDismountedDatabase(dbDir, srcDAT, destDAT, .mountSC)

    if $$$ISERR(mountSC) {
        write !, "ERROR: failed to remount ", dbName, " (", dbDir, "). Mount it manually before using ", ns, "."
        write !, "  ", $system.Status.GetErrorText(mountSC)
    }

    // Report the copy failure first when both happened. It is why packaging stopped, and the mount
    // failure has already reported itself.
    $$$ThrowOnError(copySC)
    $$$ThrowOnError(mountSC)
}

/// Dismounts dbDir, copies srcDAT to destDAT, then remounts. Returns the copy's status, and the
/// remount's in mountSC.
/// Writes nothing. Output capture resolves its handler routine in the current namespace, which %SYS
/// cannot see, so a write here takes <NOROUTINE>. The caller reports instead.
ClassMethod CopyDismountedDatabase(
	dbDir As %String,
	srcDAT As %String,
	destDAT As %String,
	Output mountSC As %Status) As %Status
{
    new $namespace
    set $namespace = "%SYS"

    $$$ThrowOnError(##class(SYS.Database).DismountDatabase(dbDir))

    // Everything between the dismount and the remount is caught, including what CopyFile itself may
    // throw. An exception escaping here would skip the remount entirely.
    set copySC = $$$OK
    try {
        if '##class(%Library.File).CopyFile(srcDAT, destDAT, 1, .result) {
            set copySC = $$$ERROR($$$GeneralError, "Cannot copy " _ srcDAT _ " to the staging directory: " _ $get(result))
        }
    } catch copyEx {
        set copySC = copyEx.AsStatus()
    }

    // Remount even after a failed copy. Leaving the namespace's code database dismounted is worse
    // than any packaging error.
    set mountSC = ##class(SYS.Database).MountDatabase(dbDir)
    if $system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
        set mountSC = $$$OK
    }
    quit copySC
}

/// Enriches an already-populated staging dir and creates the final .tgz, whose path it returns.
/// IRIS.DAT must already be in the staging dir.
Method AssemblePackage(
	stagingDir As %String,
	ByRef params) As %String
{
    set stagedDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", stagingDir)
    if '##class(%Library.File).Exists(stagedDAT) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Staging directory has no IRIS.DAT: " _ stagingDir))
    }

    // Checksum the staged file. Those are the exact bytes the .tgz ships, and the live database it
    // came from may have moved on since.
    write:$get(params("Verbose")) !, "Computing SHA-256 checksum..."
    set checksumHex = ##class(%IPM.Utils.File).ComputeSHA256Hex(stagedDAT)
    write !!, "Checksum: ", checksumHex

    // Stage non-compiled resource files so processors can find them during install
    set includeTestResources = $get(params("IncludeTests"), ..Module.IncludeTests)
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
            $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(outputDir))
        }
    }

    set packageFile = ##class(%Library.File).Construct(outputDir, ..Module.Name _ "-" _ ..Module.VersionString _ "-database.tgz")
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
    quit ##class(%Library.File).NormalizeDirectory(##class(%Library.File).Construct(stagingDir, "deps-files", depName))
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

    set deps = ..Module.GetDependencyModules()
    set mKey = ""
    for {
        #dim depModule As %IPM.Storage.Module
        set depModule = deps.GetNext(.mKey)
        quit:mKey=""

        set depDir = ..GetDependencyStagingDir(stagingDir, depModule.Name)
        $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(depDir))
        do ..StageModuleResources(depModule, depDir, includeTestResources, exportPythonDeps)
    }
}

/// Stages one module's non-compiled resource files into targetDir, mirroring the relative layout
/// the resource processors expect under a module root.
///
/// Source paths resolve the same way the consuming processor resolves them, so the staged file lands
/// where install-time lookup expects it. Destination paths are built with Construct instead, because
/// %Library.File.NormalizeFilename(name, dir) chdir's into dir and returns "" when dir does not exist,
/// and these destination subdirectories do not exist until StageFile creates them.
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
            set destPath = ##class(%Library.File).Construct(targetDir, name)
            do ..StageResourceFile(resource.Name, sourcePath, destPath)

        } elseif exportPythonDeps && resource.Processor.%IsA("%IPM.ResourceProcessor.PythonWheel") {
            set wheelName = resource.Processor.Name
            set wheelDir = resource.Processor.Directory
            set sourcePath = ##class(%Library.File).NormalizeFilename(wheelName, ##class(%Library.File).NormalizeDirectory(wheelDir, module.Root))
            set destPath = ##class(%Library.File).Construct(targetDir, wheelDir, wheelName)
            do ..StageResourceFile(resource.Name, sourcePath, destPath)

        } elseif resource.Processor.%IsA("%IPM.ResourceProcessor.CPF") {
            set cpfName = resource.Processor.Name
            set cpfSubdir = resource.Processor.Directory
            set sourcePath = ##class(%Library.File).NormalizeFilename(cpfName, ##class(%Library.File).Construct(module.Root, module.SourcesRoot, cpfSubdir))
            set destPath = ##class(%Library.File).Construct(targetDir, module.SourcesRoot, cpfSubdir, cpfName)
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

    set deps = ..Module.GetDependencyModules()
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

        set destWheelDir = ##class(%Library.File).Construct(..GetDependencyStagingDir(stagingDir, depModule.Name), "wheels")

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
                ##class(%Library.File).Construct(destWheelDir, wheelName))
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
    // Callers build destPath with Construct, which joins with the platform delimiter but leaves any
    // separators already inside a segment alone. Normalize before splitting off the directory.
    set destPath = ##class(%Library.File).NormalizeFilename(destPath)
    set destDir = ##class(%Library.File).GetDirectory(destPath)
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(destDir))
    $$$ThrowOnError(##class(%IPM.Utils.File).CopyFile(sourcePath, destPath, 1))
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

    set depNames = ..Module.GetDependencyNames()
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

// =====================================================================
// Install helpers
// =====================================================================

/// Returns 1 if this is a database install rather than a source load: the module is database-packaged
/// and IRIS.DAT sits in its root. The IRIS.DAT is what discriminates, since Packaging = "database"
/// only selects this lifecycle class and a source tree loaded from disk declares it too, with nothing
/// to swap in.
Method IsDatabaseInstall() As %Boolean [ Private ]
{
    set irisDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", ..Module.Root)
    quit (..Module.Packaging = "database") && ##class(%Library.File).Exists(irisDAT)
}

/// Returns 1 if the module.xml in dir was produced by database packaging.
/// Detected by the <Checksum> element InjectDatabasePackagingTransform adds. Checksum is not a
/// property of %IPM.Storage.Module, so it appears only in packaged manifests and never in one
/// written by hand. Reads the file rather than the installed record: a first install whose
/// metadata was rolled back leaves no record to consult.
ClassMethod IsDatabasePackagedManifest(dir As %String) As %Boolean
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
/// Ordered so the failure reported is the one worth acting on: namespace preconditions, which no
/// package can satisfy, then the package's own structure, then the whole-file hash.
/// params: only params("PreviousDependencies") is read, and passed straight to
/// ValidateNoOrphanedModules.
/// staleModules (output): modules the previous version carried that the incoming one drops.
Method ValidateBeforeSwap(
	packageDir As %String,
	ByRef params,
	Output staleModules As %List) [ Private ]
{
    set staleModules = ""

    // Namespace preconditions first: they read nothing from the package, and a namespace that cannot
    // host a database package at all should say so before the user's package is picked apart.
    do ..ValidateIPMNotInRoutinesDB()
    do ..ValidateRoutinesDatabaseNotMirrored($namespace)
    do ..ValidateRoutinesDatabaseNotShared($namespace)

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

    // Hashing reads the whole IRIS.DAT, so it runs last among the checks: every cheaper reason to
    // reject should already have reported instead of making the user wait on a multi-gigabyte read.
    set expectedChecksum = checksumResults.GetAt(1).Value
    set actualChecksum = ##class(%IPM.Utils.File).ComputeSHA256Hex(irisDAT)
    if $zconvert(actualChecksum, "L") '= $zconvert(expectedChecksum, "L") {
        set msg = "IRIS.DAT SHA-256 mismatch. Expected: " _ expectedChecksum _ " Actual: " _ actualChecksum
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }

    // After every throw, so a warning about the namespace is only printed for an install that is
    // actually going ahead.
    do ..WarnRoutinesDatabaseIsGlobalsDatabase($namespace)
}

/// Throws if the swap would destroy code the incoming package cannot replace, before anything is
/// dismounted. No flag bypasses this, -force included.
/// Examines all other modules installed in this namespace against the outgoing and incoming
/// dependency sets:
/// Stale — a dependency the incoming version drops. Its code leaves with the old DAT, so nothing is
/// lost and only the metadata record survives. Returned in staleModules to unconfigure and remove.
/// Orphaned — a dependency of neither version, with code of its own in the routines DB. Nothing
/// replaces that code, so the install fails and the error lists it. Code that is absent or mapped in
/// from elsewhere survives the swap and is exempt.
/// previousDeps: the outgoing version's dependency names, captured before its manifest was
/// overwritten. Empty on a fresh install, so nothing is stale and any module found is orphaned.
Method ValidateNoOrphanedModules(
	depsDir As %String,
	previousDeps As %List = "",
	Output staleModules As %List) [ Private ]
{
    set staleModules = ""
    set incomingDeps = ..GetPackagedDependencyNames(depsDir)

    // Module names are stored as declared, so normalize the captured set for comparison.
    set normalized = ""
    set ptr = 0
    while $listnext(previousDeps, ptr, prevName) {
        set normalized = normalized _ $listbuild($zconvert(prevName, "L"))
    }
    set previousDeps = normalized

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %IPM_Storage.ModuleItem WHERE Name != ?",
        ..Module.Name)
    if rs.%SQLCODE < 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error listing installed modules: " _ rs.%Message))
    }

    set orphaned = ""
    while rs.%Next() {
        set moduleName = rs.%Get("Name")
        if $listfind(incomingDeps, $zconvert(moduleName, "L")) {
            continue
        }
        // Carried by the outgoing version but not the incoming one: the swap replaces its code
        // rather than orphaning it, so the record is stale and must be removed, not protected.
        if $listfind(previousDeps, $zconvert(moduleName, "L")) {
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
/// installation that live outside the routines database are undone rather than orphaned by the swap.
/// Unconfigure covers web and CSP applications and the module's InstallerClass teardown callbacks.
/// Not files copied by FileCopy or wheels: those processors key their teardown on Clean, which a
/// database install cannot run here — Clean deletes by resource name, and the incoming package may
/// declare the same names.
///
/// Must be called before the swap, while these modules' own code is still in the namespace's routines
/// database.
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
            write !, "  Its web applications and installer-class effects may remain. This install"
            write !, "  removes its module record and the swap removes its code, so IPM has no way to unconfigure"
            write !, "  it afterwards; remove whatever it left behind by hand."
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

/// Whether any of the module's code resources exist locally in the routines database.
/// declaresCode reports whether the module declared any code resource at all, which distinguishes a
/// module whose code is missing from one that has none to begin with.
ClassMethod HasCodeInLocalRoutinesDB(
	module As %IPM.Storage.Module,
	Output declaresCode As %Boolean) As %Boolean
{
    set declaresCode = 0
    set orderedResourceList = module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""
        continue:'..IsCodeResourceName(resource.Name)
        set declaresCode = 1

        kill children
        $$$ThrowOnError(resource.ResolveChildren(.children))
        set docName = ""
        for {
            set docName = $order(children(docName))
            quit:docName=""
            if ..IsLocalDocument(docName) {
                return 1
            }
        }
    }
    quit 0
}

/// Whether a resource or document name is one of the types that compiles into the routines database.
ClassMethod IsCodeResourceName(name As %String) As %Boolean
{
    quit $listfind($listbuild("CLS", "PKG", "MAC", "INT", "INC"), $zconvert($piece(name, ".", *), "U")) > 0
}

/// Whether a document exists in the current routines database rather than being mapped from elsewhere.
ClassMethod IsLocalDocument(docName As %String) As %Boolean
{
    quit ##class(%Library.RoutineMgr).Exists(docName) && '##class(%Library.RoutineMgr).IsMapped(docName)
}

/// Shows swap details and prompts for y/N confirmation. Throws if the user declines.
Method PromptForSwapConfirmation(
	ns As %String,
	staleModules As %List = "") [ Private ]
{
    set dbDir = ##class(%IPM.Utils.Module).GetRoutineDatabaseDir(ns)

    write !, "WARNING: This will replace the routines database for namespace ", ns
    write !, "  Current database: ", ##class(%Library.File).Construct(dbDir, "IRIS.DAT")
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
/// dbDir and backupPath (output) are what RollbackDatabaseSwap needs on failure, so each is set as
/// soon as it is known and stays "" until then: dbDir before the dismount, backupPath only once the
/// rename has succeeded. A rollback can therefore tell how far the swap got from these two alone.
Method PerformDatabaseSwap(
	packageDir As %String,
	ns As %String,
	Output dbDir As %String,
	Output backupPath As %String) [ Private ]
{
    set dbDir = ""
    set backupPath = ""

    // Look the database up before switching: %IPM.* classes cannot be dispatched from %SYS.
    set routinesDBName = ##class(%IPM.Utils.Module).GetRoutineDatabase(ns)
    set dbDir = ##class(%IPM.Utils.Module).GetDatabaseDirectory(routinesDBName)

    new $namespace
    set $namespace = "%SYS"

    $$$ThrowOnError(##class(SYS.Database).DismountDatabase(dbDir))

    // Rename current IRIS.DAT to timestamped backup: IRIS_<dbname>_YYYYMMDDHHmmss.DAT.
    // Timestamp is second-resolution, so append a counter suffix if that name already exists
    set h = $horolog
    set timestamp = $translate($zdate(h, 8), "-", "") _ $translate($ztime($piece(h, ",", 2), 2), ":", "")
    set backupBase = ##class(%Library.File).Construct(dbDir, "IRIS_" _ routinesDBName _ "_" _ timestamp)
    set backupPath = backupBase _ ".DAT"
    set suffix = 0
    while ##class(%Library.File).Exists(backupPath) {
        set suffix = suffix + 1
        set backupPath = backupBase _ "_" _ suffix _ ".DAT"
    }
    set liveDAT = ##class(%Library.File).Construct(dbDir, "IRIS.DAT")
    if '##class(%Library.File).Rename(liveDAT, backupPath) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to rename IRIS.DAT to backup: " _ backupPath))
    }

    // Move (rename) packaged IRIS.DAT into the database directory
    set srcDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", packageDir)
    if '##class(%Library.File).Rename(srcDAT, liveDAT) {
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

    set depNames = ..Module.GetTopologicalDependencyNames()
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
            write !, "Re-merging Configuration Parameter File (CPF) '", resource.Name, "' as a dependency merged a CPF after this module's Initialize phase."
            if resource.Processor.When = "After" {
                $$$ThrowOnError(resource.Processor.OnAfterPhase("Initialize", .params))
            } else {
                $$$ThrowOnError(resource.Processor.OnBeforePhase("Initialize", .params))
            }

        } elseif resource.Processor.%IsA("%IPM.ResourceProcessor.PythonWheel") && $data(depInitClasses("%IPM.ResourceProcessor.PythonWheel")) {
            write !, "Re-installing Python wheel '", resource.Name, "' as a dependency installed a wheel after this module's Initialize phase."
            set handled = 0
            $$$ThrowOnError(resource.Processor.OnPhase("Initialize", .params, .handled))
        }
    }
}

/// Records the processor class of each resource that acts during the Initialize phase.
/// CPF is phase-configurable, so only count it when it actually targets Initialize.
/// initClasses: a set, initClasses(processor class name) = "". Holds at most the two classes checked
/// below, so it is really a pair of flags; an array because it unions idempotently across the per-dependency loop
/// in ApplyDependencyResources for free. This method only adds, never clears,
/// so a caller wanting just one module's classes must kill initClasses before the call.
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
/// dbDir: the routines database directory to dismount and remount. "" means the swap failed before
/// it was resolved, so there is nothing to roll back.
/// backupPath: the timestamped IRIS.DAT to restore. "" means the swap failed before the original was
/// renamed out, so the file in dbDir is still the original.
/// Both are the outputs PerformDatabaseSwap sets, passed on unchanged.
Method RollbackDatabaseSwap(
	dbDir As %String,
	backupPath As %String)
{
    if dbDir = "" {
        quit
    }

    do ..RestoreDatabaseFromBackup(dbDir, backupPath, .warnings)
    set key = ""
    for {
        set key = $order(warnings(key))
        quit:key=""
        write !, warnings(key)
    }
}

/// Does the %SYS half of the rollback: dismount dbDir, restore the backup IRIS.DAT when there is one,
/// remount. See CopyDismountedDatabase for why a write from %SYS is unsafe.
/// warnings (output): warnings(1..n) = message text, in the order they occurred, killed on entry.
/// Collected rather than written so the caller can write them from a namespace that can.
/// dbDir and backupPath carry the same meaning as in RollbackDatabaseSwap.
ClassMethod RestoreDatabaseFromBackup(
	dbDir As %String,
	backupPath As %String,
	Output warnings)
{
    kill warnings
    set count = 0

    new $namespace
    set $namespace = "%SYS"

    set sc = ##class(SYS.Database).DismountDatabase(dbDir)
    if $$$ISERR(sc) {
        set warnings($increment(count)) = "Rollback warning: could not dismount database at " _ dbDir
    }

    // Only touch dbDir/IRIS.DAT when a backup exists to restore. If no backup exists, the swap failed
    // before the original was renamed out, so the file still in place is the original routines DB and
    // must not be deleted.
    if (backupPath '= "") && ##class(%Library.File).Exists(backupPath) {
        set newDAT = ##class(%Library.File).Construct(dbDir, "IRIS.DAT")
        if ##class(%Library.File).Exists(newDAT) {
            if '##class(%Library.File).Delete(newDAT) {
                set warnings($increment(count)) = "Rollback warning: could not delete swapped-in IRIS.DAT at " _ newDAT
            }
        }
        if '##class(%Library.File).Rename(backupPath, newDAT) {
            set warnings($increment(count)) = "Rollback warning: could not restore backup from " _ backupPath
            set warnings($increment(count)) = "  Manual intervention required to restore IRIS.DAT."
        }
    }

    set mountSC = ##class(SYS.Database).MountDatabase(dbDir)
    if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
        set warnings($increment(count)) = "Rollback warning: could not remount database at " _ dbDir
        set warnings($increment(count)) = "  Namespace routines may be unavailable. Manual remount required."
    }
}

}
