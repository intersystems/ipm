Class Test.PM.Integration.IncludeTests Extends %UnitTest.TestCase
{

Method OnAfterAllTests() As %Status
{
  do ##class(%IPM.Main).Shell("uninstall test-output-format")
  return $$$OK
}

Method TestExcludeTestsByDefault()
{
  set status = $$$OK
  try {
    set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set moduleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/test-output-format/")
    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Loaded test-output-format module successfully.")

    set tempDir = ##class(%Library.File).TempFilename()_"dir"
    set status = ##class(%IPM.Main).Shell("test-output-format package -only -DPath="_tempDir)
    do $$$AssertStatusOK(status,"Packaged test-output-format without -include-tests successfully.")

    set outFile = ##class(%Library.File).TempFilename()
    set outDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).TempFilename()_"dir-out")
    do ##class(%Library.File).CreateDirectoryChain(outDir)
    do $$$AssertEquals($zf(-100,"/STDOUT="""_outFile_"""/STDERR="""_outFile_"""","tar","-xvf",tempDir_".tgz","-C",outDir),0)

    do $$$AssertTrue(##class(%File).Exists(outDir_"module.xml"),"module.xml is present in package.")
    do $$$AssertNotTrue(##class(%File).DirectoryExists(outDir_"tests"),"tests/ directory is absent from package by default.")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

Method TestIncludeTestsFlag()
{
  set status = $$$OK
  try {
    set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set moduleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/test-output-format/")
    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Loaded test-output-format module successfully.")

    set tempDir = ##class(%Library.File).TempFilename()_"dir"
    set status = ##class(%IPM.Main).Shell("test-output-format package -only -include-tests -DPath="_tempDir)
    do $$$AssertStatusOK(status,"Packaged test-output-format with -include-tests successfully.")

    set outFile = ##class(%Library.File).TempFilename()
    set outDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).TempFilename()_"dir-out")
    do ##class(%Library.File).CreateDirectoryChain(outDir)
    do $$$AssertEquals($zf(-100,"/STDOUT="""_outFile_"""/STDERR="""_outFile_"""","tar","-xvf",tempDir_".tgz","-C",outDir),0)

    do $$$AssertTrue(##class(%File).Exists(outDir_"module.xml"),"module.xml is present in package.")
    do $$$AssertTrue(##class(%File).Exists(outDir_"tests/Test/Output/Format/AfterAllReturn.cls"),"Test file is present in package with -include-tests.")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

Method TestIncludeTestsModuleXml()
{
  set status = $$$OK
  try {
    set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set sourceDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/test-output-format/")

    // Copy to temp dir so we can modify module.xml without altering the shared test fixture.
    set tempModuleDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).TempFilename()_"dir-src")
    do ##class(%Library.File).CreateDirectoryChain(tempModuleDir)
    if '##class(%Library.File).CopyDir(sourceDir, tempModuleDir, 1) {
      do $$$AssertTrue(0,"Failed to copy test-output-format to temp directory.")
      quit
    }

    // Inject <IncludeTests>1</IncludeTests> into the module.xml copy.
    set moduleXmlPath = tempModuleDir_"module.xml"
    set readStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(readStream.LinkToFile(moduleXmlPath))
    set xmlContent = ""
    while 'readStream.AtEnd {
      set xmlContent = xmlContent _ readStream.ReadLine() _ $char(10)
    }
    set xmlContent = $replace(xmlContent, "</Module>", "  <IncludeTests>1</IncludeTests>"_$char(10)_"    </Module>")
    set readStream = ""

    set writeStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(writeStream.LinkToFile(moduleXmlPath))
    $$$ThrowOnError(writeStream.Write(xmlContent))
    $$$ThrowOnError(writeStream.%Save())

    set status = ##class(%IPM.Main).Shell("load "_tempModuleDir)
    do $$$AssertStatusOK(status,"Loaded test-output-format module with IncludeTests from module.xml.")

    set tempDir = ##class(%Library.File).TempFilename()_"dir"
    set status = ##class(%IPM.Main).Shell("test-output-format package -only -DPath="_tempDir)
    do $$$AssertStatusOK(status,"Packaged test-output-format (IncludeTests from module.xml) successfully.")

    set outFile = ##class(%Library.File).TempFilename()
    set outDir = ##class(%Library.File).NormalizeDirectory(##class(%Library.File).TempFilename()_"dir-out")
    do ##class(%Library.File).CreateDirectoryChain(outDir)
    do $$$AssertEquals($zf(-100,"/STDOUT="""_outFile_"""/STDERR="""_outFile_"""","tar","-xvf",tempDir_".tgz","-C",outDir),0)

    do $$$AssertTrue(##class(%File).Exists(outDir_"module.xml"),"module.xml is present in package.")
    do $$$AssertTrue(##class(%File).Exists(outDir_"tests/Test/Output/Format/AfterAllReturn.cls"),"Test file is present when IncludeTests set in module.xml.")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
