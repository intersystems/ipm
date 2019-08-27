Class %ZPM.PackageManager.Developer.Processor.Default.LocalizedErrorMessages Extends (%ZPM.PackageManager.Developer.Processor.AbstractCompilable, %ZPM.PackageManager.Developer.Processor.LocalizationExport)
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for localized error messages.";

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	// Handle export of messages file for localization using the LocalizationExport resource processor class.
	If (..Filename = "") {
		// Default
		Set ..Filename = "/localize/"_$Translate($Piece(..ResourceReference.Name,".",1,*-1),".")_".xml"
	}
	Quit ##class(%ZPM.PackageManager.Developer.Processor.LocalizationExport)$This.OnBeforePhase(pPhase,.pParams)
}

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
			
			If 'tGlobalScope {
				Set tSourceDB = ##class(%ZPM.PackageManager.Developer.Utils).GetRoutineDatabase($Namespace)
				Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).AddRoutineMapping($namespace,tName,"INC",tSourceDB)
				If $$$ISERR(tSC) {
					Quit
				}
			}
			
			If '..ResourceReference.Generated {
				Set tSubDirectory = $Select(..ResourceReference.Preload:"preload/",1:"")
				Set tResourceDirectory = ##class(%File).NormalizeDirectory(tRoot_"/"_tSubDirectory_"localize/")
				
				If '..ResourceReference.Preload {
					Set tResourcePath = ##class(%File).NormalizeFilename(tResourceDirectory_$tr(tName,".%","/")_".xml")
					Set tSC = $System.OBJ.Load(tResourcePath,$Select(tVerbose:"/display",1:"/nodisplay")_"/nocompile")
					If $$$ISERR(tSC) {
						Quit
					}
				}
			}
			Set pResourceHandled = 1
		} ElseIf (pPhase = "Compile") {
			// Uses CompileList rather than Compile to support custom document type (.LOC)
			Set tSC = $System.OBJ.CompileList(..ResourceReference.Name,$Select(tVerbose:"d",1:"-d")_..Flags)
			Set pResourceHandled = 1
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
