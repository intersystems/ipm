/// Sync output that always writes to the current device, regardless of whether a whole-namespace
/// sync (`sync` with no module named) is in progress. Contrast %IPM.General.Sync.Summary, whose
/// recorders are gated on such a run being active.
Class %IPM.General.Sync.Output [ Abstract ]
{

/// Write a module-scoped status line: "[moduleName] text". Single place for the bracketed
/// per-module prefix so the many status writes in the pipeline stay consistent.
ClassMethod Log(moduleName As %String, text As %String) [ Internal ]
{
    write !, "[", moduleName, "] ", text
}

/// Count the top-level subscripts of an array. Used for the verbose "N file(s)"/"N path(s)"
/// status lines, which report only top-level keys and ignore any child nodes.
ClassMethod CountNodes(ByRef array) As %Integer [ Internal ]
{
    set count = 0
    set key = ""
    for {
        set key = $order(array(key))
        quit:key=""
        set count = count + 1
    }
    quit count
}

/// Shared closing output for both pipeline exit paths (nothing-to-sync and full sync): the
/// module.xml reload warning, the preload bootstrap warning, the unsupported-resource note, and
/// the total-elapsed line. Kept in one place so the two branches can't drift apart.
/// preloadResources is empty on the nothing-to-sync path, where no resource was routed.
ClassMethod PrintTail(
    moduleName As %String,
    verbose As %Boolean,
    moduleXmlChanged As %Boolean,
    syncStart As %Numeric,
    ByRef unsupportedResources,
    ByRef preloadResources) [ Internal ]
{
    if moduleXmlChanged {
        do ..PrintModuleXmlWarning(moduleName)
    }
    if $data(preloadResources) {
        do ..PrintPreloadWarning(moduleName, .preloadResources)
    }
    if $data(unsupportedResources) {
        do ..PrintUnsupportedNote(moduleName, verbose, .unsupportedResources)
    }
    do ..Log(moduleName, "Sync done in "_$fnumber($zhorolog - syncStart, "", 2)_"s")
}

ClassMethod PrintModuleXmlWarning(moduleName As %String) [ Internal ]
{
    write !
    write !, "WARNING: module.xml changed and was reloaded."
    write !, "  Resources may have been added/removed. Run `reload ", moduleName, "` to fully apply"
    write !, "  manifest-level changes (mappings, dependencies, defaults)."
    do ##class(%IPM.General.Sync.Summary).AddWarning(moduleName, "module.xml changed and was reloaded; run `reload " _ moduleName _ "` to fully apply.")
}

/// Warn that preload resources were synced without re-running the Initialize-phase bootstrap.
ClassMethod PrintPreloadWarning(moduleName As %String, ByRef preloadResources) [ Internal ]
{
    set names = ""
    set resName = ""
    for {
        set resName = $order(preloadResources(resName))
        quit:resName=""
        set names = names _ $select(names="":"", 1:", ") _ resName
    }
    write !
    write !, "WARNING: preload resource(s) changed and were synced: ", names
    write !, "  Bootstrap was not re-run. Preload code (installer classes, custom resource"
    write !, "  processors) only takes effect during a lifecycle run, so run `reload ", moduleName, "`"
    write !, "  if the change affects module loading itself."
    do ##class(%IPM.General.Sync.Summary).AddWarning(moduleName, "Preload resource(s) changed and were synced: " _ names _ ". Bootstrap was not re-run; run `reload " _ moduleName _ "` if the change affects module loading.")
}

ClassMethod PrintUnsupportedNote(moduleName As %String, verbose As %Boolean, ByRef unsupportedResources) [ Internal ]
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
        do ..Log(moduleName, count_" resource(s) skipped (no sync support): "_names)
        write !, "  Use `reload ", moduleName, "` to apply changes to those resources."
    }
    do ##class(%IPM.General.Sync.Summary).AddWarning(moduleName, count _ " resource(s) skipped (no sync support): " _ names _ ".")
}

}
