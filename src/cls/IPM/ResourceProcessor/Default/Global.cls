Class %IPM.ResourceProcessor.Default.Global Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for global exports.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Global,Preserve";

/// Optional name of global within the file
Property Global As %IPM.DataType.GlobalReference;

/// If set to 1, do not delete the global when the module is cleaned/uninstalled
Property Preserve As %Boolean [ InitialExpression = 0 ];

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "") [ InitialExpression = "gbl/" ];

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
                set tSubDirectory = $select(..ResourceReference.Preload:"preload/",1:"")
                set tResourceDirectory = tRoot _ "/" _ tSubDirectory

                set tSourceRoot = ..ResourceReference.Module.SourcesRoot
                if tSourceRoot'="","\/"'[$extract(tSourceRoot, *) {
                    set tSourceRoot = tSourceRoot _ "/"
                }

                set tDirectory = ..Directory
                if tDirectory'="","\/"'[$extract(tDirectory, *) {
                    set tDirectory = tDirectory _ "/"
                } else {
                    set tDirectory = "gbl/"
                }

                set tResourceDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory_tSourceRoot_tDirectory)

                if tDeveloperMode {
                    set ^Sources("GBL",tName) = tSourcesPrefix_tResourceDirectory
                }

                if '..ResourceReference.Preload {
                    set tResourcePath = tResourceDirectory_$translate(tName,"%,("")","___")_".xml"
                    set tSC = $system.OBJ.Load(tResourcePath,$select(tVerbose:"/display",1:"/nodisplay")_"/nocompile")
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

}
