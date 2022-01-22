Class Test.PM.Integration.InstallModule Extends Test.PM.Integration.Base
{

Method TestSimpleApp()
{
  Set tSC = $$$OK
  Try {
    Set tTestRoot = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot))

    Set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-module/")
    Set tSC = ##class(%ZPM.PackageManager).Shell("load "_tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully.")
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
