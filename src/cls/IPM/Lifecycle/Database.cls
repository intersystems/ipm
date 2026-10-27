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

/// Entry point for database packaging. The package ships a copy of the routines database of the
/// namespace it runs in:
/// 1. Validate that IPM is mapped in rather than living in the routines DB, and that the routines DB
///    is not mirrored
/// 2. Warn about anything the copy cannot carry, cannot run, or will carry unexpectedly
/// 3. Under -include-tests, load and compile the root module's test resources so the copy has them
/// 4. Dismount the namespace's routines database, copy its IRIS.DAT into a staging dir, remount it
/// 5. Enrich the staging dir (module.xml with the staged IRIS.DAT's SHA-256 checksum, deps/
///    manifests, non-compiled resources, Python wheels) and create the .tgz
///
/// What ships is what the namespace holds after the Compile phase, plus step 3's test resources.
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
        do ..WarnGlobalsNotShipped(includeTests)
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
            set modules = ..GetSelfAndDependencyModules()
            for i = 1:1:modules.Count() {
                do ..ExportPythonDependencies(modules.GetAt(i), .params)
            }
        }

        set stagingDir = ##class(%IPM.Utils.File).CreateTempDirectory()

        write:verbose !, "Copying the routines database..."
        do ..CopyRoutinesDatabase(ns, stagingDir)

        set packageFile = ..AssemblePackage(stagingDir, .params)
        set params("PackageFile") = packageFile

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

/// Loads and compiles the root module's test resources into the current namespace so the database
/// copy that follows contains them. Dependencies' tests are not loaded, since a database package ships
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
    // NoMapping stops Document.OnPhase from adding Config.MapPackages entries to the namespace being
    // copied.
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
            // Two-arg NormalizeDirectory would read the leading slash of a <UnitTest> name ("/tests/")
            // as an absolute path and drop the root.
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
            // that failed to load has none and skipping it here would let the compile pass without it.
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

/// Dispatches to one of two contexts: installing a package, or the no-op Reload that precedes
/// Package. Any other directory declaring database packaging has no IRIS.DAT and is refused.
/// A database install does the lifecycle's work here, so %Validate, %Compile and %Activate are no-ops.
/// Processor hooks and invokes from Reload.After onward run against the mounted database.
Method %Reload(ByRef params) As %Status
{
    if ..IsDatabaseInstall() {
        quit ..DoDatabaseInstall(.params)
    }
    // The Reload before Package in `package-database <name>` has nothing to load: packaging copies
    // what the namespace holds. ##super would reload source from ..Module.Root in developer mode.
    if '$data(params("RootDirectory")) {
        quit $$$OK
    }
    // Also what a completed install leaves, since PerformDatabaseSwap moves IRIS.DAT out.
    set msg = "module.xml in " _ params("RootDirectory") _ " declares <Packaging>database</Packaging> but there is no IRIS.DAT beside it. "
    $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
}

