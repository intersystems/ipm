Include (%occErrors, %IPM.Common)

/// The incremental-sync pipeline for a dev-mode module. %IPM.Lifecycle.Base's %Sync phase is a
/// thin delegator to Run below; all the sync orchestration and its helpers live here so Base.cls
/// stays a lifecycle hook surface rather than the sync implementation.
Class %IPM.General.Sync.Pipeline [ Abstract ]
{

/// Incrementally sync changed files from disk into the namespace for a dev-mode module.
/// Detects files changed since last load/sync, routes them to resource processors, and recompiles.
/// module is the lifecycle's already-opened, validated module instance; SyncCheckModuleXml may
/// replace it with a freshly-reloaded instance if module.xml changed.
ClassMethod Run(
    module As %IPM.Storage.Module,
    ByRef params) As %Status
{
    set sc = $$$OK
    try {
        set syncStart = $zhorolog
        set verbose = $get(params("Verbose"), 0)
        set processDeletes = $get(params("ProcessDeletes"), 0)
        set runTests = $get(params("RunTests"), 0)

        // Intentional ByRef mutation of caller's array: params("Sync") is the per-module scratch
        // subtree for test-case tracking. Main.Sync reuses the same params array across modules,
        // so without this kill a prior module's ChangedTestCases leak into this module's SyncRunTests.
        kill params("Sync")

        set moduleName = module.Name

        if 'module.DeveloperMode {
            $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Module '%1' is not in development mode. Sync requires dev mode.", moduleName)))
        }

        set root = ##class(%File).NormalizeDirectory(module.Root)
        if root = "" {
            $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Module '%1' has no root directory configured.", moduleName)))
        }

        // Step 1: Check if module.xml changed; reload manifest if so
        set moduleXmlRelPath = ##class(%IPM.Storage.FileHash).NormalizePath("module.xml")
        set moduleXmlPath = root _ "module.xml"
        set moduleXmlChanged = ..SyncCheckModuleXml(.module, moduleXmlPath, moduleXmlRelPath)

        if '##class(%IPM.Storage.FileHash).HasBaseline(moduleName) {
            // Self-heal: establish baseline for modules loaded before this feature
            $$$ThrowOnError(##class(%IPM.Storage.FileHash).StampModule(module))
            write !, "[", moduleName, "] Baseline established. Run sync again to detect changes."
            quit
        }

        // No StampModule call here after a manifest reload: StampModule would overwrite current
        // hashes for ALL files (including ones the user just edited), causing ComputeChanges to
        // see current-vs-current and report zero changes for co-edited files.
        // Newly-declared resources are handled without a full stamp: SyncBuildReverseIndex
        // (step 3) calls ResolveChildren, which adds their derived relPaths to reverseIndex →
        // manifestPaths. ComputeChanges Pass 2 finds those paths with no baseline row and
        // reports them as modified, so they are loaded in this same sync call.

        // Step 2: Collect scan directories from resource processors, then walk only those.
        // Each processor declares its owned directory via GetSyncDirectory(); sync never
        // touches files outside declared locations.
        set orderedResourceList = module.GetOrderedResourceList()
        kill scanDirs
        set rlKey = ""
        for {
            set rlResource = orderedResourceList.GetNext(.rlKey)
            quit:rlKey=""
            if '$isobject(rlResource.Processor) {
                continue
            }
            if 'rlResource.Processor.SupportsSync() {
                continue
            }
            set syncDir = rlResource.Processor.GetSyncDirectory()
            if syncDir '= "" {
                set scanDirs(syncDir) = ""
            }
        }
        do ##class(%IPM.Storage.FileHash).DeduplicateScanDirs(.scanDirs)

        set walkStart = $zhorolog
        kill allFiles, allHashes, bfsFiles
        $$$ThrowOnError(##class(%IPM.Storage.FileHash).WalkAndHashDirs(root, .scanDirs, .allFiles, .allHashes))

        // module.xml is always tracked — add it to allFiles/allHashes explicitly.
        if ##class(%File).Exists(root _ "module.xml") {
            set allFiles("module.xml") = root _ "module.xml"
            set allHashes("module.xml") = $$$lcase(##class(%File).SHA1Hash(root _ "module.xml", 1))
        }

        // Build compilable-only subset for ComputeChanges Pass 1; count total for verbose.
        set relPath = "", fileCount = 0
        for {
            set relPath = $order(allFiles(relPath), 1, fullPath)
            quit:relPath=""
            set fileCount = fileCount + 1
            set ext = $$$lcase($piece(relPath, ".", *))
            if ",cls,inc,mac,int," [ (","_ext_",") {
                set bfsFiles(relPath) = fullPath
            }
        }
        if verbose {
            set dirCount = 0
            set tmpDir = ""
            for { set tmpDir = $order(scanDirs(tmpDir)) quit:tmpDir=""  set dirCount = dirCount + 1 }
            write !, "[", moduleName, "] Scanned ", fileCount, " file(s) across ", dirCount, " director(ies) in ", $fnumber($zhorolog - walkStart, "", 2), "s"
        }

        // Step 3: Build reverse index (relPath -> owning resource + processor).
        kill reverseIndex, unsupportedResources
        do ..SyncBuildReverseIndex(module, orderedResourceList, .reverseIndex, .unsupportedResources, .allFiles)

        // Collect manifest-derived paths from reverseIndex for ComputeChanges.
        kill manifestPaths
        set riCount = 0
        set riKey = ""
        for {
            set riKey = $order(reverseIndex(riKey))
            quit:riKey=""
            set manifestPaths(riKey) = ""
            set riCount = riCount + 1
        }
        if verbose {
            write !, "[", moduleName, "] Tracking ", riCount, " path(s) across ", orderedResourceList.Count(), " resource(s)"
        }

        // Step 4: Compute disk changes vs baseline
        $$$ThrowOnError(##class(%IPM.Storage.FileHash).ComputeChanges(module, .modified, .deleted, .manifestPaths, .bfsFiles, .allFiles, .allHashes))

        // Exclude module.xml from file routing (handled by SyncCheckModuleXml above)
        kill modified(moduleXmlRelPath)
        kill deleted(moduleXmlRelPath)

        // Falls through when only deletes exist and processDeletes=1
        if '$data(modified) && ('$data(deleted) || 'processDeletes) {
            write !, "[", moduleName, "] Nothing to sync."
            if '$data(modified) && $data(deleted) && 'processDeletes {
                set delCount = 0
                set key = ""
                for { set key = $order(deleted(key)) quit:key=""  set delCount = delCount + 1 }
                write !, "  ", delCount, " deleted file(s) detected but not applied. Use -delete to remove from server."
                do ##class(%IPM.General.Sync.Summary).AddWarning(moduleName, delCount _ " deleted file(s) detected but not applied; use -delete to remove from server.")
            }
            if moduleXmlChanged {
                do ..SyncCommitModuleXml(module, moduleXmlPath, moduleXmlRelPath)
                do ..SyncPrintModuleXmlWarning(moduleName)
            }
            if $data(unsupportedResources) {
                do ..SyncPrintUnsupportedNote(moduleName, verbose, .unsupportedResources)
            }
            write !, "[", moduleName, "] Sync done in ", $fnumber($zhorolog - syncStart, "", 2), "s"
            quit
        }

        // Step 5: Partition changes by owning resource
        kill syncByResource
        do ..SyncRoutePathSet(.modified, .reverseIndex, "modified", .syncByResource)
        if processDeletes {
            do ..SyncRoutePathSet(.deleted, .reverseIndex, "deleted", .syncByResource)
        }

        // Step 6: Dispatch OnSync to each processor; load unhandled compilable files
        if verbose {
            set resCount = 0
            set resName = ""
            for {
                set resName = $order(syncByResource(resName))
                quit:resName=""
                set resCount = resCount + 1
            }
            write !, "[", moduleName, "] Dispatching to ", resCount, " resource(s)"
        }
        $$$ThrowOnError(..SyncDispatchProcessors(module, root, verbose, .syncByResource, .params, .loadItems))

        // Step 7: Compile the full resource set with u-flag to pick up dependent recompiles
        if loadItems > 0 {
            $$$ThrowOnError(..SyncCompile(module, orderedResourceList, verbose, .params))
        }

        // Step 8: Delete server-side documents for removed files, then recompile
        if processDeletes && ($data(deleted) > 1) {
            do ..SyncApplyDeletes(moduleName, .deleted, .reverseIndex, .syncByResource, verbose)
            $$$ThrowOnError(..SyncCompile(module, orderedResourceList, verbose, .params))
        }

        // Step 9: Commit new hashes on success (skipped on error so next sync re-detects).
        // Done before running tests below so a test failure doesn't prevent the file-sync
        // outcome from being committed and reported — file sync and test results are independent.
        $$$ThrowOnError(##class(%IPM.Storage.FileHash).CommitChanges(module, .modified, .deleted, processDeletes))
        if moduleXmlChanged {
            do ..SyncCommitModuleXml(module, moduleXmlPath, moduleXmlRelPath)
        }

        set modCount = 0
        set key = ""
        for {
            set key = $order(modified(key))
            quit:key=""
            set modCount = modCount + 1
            write !, "  Updated: ", key
            do ##class(%IPM.General.Sync.Summary).RecordFile(moduleName, key, "Updated")
        }
        set delCount = 0
        if processDeletes {
            set key = ""
            for {
                set key = $order(deleted(key))
                quit:key=""
                set delCount = delCount + 1
                write !, "  Deleted: ", key
                do ##class(%IPM.General.Sync.Summary).RecordFile(moduleName, key, "Deleted")
            }
        }
        write !, "[", moduleName, "] Sync complete: ", modCount, " file(s) updated"
        if delCount > 0 {
            write ", ", delCount, " deleted"
        }
        write "."

        if moduleXmlChanged {
            do ..SyncPrintModuleXmlWarning(moduleName)
        }
        if $data(unsupportedResources) {
            do ..SyncPrintUnsupportedNote(moduleName, verbose, .unsupportedResources)
        }

        write !, "[", moduleName, "] Sync done in ", $fnumber($zhorolog - syncStart, "", 2), "s"

        // File sync is committed and reported. Mark success before running tests so a fatal
        // test failure below is reported as a test failure, not a sync error, in the summary.
        do ##class(%IPM.General.Sync.Summary).MarkSyncOK(moduleName)

        // Step 10: Run changed test-phase tests if -test flag is set (after sync is reported)
        if runTests {
            $$$ThrowOnError(..SyncRunTests(orderedResourceList, verbose, .params))
        }

    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Check if module.xml changed and reload the manifest if so.
/// Returns 1 if module.xml changed and was reloaded, 0 otherwise.
/// On reload, replaces module with the freshly-opened instance.
ClassMethod SyncCheckModuleXml(
    ByRef module As %IPM.Storage.Module,
    moduleXmlPath As %String,
    moduleXmlRelPath As %String) As %Boolean [ Private ]
{
    if '##class(%File).Exists(moduleXmlPath) {
        quit 0
    }
    set existing = ##class(%IPM.Storage.FileHash).ModulePathIndexOpen(module.Name, moduleXmlRelPath)
    if '$isobject(existing) {
        quit 0
    }
    set newHash = $$$lcase(##class(%File).SHA1Hash(moduleXmlPath, 1))
    if newHash = existing.Hash {
        quit 0
    }
    $$$ThrowOnError($system.OBJ.Load(moduleXmlPath, "-d"))
    set module = ##class(%IPM.Storage.Module).NameOpen(module.Name, , .openSC)
    $$$ThrowOnError(openSC)
    quit 1
}

/// Build a reverse index: normalizedRelPath -> resource name, Processor, Resource object.
/// Used by SyncRoutePathSet to map changed files back to their owning resource processors.
/// Skips resources whose processor does not support sync — those are collected in
/// unsupportedResources(resourceName)="" for informational display.
///
/// Step 1 builds docToResource (docName → owner) from ResolveChildren, and prefix-scans
/// allFiles for directory-owned resources (e.g. test dirs) via GetSyncDirectory().
/// Step 2 maps all stored baseline paths to owners via RelPathToDocName → docToResource.
ClassMethod SyncBuildReverseIndex(module As %IPM.Storage.Module, orderedResourceList As %ListOfObjects, ByRef reverseIndex, Output unsupportedResources, ByRef allFiles) [ Private ]
{
    kill unsupportedResources
    // docToResource maps server document names (e.g. "SyncTest.SuperClass.CLS") to the
    // resource that owns them. This lets us resolve filesystem paths → owners in O(1) below,
    // since RelPathToDocName converts a relPath to a docName deterministically.
    kill docToResource
    set key = ""
    for {
        set resource = orderedResourceList.GetNext(.key)
        quit:key=""

        if '$isobject(resource.Processor) {
            continue
        }

        if 'resource.Processor.SupportsSync() {
            set unsupportedResources(resource.Name) = ""
            continue
        }

        // ResolveChildren returns childArr keyed by document name (server-side identifier).
        kill childArr
        set childSC = resource.ResolveChildren(.childArr)
        if $$$ISERR(childSC) {
            continue
        }

        set childName = ""
        for {
            set childName = $order(childArr(childName))
            quit:childName=""
            set docToResource(childName) = resource.Name
            set docToResource(childName, "Processor") = resource.Processor
            set docToResource(childName, "Resource") = resource

            // Newly-declared resources have no baseline row yet (StampModule skips uncompiled
            // classes), so GetStoredPaths below won't find them. Map their relPath directly.
            set relPath = $get(childArr(childName, "RelativePath"))
            if relPath = "" {
                set relPath = resource.Processor.OnItemRelativePath(childName)
            }
            if relPath '= "" {
                set normalizedRelPath = ##class(%IPM.Storage.FileHash).NormalizePath(relPath)
                set reverseIndex(normalizedRelPath) = resource.Name
                set reverseIndex(normalizedRelPath, "Processor") = resource.Processor
                set reverseIndex(normalizedRelPath, "Resource") = resource
            }
        }

        // Directory-based resources (e.g. test dirs) own all files under their declared
        // directory. Prefix-scan allFiles to map every file under that dir to this resource.
        set syncDir = resource.Processor.GetSyncDirectory()
        if syncDir '= "" {
            set prefix = ##class(%IPM.Storage.FileHash).NormalizePath(syncDir _ "/")
            set prefixLen = $length(prefix)
            set dirRelPath = prefix
            for {
                set dirRelPath = $order(allFiles(dirRelPath))
                quit:dirRelPath=""
                quit:($extract(dirRelPath, 1, prefixLen) '= prefix)
                if '$data(reverseIndex(dirRelPath)) {
                    set reverseIndex(dirRelPath) = resource.Name
                    set reverseIndex(dirRelPath, "Processor") = resource.Processor
                    set reverseIndex(dirRelPath, "Resource") = resource
                }
            }
        }
    }

    // Resolve compilable paths: every baseline path not already claimed above gets mapped
    // through RelPathToDocName → docToResource.
    kill storedPaths
    do ##class(%IPM.Storage.FileHash).GetStoredPaths(module.Name, .storedPaths)
    set relPath = ""
    for {
        set relPath = $order(storedPaths(relPath))
        quit:relPath=""

        if $data(reverseIndex(relPath)) {
            continue
        }

        set docName = ##class(%IPM.Storage.FileHash).RelPathToDocName(relPath)
        if docName = "" {
            continue
        }
        if '$data(docToResource(docName)) {
            continue
        }

        set reverseIndex(relPath) = docToResource(docName)
        set reverseIndex(relPath, "Processor") = docToResource(docName, "Processor")
        set reverseIndex(relPath, "Resource") = docToResource(docName, "Resource")
    }
}

