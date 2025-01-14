Include %IPM.Formatting

Class %IPM.Utils.LegacyCompat
{

/// This method updates the superclasses of a list of classes that have been loaded but not compiled.
ClassMethod UpdateSuperclassAndCompile(ByRef pItems, ByRef qSpec = "") As %Status
{
    Set tName = "" 
    For {
        Set tName = $ORDER(pItems(tName))
        If (tName = "") {
            Quit
        } 
        If ($$$lcase($EXTRACT(tName, *-3, *)) '= ".cls") {
            Continue
        }
        Set tClass = $EXTRACT(tName, 1, *-4)

        Set tPairs = $ListBuild(
            $LISTBUILD("%ZPM.PackageManager.Developer.Lifecycle.Module", "%IPM.Lifecycle.Module"),
            $LISTBUILD("%ZPM.PackageManager.Developer.Processor.Abstract", "%IPM.ResourceProcessor.Abstract")
        )
        Set ptr = 0
        While $ListNext(tPairs, ptr, pair) {
            Set $ListBuild(tOldLifecycle, tNewLifecycle) = pair
            If $$$defClassKeyGet(tClass, $$$cCLASSsuper) = tOldLifecycle {
                $$$defClassKeySet(tClass, $$$cCLASSsuper, tNewLifecycle)
                Write !, $$$FormattedLine($$$Magenta, "WARNING: ")
                Write tName _ " extends the deprecated class " _ tOldLifecycle _ ". It has been updated to " _ tNewLifecycle _ " before compilation.", !
            }
        }
    }

    // If the install-time configuration (aka env.json) is set, compile in the current process where singleton %IPM.General.InstallTimeConfig is available 
    // Methods with [CodeMode = objectgenerator] can then use this to access configuration set in env.json
    Set itconfig = ##class(%IPM.General.InstallTimeConfig).%Get()
    If 'itconfig.IsEmpty() {
        Set qSpec = qSpec _ "/multicompile=0"
    }

    Quit $System.OBJ.CompileList(.pItems, .qSpec)
}

}