/// Validate, swap the DB, register metadata, and run post-swap steps.
/// Injects a DatabaseInstall flag into params before the swap so downstream phases can check it without
/// re-examining the filesystem. Rolls back only on swap-mechanics failures; once the swap lands it
/// commits down to params("InstallTLevel") and reports later failures forward.
Method DoDatabaseInstall(ByRef params) As %Status [ Private ]
{
    set params("DatabaseInstall") = 1
    set sc = $$$OK
    set swapStarted = 0
    set swapCompleted = 0
    set staleModules = ""
    set verbose = $get(params("Verbose"))
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

        set swapStarted = 1
        set backupPath = ..PerformDatabaseSwap(packageDir, ns)
        // Past this point the swap is the state to keep, not to undo: a rollback would discard a
        // good swap and could not reverse the side effects of the steps that follow.
        set swapCompleted = 1
        // Commit before applying mappings: their config locks would block a dependency's CPF merge.
        while $tlevel > $get(params("InstallTLevel"), $tlevel) {
            tcommit
        }

        // Only once the swap has landed: a rollback restores these modules' code, so their records
        // must survive until then.
        do ..RemoveStaleModuleMetadata(staleModules)

        do ##class(%IPM.Lifecycle.Database).RegisterDependencyMetadata(packageDir)

        if $tlevel = 0 {
            set modules = ..GetSelfAndDependencyModules()
            for i = 1:1:modules.Count() {
                do ##class(%IPM.Lifecycle.Base).ApplyModuleMappings(modules.GetAt(i), verbose)
            }
        } else {
            do ..WarnMappingsNotApplied()
        }

        // Dependencies get their phases here rather than in a chain of their own: at this point the
        // swap has landed, so their compiled code is mounted and their staged files are reachable.
        do ..ApplyDependencyResources(packageDir, .params, .depInitClasses)
        do ..ReassertRootInitializeResources(.depInitClasses, .params)

        // A fresh install seeds every update step as already run, as Module.cls:%Activate does, so a
        // later 'update' runs only newer steps. An update runs its steps instead.
        if '$get(params("Update")) {
            $$$ThrowOnError(..Module.HandleAllUpdateSteps(, 1, verbose))
        }

        write !, "Database swap complete for namespace ", ns
        write !, "  Backup: ", backupPath

    } catch ex {
        set sc = ex.AsStatus()
        if swapCompleted {
            do ..ReportPostSwapFailure(sc, $get(ns, $namespace), backupPath, $get(params("Update"), 0))
        } elseif swapStarted {
            // Written here as well as returned: DisplayError shows only the first error of a combined
            // status and the rest say what the restore could not do.
            write !, "ERROR: the database swap failed: ", $system.Status.GetErrorText(sc)
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
/// %Package copies its routines database.
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

/// Warns that <Mapping> elements are skipped inside an outer transaction, whose config locks would
/// block a dependency's <CPF> merge ('iris merge').
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
        write " will not be applied during this install, because it runs inside an outer transaction."
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

/// Warns about <Global> resources: their data lives in the globals database, which is not packaged,
/// and a database install has no Reload phase to load it.
Method WarnGlobalsNotShipped(includeTests As %Boolean)
{
    set modules = ..GetSelfAndDependencyModules()
    set warned = 0
    set mKey = ""
    for {
        #dim module As %IPM.Storage.Module
        set module = modules.GetNext(.mKey)
        quit:mKey=""

        set rKey = ""
        for {
            #dim resource As %IPM.Storage.ResourceReference
            set resource = module.Resources.GetNext(.rKey)
            quit:rKey=""
            if '$isobject(resource.Processor) || 'resource.Processor.%IsA("%IPM.ResourceProcessor.Default.Global") {
                continue
            }
            if 'includeTests && resource.IsTestScoped() {
                continue
            }
            write !, "WARNING: Global resource '", resource.Name, "' in ", $select(module.Name = ..Module.Name: "this module", 1: "dependency '" _ module.Name _ "'")
            write " cannot be shipped in a database package."
            set warned = 1
        }
    }
    if warned {
        write !, "  Install the module from source, or load that data separately."
    }
}

/// Warns when a dependency declares code resources but none of that code is in the local routines
/// database, so the database copy will ship without it. Nothing at install time compiles a
/// dependency's source, so a dependency missing from the copy is missing from the installation.
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
        write !, "  The package ships a copy of that database, so ", module.Name, " ", module.VersionString, " will not be in it."
        write !, "  Load or install ", module.Name, " into this namespace before packaging."
    }
}

