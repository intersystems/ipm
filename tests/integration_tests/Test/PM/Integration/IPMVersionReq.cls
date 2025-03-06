Class Test.PM.Integration.IPMVersionReq Extends Test.PM.Integration.Base
{

Parameter CommonPathPrefix As STRING = "ipm-version-req-test";

Method TestInteroperabilityEnabled()
{
  Set tCases = $ListBuild( 
    $ListBuild("version-req-missing", 1),
    $ListBuild("version-req-satisfied", 1),
    $ListBuild("version-req-too-high", 0),
    $ListBuild("version-req-too-low", 0)
  )
  Set ptr = 0
  While $ListNext(tCases, ptr, case) {
    set $ListBuild(subfolder, expected) = case
    Set tModuleDir = ..GetModuleDir(..#CommonPathPrefix, subfolder)
    Set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
    If expected = 1 {
      Do $$$AssertStatusOK(tSC,"Loaded module successfully (" _ subfolder _ ")")
    } Else {
      Do $$$AssertStatusNotOK(tSC, "Load modules failed as expected (" _ subfolder _ ")")
    }
  }
}

}
