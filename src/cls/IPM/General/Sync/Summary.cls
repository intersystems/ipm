/// Naked-sync summary accumulator. Main.Sync ("sync" with no module named) opens the summary with
/// Begin, runs its per-module loop, then prints with Report. While open, each module's %Sync
/// records its own outcome into the process-private global ^||IPM.Sync.Summary so the reader can
/// aggregate without threading data through ExecutePhases' by-ref params. Shape:
///   ^||IPM.Sync.Summary("Active")                        = 1 while a sync-all is in progress
///   ^||IPM.Sync.Summary("Module",name,"File",relPath)    = "Updated" | "Deleted"
///   ^||IPM.Sync.Summary("Module",name,"SyncOK")          = 1 once file sync committed (pre-tests)
///   ^||IPM.Sync.Summary("Module",name,"TestsPassed")     = running count of passed test methods
///   ^||IPM.Sync.Summary("Module",name,"TestsFailed")     = running count of failed test methods
///   ^||IPM.Sync.Summary("Module",name,"Skipped",seq)     = verify-scoped test class not run
///   ^||IPM.Sync.Summary("Module",name,"Warning",seq)     = warning text
/// Every recorder is a no-op unless "Active" is set, so a single-module sync (which never calls
/// Begin) records nothing and prints no summary.
///
/// SyncOK separates a genuine sync failure from a test failure: %Sync runs tests with
/// FailuresAreFatal, so a failing test makes %Sync return an error status just like a compile
/// failure would. %Sync sets SyncOK once file sync is committed (before tests run), so the
/// reader can tell the two apart — a module in the failures list with SyncOK set had its files
/// synced fine and only a test failed; without SyncOK the sync itself failed.
Class %IPM.General.Sync.Summary [ Abstract ]
{

ClassMethod Begin() [ Internal ]
{
    kill ^||IPM.Sync.Summary
    set ^||IPM.Sync.Summary("Active") = 1
}

ClassMethod End() [ Internal ]
{
    kill ^||IPM.Sync.Summary
}

/// Record one synced file for the module. action is "Updated" or "Deleted".
ClassMethod RecordFile(
    moduleName As %String,
    relPath As %String,
    action As %String) [ Internal ]
{
    if '$get(^||IPM.Sync.Summary("Active")) {
        quit
    }
    set ^||IPM.Sync.Summary("Module", moduleName, "File", relPath) = action
}

/// Mark that the module's file sync committed successfully. Called by %Sync just before it runs
/// tests, so a later test failure (which returns an error status) is distinguishable from a
/// sync/compile failure that never reached this point.
ClassMethod MarkSyncOK(moduleName As %String) [ Internal ]
{
    if '$get(^||IPM.Sync.Summary("Active")) {
        quit
    }
    set ^||IPM.Sync.Summary("Module", moduleName, "SyncOK") = 1
}

/// Record a verify-scoped test class that sync detected as changed but did not run (needs
/// `verify`). Called once per skipped class by SyncRunTests.
ClassMethod AddSkipped(
    moduleName As %String,
    className As %String) [ Internal ]
{
    if '$get(^||IPM.Sync.Summary("Active")) {
        quit
    }
    set seq = $increment(^||IPM.Sync.Summary("Module", moduleName, "SkippedCount"))
    set ^||IPM.Sync.Summary("Module", moduleName, "Skipped", seq) = className
}

/// Record one advisory warning for the module (e.g. module.xml reloaded, deletes not applied).
ClassMethod AddWarning(
    moduleName As %String,
    text As %String) [ Internal ]
{
    if '$get(^||IPM.Sync.Summary("Active")) {
        quit
    }
    set seq = $increment(^||IPM.Sync.Summary("Module", moduleName, "WarningCount"))
    set ^||IPM.Sync.Summary("Module", moduleName, "Warning", seq) = text
}

/// Add to the module's running test-method pass/fail tally. Called once per test resource by
/// OnSyncRunTests.
ClassMethod AddTests(
    moduleName As %String,
    passed As %Integer,
    failed As %Integer) [ Internal ]
{
    if '$get(^||IPM.Sync.Summary("Active")) {
        quit
    }
    set ^||IPM.Sync.Summary("Module", moduleName, "TestsPassed") = $get(^||IPM.Sync.Summary("Module", moduleName, "TestsPassed"), 0) + passed
    set ^||IPM.Sync.Summary("Module", moduleName, "TestsFailed") = $get(^||IPM.Sync.Summary("Module", moduleName, "TestsFailed"), 0) + failed
}

