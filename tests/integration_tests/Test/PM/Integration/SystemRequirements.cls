Class Test.PM.Integration.SystemRequirements Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
{
    set sc = ##class(%IPM.Main).Shell("enable -map -globally")
    do $$$AssertStatusOK(sc, "IPM mapped to all namespaces globally.")
    return $$$OK
}

Method OnAfterAllTests() As %Status
{
    new $namespace
    set $namespace = "%SYS"
    do ##class(%IPM.Main).Shell("uninstall sys-ns-module")
    set sc = ##class(%IPM.Main).Shell("unmap -g")
    do $$$AssertStatusOK(sc, "IPM unmapped globally.")
    return $$$OK
}

Method TestSYSNamespaceRequirement() As %Status
{
    if $namespace = "%SYS" { return $$$OK }
    set sourceDir = ..GetModuleDir("sys-ns-module")

    // Try loading in current namespace; should fail with %SYS requirement error
    set sc = ##class(%IPM.Main).Shell("load " _ sourceDir)
    do $$$AssertStatusNotOK(sc, "sys-ns-module load fails in non-%SYS namespace as expected.")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "requires the %SYS namespace", "Error cites %SYS namespace requirement.")

    // Try loading in %SYS namespace; should succeed
    new $namespace
    set $namespace = "%SYS"
    set sc = ##class(%IPM.Main).Shell("load " _ sourceDir)
    do $$$AssertStatusOK(sc, "sys-ns-module loads in %SYS namespace.")
    do $$$AssertEquals(##class(SysNS.Module).Hello(), "Hello from SysNS.Module", "SysNS.Module.Hello() runs and returns expected value.")
    return $$$OK
}

}