/// Route a set of changed paths to their owning resources, categorized by type (modified/deleted).
/// Only sync-supporting resources appear in reverseIndex, so no filtering needed here.
ClassMethod SyncRoutePathSet(
    ByRef paths,
    ByRef reverseIndex,
    category As %String,
    ByRef syncByResource) [ Private ]
{
    set relPath = ""
    for {
        set relPath = $order(paths(relPath))
        quit:relPath=""

        if '$data(reverseIndex(relPath)) {
            continue
        }
        set resName = reverseIndex(relPath)
        set syncByResource(resName, category, relPath) = ""
        set syncByResource(resName, "Processor") = reverseIndex(relPath, "Processor")
        set syncByResource(resName, "Resource") = reverseIndex(relPath, "Resource")
    }
}

/// Call OnSync on each processor, then load any unhandled compilable files.
/// Returns the number of files loaded (used to decide whether SyncCompile is needed).
/// If a processor sets handled=1 in OnSync, it fully owns the sync for that resource
/// (e.g. Test reloads its own way). Otherwise the default path loads+compiles each file.
ClassMethod SyncDispatchProcessors(
    module As %IPM.Storage.Module,
    root As %String,
    verbose As %Boolean,
    ByRef syncByResource,
    ByRef params,
    Output loadItems As %Integer = 0) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        set resName = ""
        for {
            set resName = $order(syncByResource(resName))
            quit:resName=""

            if '$data(syncByResource(resName, "Processor")) {
                continue
            }
            set processor = syncByResource(resName, "Processor")

            kill resModified, resDeleted
            merge resModified = syncByResource(resName, "modified")
            merge resDeleted = syncByResource(resName, "deleted")

            set handled = 0
            $$$ThrowOnError(processor.OnSync(.resModified, .resDeleted, .params, .handled))

            if handled || 'processor.%IsA("%IPM.ResourceProcessor.AbstractCompilable") {
                continue
            }

            // Default: load each changed file; SyncCompile will do a full compile with u-flag
            set loadRelPath = ""
            for {
                set loadRelPath = $order(resModified(loadRelPath))
                quit:loadRelPath=""

                set fullPath = ##class(%File).NormalizeFilename(loadRelPath, root)
                if ##class(%File).Exists(fullPath) {
                    set loadFlags = $select(verbose:"d", 1:"-d")
                    $$$ThrowOnError($system.OBJ.Load(fullPath, loadFlags _ "c"))
                    set loadItems = loadItems + 1
                }
            }
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Delete server-side documents for compilable deleted files.
/// Guards skip paths with no owner, no processor, or non-compilable processors — those are
/// handled elsewhere (unsupported warnings) or aren't server-side documents at all.
ClassMethod SyncApplyDeletes(
    moduleName As %String,
    ByRef deleted,
    ByRef reverseIndex,
    ByRef syncByResource,
    verbose As %Boolean) As %Status [ Private ]
{
    set sc = $$$OK
    set relPath = ""
    for {
        set relPath = $order(deleted(relPath))
        quit:relPath=""

        if '$data(reverseIndex(relPath)) {
            continue
        }
        set resName = reverseIndex(relPath)
        if '$data(syncByResource(resName, "Processor")) {
            continue
        }
        set processor = syncByResource(resName, "Processor")
        if 'processor.%IsA("%IPM.ResourceProcessor.AbstractCompilable") {
            continue
        }
        set docName = ##class(%IPM.Storage.FileHash).RelPathToDocName(relPath)
        if docName '= "" {
            set delFlags = $select(verbose:"d", 1:"-d")
            set delSC = $system.OBJ.Delete(docName, delFlags)
            // Delete failures are non-fatal: the SyncCompile pass that immediately follows
            // will fail to compile any class that still references the deleted doc, surfacing
            // the error with full context. Aborting the delete loop here would leave other
            // deletions unapplied and make the overall error harder to diagnose.
            // Non-fatal: the SyncCompile pass that follows will surface any compilation errors
            // caused by the still-present document, giving the user full context. Aborting here
            // would leave remaining deletions unapplied and make the overall error harder to diagnose.
            if $$$ISERR(delSC) {
                set errText = $system.Status.GetOneErrorText(delSC)
                write !, "Warning: could not delete ", docName, ": ", errText
                do ##class(%IPM.General.Sync.Summary).AddWarning(moduleName, "Could not delete " _ docName _ ": " _ errText)
                set sc = $$$ADDSC(sc, delSC)
            }
        }
    }
    quit sc
}

