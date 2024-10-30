/// Most convenient to represent this as an integration test
/// to reuse the integration test packages.
Class Test.PM.Integration.FileBinaryTar Extends %UnitTest.TestCase
{

Method TestPackageAndExtract()
{
  Set tSC = $$$OK
  Try {
    Set tTestRoot = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot))

    Set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-module/")
    Set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully.")

    Set tempDir = ##class(%Library.File).TempFilename()_"dir"
    Set tSC = ##class(%IPM.Main).Shell("simplemodule package -only -DPath="_tempDir)
    Do $$$AssertStatusOK(tSC,"Packaged SimpleModule successfully.")

    Set outFile = ##class(%Library.File).TempFilename()
    Set outDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).TempFilename()_"dir-out")
    Do ##class(%Library.File).CreateDirectoryChain(outDir)
    Do $$$AssertEquals($zf(-100,"/STDOUT="_outFile_"/STDERR="_outFile,"tar","-xvf",tempDir_".tgz","-C",outDir),0)

    Do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"src/cls/Test/Test"))
    Do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"src/src"))
    Do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"simplemodule"))
    Do $$$AssertTrue(##class(%File).Exists(outDir_"src/cls/Test/Test.cls"))
    Do $$$AssertTrue(##class(%File).Exists(outDir_"module.xml"))

    Set tSC = ##class(%IPM.Main).Shell("load "_outFile)
    Do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully from .tgz file.")

    Set tSC = ##class(%IPM.Main).Shell("load "_outDir)
    Do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully from package directory.")
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
