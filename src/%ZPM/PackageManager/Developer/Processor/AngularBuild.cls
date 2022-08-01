Class %ZPM.PackageManager.Developer.Processor.AngularBuild Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Runs npm install and Angular 6+ builds in a specified directory.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "baseHref,clearTarget";

/// Base URL for the application (e.g., including index.html)
/// If unspecified, will default to deployUrl_"index.html"
Property baseHref As %String;

/// URL to which the application is deployed (relative to the host)
/// Must be specified.
Property deployUrl As %String [ InitialExpression = {"/csp/hslib/" _ pResourceReference.Module.Name _ "/"}, Private, ReadOnly ];

/// Set to false if the target for the deployed UI has other files too (e.g., that shouldn't be deleted).
Property clearTarget As %Boolean [ InitialExpression = 1 ];

Property angularCliVersion As %String(MAXLEN = "") [ Private ];

Property buildScript As %String(MAXLEN = "");

Property dependencies As %String(MAXLEN = "");

Property tempDirectory As %String(MAXLEN = "") [ Private ];

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		if $get(pParams("AngularBuild", "Run"), 0) = 1 {
			$$$ThrowOnError(##super(pPhase, .pParams))
			Do ..CleanSettings()
			If (pPhase = "Compile") {
				do ..ConfigureWorkspace(.pParams)
				// Compile the Angular UI. Supposes npm is installed and on the PATH, but that's it.
				Do ..RunAngularBuild(.pParams)
			} ElseIf (pPhase = "Activate") {
				// Move files to the right place.
				Set verbose = $Get(pParams("Verbose"),0)
				Set buildDir = ##class(%Library.File).NormalizeDirectory(..tempDirectory_"/dist/"_$piece(..ResourceReference.Name, "/", *-1))
				Set testFile = buildDir_"index.html"
				If '##class(%Library.File).Exists(testFile) {
					$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("File '%1' does not exist; will not activate angular UI changes.",testFile)))
				}
				set isReleng = 0
				Set targetDir = $System.CSP.GetFileName(..deployUrl)
				If targetDir = "" {
					//We're in a releng build. Copy it to a directory that gets staged into kits
					set isReleng = 1
					set targetDir = ##class(%Library.File).NormalizeDirectory($zu(12) _ "/ui-build/" _ ..ResourceReference.Module.Name)
				}
				If verbose {
					Write !,"Activating Angular application changes..."
					Write !,"Copying ",buildDir," to ",targetDir
				}
				$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.File).CopyDir(buildDir,targetDir,..clearTarget))
				
				if 'isReleng {
					If verbose {
						Write !,"Clearing temporary workspace"
					}
					Set removed = ##class(%File).RemoveDirectoryTree(..tempDirectory)
					If 'removed {
						Write !,"Could not remove directory " _ ..tempDirectory
					}
					
					// Clear CSPGateway caches...
					If verbose {
						Write !,"Clearing CSPGateway caches..."
					}
					#dim registry As %CSP.Mgr.GatewayRegistry
					Set registry = $System.CSP.GetGatewayRegistry()
					$$$ThrowOnError(registry.RemoveFilesFromCaches(..deployUrl_"*"))
				}
				
				If verbose {
					Write !,"Angular UI changes activated."
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method CleanSettings()
{
	// Ensure baseHref is defined.
	If (..baseHref = "") {
		Set ..baseHref = ..deployUrl_"index.html"
	}
	
	Set ..tempDirectory = ##class(%File).NormalizeDirectory(##class(%File).SubDirectoryName($zu(12),"Temp") _ "/" _ ..ResourceReference.Module.Name)
	
	set ..buildScript = ##class(%File).NormalizeFilename(..ResourceReference.Module.Root _ ..ResourceReference.Name _ "/build/build.bat")
	if ..buildScript = "" {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Build script does not exist"))
	}
	
	set ..dependencies = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root _ ..ResourceReference.Name _ "/build/dependencies")
	if ..dependencies = "" {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Dependency path does not exist"))
	}
	
	set packageFile = ##class(%File).NormalizeFilename(..ResourceReference.Module.Root _ ..ResourceReference.Name _ "/package.json")
	if packageFile = "" {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Could not find package.json file"))
	}
	set packageJson = ##class(%DynamicObject).%FromJSON(packageFile)
	set ..angularCliVersion = packageJson.devDependencies."@angular/cli"
	if ..angularCliVersion = "" {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Could not determine Angular CLI version"))
	}
}

Method ConfigureWorkspace(ByRef pParams) [ Internal ]
{
	Set verbose = $Get(pParams("Verbose"),0)
	If verbose {
		Write !,"Creating temporary workspace ",..tempDirectory
	}
	
	If '##class(%File).DirectoryExists(..tempDirectory) {
		Set created = ##class(%File).CreateDirectoryChain(..tempDirectory,)
		If 'created {
			$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Error creating directory %1: %2",..tempDirectory,created)))
		}
	}
	
	Set buildDirectory = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root _ ..ResourceReference.Name)
	If verbose {
		Write !,"Copying ",buildDirectory," to ",..tempDirectory
	}
	$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.File).CopyDir(buildDirectory,..tempDirectory,1))
}

Method RunAngularBuild(ByRef pParams) [ Internal ]
{
	Set verbose = $Get(pParams("Verbose"),0)
	If verbose {
		Write !!,"Running Angular build script...",!
	}
	
	set outputFile = ##class(%File).NormalizeFilename($zu(12) _ "\ui-build.log")
	set status = $zf(-100, "/STDOUT=" _ outputFile, ..buildScript, ..tempDirectory, ..dependencies, ..angularCliVersion, ..baseHref)
	If verbose {
		Write !!,"Angular build complete. See details in " _ outputFile,!
	}
	
	if status '= 0 {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Angular build failed"))
	}
}

}
