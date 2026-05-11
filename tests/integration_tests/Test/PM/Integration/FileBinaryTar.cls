/// Most convenient to represent this as an integration test
/// to reuse the integration test packages.
Class Test.PM.Integration.FileBinaryTar Extends %UnitTest.TestCase
{

Method TestPackageAndExtract()
{
  set sc = $$$OK
  try {
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))

    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-module/")
    set sc = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusOK(sc,"Loaded SimpleModule module successfully.")

    set tempDir = ##class(%Library.File).TempFilename()_"dir"
    set sc = ##class(%IPM.Main).Shell("simplemodule package -only -DPath="_tempDir)
    do $$$AssertStatusOK(sc,"Packaged SimpleModule successfully.")

    set outFile = ##class(%Library.File).TempFilename()
    set outDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).TempFilename()_"dir-out")
    do ##class(%Library.File).CreateDirectoryChain(outDir)
    do $$$AssertEquals($zf(-100,"/STDOUT="""_outFile_"""/STDERR="""_outFile_"""","tar","-xvf",tempDir_".tgz","-C",outDir),0)

    do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"src/cls/Test/Test"))
    do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"src/src"))
    do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"simplemodule"))
    do $$$AssertTrue(##class(%File).Exists(outDir_"src/cls/Test/Test.cls"))
    do $$$AssertTrue(##class(%File).Exists(outDir_"module.xml"))

    set sc = ##class(%IPM.Main).Shell("load "_tempDir_".tgz")
    do $$$AssertStatusOK(sc,"Loaded SimpleModule module successfully from .tgz file.")

    set sc = ##class(%IPM.Main).Shell("load "_outDir)
    do $$$AssertStatusOK(sc,"Loaded SimpleModule module successfully from package directory.")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

Method TestLoadDestinationDirectory()
{
  set sc = $$$OK
  try {
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-module/")

    // Load from directory — files should land in DataDirectory/ipm/<name>/<version>/
    set sc = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusOK(sc,"Loaded SimpleModule from directory.")
    set tModule = ##class(%IPM.Storage.Module).NameOpen("simplemodule",,.sc)
    do $$$AssertStatusOK(sc,"Opened module after directory load.")
    set tExpectedDir = ##class(%Library.File).NormalizeDirectory(
      ##class(%SYSTEM.Util).DataDirectory()_"ipm/"_tModule.Name_"/"_tModule.VersionString)
    do $$$AssertTrue(##class(%File).DirectoryExists(tExpectedDir),"Module directory exists at standard path after load from directory.")
    do $$$AssertTrue(##class(%File).Exists(tExpectedDir_"module.xml"),"module.xml present at standard path after load from directory.")
    set sc = ##class(%IPM.Main).Shell("uninstall simplemodule")
    do $$$AssertStatusOK(sc,"Uninstalled SimpleModule.")

    // Load from tarball — files should also land in DataDirectory/ipm/<name>/<version>/
    set tempDir = ##class(%Library.File).TempFilename()_"dir"
    set sc = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusOK(sc,"Loaded SimpleModule from directory to enable packaging.")
    set sc = ##class(%IPM.Main).Shell("simplemodule package -only -DPath="_tempDir)
    do $$$AssertStatusOK(sc,"Packaged SimpleModule.")
    set sc = ##class(%IPM.Main).Shell("uninstall simplemodule")
    do $$$AssertStatusOK(sc,"Uninstalled SimpleModule before tarball load.")
    set sc = ##class(%IPM.Main).Shell("load "_tempDir_".tgz")
    do $$$AssertStatusOK(sc,"Loaded SimpleModule from tarball.")
    set tModule = ##class(%IPM.Storage.Module).NameOpen("simplemodule",,.sc)
    do $$$AssertStatusOK(sc,"Opened module after tarball load.")
    set tExpectedDir = ##class(%Library.File).NormalizeDirectory(
      ##class(%SYSTEM.Util).DataDirectory()_"ipm/"_tModule.Name_"/"_tModule.VersionString)
    do $$$AssertTrue(##class(%File).DirectoryExists(tExpectedDir),"Module directory exists at standard path after load from tarball.")
    set sc = ##class(%IPM.Main).Shell("uninstall simplemodule")
    do $$$AssertStatusOK(sc,"Uninstalled SimpleModule.")

    // Load -dev from directory — module Root should point to the original path, not DataDirectory
    $$$ThrowOnError(##class(%IPM.Utils.File).RemoveDirectoryTree(tExpectedDir))
    set sc = ##class(%IPM.Main).Shell("load -dev "_tModuleDir)
    do $$$AssertStatusOK(sc,"Loaded SimpleModule in dev mode.")
    set tModule = ##class(%IPM.Storage.Module).NameOpen("simplemodule",,.sc)
    do $$$AssertStatusOK(sc,"Opened module after dev mode load.")
    do $$$AssertEquals(tModule.Root, tModuleDir, "Module Root points to original directory in dev mode.")
    do $$$AssertNotTrue(##class(%File).DirectoryExists(tExpectedDir),"Module NOT copied to standard path in dev mode.")
    set sc = ##class(%IPM.Main).Shell("uninstall simplemodule")
    do $$$AssertStatusOK(sc,"Uninstalled SimpleModule.")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
