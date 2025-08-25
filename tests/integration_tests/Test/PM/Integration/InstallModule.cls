Class Test.PM.Integration.InstallModule Extends Test.PM.Integration.Base
{

/// Update module TO-DOs:
/// 
/// 1. Add test to verify that attempting to run "install" without the force flag fails if a module is already installed
/// 2. Add test to check that a module with dependencies is has the latest version available in the configured repo
/// 3. Create Uninstall test suite with the following checks:
///   - Verify that rows in the UpdateStep table are properly removed when the module is uninstalled
///   - Verify that, if trying to uninstall a dependency module (should throw an error), it errors out and no update metadata is removed
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
}

}