/// Warns when the database copy ships code from other installed modules, which this module did not ask for.
Method WarnOtherModulesInDatabase()
{
    kill expected
    set expected(..Module.Name) = ""
    set deps = ..Module.GetDependencyModules()
    set mKey = ""
    for {
        #dim depModule As %IPM.Storage.Module
        set depModule = deps.GetNext(.mKey)
        quit:mKey=""
        set expected(depModule.Name) = ""
    }

    set extra = ""
    set rs = ##class(%SQL.Statement).%ExecDirect(, "select Name from %IPM_Storage.ModuleItem")
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    while rs.%Next(.sc) {
        $$$ThrowOnError(sc)
        set name = rs.%Get("Name")
        continue:$data(expected(name))
        #dim otherModule As %IPM.Storage.Module
        set otherModule = ##class(%IPM.Storage.Module).NameOpen(name)
        continue:'$isobject(otherModule)
        continue:'..HasCodeInLocalRoutinesDB(otherModule)
        set extra = extra _ $listbuild(name)
    }
    $$$ThrowOnError(sc)

    quit:extra=""

    write !!, "WARNING: this namespace's routines database also holds code from ", $listtostring(extra, ", "), "."
    write !, "  The package ships a copy of the whole database, so that code ships too."
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
    write !, "  -include-tests was not passed, but the package copies the database whole and excludes nothing."
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
/// Packaging copies the whole IRIS.DAT, so every global in that namespace ships in the package,
/// including application data and ^IPM.Storage.*, the packaging machine's own module registry.
ClassMethod WarnPackagingRoutinesDatabaseIsGlobalsDatabase(ns As %String)
{
    set sharedDir = ..GetSharedRoutinesAndGlobalsDirectory(ns)
    quit:sharedDir=""

    write !!, "WARNING: globals in namespace ", ns, " will ship inside this package."
    write !, "  ", ns, " uses one database for both routines and globals (", sharedDir, ") and packaging copies it whole."
    write !, "  Give ", ns, " a globals database of its own to avoid shipping that data."
}

/// Warns when another namespace shares the routines database being copied. Packaging dismounts
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
/// directory and only the directory identifies the file being swapped or dismounted.
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

/// Copies the routines database of ns into stagingDir as IRIS.DAT. The database is dismounted for
/// the copy so blocks still in the buffer pool are flushed to disk, and ns cannot run code until the
/// remount. The caller must have checked that the database is not mirrored.
ClassMethod CopyRoutinesDatabase(
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
    // another process is writing and that process then takes <PROTECT> on ^ZBUSY2 until the remount.
    // This is an outage the caller chooses, not a check that the namespace is idle.
    write !, "Dismounting ", dbName, " for the copy. ", ns, " cannot run code until the copy finishes."
    set copySC = ..DismountAndCopyDatabase(dbDir, srcDAT, destDAT, .mountSC)

    // Written here as well as thrown: DisplayError shows only the first error of a combined status.
    if $$$ISERR(mountSC) {
        write !, "ERROR: failed to remount ", dbName, " (", dbDir, "). Mount it manually before using ", ns, "."
        write !, "  ", $system.Status.GetErrorText(mountSC)
    }

    $$$ThrowOnError($$$ADDSC(copySC, mountSC))
}

/// Dismounts dbDir, copies srcDAT to destDAT, then remounts. Returns the copy's status and puts the
/// remount's in mountSC.
/// Writes nothing. Output capture resolves its handler routine in the current namespace, which %SYS
/// cannot see, so a write here takes <NOROUTINE>. The caller reports instead.
ClassMethod DismountAndCopyDatabase(
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

    // Checksum the staged file. Those are the exact bytes the .tgz ships and the live database it
    // came from may have moved on since.
    write:$get(params("Verbose")) !, "Computing SHA-256 checksum..."
    set checksumHex = ##class(%IPM.Utils.File).ComputeSHA256Hex(stagedDAT)
    write !!, "Checksum: ", checksumHex

    // Stage non-compiled resource files so processors can find them during install
    do ..CopyNonCompiledResources(stagingDir, .params)

    // Bare "<major>.<minor>" is an exact-match semver expression, not a floor, so the package will
    // only install on the IRIS version that built it.
    set irisVersion = $system.Version.GetMajor() _ "." _ $system.Version.GetMinor()
    write !, "This package will only install on IRIS ", irisVersion, ", the version it was built on."
    do ..WritePackageModuleXML(stagingDir, checksumHex, irisVersion)
    do ..WriteDependencies(stagingDir)

    set outputDir = $get(params("Path"))
    if outputDir = "" {
        set outputDir = ##class(%Library.File).NormalizeDirectory(##class(%IPM.Utils.File).CreateTempDirectory())
    } else {
        set outputDir = ##class(%Library.File).NormalizeDirectory(outputDir)
        $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(outputDir))
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

/// Has each resource processor of this module and of each transitive dependency stage the files it
/// reads at install time into stagingDir. Dependency files go under deps-files/<depname>/ so the
/// install-time dependency pass can point that dependency's Root at them.
/// The per-dependency directory is created even when empty: install always sets Root to it and a
/// Root pointing at a nonexistent directory would resolve paths on the packaging machine instead.
Method CopyNonCompiledResources(
	stagingDir As %String,
	ByRef params)
{
    set includeTestResources = $get(params("IncludeTests"), ..Module.IncludeTests)
    do ..StageModuleResources(..Module, stagingDir, includeTestResources, .params)

    set deps = ..Module.GetDependencyModules()
    set mKey = ""
    for {
        #dim depModule As %IPM.Storage.Module
        set depModule = deps.GetNext(.mKey)
        quit:mKey=""

        set depDir = ..GetDependencyStagingDir(stagingDir, depModule.Name)
        $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(depDir))
        do ..StageModuleResources(depModule, depDir, includeTestResources, .params)
    }
}

/// Stages one module's files into targetDir through each resource processor's
/// OnStageForDatabasePackage, skipping test-scoped resources unless includeTestResources is set.
ClassMethod StageModuleResources(
	module As %IPM.Storage.Module,
	targetDir As %String,
	includeTestResources As %Boolean,
	ByRef params)
{
    set orderedResourceList = module.GetOrderedResourceList()
    set key = ""
    for {
        #dim resource As %IPM.Storage.ResourceReference
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""

        if 'includeTestResources && resource.IsTestScoped() {
            continue
        }
        if '$isobject(resource.Processor) {
            continue
        }
        $$$ThrowOnError(resource.Processor.OnStageForDatabasePackage(targetDir, .params))
    }
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
Method WriteDependencies(targetDir As %String)
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
        $$$ThrowOnError(exportStream.Rewind())
        $$$ThrowOnError(fileStream.CopyFrom(exportStream))
        $$$ThrowOnError(fileStream.%Save())
    }
}

