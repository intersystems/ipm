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

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResourceHandled = 0
	Try {
		Set tVerbose = $Get(pParams("Verbose"),0)
		Set tDeveloperMode = $Get(pParams("DeveloperMode"),0)
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tRoot = ..ResourceReference.Module.Root
		If (pPhase = "Reload") {
			Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
			Set tSourcesPrefix = $c($parameter("%IPM.ExtensionBase.SourceControl.Interface","NOPREFIXCHARCODE"))
			
			// Format: ^^directory (to which the global is currently mapped)
			Set tGlobalDBDir = $$$GBLDB(@("^"_$Piece(..ResourceReference.Name,".",1,*-1)))
			Set tGlobalDB = ##class(%IPM.Utils.Module).GetGlobalDatabase($Namespace)
			Set tExpectedDir = "^^"_##class(%IPM.Utils.Module).GetDatabaseDirectory(tGlobalDB)
			
			// Normalize the directory name in case of case-insensitivity
			Set tGlobalDBDir = ##class(%File).NormalizeDirectory($e(tGlobalDBDir,3,*))
			Set tExpectedDir = ##class(%File).NormalizeDirectory($e(tExpectedDir,3,*))
			
			// See if global must be mapped to be loaded into the current default DB for globals
			If 'tGlobalScope && (tGlobalDBDir '= tExpectedDir) && '$Get(pParams("NoMapping"),0) {
				Set tSC = ##class(%IPM.Utils.Module).AddGlobalMapping($Namespace,tName,tGlobalDB)
				If $$$ISERR(tSC) {
					Quit
				}
			}
			
			If '..ResourceReference.Generated {
				Set tSubDirectory = $Select(..ResourceReference.Preload:"preload/",1:"")
				Set tResourceDirectory = tRoot _ "/" _ tSubDirectory
				
        Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
				If tSourceRoot'="","\/"'[$EXTRACT(tSourceRoot, *) {
					Set tSourceRoot = tSourceRoot _ "/"
				}

				Set tDirectory = ..Directory
				If tDirectory'="","\/"'[$EXTRACT(tDirectory, *) {
					Set tDirectory = tDirectory _ "/"
				} Else {
					Set tDirectory = "gbl/"
				}

        Set tResourceDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory_tSourceRoot_tDirectory)

				If tDeveloperMode {
					Set ^Sources("GBL",tName) = tSourcesPrefix_tResourceDirectory
				}
				
				If '..ResourceReference.Preload {
					Set tResourcePath = tResourceDirectory_$tr(tName,"%,("")","___")_".xml"
					Set tSC = $System.OBJ.Load(tResourcePath,$Select(tVerbose:"/display",1:"/nodisplay")_"/nocompile")
					If $$$ISERR(tSC) {
						Quit
					}
				}
			}
			Set pResourceHandled = 1
		} ElseIf (pPhase = "Clean") {
			Set pResourceHandled = 1
			If (..Global '= "") && ('..Preserve) {
				Kill @..Global
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
