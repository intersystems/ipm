Class Test.PM.Integration.Interoperability Extends Test.PM.Integration.Base
{

Method TestInteroperability()
{
  Set tSC = $$$OK
  Try {
    Set tTestRoot = ##class(%File).NormalizeDirectory($GET(^UnitTestRoot))
    Set tTestRoot = ##class(%File).GetDirectory(tTestRoot)
    Set tModuleDir = ##class(%File).Construct(tTestRoot, "_data", "interoperability-test", "interoperability-disabled")
    Set tModuleDir = ##class(%File).NormalizeDirectory(tModuleDir)
    // TODO: how to programmatically enable/disable interoperability?
    // TODO: how to programmatically switch between iris and iris-for-health?
    Set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded SimpleModule module successfully.")
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
