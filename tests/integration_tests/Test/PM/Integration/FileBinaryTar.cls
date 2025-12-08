/// Most convenient to represent this as an integration test
/// to reuse the integration test packages.
Class Test.PM.Integration.FileBinaryTar Extends %UnitTest.TestCase
{

Method TestPackageAndExtract()
{
  set tSC = $$$OK
  try {
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))

    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-module/")
    set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
    do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully.")

    set tempDir = ##class(%Library.File).TempFilename()_"dir"
    set tSC = ##class(%IPM.Main).Shell("simplemodule package -only -DPath="_tempDir)
    do $$$AssertStatusOK(tSC,"Packaged SimpleModule successfully.")

    set outFile = ##class(%Library.File).TempFilename()
    set outDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).TempFilename()_"dir-out")
    do ##class(%Library.File).CreateDirectoryChain(outDir)
    do $$$AssertEquals($zf(-100,"/STDOUT="""_outFile_"""/STDERR="""_outFile_"""","tar","-xvf",tempDir_".tgz","-C",outDir),0)

    do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"src/cls/Test/Test"))
    do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"src/src"))
    do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"simplemodule"))
    do $$$AssertTrue(##class(%File).Exists(outDir_"src/cls/Test/Test.cls"))
    do $$$AssertTrue(##class(%File).Exists(outDir_"module.xml"))

    set tSC = ##class(%IPM.Main).Shell("load -force "_tempDir_".tgz")
    do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully from .tgz file.")

    set tSC = ##class(%IPM.Main).Shell("load -force "_outDir)
    do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully from package directory.")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
