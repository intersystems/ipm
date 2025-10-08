Class %IPM.ResourceProcessor.Test Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Loads unit tests (extending %UnitTest.TestCase) from the specified directory and runs them during (Phase). For modules in development mode, the unit tests are always loaded and are not deleted after they are run.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Phase,Package,Class,ManagerClass,Format,ExportFlags";

/// Phase in which the unit tests run - "test" (dev namespace), "verify" (separate, clean namespace), or "test,verify" (to run in both cases).
Property Phase As %IPM.DataType.ListOfOptions(VALUELIST = ",test,verify") [ InitialExpression = {$listbuild("test")}, Required ];

// NOTE: Either Package or Class MUST be defined.

/// Package containing unit tests - this will be mapped properly on development systems, and unit tests won't be deleted in the "test" phase if any classes in it exist.
Property Package As %String(MAXLEN = 255);

/// Class containing unit tests - this will be mapped properly on development systems, and unit tests won't be deleted in the "test" phase
Property Class As %String(MAXLEN = 255);

/// Extension to use internally based on whether the resource is a package or a class
Property Extension As %String [ Calculated, Internal ];

Method ExtensionGet() As %String [ CodeMode = expression ]
{
$case(..Package '= "", 1: ".PKG", : ".CLS")
}

/// Class extending %UnitTest.Manager to use to run unit tests
Property ManagerClass As %Dictionary.Classname [ InitialExpression = "%IPM.Test.Manager" ];

/// Export format
Property Format As %String(VALUELIST = ",UDL,XML");

/// Flags/qualifiers to export items with.
Property ExportFlags As %String(MAXLEN = "");

/// Embedded processor to handle unit test resources as a package.
Property EmbeddedProcessor As %IPM.ResourceProcessor.Default.Document [ Private ];

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tSC = $$$OK
    try {
        set tVerbose = $get(pParams("Verbose"))
        set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
        if (pPhase = "Reload") {
            // Only load unit tests if we're in developer mode.
            if $get(pParams("DeveloperMode")) {
                // LoadTestDirectory rather than recursive $System.OBJ.LoadDir to omit _ directories.
                set tSC = ##class(%IPM.Test.Manager).LoadTestDirectory(tUnitTestDir,tVerbose,.tLoadedList,..Format)
                $$$ThrowOnError(tSC)

                set tSC = ##class(%IPM.Storage.LoadedResource).TrackResourceNames(..ResourceReference.Module.Name,..ResourceReference.UniqueName,tLoadedList)
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method TestsShouldRun(
	pPhase As %String,
	ByRef pParams) As %Boolean
{
    set tPathMatch = 1
    set tTestPath = ""
    if (..Package '= "") {
        if $data(pParams("UnitTest","Suite"),tTestSuite)#2 {
            set tTestPath = $translate(tTestSuite,"/\","..")
        } elseif $data(pParams("UnitTest","Case"),tTestCase)#2 {
            set tTestPath = tTestCase
        }
    }
    if (tTestPath '= "") {
        if (..Package '= "") {
            if $length(tTestPath) > $length(..Package) {
                set tPathMatch = ($extract(tTestPath,1,$length(..Package)) = ..Package)
            } else {
                set tPathMatch = ($extract(..Package,1,$length(tTestPath)) = tTestPath)
            }
        } elseif (..Class '= "") {
            // No action needed, the pParams are ignored for this case so tPatchMatch
            // always equals 1
        }
    }
    quit tPathMatch && ($listfind(..Phase,$zconvert(pPhase,"L")) > 0)
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        if ..TestsShouldRun(pPhase,.pParams) {
            // In test/verify phase, run unit tests.
            set tVerbose = $get(pParams("Verbose"), 0)
            set tFlags = $select(tVerbose:"/display=all",1:"/display=none")

            // Ensure unit tests and related classes are loaded.
            set tUnitTestDir = ##class(%File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name)
            set tSC = ##class(%IPM.Test.Manager).LoadTestDirectory(tUnitTestDir,tVerbose, ,..Format)
            $$$ThrowOnError(tSC)

            set tCompileFlags = "ck"_$select(tVerbose:"d",1:"-d")
            set tDoDelete = 1
            set tTestSpec = ""
            if (..Package '= "") {
                $$$ThrowOnError($system.OBJ.CompilePackage(..Package, tCompileFlags))

                // See if package contains any classes.
                // If it does, we won't delete the classes after running the test.
                // It's assumed that the version of these classes on disk is the authority.
                set tNextClass = $order(^oddDEF(..Package_"."))
                if ($extract(tNextClass,1,$length(..Package)) = ..Package) {
                    set tDoDelete = 0
                }

                set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir)
                if $data(pParams("UnitTest","Suite"),tTestSuite) {
                    set tTestSubDir = $replace(tTestSuite,".","\")
                    set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
                } elseif $data(pParams("UnitTest","Case"),tTestCase) {
                    set tTestSpec = ":"_tTestCase
                    // Target the directory that contains this specific test case.
                    set tTestSubDir = $replace($piece(tTestCase,".",1,*-1),".","/")
                    // Avoid nested directories
                    set tFlags = tFlags_"/norecursive"
                    set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
                    if $data(pParams("UnitTest","Method"),tTestMethod) {
                        set tTestSpec = tTestSpec_":"_tTestMethod
                    }
                } else {
                    set tTestSubDir = $replace(..Package,".","\")
                    set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
                }
            } elseif (..Class '= "") {
                $$$ThrowOnError($system.OBJ.Compile(..Class, tCompileFlags))
                // See if class exists.
                // If it does, we won't delete the class after running the test.
                // It's assumed that the version on disk is the authority.
                if $$$comClassDefined(..Class) {
                    set tDoDelete = 0
                }

                // Since this is only a class, we do not support "Suite" or "Case".
                // Only support "Method"
                set tTestCase = ..Class
                set tTestSpec = ":"_tTestCase
                // Target the directory that contains this specific test case.
                set tTestSubDir = $replace($piece(tTestCase,".",1,*-1),".","/")
                // Avoid nested directories
                set tFlags = tFlags_"/norecursive"
                set tUnitTestDir = ##class(%File).NormalizeDirectory(tUnitTestDir_tTestSubDir)
                if $data(pParams("UnitTest","Method"),tTestMethod) {
                    set tTestSpec = tTestSpec_":"_tTestMethod
                }
            }
            if 'tDoDelete {
                set tFlags = tFlags_"/nodelete"
            }

            set tFlags = tFlags_$get(pParams("UnitTest","Flags"))

            set tManagerClass = $get(pParams("UnitTest","ManagerClass"),..ManagerClass)
            if (tManagerClass = "") {
                set tManagerClass = "%IPM.Test.Manager"
            }
            merge tUserParams = pParams("UnitTest","UserParam")

            if $data(^UnitTestRoot,tOldUnitTestRoot) // Stash ^UnitTestRoot
            set ^UnitTestRoot = tUnitTestDir
            set tSC = $classmethod(tManagerClass,"RunTest",tTestSpec,tFlags,.tUserParams)

            // If running integration tests in the verify phase, uninstall all modules after each test
            if $get(pParams("verifyNamespace"))'="" {
                set oldNamespace = $namespace
                set $namespace = pParams("verifyNamespace")
                $$$ThrowOnError(##class(%IPM.Utils.Module).UninstallAll(0,.pParams))
                set $namespace = oldNamespace
            }

            zkill ^UnitTestRoot
            $$$ThrowOnError(tSC)

            if $data(pParams("UnitTest","JUnitOutput"),tJUnitFile) {
                set tPostfix = "-"_$zconvert(pPhase,"L")_"-"
                if (..Package '= "") {
                    set tPostfix = tPostfix_$replace(..Package,".","-")_"-PKG"
                } elseif (..Class '= "") {
                    set tPostfix = tPostfix_$replace(..Class,".","-")_"-CLS"
                }
                set tJUnitFile = $piece(tJUnitFile,".",1,*-1)_tPostfix_".xml"
                set tSC = ##class(%IPM.Test.JUnitOutput).ToFile(tJUnitFile)
                $$$ThrowOnError(tSC)
            }

            // By default, detect and report unit test failures as an error from this phase
            if $get(pParams("UnitTest","FailuresAreFatal"),1) {
                do ##class(%IPM.Test.Manager).OutputFailures()
                set tSC = ##class(%IPM.Test.Manager).GetLastStatus()
                $$$ThrowOnError(tSC)
            }
            write !
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if $data(tOldUnitTestRoot,^UnitTestRoot) // Restore ^UnitTestRoot
    quit tSC
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
    set tSC = $$$OK
    try {
        set tModuleName = ..ResourceReference.Module.Name
        set tResourceInfo = tModuleName
        set tResourceInfo("Generated") = 0
        set tResourceInfo("Preload") = 0
        set tResourceInfo("Scope") = ..Phase
        set tResourceInfo("Deploy") = 0
        set tResourceInfo("Processor") = $this
        set tResourceInfo("UnitTest") = 1
        set tResource = $case(..Package '= "", 1: ..Package, : ..Class)_..Extension
        $$$ThrowOnError(##class(%IPM.Storage.ResourceReference).GetChildren(tResource,tModuleName,1,.tResourceInfo,.pResourceArray))
        $$$ThrowOnError(..EmbeddedProcessor.OnResolveChildren(.pResourceArray))
        merge pResourceArray = tResourceInfo
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
    set pUniqueName = $case(..Package '= "", 1: ..Package, : ..Class)_..Extension
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
    set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
    set pInfo.SourceControlAware = 1
    set pInfo.Prefix = $case(..Package '= "", 1: ..Package_".", : ..Class)
    set pInfo.RelativePath = ..ResourceReference.Name
    set pInfo.ResourceType = "cls"
    quit $$$OK
}

Method %OnNew(pResourceReference As %IPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = ##super(pResourceReference)
    if (..Package '= "") {
        set ..EmbeddedProcessor = ##class(%IPM.ResourceProcessor.Default.Package).%New(pResourceReference)
        set ..EmbeddedProcessor.Directory = ..ResourceReference.Name
    } elseif (..Class '= "") {
        set ..EmbeddedProcessor = ##class(%IPM.ResourceProcessor.Default.Class).%New(pResourceReference)
    }
    set ..EmbeddedProcessor.ExportFlags = ..ExportFlags
    if (..Format '= "") {
        set ..EmbeddedProcessor.Format = ..Format
        set ..EmbeddedProcessor.FilenameExtension = $case(..Format,"XML":"xml","UDL":"cls")
    }
    quit tSC
}

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    quit ..EmbeddedProcessor.OnExportItem(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
    quit ..EmbeddedProcessor.OnItemRelativePath(pItemName)
}

Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
    if ((..Package = "") && (..Class = "")) || ((..Package '= "") && (..Class '= "")) {
        return $$$ERROR($$$GeneralError, "EXACTLY ONE of 'Package' or 'Class' attributes must be specified")
    }
    quit $$$OK
}

}
