Class %ZPM.PackageManager.Developer.Processor.UIFW Extends (%ZPM.PackageManager.Developer.Processor.Abstract, %ZPM.PackageManager.Developer.IConfigurable)
{

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "RunTests,Project,SkipIfBuilt";

/// Set to 1 to run tests via gulp during the test lifecycle phase
Property RunTests As %Boolean [ InitialExpression = 0 ];

/// Build "project" name - this becomes a directory in <module root>/built
Property Project As %String [ Required ];

/// If ..BuildDirectory already exists, don't rebuild. (Eventually will be subject to a "force build" parameter.)
Property SkipIfBuilt As %Boolean [ InitialExpression = 0 ];

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"),0)
		Set tDevMode = '..ResourceReference.Deploy
		
		Set tDir = ..ResourceReference.Module.Root
		If (tDir = "") {
			Write:tVerbose !,"Skipping UIFW resource processor - module root directory is missing."
			Quit
		}
		
		If (..Project = "") {
			Set ..Project = $Translate($ZStrip(..ResourceReference.Name,"<>P"),"/\","__")
		}
		
		Set tBuiltDir = ##class(%File).NormalizeDirectory(tDir_"built/"_..Project)
		
		If (pPhase = "Clean") {
			$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.File).RemoveDirectoryTree(tBuiltDir))
			Quit
		}
		
		If ..SkipIfBuilt && ##class(%File).DirectoryExists(tBuiltDir) {
			Write:tVerbose !,tBuiltDir," already exists - skipping UIFW build."
			Quit
		}
		
		// TODO: Generalize.
		Set tGitPath = ..GetPortableGitPath()
		Set tPythonPath = ..GetPythonPath()
		
		// Strip trailing slash - necessary for build-ui.bat!
		If ($Extract(tGitPath,*)="\") {
			Set tGitPath = $Extract(tGitPath,1,*-1)
		}
		
		If (pPhase = "Validate") {
			If (tPythonPath = "") {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Python executable not specified. Correct with: Do ##class("_$classname()_").SetPythonPath(""<valid path to python.exe>"")",tPythonPath))
				Quit
			} ElseIf '##class(%File).Exists(tPythonPath) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Python executable '%1' does not exist. Correct this by running: Do ##class("_$classname()_").SetPythonPath(""<valid path to python.exe>"")",tPythonPath))
				Quit
			}
			If (tGitPath = "") {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Portable git directory not specified. Correct with: Do ##class("_$classname()_").SetPortableGitPath(""<valid path to portable git>"")",tGitPath))
				Quit
			} ElseIf '##class(%File).DirectoryExists(tGitPath) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Portable git directory '%1' does not exist. Correct this by running: Do ##class("_$classname()_").SetPortableGitPath(""<valid path to portable git>"")",tGitPath))
				Quit
			}
		} ElseIf (pPhase = "Compile") || (..RunTests && (pPhase = "Test")) {
			Set tBuildRoot = ##class(%File).NormalizeDirectory(tDir_..ResourceReference.Name)
			Set tBuildDir = ##class(%File).NormalizeDirectory(tBuildRoot_"isc-tools/build")
			
			// Remove existing built directory (TODO: move to build script?)
			$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.File).RemoveDirectoryTree(tBuiltDir))
			
			// Select build/test/deploy based on context
			Set tPhase = $Case(pPhase,"Test":"test",:$Select(tDevMode:"build",1:"deploy"))
			
			Set tCmd = "cd "_tDir_" && "_tBuildDir_"ui-build.bat "_tBuildRoot_" "_..Project_" """" """" "_tPhase_" "_tGitPath_" "_tPythonPath_" 1"
			Set tSC = ..RunCommandWrapper(tCmd,tVerbose)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod SetPortableGitPath(pPath As %String)
{
	Set ^SYS("PackageManager","Utilities","PortableGit") = pPath
	Set ^%SYS("PackageManager","Utiltities","PortableGit") = pPath
}

ClassMethod GetPortableGitPath() As %String
{
	Set tGitPath = ""
	If '$Data(^ZPM.Dev.PortableGitPath,tGitPath) {
		If '$Data(^SYS("PackageManager","Utilities","PortableGit"),tGitPath) {
			If '$Data(^%SYS("PackageManager","Utiltities","PortableGit"),tGitPath)
		}
	}
	
	If (tGitPath '= "") {
		Set ^SYS("PackageManager","Utilities","PortableGit") = tGitPath
		Set ^%SYS("PackageManager","Utiltities","PortableGit") = tGitPath
	}
	Quit tGitPath
}

ClassMethod SetPythonPath(pPath As %String)
{
	Set ^SYS("PackageManager","Utilities","Python") = pPath
	Set ^%SYS("PackageManager","Utiltities","Python") = pPath
}

ClassMethod GetPythonPath() As %String
{
	Set tPythonPath = ""
	If '$Data(^ZPM.Dev.PythonPath,tPythonPath) {
		If '$Data(^SYS("PackageManager","Utilities","Python"),tPythonPath) {
			If '$Data(^%SYS("PackageManager","Utiltities","Python"),tPythonPath)
		}
	}
	
	If (tPythonPath '= "") {
		Set ^SYS("PackageManager","Utilities","Python") = tPythonPath
		Set ^%SYS("PackageManager","Utiltities","Python") = tPythonPath
	}
	
	Quit tPythonPath
}

ClassMethod RunCommandWrapper(pCmd As %String, pVerbose As %Boolean) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		Write:pVerbose !,pCmd
		Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).RunCommandViaZF(pCmd,.tLogOutput,.tErrOutput,,.tRetCode)
		If $$$ISERR(tSC) {
			Quit
		}
		If (pVerbose) {
			For i=1:1:$Get(tLogOutput) {
				Write !,tLogOutput(i)
			}
		}
		For i=1:1:$Get(tErrOutput) {
			Write !,tErrOutput(i)
		}
		If (tRetCode '= 0) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("An error occurred executing command '%1' - see log for details.",pCmd))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// A delimited string in the format:
/// Key:Description[|Key:Description...]
Parameter SETTINGS = "PythonPath:Path to python.exe; required for UIFW build processes.|PortableGitPath:Root path to Portable Git; required for UIFW build processes.";

/// A string to show in the grouping of settings for this class
Parameter DESCRIPTION = "UIFW Build Processes";

ClassMethod GetSettingValue(pName As %String) As %String
{
	Quit $Case(pName,
		"PythonPath":..GetPythonPath(),
		"PortableGitPath":..GetPortableGitPath())
}

ClassMethod SettingIsDefined(pName As %String) As %Boolean
{
	Quit (..GetSettingValue(pName) '= "")
}

ClassMethod ClearSettingValue(pName As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Do ..SetSettingValue(pName,"")
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod SetSettingValue(pName As %String, pValue As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Do $Case(pName,
			"PythonPath":..SetPythonPath(pValue),
			"PortableGitPath":..SetPortableGitPath(pValue))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnBeforeArtifact(pExportDirectory As %String, pWorkingDirectory As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If (pExportDirectory = pWorkingDirectory) {
			Quit
		}
		Write !,"[OnBeforeArtifact] "_..ResourceReference.Name
		If '..ResourceReference.Deploy {
			Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(
				pExportDirectory_..ResourceReference.Name,
				pWorkingDirectory_..ResourceReference.Name)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
