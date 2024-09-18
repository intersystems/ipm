Class Test.PM.Integration.CustomPhase Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "custom-phase-without-lifecycle";

Method TestCustomPhaseWithoutLifecycle()
{
    Set tModuleDir = ..GetModuleDir(..#TargetModuleName)

    // Custom phase should not be executed during load
    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)
    Set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pLoadOutput)
    Do $$$AssertNotTrue(..FindStringInMultiDimArray("Hello", .pLoadOutput))
    Do $$$AssertStatusOK(tSC,"Loaded module successfully")

    // Custom phase should be executed during module-actions
    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)
    Set tSC = ##class(%IPM.Main).Shell(..#TargetModuleName _ " greeting -only")
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pModuleActionOutput)
    Do $$$AssertTrue(..FindStringInMultiDimArray("Hello", .pModuleActionOutput))
    Do $$$AssertStatusOK(tSC,"Custom phase greeting executed successfully")

    // Custom phase should not be executed during uninstall
    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.tCookie)
    Set tSC = ##class(%IPM.Main).Shell("uninstall -verbose " _ ..#TargetModuleName)
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(tCookie,.pUninstallOutput)
    Do $$$AssertNotTrue(..FindStringInMultiDimArray("Hello", .pUninstallOutput))
    Do $$$AssertStatusOK(tSC,"Deleted module succesfully")
}

}
