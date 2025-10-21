Class Test.PM.Integration.VersionReq Extends Test.PM.Integration.Base
{

Parameter CommonPathPrefix As STRING = "version-req-test";

Method TestIPMVersionRequirements()
{
    set tCases = $listbuild(
        $listbuild("version-req-missing", 1),
        $listbuild("version-req-satisfied", 1),
        $listbuild("version-req-too-high", 0),
        $listbuild("version-req-too-low", 0)
    )
    set ptr = 0
    while $listnext(tCases, ptr, case) {
        set $listbuild(subfolder, expected) = case
        set tModuleDir = ..GetModuleDir(..#CommonPathPrefix, subfolder)
        set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
        if expected = 1 {
            do $$$AssertStatusOK(tSC,"Loaded module successfully (" _ subfolder _ ")")
        } else {
            do $$$AssertStatusNotOK(tSC, "Load modules failed as expected (" _ subfolder _ ")")
        }
    }
}

Method TestPythonVersionRequirements()
{
    set tCases = $listbuild(
        $listbuild("python-version-req-satisfied", 1),
        $listbuild("python-version-req-too-high", 0),
        $listbuild("python-version-req-too-low", 0)
    )
    set ptr = 0
    while $listnext(tCases, ptr, case) {
        set $listbuild(subfolder, expected) = case
        set tModuleDir = ..GetModuleDir(..#CommonPathPrefix, subfolder)
        set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
        if expected = 1 {
            do $$$AssertStatusOK(tSC,"Loaded module successfully (" _ subfolder _ ")")
        } else {
            do $$$AssertStatusNotOK(tSC, "Load modules failed as expected (" _ subfolder _ ")")
        }
    }
}

}
