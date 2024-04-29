Class Test.PM.Integration.Health Extends Test.PM.Integration.Base
{

Method TestHealthTrue()
{
  If '..IsHealthInstance() {
    do $$$AssertSkipped("Health instance not found. Skipping test.")
    Return $$$OK
  }
  set tModuleDir = ..GetModuleDir("health-true")
  set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
  do $$$AssertStatusOK(tSC,"Loaded module successfully (health-true)")
}

Method TestHealthFalse()
{
  set tModuleDir = ..GetModuleDir("health-false")
  set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
  do $$$AssertStatusOK(tSC,"Loaded module successfully (health-false)")
}

Method TestHealthOmitted()
{
  set tModuleDir = ..GetModuleDir("health-omitted")
  set tSC = ##class(%IPM.Main).Shell("load "_tModuleDir)
  do $$$AssertStatusOK(tSC,"Loaded module successfully (health-omitted)")
}

ClassMethod GetModuleDir(subfolder As %String) As %String
{
  Set tTestRoot = ##class(%File).NormalizeDirectory($GET(^UnitTestRoot))
  Set tTestRoot = ##class(%File).GetDirectory(tTestRoot)
  Set tModuleDir = ##class(%File).Construct(tTestRoot, "_data", "health-test", subfolder)
  Set tModuleDir = ##class(%File).NormalizeDirectory(tModuleDir)
  Quit tModuleDir
}

ClassMethod IsHealthInstance() As %Boolean
{
  Return ''$LISTFIND($SYSTEM.Version.GetISCComponents(), "Health")
}

}
