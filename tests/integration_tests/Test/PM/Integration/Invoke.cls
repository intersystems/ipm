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

}
