Class Test.PM.Integration.Interoperability Extends Test.PM.Integration.Base
{

Parameter CommonPathPrefix As STRING = "interoperability-test";

Method TestInteroperabilityDisabled()
{
  Set subfolder = "interoperability-disabled"
  Set tModuleDir = ..GetModuleDir(subfolder)
  Set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
  Do $$$AssertStatusOK(tSC,"Loaded module successfully(" _ subfolder _ ")")
}

Method TestInteroperabilityEnabled()
{
  For subfolder = "interoperability-enabled", "iris-for-health" {
    Set tModuleDir = ..GetModuleDir(..#CommonPathPrefix, subfolder)
    Set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)

    if ('##class(%IPM.Storage.SystemRequirements).IsInteroperabilityEnabled()) || ('##class(%IPM.Storage.SystemRequirements).IsHealthInstance() && (subfolder = "iris-for-health")) {
      Do $$$AssertStatusNotOK(tSC, "Load modules failed as expected")
    } else {
      Do $$$AssertStatusOK(tSC,"Loaded module successfully(" _ subfolder _ ")")
    }
  }
}

}
