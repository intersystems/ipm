Class %IPM.ResourceProcessor.Default.Global Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for global exports.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Global,Preserve,Directory,FilenameTranslateIdentifier,FilenameTranslateAssociator";

/// Optional name of global within the file
Property Global As %IPM.DataType.GlobalReference;

/// If set to 1, do not delete the global when the module is cleaned/uninstalled
Property Preserve As %Boolean [ InitialExpression = 0 ];

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "") [ InitialExpression = "gbl/" ];

/// Characters in the resource name to translate when building the filename.
Property FilenameTranslateIdentifier As %String [ InitialExpression = "%,("")" ];

/// Replacement characters corresponding to FilenameTranslateIdentifier.
Property FilenameTranslateAssociator As %String [ InitialExpression = "___" ];

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set pResourceHandled = 0
    try {
        set tVerbose = $get(pParams("Verbose"),0)
        set tDeveloperMode = $get(pParams("DeveloperMode"),0)
        set tName = $piece(..ResourceReference.Name,".",1,*-1)
        set tRoot = ..ResourceReference.Module.Root
        if (pPhase = "Reload") {
            set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$get(pParams("Reload","ForceLocalScope"),0)
            set tSourcesPrefix = $char($parameter("%IPM.ExtensionBase.SourceControl.Interface","NOPREFIXCHARCODE"))

            // Format: ^^directory (to which the global is currently mapped)
            set tGlobalDBDir = $$$GBLDB(@("^"_$piece(..ResourceReference.Name,".",1,*-1)))
            set tGlobalDB = ##class(%IPM.Utils.Module).GetGlobalDatabase($namespace)
            set tExpectedDir = "^^"_##class(%IPM.Utils.Module).GetDatabaseDirectory(tGlobalDB)

            // Normalize the directory name in case of case-insensitivity
            set tGlobalDBDir = ##class(%File).NormalizeDirectory($extract(tGlobalDBDir,3,*))
            set tExpectedDir = ##class(%File).NormalizeDirectory($extract(tExpectedDir,3,*))

            // See if global must be mapped to be loaded into the current default DB for globals
            if 'tGlobalScope && (tGlobalDBDir '= tExpectedDir) && '$get(pParams("NoMapping"),0) {
                set tSC = ##class(%IPM.Utils.Module).AddGlobalMapping($namespace,tName,tGlobalDB)
                if $$$ISERR(tSC) {
                    quit
                }
            }

            if '..ResourceReference.Generated {
                set relativePath = ..OnItemRelativePath(..ResourceReference.Name)
                set resourcePath = ##class(%File).NormalizeFilename(tRoot _ "/" _ relativePath)
                set resourceDirectory = ##class(%File).GetDirectory(resourcePath)

                if tDeveloperMode {
                    set ^Sources("GBL", tName) = tSourcesPrefix _ resourceDirectory
                }

                if '..ResourceReference.Preload {
                    set tSC = $system.OBJ.Load(resourcePath, $select(tVerbose:"/display", 1:"/nodisplay") _ "/nocompile")
                    if $$$ISERR(tSC) {
                        quit
                    }
                }
            }
            set pResourceHandled = 1
        } elseif (pPhase = "Clean") {
            set pResourceHandled = 1
            if (..Global '= "") && ('..Preserve) {
                kill @..Global
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Sets the relative path for the globals resource so the packaging phase
/// exports the file to the correct location, respecting SourcesRoot.
Method OnResolveChildren(ByRef resourceArray) As %Status
{
    set resourceArray(..ResourceReference.Name, "RelativePath") = ..OnItemRelativePath(..ResourceReference.Name)
    quit $$$OK
}

/// Returns the path of <var>itemName</var> relative to the module root,
/// including SourcesRoot and the configured Directory.
Method OnItemRelativePath(itemName As %String) As %String
{
    set sourceRoot = ..ResourceReference.Module.SourcesRoot
    // Append trailing slash only if sourceRoot is non-empty and doesn't already end with / or \
    if (sourceRoot '= "") && ("\/" '[ $extract(sourceRoot, *)) {
        set sourceRoot = sourceRoot _ "/"
    }

    set directory = ..Directory
    if directory = "" {
        set directory = "gbl/"
    } elseif "\/" '[ $extract(directory, *) {
        set directory = directory _ "/"
    }

    set name = $piece(itemName, ".", 1, * - 1)
    quit $select(..ResourceReference.Preload:"preload/", 1:"") _ sourceRoot _ directory _ $translate(name, ..FilenameTranslateIdentifier, ..FilenameTranslateAssociator) _ ".xml"
}

}