/// Run test-phase tests for changed test case classes recorded in params("Sync","ChangedTestCases").
/// Groups changed classes by owning resource first, then dispatches one batched RunTest call
/// per resource (via OnSyncRunTests) instead of one call per class — avoids N separate
/// reload/compile/run cycles when several test classes in the same resource changed together.
ClassMethod SyncRunTests(
    orderedResourceList As %ListOfObjects,
    verbose As %Boolean,
    ByRef params) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        // Step 1: group changed classes by owning resource: byResource(resourceName, className) = ""
        kill byResource
        set className = ""
        for {
            set className = $order(params("Sync", "ChangedTestCases", className), 1, owningResource)
            quit:className=""
            set byResource(owningResource, className) = ""
        }

        // Step 2: one OnSyncRunTests call per resource
        set testKey = ""
        for {
            set testResource = orderedResourceList.GetNext(.testKey)
            quit:testKey=""

            if '$isobject(testResource.Processor) {
                continue
            }
            if 'testResource.Processor.%IsA("%IPM.ResourceProcessor.Test") {
                continue
            }
            if '$data(byResource(testResource.Name)) {
                continue
            }
            if '$listfind(testResource.Processor.Phase, "test") {
                set skipClassName = ""
                for {
                    set skipClassName = $order(byResource(testResource.Name, skipClassName))
                    quit:skipClassName=""
                    write:verbose !, "Skipping verify-scoped test: ", skipClassName, " (use 'verify' to run)"
                    do ##class(%IPM.General.Sync.Summary).AddSkipped(testResource.Module.Name, skipClassName)
                }
                continue
            }
            kill classInfo
            merge classInfo = byResource(testResource.Name)
            kill testParams
            merge testParams = params
            set testParams("DeveloperMode") = 1
            $$$ThrowOnError(testResource.Processor.OnSyncRunTests(.classInfo, .testParams))
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Commit the current module.xml hash to the baseline.
ClassMethod SyncCommitModuleXml(
    module As %IPM.Storage.Module,
    moduleXmlPath As %String,
    moduleXmlRelPath As %String) [ Private ]
{
    kill moduleXmlMod, emptyDel
    set moduleXmlMod(moduleXmlRelPath) = $$$lcase(##class(%File).SHA1Hash(moduleXmlPath, 1))
    set commitSC = ##class(%IPM.Storage.FileHash).CommitChanges(module, .moduleXmlMod, .emptyDel, 0)
    if $$$ISERR(commitSC) {
        // Non-fatal: the next sync will re-detect module.xml as changed and reload the manifest again.
        write !, "Warning: failed to record module.xml hash: ", $system.Status.GetOneErrorText(commitSC)
    }
}

ClassMethod SyncPrintModuleXmlWarning(moduleName As %String) [ Private ]
{
    write !
    write !, "Warning: module.xml changed and was reloaded."
    write !, "  Resources may have been added/removed. Run `reload ", moduleName, "` to fully apply"
    write !, "  manifest-level changes (mappings, dependencies, defaults)."
    do ##class(%IPM.General.Sync.Summary).AddWarning(moduleName, "module.xml changed and was reloaded; run `reload " _ moduleName _ "` to fully apply.")
}

ClassMethod SyncPrintUnsupportedNote(moduleName As %String, verbose As %Boolean, ByRef unsupportedResources) [ Private ]
{
    set count = 0
    set names = ""
    set resName = ""
    for {
        set resName = $order(unsupportedResources(resName))
        quit:resName=""
        set count = count + 1
        if count <= 3 {
            set names = names _ $select(names="":"", 1:", ") _ resName
        }
    }
    if count > 3 {
        set names = names _ ", ... (" _ (count - 3) _ " more)"
    }
    if verbose {
        write !, "[", moduleName, "] ", count, " resource(s) skipped (no sync support): ", names
        write !, "  Use `reload ", moduleName, "` to apply changes to those resources."
    }
    do ##class(%IPM.General.Sync.Summary).AddWarning(moduleName, count _ " resource(s) skipped (no sync support): " _ names _ ".")
}

/// Recompile all compilable resources in the module to catch dependents invalidated by
/// changes loaded in SyncDispatchProcessors. Skips CompileFromProject resources — those are
/// deployed code loaded via Studio project files (.prj); compiling them individually would
/// fail because deployed classes have no source in the routine database.
ClassMethod SyncCompile(module As %IPM.Storage.Module, orderedResourceList As %ListOfObjects, verbose As %Boolean = 0, ByRef params) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        kill compileArray

        set key = ""
        for {
            set resource = orderedResourceList.GetNext(.key)
            quit:key=""

            if '$isobject(resource.Processor) {
                continue
            }
            if 'resource.Processor.%IsA("%IPM.ResourceProcessor.AbstractCompilable") {
                continue
            }
            if 'resource.IsInScope("Compile") {
                continue
            }
            if resource.Processor.CompileFromProject {
                continue
            }

            kill oneResourceList
            set oneResourceList(resource.Name) = ""
            set resSC = resource.ResolveChildren(.oneResourceList)
            if $$$ISERR(resSC) {
                continue
            }

            set childKey = ""
            for {
                set childKey = $order(oneResourceList(childKey))
                quit:childKey=""
                set ext = $zconvert($piece(childKey, ".", *), "U")
                if ext = "CLS" {
                    set className = $piece(childKey, ".", 1, *-1)
                    if '$$$comClassDefined(className) {
                        continue
                    }
                }
                set compileArray(childKey) = ""
            }
        }

        if $data(compileArray) > 1 {
            set flags = $select(verbose:"d", 1:"-d") _ "cku"
            set sc = ##class(%IPM.Utils.LegacyCompat).UpdateSuperclassAndCompile(.compileArray, .flags)
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

}
