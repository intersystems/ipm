Class %ZPM.PackageManager.Developer.Processor.Default.Global Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for global exports.";

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
			
			If 'tGlobalScope && ##class(%RoutineMgr).IsMapped(..ResourceReference.Name) {
				// Format: ^^directory (to which the global is currently mapped)
				Set tGlobalDBDir = $$$GBLDB(@("^"_$Piece(..ResourceReference.Name,".",1,*-1)))
				Set tGlobalDB = ##class(%ZPM.PackageManager.Developer.Utils).GetGlobalDatabase($Namespace)
				Set tExpectedDir = "^^"_##class(%ZPM.PackageManager.Developer.Utils).GetDatabaseDirectory(tGlobalDB)
				
				// Normalize the directory name in case of case-insensitivity
				Set tGlobalDBDir = ##class(%File).NormalizeDirectory($e(tGlobalDBDir,3,*))
				Set tExpectedDir = ##class(%File).NormalizeDirectory($e(tExpectedDir,3,*))
				If tGlobalDBDir'=tExpectedDir {
					Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).AddGlobalMapping($Namespace,tName,tGlobalDB)
					If $$$ISERR(tSC) {
						Quit
					}
				}
			}
			
			If '..ResourceReference.Generated {
				Set tSubDirectory = $Select(..ResourceReference.Preload:"preload/",1:"")
				Set tResourceDirectory = ##class(%File).NormalizeDirectory(tRoot_"/"_tSubDirectory_"gbl/")
				
				If '..ResourceReference.Preload {
					Set tResourcePath = tResourceDirectory_$tr(tName,"%,("")","___")_".xml"
					Set tSC = $System.OBJ.Load(tResourcePath,$Select(tVerbose:"/display",1:"/nodisplay")_"/nocompile")
					If $$$ISERR(tSC) {
						Quit
					}
				}
			}
			Set pResourceHandled = 1
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
