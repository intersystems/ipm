Include %IPM.Common

Class Test.PM.Integration.StaticFileExport Extends Test.PM.Integration.Base
{

Method TestWSGIApp()
{
  set tSC = $$$OK
  try {
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/static-file-export-test/")
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    do $$$AssertStatusOK(tSC,"Module successfully. " _ tModuleDir)
    set exportDir = ##class(%File).NormalizeDirectory($$$FileTempDirSys)
    set tSC = ##class(%IPM.Main).Shell("static-file-export-test package -verbose -DPath="_exportDir)
    do $$$AssertStatusOK(tSC,"Exported to directory " _ exportDir _ " successfully.")
    // Need to unpack the tgz file
    do $$$AssertStatusOK(##class(%IPM.Utils.File).RemoveDirectoryTree(exportDir))
    set tgzFile = $zstrip(exportDir,">","/\")_".tgz"
    set tSC = ##class(%IPM.General.Archive).Extract(tgzFile,exportDir,.tOutput)
    do $$$AssertStatusOK(tSC, "Unpackaged " _ tgzFile _ " to "_exportDir)

    do $$$AssertTrue(##class(%File).DirectoryExists(exportDir))
    for file = "LICENSE","README.md","requirements.txt","CHANGELOG.md" {
      set tFile = ##class(%File).NormalizeFilename(file, exportDir)
      if '$$$AssertTrue(##class(%File).Exists(tFile)) {
        do $$$LogMessage("File "_tFile_" does not exist.")
      }
    }
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(), "An exception occurred.")
  }
}

}
