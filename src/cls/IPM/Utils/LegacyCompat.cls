Include %IPM.Formatting

Class %IPM.Utils.LegacyCompat
{

/// This method updates the superclasses of a list of classes that have been loaded but not compiled.
ClassMethod UpdateSuperclassAndCompile(
	ByRef pItems,
	ByRef qSpec = "") As %Status
{
    set tName = ""
    for {
        set tName = $order(pItems(tName))
        if (tName = "") {
            quit
        }
        if ($$$lcase($extract(tName, *-3, *)) '= ".cls") {
            continue
        }
        set tClass = $extract(tName, 1, *-4)

        set tPairs = $listbuild(
            $listbuild("%ZPM.PackageManager.Developer.Lifecycle.Module", "%IPM.Lifecycle.Module"),
            $listbuild("%ZPM.PackageManager.Developer.Processor.Abstract", "%IPM.ResourceProcessor.Abstract")
        )
        set ptr = 0
        while $listnext(tPairs, ptr, pair) {
            set $listbuild(tOldLifecycle, tNewLifecycle) = pair
            if $$$defClassKeyGet(tClass, $$$cCLASSsuper) = tOldLifecycle {
                $$$defClassKeySet(tClass, $$$cCLASSsuper, tNewLifecycle)
                write !, $$$FormattedLine($$$Magenta, "WARNING: ")
                write tName _ " extends the deprecated class " _ tOldLifecycle _ ". It has been updated to " _ tNewLifecycle _ " before compilation.", !
            }
        }
    }

    // If the install-time configuration (aka env.json) is set, compile in the current process where singleton %IPM.General.EnvironmentConfig is available
    // Methods with [CodeMode = objectgenerator] can then use this to access configuration set in env.json
    if '##class(%IPM.General.EnvironmentConfig).%Get().IsEmpty() {
        set qSpec = qSpec _ "/multicompile=0"
    }

    quit $system.OBJ.CompileList(.pItems, .qSpec)
}

}