// =====================================================================
// Install helpers
// =====================================================================

/// Returns 1 if this is a database install: the module is database-packaged and IRIS.DAT sits in its
/// root.
Method IsDatabaseInstall() As %Boolean [ Private ]
{
    set irisDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", ..Module.Root)
    quit (..Module.Packaging = "database") && ##class(%Library.File).Exists(irisDAT)
}

/// Pre-install validation. Throws on any failure; does not modify state.
/// Ordered so the failure reported is the one worth acting on: namespace preconditions, which no
/// package can satisfy, then the package's own structure, then the whole-file hash.
/// params: only params("PreviousDependencies") is read and passed straight to
/// ValidateNoOrphanedModules.
/// staleModules (output): modules the previous version carried that the incoming one drops.
Method ValidateBeforeSwap(
	packageDir As %String,
	ByRef params,
	Output staleModules As %List) [ Private ]
{
    set staleModules = ""

    // Namespace preconditions first: they read nothing from the package and a namespace that cannot
    // host a database package at all should say so before the user's package is picked apart.
    do ..ValidateIPMNotInRoutinesDB()
    do ..ValidateRoutinesDatabaseNotMirrored($namespace)
    do ..ValidateRoutinesDatabaseNotShared($namespace)

    set irisDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", packageDir)
    set xmlStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(xmlStream.LinkToFile(##class(%Library.File).NormalizeFilename("module.xml", packageDir)))
    $$$ThrowOnError(##class(%XML.XPATH.Document).CreateFromStream(xmlStream, .xpathDoc))

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

    // Mappings are applied after the swap, where a failure isn't rolled back, so check the root's
    // source databases here. Its Initialize-phase CPFs, which may create them, have already merged.
    do ..ValidateMappingSources()

    // Only one database package per namespace is allowed
    set conflictRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %IPM_Storage.ModuleItem WHERE Packaging = 'database' AND Name != ?",
        ..Module.Name)
    $$$ThrowSQLIfError(conflictRS.%SQLCODE, conflictRS.%Message)
    if conflictRS.%Next(.sc) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "A database package ('" _ conflictRS.%Get("Name") _ "') is already installed in this namespace. Only one database package per namespace is allowed."))
    }
    $$$ThrowOnError(sc)

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

