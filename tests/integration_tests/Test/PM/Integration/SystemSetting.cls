Class Test.PM.Integration.SystemSetting Extends Test.PM.Integration.Base
{

Method TestSystemSetting()
{
    set tSC = $$$OK
    try {
        // clean up any existing CSP settings
        kill ^%SYS("CSP","Test")

        set tModuleDir = ..GetModuleDir("system-setting")
        set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
        do $$$AssertStatusOK(tSC,"Module successfully installed")
        do $$$AssertEquals($get(^%SYS("CSP","Test")),"123","CSP setting was created with correct value")

        // clean up after test
        kill ^%SYS("CSP","Test")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestSystemSetting.")
    }
}

}
