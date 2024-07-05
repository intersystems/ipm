Include %IPM.Formatting

Class %IPM.Utils.LegacyCompat
{

/// This method updates the superclasses of a list of classes that have been loaded but not compiled.
ClassMethod UpdateSuperclassAndCompile(ByRef tClasses, ByRef qSpec = "") As %Status
{
    Set tName = "" 
    Set tToCompile = ""
    For {
        Set tName = $ORDER(tClasses(tName))
        If (tName = "") { Quit } 
        If ($$$lcase($EXTRACT(tName, *-3, *)) '= ".cls") { Continue }

        Set tClassName = $EXTRACT(tName, 1, *-4)
        Set tToCompile(tClassName) = ""
        Set tClass = ##class(%Dictionary.ClassDefinition).%OpenId(tClassName)

        // Assuming this is the only one we care about. Eventually it may become a list.
        Set tOldLifecycle = "%ZPM.PackageManager.Developer.Lifecycle.Module"
        Set tNewLifecycle = "%IPM.Lifecycle.Module"
        
        If tClass.Super = tOldLifecycle {
            Set tClass.Super = tNewLifecycle
            $$$ThrowOnError(tClass.%Save())
            Write !, $$$FormattedLine($$$Magenta, "WARNING: ")
            Write tName _ " extends the deprecated class " _ tOldLifecycle _ ". It has been updated to " _ tNewLifecycle _ " before compiled.", !
        }
    }
    Quit $System.OBJ.Compile(.tToCompile, .qSpec)
}

}
