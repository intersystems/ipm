Class Test.PM.Integration.InstallModule Extends Test.PM.Integration.Base
{

Method TestSimpleApp()
{
  Set tSC = $$$OK
  Try {
    Set tTestRoot = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot))

    Set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-module/")
    Set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully.")
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }

  // Check that the UpdateStep is seeded, if UpdateSteps exist
  // Check that error is thrown if the module is already installed
}

}