/// Print the bordered sync-all summary from the accumulated ^||IPM.Sync.Summary data.
/// orderedNames is the full dependency-ordered dev-mode module list (the "checked" set);
/// failures is the $list of module names whose Sync phase returned an error status. A module in
/// failures that still recorded SyncOK synced its files fine and only had a failing test — that
/// is reflected in its test tally, not the Errors row (see SyncOK). A per-module line is shown
/// only for modules that were updated, had a real sync error, or ran/skipped tests — unchanged
/// modules are implied by the "checked" count.
ClassMethod Report(
    orderedNames As %List,
    failures As %List = "") [ Internal ]
{
    if '$get(^||IPM.Sync.Summary("Active")) {
        quit
    }
    set border = $translate($justify("", 64), " ", "=")
    set checkedCount = $listlength(orderedNames)

    // Header count: modules that actually had at least one file change.
    set updatedCount = 0
    for i = 1:1:checkedCount {
        set name = $list(orderedNames, i)
        if $data(^||IPM.Sync.Summary("Module", name, "File")) {
            set updatedCount = updatedCount + 1
        }
    }

    write !!, border
    write !, "Sync Summary"
    write !, border

    // Write module name list, wrapping at border width with aligned continuation lines.
    set linePrefix = "Modules checked:  " _ checkedCount _ "  ("
    set contPrefix = $justify("", $length(linePrefix))
    set nameLine = linePrefix
    for i = 1:1:checkedCount {
        set name = $list(orderedNames, i)
        set sep = $select(i < checkedCount: ", ", 1: ")")
        if ($length(nameLine) + $length(name) + $length(sep)) > $length(border) && (nameLine '= linePrefix) {
            write !, nameLine
            set nameLine = contPrefix
        }
        set nameLine = nameLine _ name _ sep
    }
    write !, nameLine
    write !, "Modules updated:  ", updatedCount

    set warningCount = 0, errorNames = ""
    kill warnings
    for i = 1:1:checkedCount {
        set name = $list(orderedNames, i)

        set fileCount = 0
        set relPath = ""
        for {
            set relPath = $order(^||IPM.Sync.Summary("Module", name, "File", relPath))
            quit:relPath=""
            set fileCount = fileCount + 1
        }
        // A real sync error: the Sync phase failed AND file sync never committed. If SyncOK is
        // set, the phase error came from a fatal test failure, not from sync itself.
        set isError = $listfind(failures, name) && '$get(^||IPM.Sync.Summary("Module", name, "SyncOK"))
        if isError {
            set errorNames = errorNames _ $listbuild(name)
        }
        set passed = $get(^||IPM.Sync.Summary("Module", name, "TestsPassed"))
        set failed = $get(^||IPM.Sync.Summary("Module", name, "TestsFailed"))
        set hasTests = (passed '= "") || (failed '= "")
        set skippedCount = $get(^||IPM.Sync.Summary("Module", name, "SkippedCount"), 0)

        if fileCount || isError || hasTests || skippedCount {
            set line = "  " _ name
            if fileCount {
                set line = line _ "   " _ fileCount _ " file" _ $select(fileCount = 1:"", 1:"s")
            }
            if hasTests {
                // "passed/total" already conveys the failure count; no redundant "N failed".
                set line = line _ "   tests " _ (+passed) _ "/" _ ((+passed) + (+failed))
            }
            if isError {
                set line = line _ "   ERROR"
            }
            write !, line
            // Enumerate verify-scoped test classes that were detected but not run.
            set sseq = ""
            for {
                set sseq = $order(^||IPM.Sync.Summary("Module", name, "Skipped", sseq), 1, skippedClass)
                quit:sseq=""
                write !, "    skipped (verify-scoped): ", skippedClass
            }
        }

        // Collect this module's warnings for the aggregated section below.
        set wseq = ""
        for {
            set wseq = $order(^||IPM.Sync.Summary("Module", name, "Warning", wseq), 1, wtext)
            quit:wseq=""
            set warningCount = warningCount + 1
            set warnings(warningCount) = "  [" _ name _ "] " _ wtext
        }
    }

    if errorNames '= "" {
        write !, "Errors:    ", $listtostring(errorNames, ", ")
    }
    if warningCount {
        write !, "Warnings:  ", warningCount
        for i = 1:1:warningCount {
            write !, warnings(i)
        }
    }
    write !, border
}

}
