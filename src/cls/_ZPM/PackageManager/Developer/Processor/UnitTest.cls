Class %ZPM.PackageManager.Developer.Processor.UnitTest Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Loads unit tests (extending %UnitTest.TestCase) from the specified directory and runs them during (Phase). For modules in development mode, the unit tests are always loaded and are not deleted after they are run.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Phase,Package,ManagerClass,Format";

/// Class extending %UnitTest.Manager to use to run unit tests
Property ManagerClass As %Dictionary.Classname [ InitialExpression = "%ZPM.PackageManager.Developer.UnitTest.Manager" ];

/// Phase in which the unit tests run - "test" (dev namespace), "verify" (separate, clean namespace), or "test,verify" (to run in both cases).
Property Phase As %ZPM.PackageManager.Core.ListOfOptions(VALUELIST = ",test,verify") [ InitialExpression = {$ListBuild("test")}, Required ];

/// Package containing unit tests - this will be mapped properly on development systems, and unit tests won't be deleted in the "test" phase if any classes in it exist.
Property Package As %String(MAXLEN = 255) [ Required ];

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

/// Embedded processor to handle unit test resources as a package.
Property EmbeddedProcessor As %ZPM.PackageManager.Developer.Processor.Default.Package [ Private ];

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
		If (pPhase = "Reload") {
			// Only load unit tests if we're in developer mode.
			If $Get(pParams("DeveloperMode")),##class(%File).DirectoryExists(tUnitTestDir) {
				// LoadTestDirectory rather than recursive $System.OBJ.LoadDir to omit _ directories.
				Set tSC = ##class(%ZPM.PackageManager.Developer.UnitTest.Manager).LoadTestDirectory(tUnitTestDir,tVerbose,.tLoadedList,..Format)
				$$$ThrowOnError(tSC)
				
				Set tSC = ##class(%ZPM.PackageManager.Developer.LoadedResource).TrackResourceNames(..ResourceReference.Module.Name,..ResourceReference.UniqueName,tLoadedList)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method TestsShouldRun(pPhase As %String, ByRef pParams) As %Boolean
{
	Set tPathMatch = 1
	Set tTestPath = ""
	If $Data(pParams("UnitTest","Suite"),tTestSuite)#2 {
		Set tTestPath = $Translate(tTestSuite,"/\","..")
	} ElseIf $Data(pParams("UnitTest","Case"),tTestCase)#2 {
		Set tTestPath = tTestCase
	}
	If (tTestPath '= "") && (..Package '= "") {
		If $Length(tTestPath) > $Length(..Package) {
			Set tPathMatch = ($Extract(tTestPath,1,$Length(..Package)) = ..Package)
		} Else {
			Set tPathMatch = ($Extract(..Package,1,$Length(tTestPath)) = tTestPath)
		}
	}
	Quit tPathMatch && ($ListFind(..Phase,$ZConvert(pPhase,"L")) > 0)
}

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		If ..TestsShouldRun(pPhase,.pParams) {
			// In test/verify phase, run unit tests.
			Set tVerbose = $Get(pParams("Verbose"))
			Set tFlags = $Select(tVerbose:"/display=all",1:"/display=none")
			
			// Ensure unit tests and related classes are loaded.
			Set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
			Set tSC = ##class(%ZPM.PackageManager.Developer.UnitTest.Manager).LoadTestDirectory(tUnitTestDir,tVerbose, ,..Format)
			$$$ThrowOnError(tSC)
			
			$$$ThrowOnError($System.OBJ.CompilePackage(..Package,"ck"_$Select(tVerbose:"d",1:"-d")))
			
			If (..Package '= "") {
				// See if package contains any classes.
				// If it does, we won't delete the classes after running the test.
				// It's assumed that the version of these classes on disk is the authority.
				Set tNextClass = $Order(^oddDEF(..Package_"."))
				If ($Extract(tNextClass,1,$Length(..Package)) = ..Package) {
					Set tFlags = tFlags_"/nodelete"
				}
			}
			
			Set tTestSpec = ""
			If $Data(pParams("UnitTest","Suite"),tTestSuite) {
				Set tTestSubDir = $Replace(tTestSuite,".","\")
				Set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
			} ElseIf $Data(pParams("UnitTest","Case"),tTestCase) {
				Set tTestSpec = ":"_tTestCase
				// Target the directory that contains this specific test case.
				Set tTestSubDir = $Replace($Piece(tTestCase,".",1,*-1),".","/")
				// Avoid nested directories
				Set tFlags = tFlags_"/norecursive"
				Set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
				If $Data(pParams("UnitTest","Method"),tTestMethod) {
					Set tTestSpec = tTestSpec_":"_tTestMethod
				}
			}
			
			Set tFlags = tFlags_$Get(pParams("UnitTest","Flags"))
			
			Set tManagerClass = $Get(pParams("UnitTest","ManagerClass"),..ManagerClass)
			If (tManagerClass = "") {
				Set tManagerClass = "%ZPM.PackageManager.Developer.UnitTest.Manager"
			}
			Merge tUserParams = pParams("UnitTest","UserParam")
			
			If $Data(^UnitTestRoot,tOldUnitTestRoot) // Stash ^UnitTestRoot
			Set ^UnitTestRoot = tUnitTestDir
			Set tSC = $ClassMethod(tManagerClass,"RunTest",tTestSpec,tFlags,.tUserParams)
			ZKill ^UnitTestRoot
			$$$ThrowOnError(tSC)
			
			If $Data(pParams("UnitTest","JUnitOutput"),tJUnitFile) {
				Set tPostfix = "-"_$ZConvert(pPhase,"L")_"-"_$Replace(..Package,".","-")
				Set tJUnitFile = $Piece(tJUnitFile,".",1,*-1)_tPostfix_".xml"
				Set tSC = ##class(%ZPM.PackageManager.Developer.UnitTest.JUnitOutput).ToFile(tJUnitFile)
				$$$ThrowOnError(tSC)
			}
			
			// By default, detect and report unit test failures as an error from this phase
			If $Get(pParams("UnitTest","FailuresAreFatal"),1) {
				Set tSC = ##class(%ZPM.PackageManager.Developer.UnitTest.Manager).GetLastStatus()
				$$$ThrowOnError(tSC)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If $Data(tOldUnitTestRoot,^UnitTestRoot) // Restore ^UnitTestRoot
	Quit tSC
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..Package '= "") {
			Set tModuleName = ..ResourceReference.Module.Name
			Set tResourceInfo = tModuleName
			Set tResourceInfo("Generated") = 0
			Set tResourceInfo("Preload") = 0
			Set tResourceInfo("UnitTest") = 1
			Set tResourceInfo("Scope") = ..Phase
			Set tResourceInfo("Deploy") = 0
			Set tResourceInfo("Processor") = $This
			Set tResourceInfo("IsAPI") = 0
			$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.ResourceReference).GetChildren(..Package_".PKG",tModuleName,1,.tResourceInfo,.pResourceArray))
			$$$ThrowOnError(..EmbeddedProcessor.OnResolveChildren(.pResourceArray))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
	If (..Package '= "") {
		Set pUniqueName = ..Package_".PKG"
	}
}

Method GetSourceControlInfo(Output pInfo As %ZPM.PackageManager.Developer.Extension.SourceControl.ResourceInfo) As %Status
{
	Set pInfo = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ResourceInfo).%New()
	If (..Package '= "") {
		Set pInfo.SourceControlAware = 1
		Set pInfo.Prefix = ..Package_"."
		Set pInfo.RelativePath = ..ResourceReference.Name
		Set pInfo.ResourceType = "CLS"
	}
	Quit $$$OK
}

Method %OnNew(pResourceReference As %ZPM.PackageManager.Developer.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = ##super(pResourceReference)
	Set ..EmbeddedProcessor = ##class(%ZPM.PackageManager.Developer.Processor.Default.Package).%New(pResourceReference)
	Set ..EmbeddedProcessor.Directory = ..ResourceReference.Name
	Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
  Set pItemHandled = 1
	Quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
	Quit ..EmbeddedProcessor.OnItemRelativePath(pItemName)
}

}
