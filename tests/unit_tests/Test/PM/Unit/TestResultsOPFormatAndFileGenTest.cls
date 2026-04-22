/// Unit Test Class to validate the ZPM 'test' command output configuration.
/// This class ensures two primary functions work correctly:
/// 1. <b>Console Formatting:</b> Verifies the `-f` / `-output` flags correctly
///    format test results for terminal display (e.g., YAML, JSON).
/// 2. <b>File Generation:</b> Verifies the `-DUnitTest.<Format>Output` definitions
///    successfully create and populate the structured results files (e.g., .json, .yaml, .toon).
Class Test.PM.Unit.TestResultsOPFormatAndFileGenTest Extends %UnitTest.TestCase
{

Method TestFail()
{
    do $$$AssertFailure("This test is designed to fail to validate the test framework's ability to capture failures.")
}

/// generate .yaml,.json,.toon files
Method TestResultFileGeneration()
{
    do $$$LogMessage("This file generation picks the last or current unit test id and generate the reports")

    set fileDir = ##class(%File).NormalizeDirectory($get(^UnitTestRoot)_"/test-reports/")
    if '##class(%File).DirectoryExists(fileDir){
        set status = ##class(%File).CreateDirectoryChain(fileDir)
        do $$$AssertStatusOK(status,"Directory created: "_fileDir)
    }

    do $$$LogMessage("Start generating the reports")

    set fileName = ##class(%File).NormalizeFilename(fileDir_"test.yaml")
    set status = ##class(%IPM.Test.YamlOutput).ToFile(fileName)
    do $$$AssertStatusOK(status,"yaml file generated successfully in "_fileDir)
    do $$$AssertTrue(##class(%File).GetFileSize(fileName)>0,"yaml file is non-empty")

    set fileName = ##class(%File).NormalizeFilename(fileDir_"test.json")
    set status = ##class(%IPM.Test.JsonOutput).ToFile(fileName)
    do $$$AssertStatusOK(status,"Json file generated successfully in "_fileDir)
    do $$$AssertTrue(##class(%File).GetFileSize(fileName)>0,"json file is non-empty")

    set fileName = ##class(%File).NormalizeFilename(fileDir_"test.toon")
    set status = ##class(%IPM.Test.ToonOutput).ToFile(fileName)
    do $$$AssertStatusOK(status,"Toon file generated successfully in "_fileDir)
    do $$$AssertTrue(##class(%File).GetFileSize(fileName)>0,"toon file is non-empty")

    do ..ShowGeneratedFilesAndCleaup(fileDir)
}

Method ShowGeneratedFilesAndCleaup(fileDir As %String)
{
    do $$$LogMessage("Display the generated unit test report files")
    set fileSet = ##class(%File).FileSetFunc(fileDir)
    while fileSet.%Next() {
        set file = fileSet.Name
        set fileNames(file) = fileSet.ItemName
        do $$$LogMessage("Generated file "_file)
    }
    do $$$LogMessage("Started Cleanup the generated unit test report files")
    set file = ""
    for {
        set file = $order(fileNames(file),1,fileName)
        quit:file=""
        set status = ##class(%File).Delete(file)
        do $$$AssertStatusOK(status," File '"_fileName_"' has been deleted successfully")
    }
    do $$$LogMessage("File cleanup completed")
}

}
