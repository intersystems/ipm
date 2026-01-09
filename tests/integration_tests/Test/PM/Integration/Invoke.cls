Class Test.PM.Integration.Invoke Extends Test.PM.Integration.Base
{

Method TestInvokeCheckStatus()
{
    // These invokes should succeed
    set moduleDir = ..GetModuleDir("invoke/success")
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc,"Loaded module successfully")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall -verbose invoke")
    do $$$AssertStatusOK(sc,"Uninstalled module successfully")

    // These invokes should fail
    set prefix = "invoke/failure/"
    set modules = $listbuild("NonStatusReturnCheckStatus", "NonStatusReturnNoCheckStatus", "NoStatusCheckStatus", "ReturnErrorCheckStatus",  "ReturnErrorNoCheckStatus", "ReturnNonErrorCheckStatus", "StatusNotReturnedCheckStatus", "StatusNotReturnedNoCheckStatus")

    set pos = 0
    while $listnext(modules, pos, mod) {
        set moduleDir = ..GetModuleDir(prefix _ mod)
        set tSC = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
        do $$$AssertStatusNotOK(tSC,"Module load failed")
    }
}

Method TestInvokeIpmDirExpression()
{
    set sc = $$$OK
    try {
        // Clear any previous test data
        kill ^IRIS.Temp.Test.IpmDir

        // Load module that invokes with ${ipmdir} argument
        set moduleDir = ..GetModuleDir("invoke-ipmdir")
        set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
        do $$$AssertStatusOK(sc, "Module loaded successfully")

        // Verify the invoke was called and stored the path
        do $$$AssertTrue($data(^IRIS.Temp.Test.IpmDir), "Invoke.IpmDirTest method was called")

        // Verify the path is correct
        set receivedPath = $get(^IRIS.Temp.Test.IpmDir)
        set expectedPath = ##class(%Library.File).NormalizeDirectory(
            $system.Util.DataDirectory() _ "ipm/invoke-ipmdir-test/1.0.0/")
        do $$$AssertEquals(receivedPath, expectedPath, "ipmDir expression correctly evaluated to: " _ expectedPath)

        // Clean up - uninstall module
        set sc = ##class(%IPM.Main).Shell("uninstall -verbose invoke-ipmdir-test")
        do $$$AssertStatusOK(sc, "Module uninstalled successfully")

        // Clean up temp global
        kill ^IRIS.Temp.Test.IpmDir

    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "Exception in TestInvokeIpmDirExpression")
    }
}

}
