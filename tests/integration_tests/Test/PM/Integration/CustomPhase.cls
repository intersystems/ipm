Class Test.PM.Integration.CustomPhase Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "custom-phase-without-lifecycle";

Method TestCustomPhaseWithoutLifecycle()
{
    Set tModuleDir = ..GetModuleDir(..#TargetModuleName)
    Set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded module successfully")
    Set tSC = ##class(%IPM.Main).Shell(..#TargetModuleName _ " greeting -only")
    Do $$$AssertStatusOK(tSC,"Custom phase greeting executed successfully")
    Set tSC = ##class(%IPM.Main).Shell("uninstall -verbose " _ ..#TargetModuleName)
    Do $$$AssertStatusOK(tSC,"Deleted module succesfully")
}

}