/// Throws if a <Mapping> of this module maps from a database this instance lacks.
Method ValidateMappingSources() [ Private ]
{
    new $namespace
    set moduleName = ..Module.Name
    // Collected before switching: the mapping objects cannot be read from %SYS.
    set sources = ""
    set key = ""
    for {
        #dim mapping As %IPM.Storage.MappingReference
        set mapping = ..Module.Mappings.GetNext(.key)
        quit:key=""
        set:mapping.SourceResolved'="" sources = sources _ $listbuild(mapping.SourceResolved)
    }

    set $namespace = "%SYS"
    set ptr = 0
    while $listnext(sources, ptr, source) {
        if '##class(Config.Databases).Exists($zconvert(source, "U")) {
            set msg = "Module '" _ moduleName _ "' has a <Mapping> from database '" _ source _ "', which does not exist on this instance."
            $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
        }
    }
}

/// Throws if the swap would destroy code the incoming package cannot replace, before anything is
/// dismounted. No flag bypasses this, -force included.
/// Examines all other modules installed in this namespace against the outgoing and incoming
/// dependency sets:
/// Stale: a dependency the incoming version drops. Its code leaves with the old DAT, so nothing is
/// lost and only the metadata record survives. Returned in staleModules to unconfigure and remove.
/// Orphaned: a dependency of neither version, with code of its own in the routines DB. Nothing
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

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %IPM_Storage.ModuleItem WHERE Name != ?",
        ..Module.Name)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)

    set orphaned = ""
    while rs.%Next(.sc) {
        $$$ThrowOnError(sc)
        set moduleName = rs.%Get("Name")
        if $listfind(incomingDeps, moduleName) {
            continue
        }
        // Carried by the outgoing version but not the incoming one: the swap replaces its code
        // rather than orphaning it, so the record is stale and must be removed, not protected.
        if $listfind(previousDeps, moduleName) {
            set staleModules = staleModules _ $listbuild(moduleName)
            continue
        }
        set installedModule = ##class(%IPM.Storage.Module).NameOpen(moduleName, , .openSC)
        $$$ThrowOnError(openSC)
        if ..HasCodeInLocalRoutinesDB(installedModule) {
            set orphaned = orphaned _ $listbuild(moduleName)
        }
    }
    $$$ThrowOnError(sc)
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
        // The swap replaces the module records too when the routines and globals databases are one.
        if '##class(%IPM.Storage.Module).NameExists(moduleName) {
            continue
        }
        // Delete the document, not just the record, or the .ZPM is left behind.
        $$$ThrowOnError(##class(%IPM.StudioDocument.Module).Delete(moduleName _ ".ZPM"))
        write !, "Removed module no longer carried by this package: ", moduleName
    }
}

