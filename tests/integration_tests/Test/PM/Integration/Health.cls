Class Test.PM.Integration.Health Extends Test.PM.Integration.Base
{

Parameter CommonPathPrefix As STRING = "health-test";

Method TestHealthTrue()
{
  set tModuleDir = ..GetModuleDir(..#CommonPathPrefix, "health-true")
  set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
  if ##class(%IPM.Storage.SystemRequirements).IsHealthInstance() {
    do $$$AssertStatusOK(tSC,"Loaded module successfully (health-true)")
  } else {
    do $$$AssertStatusNotOK(tSC, "Load module failed as expected (health-true)")
  }
}

Method TestHealthFalse()
{
  set tModuleDir = ..GetModuleDir(..#CommonPathPrefix, "health-false")
  set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
  if ##class(%IPM.Storage.SystemRequirements).IsHealthInstance() {
    do $$$AssertStatusNotOK(tSC, "Load module failed as expected (health-false)")
  } else {
    do $$$AssertStatusOK(tSC,"Loaded module successfully (health-false)")
  }
}

Method TestHealthOmitted()
{
  set tModuleDir = ..GetModuleDir(..#CommonPathPrefix, "health-omitted")
  set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
  do $$$AssertStatusOK(tSC,"Loaded module successfully (health-omitted)")
}

}
