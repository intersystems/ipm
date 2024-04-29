Class Test.PM.Integration.Interoperability Extends Test.PM.Integration.Base
{

Method TestInteroperabilityDisabled()
{
  Set subfolder = "interoperability-disabled"
  Set tModuleDir = ..GetModuleDir(subfolder)
  Set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
  Do $$$AssertStatusOK(tSC,"Loaded module successfully(" _ subfolder _ ")")
}

Method TestInteroperabilityEnabled()
{
  If ('..IsInteroperabilityEnabled()) {
    Do $$$AssertSkipped("Interoperability not enabled for current namespace. Skipping test.")
    Return $$$OK
  }

  For subfolder = "interoperability-enabled", "iris-for-health" {
    If subfolder = "iris-for-health" {
      If '..IsHealthInstance() {
        Do $$$AssertSkipped("Health instance not found. Skipping test.")
        Return $$$OK
      }
    }
    Set tModuleDir = ..GetModuleDir(subfolder)
    Set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded module successfully(" _ subfolder _ ")")
  }
}

ClassMethod GetModuleDir(subfolder As %String) As %String
{
  Set tTestRoot = ##class(%File).NormalizeDirectory($GET(^UnitTestRoot))
  Set tTestRoot = ##class(%File).GetDirectory(tTestRoot)
  Set tModuleDir = ##class(%File).Construct(tTestRoot, "_data", "interoperability-test", subfolder)
  Set tModuleDir = ##class(%File).NormalizeDirectory(tModuleDir)
  Quit tModuleDir
}

ClassMethod IsInteroperabilityEnabled() As %Boolean
{
  Return ##class(%EnsembleMgr).IsEnsembleNamespace($NAMESPACE) && ##class(%EnsembleMgr).validateNamespace($NAMESPACE, 1)
}

ClassMethod IsHealthInstance() As %Boolean
{
  Return ''$LISTFIND($SYSTEM.Version.GetISCComponents(), "Health")
}

}
