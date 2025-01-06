Include %IPM.Common

Class Test.PM.Integration.StaticFileExport Extends Test.PM.Integration.Base
{

Method TestWSGIApp()
{
  Set tSC = $$$OK
  Try {
    Set tTestRoot = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot))
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/static-file-export-test/")
    Set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    Do $$$AssertStatusOK(tSC,"Module successfully. " _ tModuleDir)
    Set exportDir = ##class(%File).NormalizeDirectory($$$FileTempDirSys)
    Set tSC = ##class(%IPM.Main).Shell("static-file-export-test package -DPath="_exportDir)
    Do $$$AssertStatusOK(tSC,"Exported to directory " _ exportDir _ " successfully.")
    Do $$$AssertTrue(##class(%File).DirectoryExists(exportDir))
    For file = "LICENSE","README.md","requirements.txt","CHANGELOG.md" {
      Set tFile = ##class(%File).NormalizeFilename(file, exportDir)
      If '$$$AssertTrue(##class(%File).Exists(tFile)) {
        Do $$$LogMessage("File "_tFile_" does not exist.")
      }
    }
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(), "An exception occurred.")
  }
}

}
