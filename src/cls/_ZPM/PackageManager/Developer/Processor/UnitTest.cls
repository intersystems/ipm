Class %ZPM.PackageManager.Developer.Processor.UnitTest Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Loads unit tests (extending %UnitTest.TestCase) from the specified directory and runs them during (Phase). For modules in development mode, the unit tests are always loaded and are not deleted after they are run.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Phase,Package";

/// Phase in which the unit tests run - "test" (dev namespace) or "verify" (separate, clean namespace)
Property Phase As %String(VALUELIST = ",test,verify") [ InitialExpression = "test", Required ];

/// Package containing unit tests - this will be mapped properly on development systems, and unit tests won't be deleted in the "test" phase if any classes in it exist.
Property Package As %String(MAXLEN = 255) [ Required ];

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
				Set tSC = ##class(%ZPM.PackageManager.Developer.UnitTest.Manager).LoadTestDirectory(tUnitTestDir,tVerbose)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
		If ($ZConvert(pPhase,"L") = ..Phase) {
			// In test/verify phase, run unit tests.
			Set tVerbose = $Get(pParams("Verbose"))
			Set tFlags = $Select(tVerbose:"/display=all",1:"/display=none")
			
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
			If $Data(pParams("UnitTest","Case"),tTestCase) {
				Set tTestSpec = ":"_tTestCase
				If $Data(pParams("UnitTest","Method"),tTestMethod) {
					Set tTestSpec = tTestSpec_":"_tTestMethod
				}
			}
			
			Set tFlags = tFlags_$Get(pParams("UnitTest","Flags"))
			
			If $Data(^UnitTestRoot,tOldUnitTestRoot) // Stash ^UnitTestRoot
			Set ^UnitTestRoot = tUnitTestDir
			Set tSC = ##class(%ZPM.PackageManager.Developer.UnitTest.Manager).RunTest(tTestSpec,tFlags)
			ZKill ^UnitTestRoot
			$$$ThrowOnError(tSC)
			
			// TODO: Detect and report unit test failures as an error from this phase?
			Set tSC = ##class(%ZPM.PackageManager.Developer.UnitTest.Manager).GetLastStatus()
			$$$ThrowOnError(tSC)
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
	QUIT tSC
	#; Don't see any reasons why we need it, it still works other way
	Try {
		If (..Package '= "") {
			Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name from %Dictionary.ClassDefinition where Name %STARTSWITH ? And Deployed = 0",..Package_".")
			If (tRes.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
			}
			While tRes.%Next(.tSC) {
				Set tResource = tRes.%Get("Name")_".CLS"
				Set pResourceArray(tResource) = ..ResourceReference.Module.Name
				Set pResourceArray(tResource,"Generated") = 0
				Set pResourceArray(tResource,"Preload") = 0
				Set pResourceArray(tResource,"Scope") = ..Phase
				Set pResourceArray(tResource,"Deploy") = 0
			}
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

}