/// Runs the Unconfigure phase (web applications, InstallerClass teardown) for each module the
/// incoming package drops. Clean is not run, because it deletes by resource name and the incoming
/// package may declare the same names. Must run before the swap, while their code is still there.
/// Failures are reported and skipped, since the swap removes their code regardless.
ClassMethod UnconfigureStaleModules(
	staleModules As %List = "",
	ByRef params)
{
    set ptr = 0
    while $listnext(staleModules, ptr, moduleName) {
        // Run the phase rather than calling %Unconfigure directly: resource processors do their
        // teardown in OnBeforePhase("Unconfigure"), which only ExecutePhases invokes.
        // Only Verbose carries over: the other install params (root directory, forced lifecycle
        // class, install context) describe the incoming package, not this module.
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

/// Returns the names of dependencies carried in deps/ (one .xml per dependency).
ClassMethod GetPackagedDependencyNames(depsDir As %String) As %List
{
    set names = ""
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ItemName FROM %Library.File_FileSet(?, ?, ?, ?)",
        depsDir, "*.xml", "", 0)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    while rs.%Next(.sc) {
        $$$ThrowOnError(sc)
        set itemName = rs.%Get("ItemName")
        continue:itemName=""
        set names = names _ $listbuild($piece(itemName, ".", 1, *-1))
    }
    $$$ThrowOnError(sc)
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
/// in, and remounts. Returns the backup's path. The namespace is briefly without a routines DB; it
/// should be idle during swap.
/// On failure, restores the original IRIS.DAT and remounts before throwing. Anything the restore
/// could not do is added to the thrown status, since a write from %SYS is unsafe (see
/// DismountAndCopyDatabase).
Method PerformDatabaseSwap(
	packageDir As %String,
	ns As %String) As %String [ Private ]
{
    // Look the database up before switching: %IPM.* classes cannot be dispatched from %SYS.
    set routinesDBName = ##class(%IPM.Utils.Module).GetRoutineDatabase(ns)
    set dbDir = ##class(%IPM.Utils.Module).GetDatabaseDirectory(routinesDBName)
    set srcDAT = ##class(%Library.File).NormalizeFilename("IRIS.DAT", packageDir)

    new $namespace
    set $namespace = "%SYS"

    $$$ThrowOnError(##class(SYS.Database).DismountDatabase(dbDir))

    set liveDAT = ##class(%Library.File).Construct(dbDir, "IRIS.DAT")
    set backupPath = ""
    try {
        // Rename the current IRIS.DAT to IRIS_<dbname>_YYYYMMDDHHmmss.DAT. The timestamp has
        // one-second resolution, so a counter suffix follows if that name is taken.
        set h = $horolog
        set timestamp = $translate($zdate(h, 8), "-", "") _ $translate($ztime($piece(h, ",", 2), 2), ":", "")
        set backupBase = ##class(%Library.File).Construct(dbDir, "IRIS_" _ routinesDBName _ "_" _ timestamp)
        set candidate = backupBase _ ".DAT"
        set suffix = 0
        while ##class(%Library.File).Exists(candidate) {
            set suffix = suffix + 1
            set candidate = backupBase _ "_" _ suffix _ ".DAT"
        }
        if '##class(%Library.File).Rename(liveDAT, candidate) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to rename IRIS.DAT to backup: " _ candidate))
        }
        set backupPath = candidate

        if '##class(%Library.File).Rename(srcDAT, liveDAT) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to move IRIS.DAT from " _ srcDAT _ " to " _ dbDir))
        }
        $$$ThrowOnError(##class(SYS.Database).MountDatabase(dbDir))
    } catch ex {
        set sc = ex.AsStatus()
        if backupPath '= "" {
            if ##class(%Library.File).Exists(liveDAT) && '##class(%Library.File).Delete(liveDAT) {
                set sc = $$$ADDSC(sc, $$$ERROR($$$GeneralError, "Could not delete the swapped-in IRIS.DAT at " _ liveDAT))
            }
            if '##class(%Library.File).Rename(backupPath, liveDAT) {
                set sc = $$$ADDSC(sc, $$$ERROR($$$GeneralError, "Could not restore the original IRIS.DAT from " _ backupPath _ ". Restore it manually."))
            }
        }
        set mountSC = ##class(SYS.Database).MountDatabase(dbDir)
        if $$$ISERR(mountSC) && '$system.Status.Equals(mountSC, $$$ERRORCODE($$$AlreadyMounted)) {
            set sc = $$$ADDSC(sc, $$$ERROR($$$GeneralError, "Could not remount " _ dbDir _ ". Mount it manually."))
        }
        $$$ThrowStatus(sc)
    }
    quit backupPath
}

/// Loads deps/ export files to register dependency metadata in IPM storage.
/// The dependency code is already in the swapped-in DB; this only makes it visible to `zpm list`.
/// Loads every file even when one fails, since the swap has already landed, then throws all
/// failures together.
ClassMethod RegisterDependencyMetadata(packageDir As %String)
{
    set depsDir = ##class(%Library.File).NormalizeDirectory(
        ##class(%Library.File).NormalizeFilename("deps", packageDir))

    // Each file in deps/ is a standalone IRIS export, one per dependency.
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %Library.File_FileSet(?, ?, ?, ?)",
        depsDir, "*.xml", "", 0)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    set loadSC = $$$OK
    while rs.%Next(.sc) {
        $$$ThrowOnError(sc)
        set fileName = rs.%Get("Name")
        set oneSC = $system.OBJ.Load(fileName, "ck")
        if $$$ISERR(oneSC) {
            // Written as it happens: DisplayError shows only the first error of a combined status.
            write !, "ERROR: failed to register dependency metadata from ", fileName, ": ", $system.Status.GetErrorText(oneSC)
            set loadSC = $$$ADDSC(loadSC, oneSC)
        }
    }
    $$$ThrowOnError(sc)
    $$$ThrowOnError(loadSC)
}

