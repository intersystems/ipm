Class %IPM.ResourceProcessor.Test Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Loads unit tests (extending %UnitTest.TestCase) from the specified directory and runs them during (Phase). For modules in development mode, the unit tests are always loaded and are not deleted after they are run.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Phase,Package,Class,ManagerClass,Format,ExportFlags";

/// Phase in which the unit tests run - "test" (dev namespace), "verify" (separate, clean namespace), or "test,verify" (to run in both cases).
Property Phase As %IPM.DataType.ListOfOptions(VALUELIST = ",test,verify") [ InitialExpression = {$ListBuild("test")}, Required ];

// NOTE: Either Package or Class MUST be defined.

/// Package containing unit tests - this will be mapped properly on development systems, and unit tests won't be deleted in the "test" phase if any classes in it exist.
Property Package As %String(MAXLEN = 255);

/// Class containing unit tests - this will be mapped properly on development systems, and unit tests won't be deleted in the "test" phase
Property Class As %String(MAXLEN = 255);

/// Extension to use internally based on whether the resource is a package or a class
Property Extension As %String [ Calculated, Internal ];

Method ExtensionGet() As %String [ CodeMode = expression ]
{
$Case(..Package '= "", 1: ".PKG", : ".CLS")
}

/// Class extending %UnitTest.Manager to use to run unit tests
Property ManagerClass As %Dictionary.Classname [ InitialExpression = "%IPM.Test.Manager" ];

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

/// Flags/qualifiers to export items with.
Property ExportFlags As %String(MAXLEN = "");

/// Embedded processor to handle unit test resources as a package.
Property EmbeddedProcessor As %IPM.ResourceProcessor.Default.Document [ Private ];

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
		If (pPhase = "Reload") {
			// Only load unit tests if we're in developer mode.
			If $Get(pParams("DeveloperMode")) {
				// LoadTestDirectory rather than recursive $System.OBJ.LoadDir to omit _ directories.
				Set tSC = ##class(%IPM.Test.Manager).LoadTestDirectory(tUnitTestDir,tVerbose,.tLoadedList,..Format)
				$$$ThrowOnError(tSC)
				
				Set tSC = ##class(%IPM.Storage.LoadedResource).TrackResourceNames(..ResourceReference.Module.Name,..ResourceReference.UniqueName,tLoadedList)
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
	If (..Package '= "") {
		If $Data(pParams("UnitTest","Suite"),tTestSuite)#2 {
			Set tTestPath = $Translate(tTestSuite,"/\","..")
		} ElseIf $Data(pParams("UnitTest","Case"),tTestCase)#2 {
			Set tTestPath = tTestCase
		}
	}
	If (tTestPath '= "") {
		If (..Package '= "") {
			If $Length(tTestPath) > $Length(..Package) {
				Set tPathMatch = ($Extract(tTestPath,1,$Length(..Package)) = ..Package)
			} Else {
				Set tPathMatch = ($Extract(..Package,1,$Length(tTestPath)) = tTestPath)
			}
		} ElseIf (..Class '= "") {
			// No action needed, the pParams are ignored for this case so tPatchMatch
			// always equals 1
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
			Set tVerbose = $Get(pParams("Verbose"), 0)
			Set tFlags = $Select(tVerbose:"/display=all",1:"/display=none")
			
			// Ensure unit tests and related classes are loaded.
			Set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
			Set tSC = ##class(%IPM.Test.Manager).LoadTestDirectory(tUnitTestDir,tVerbose, ,..Format)
			$$$ThrowOnError(tSC)
			
			Set tCompileFlags = "ck"_$Select(tVerbose:"d",1:"-d")
			Set tDoDelete = 1
			Set tTestSpec = ""
			If (..Package '= "") {
				$$$ThrowOnError($System.OBJ.CompilePackage(..Package, tCompileFlags))
				
				// See if package contains any classes.
				// If it does, we won't delete the classes after running the test.
				// It's assumed that the version of these classes on disk is the authority.
				Set tNextClass = $Order(^oddDEF(..Package_"."))
				If ($Extract(tNextClass,1,$Length(..Package)) = ..Package) {
					Set tDoDelete = 0
				}

				Set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir)
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
				} Else {
					Set tTestSubDir = $Replace(..Package,".","\")
					Set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
				}
			} ElseIf (..Class '= "") {
				$$$ThrowOnError($System.OBJ.Compile(..Class, tCompileFlags))
				// See if class exists.
				// If it does, we won't delete the class after running the test.
				// It's assumed that the version on disk is the authority.
				If $$$comClassDefined(..Class) {
					Set tDoDelete = 0
				}

				// Since this is only a class, we do not support "Suite" or "Case".
				// Only support "Method"
				Set tTestCase = ..Class
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
			If 'tDoDelete {
				Set tFlags = tFlags_"/nodelete"
			}
			
			Set tFlags = tFlags_$Get(pParams("UnitTest","Flags"))
			
			Set tManagerClass = $Get(pParams("UnitTest","ManagerClass"),..ManagerClass)
			If (tManagerClass = "") {
				Set tManagerClass = "%IPM.Test.Manager"
			}
			Merge tUserParams = pParams("UnitTest","UserParam")
			
			If $Data(^UnitTestRoot,tOldUnitTestRoot) // Stash ^UnitTestRoot
			Set ^UnitTestRoot = tUnitTestDir
			Set tSC = $ClassMethod(tManagerClass,"RunTest",tTestSpec,tFlags,.tUserParams)
			ZKill ^UnitTestRoot
			$$$ThrowOnError(tSC)
			
			If $Data(pParams("UnitTest","JUnitOutput"),tJUnitFile) {
				Set tPostfix = "-"_$ZConvert(pPhase,"L")_"-"
				If (..Package '= "") {
					Set tPostfix = tPostfix_$Replace(..Package,".","-")_"-PKG"
				} ElseIf (..Class '= "") {
					Set tPostfix = tPostfix_$Replace(..Class,".","-")_"-CLS"
				}
				Set tJUnitFile = $Piece(tJUnitFile,".",1,*-1)_tPostfix_".xml"
				Set tSC = ##class(%IPM.Test.JUnitOutput).ToFile(tJUnitFile)
				$$$ThrowOnError(tSC)
			}
			
			// By default, detect and report unit test failures as an error from this phase
			If $Get(pParams("UnitTest","FailuresAreFatal"),1) {
        Do ##class(%IPM.Test.Manager).OutputFailures()
				Set tSC = ##class(%IPM.Test.Manager).GetLastStatus()
				$$$ThrowOnError(tSC)
			}
			Write !
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
		Set tModuleName = ..ResourceReference.Module.Name
		Set tResourceInfo = tModuleName
		Set tResourceInfo("Generated") = 0
		Set tResourceInfo("Preload") = 0
		Set tResourceInfo("Scope") = ..Phase
		Set tResourceInfo("Deploy") = 0
		Set tResourceInfo("Processor") = $This
		Set tResourceInfo("UnitTest") = 1
		Set tResource = $Case(..Package '= "", 1: ..Package, : ..Class)_..Extension
		$$$ThrowOnError(##class(%IPM.Storage.ResourceReference).GetChildren(tResource,tModuleName,1,.tResourceInfo,.pResourceArray))
		$$$ThrowOnError(..EmbeddedProcessor.OnResolveChildren(.pResourceArray))
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
	Set pUniqueName = $Case(..Package '= "", 1: ..Package, : ..Class)_..Extension
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
	Set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
	Set pInfo.SourceControlAware = 1
	Set pInfo.Prefix = $Case(..Package '= "", 1: ..Package_".", : ..Class)
	Set pInfo.RelativePath = ..ResourceReference.Name
	Set pInfo.ResourceType = "cls"
	Quit $$$OK
}

Method %OnNew(pResourceReference As %IPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = ##super(pResourceReference)
	If (..Package '= "") {
		Set ..EmbeddedProcessor = ##class(%IPM.ResourceProcessor.Default.Package).%New(pResourceReference)
		Set ..EmbeddedProcessor.Directory = ..ResourceReference.Name
	} ElseIf (..Class '= "") {
		Set ..EmbeddedProcessor = ##class(%IPM.ResourceProcessor.Default.Class).%New(pResourceReference)
	}
	Set ..EmbeddedProcessor.ExportFlags = ..ExportFlags
	If (..Format '= "") {
		Set ..EmbeddedProcessor.Format = ..Format
		Set ..EmbeddedProcessor.FilenameExtension = $Case(..Format,"XML":"xml","UDL":"cls")
	}
	Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	Quit ..EmbeddedProcessor.OnExportItem(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
	Quit ..EmbeddedProcessor.OnItemRelativePath(pItemName)
}

Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	If ((..Package = "") && (..Class = "")) || ((..Package '= "") && (..Class '= "")) {
		Return $$$ERROR($$$GeneralError, "EXACTLY ONE of 'Package' or 'Class' attributes must be specified")
	}
	Quit $$$OK
}

}
