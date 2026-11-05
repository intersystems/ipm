/// Covers what the show command reads from the namespace. Test.PM.Unit.ModuleSummary covers formatting.
Class Test.PM.Integration.Show Extends Test.PM.Integration.Base
{

Method TestShowsInstalledModule()
{
    set depDir = ..GetModuleDir("show", "show-dep")
    set mainDir = ..GetModuleDir("show", "show-main")
    try {
        set sc = ##class(%IPM.Main).Shell("load " _ depDir _ " -bypass-py-deps")
        do $$$AssertStatusOK(sc, "Loaded show-dep")
        set sc = ##class(%IPM.Main).Shell("load " _ mainDir _ " -bypass-py-deps")
        do $$$AssertStatusOK(sc, "Loaded show-main")

        do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
        set sc = ##class(%IPM.Main).Shell("show SHOW-MAIN")
        do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .mainOutput)
        do $$$AssertStatusOK(sc, "show SHOW-MAIN")
        do $$$AssertTrue(..FindStringInMultiDimArray("ShowMain (show-main) 1.2.3", .mainOutput), "Title")
        do $$$AssertTrue(..FindStringInMultiDimArray(mainDir, .mainOutput), "Root")
        do $$$AssertTrue(..FindLineWithAll(.mainOutput, "show-dep", "^1.0.0", "installed 1.0.0"), "Installed dependency version")
        do $$$AssertTrue(..FindStringInMultiDimArray("requirements.txt: requests", .mainOutput), "requirements.txt")
        do $$$AssertNotTrue(..FindStringInMultiDimArray("show-missing", .mainOutput), "Scoped dependency is left out")

        do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
        set sc = ##class(%IPM.Main).Shell("show showmain")
        do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .externalNameOutput)
        do $$$AssertStatusOK(sc, "show showmain")
        do $$$AssertTrue(..FindStringInMultiDimArray("ShowMain (show-main) 1.2.3", .externalNameOutput), "Lookup by ExternalName")

        do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
        set sc = ##class(%IPM.Main).Shell("show show-dep")
        do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .depOutput)
        do $$$AssertStatusOK(sc, "show show-dep")
        do $$$AssertTrue(..FindStringInMultiDimArray("Required by directly (1)", .depOutput), "Required by heading")
        do $$$AssertTrue(..FindStringInMultiDimArray("show-main 1.2.3", .depOutput), "Direct dependent")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(), "No exception")
    }
    do ##class(%IPM.Main).Shell("uninstall show-main")
    do ##class(%IPM.Main).Shell("uninstall show-dep")
}

Method TestUnknownModuleFails()
{
    set sc = ##class(%IPM.Main).Shell("show no-such-module")
    do $$$AssertStatusNotOK(sc, "show fails for a module that is not installed")
    set text = $system.Status.GetErrorText(sc)
    do $$$AssertTrue(text [ "no-such-module", "Error names the module: " _ text)
    do $$$AssertTrue(text [ $namespace, "Error names the namespace: " _ text)
}

/// Returns whether one element of array contains every string in parts.
ClassMethod FindLineWithAll(
	ByRef array,
	parts... As %String) As %Boolean
{
    set sub = ""
    for {
        set sub = $order(array(sub), 1, line)
        quit:sub=""
        set found = 1
        for i = 1:1:parts {
            if '(line [ parts(i)) {
                set found = 0
                quit
            }
        }
        if found {
            return 1
        }
    }
    return 0
}

}
