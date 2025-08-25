Class Test.PM.Integration.FileCopy Extends Test.PM.Integration.Base
{

Method TestPackageNameExpression()
{
    set tSC = $$$OK
    try {
        set tModuleDir = ..GetModuleDir("packagename")
        set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
        do $$$AssertStatusOK(tSC,"Module successfully installed")

        // Verify the destination has correctly replaced $(packagename)
        set mgrDir = $system.Util.ManagerDirectory()
        do $$$AssertTrue(##class(%File).Exists(mgrDir _ "FileCopy/testmodule/cls/Test.cls"), "Test.cls in " _ mgrDir _ "FileCopy/testmodule/cls exists")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestPackageNameExpression.")
    }
}

}