/// Phases a dependency must not run during a database install, with the reason for each.
/// Reload: no source ships for a dependency and Base.%Reload early-exits without a root.
/// Compile: the code is already compiled into IRIS.DAT.
/// "*": the module-refresh checkpoint, meaningful only for the module being installed.
ClassMethod GetDependencyExcludedPhases() As %List
{
    quit $listbuild("Reload", "Compile", "*")
}

/// Derives the phases each dependency runs from the canonical install chain, minus the exclusions.
/// Derived rather than hardcoded so a phase added to GetCompletePhasesForOne is not silently
/// skipped for dependencies.
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
/// Dependencies run first: a dependency's phases may rely on a deeper dependency's files.
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

    set depNames = ..Module.GetDependencyNames()
    set verbose = $get(params("Verbose"))
    set isUpdate = $get(params("Update"), 0)
    set depPhases = ..GetDependencyInstallPhases(isUpdate)
    set ptr = 0
    while $listnext(depNames, ptr, depName) {
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
/// wheel there is nothing to correct and a CPF merge costs a subprocess call. Both affected
/// processors are safe to repeat: a merge applies file values and a present wheel is a no-op.
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
            write !, "Re-merging Configuration Parameter File (CPF) '", resource.Name, "', as a dependency merged a CPF after this module's Initialize phase."
            if resource.Processor.When = "After" {
                $$$ThrowOnError(resource.Processor.OnAfterPhase("Initialize", .params))
            } else {
                $$$ThrowOnError(resource.Processor.OnBeforePhase("Initialize", .params))
            }

        } elseif resource.Processor.%IsA("%IPM.ResourceProcessor.PythonWheel") && $data(depInitClasses("%IPM.ResourceProcessor.PythonWheel")) {
            write !, "Re-installing Python wheel '", resource.Name, "', as a dependency installed a wheel after this module's Initialize phase."
            set handled = 0
            $$$ThrowOnError(resource.Processor.OnPhase("Initialize", .params, .handled))
        }
    }
}

/// Records the processor class of each resource that acts during the Initialize phase.
/// CPF is phase-configurable, so only count it when it actually targets Initialize.
/// initClasses: initClasses(processor class name) = "". Only adds, so it unions across the
/// dependency loop in ApplyDependencyResources; kill it first to get one module's classes.
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

/// Reports a failure after the swap landed. The swap is kept, since the post-swap steps' side effects
/// cannot be undone.
Method ReportPostSwapFailure(
	sc As %Status,
	ns As %String,
	backupPath As %String,
	isUpdate As %Boolean) [ Private ]
{
    write !, "ERROR: the database swap succeeded but a later step failed: ", $system.Status.GetErrorText(sc)
    write !, "  Namespace ", ns, " is running on the newly installed IRIS.DAT. It was not rolled back."
    // Inside an outer transaction the install's commit only folds into it, so the caller's rollback
    // still undoes the records.
    if $tlevel > 0 {
        write !, "  Module metadata is in globals and will be rolled back with the enclosing transaction; the swapped"
        write !, "  IRIS.DAT is a file rename and stays. 'list' will then report the previous version."
    } else {
        write !, "  The record for ", ..Module.Name, " matches the mounted code."
    }
    if isUpdate {
        write !, "  Fix the error reported above. Re-run the same update command, not 'load' or 'install':"
        write !, "  those would mark this version's update steps as done without running them."
    } else {
        write !, "  Fix the error reported above, then re-run the same install."
    }
    write !, "  Re-run from the .tgz or the registry: the package directory no longer holds IRIS.DAT."
    write !, "  To revert manually instead, restore the previous database from: ", backupPath
}

}
