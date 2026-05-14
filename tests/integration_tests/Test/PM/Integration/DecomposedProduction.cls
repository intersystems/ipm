Class Test.PM.Integration.DecomposedProduction Extends Test.PM.Integration.Base
{

Parameter NEEDSREGISTRY As BOOLEAN = 0;

Method OnBeforeAllTests() As %Status
{
    set status = ##class(%IPM.Main).Shell("repo -n integration-tests -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/")
    $$$ThrowOnError(status)
    if '##class(%IPM.Storage.SystemRequirements).IsInteroperabilityEnabled() {
        set status = ##class(%EnsembleMgr).EnableNamespace($namespace, 1)
        $$$ThrowOnError(status)
    }
    quit $$$OK
}

Method TestLoadFromDirectory()
{
    set status = $$$OK
    try {
        set moduleDir = ..GetModuleDir("decomposed-production")
        set status = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
        do $$$AssertStatusOK(status, "Loaded module-a from directory.")

        do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Sample.NewProduction"), "Production class Sample.NewProduction exists after load.")

        set prodConfig = ##class(Ens.Config.Production).%OpenId("Sample.NewProduction", , .openSC)
        do $$$AssertStatusOK(openSC, "Ens.Config.Production record for Sample.NewProduction is accessible.")
        do $$$AssertTrue($isobject(prodConfig), "Ens.Config.Production object is valid.")

        set status = ##class(%IPM.Main).Shell("uninstall module-a -r")
        do $$$AssertStatusOK(status, "Uninstalled module-a.")

        do $$$AssertTrue('##class(%Dictionary.ClassDefinition).%ExistsId("Sample.NewProduction"), "Production class Sample.NewProduction removed after uninstall.")
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "An exception occurred in TestLoadFromDirectory.")
    }
}

Method TestAutoStart()
{
    set status = $$$OK
    try {
        set moduleDir = ..GetModuleDir("decomposed-production")
        set status = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
        do $$$AssertStatusOK(status, "Loaded module-a from directory.")

        do $$$AssertEquals($get(^Ens.AutoStart), "Sample.NewProduction")

        set status = ##class(%IPM.Main).Shell("uninstall module-a -r")
        do $$$AssertStatusOK(status, "Uninstalled module-a.")

        do $$$AssertEquals($get(^Ens.AutoStart), "")
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "An exception occurred in TestAutoStart.")
    }
}

Method TestPackagePublishInstall()
{
    set status = $$$OK
    try {
        set status = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
        do $$$AssertStatusOK(status, "Configured Zot registry.")

        set moduleDir = ..GetModuleDir("decomposed-production")
        set status = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
        do $$$AssertStatusOK(status, "Loaded module-a from directory.")

        set status = ##class(%IPM.Main).Shell("publish module-a -r zot -verbose")
        do $$$AssertStatusOK(status, "Published module-a to Zot registry.")

        set status = ##class(%IPM.Main).Shell("uninstall module-a -r")
        do $$$AssertStatusOK(status, "Uninstalled module-a before reinstall from registry.")

        do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Sample.NewProduction"), "Production class removed after uninstall.")

        set status = ##class(%IPM.Main).Shell("install module-a -verbose")
        do $$$AssertStatusOK(status, "Installed module-a from Zot registry.")

        do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Sample.NewProduction"), "Production class Sample.NewProduction exists after install from registry.")

        set status = ##class(%IPM.Main).Shell("uninstall module-a -r")
        do $$$AssertStatusOK(status, "Final uninstall of module-a.")
    } catch ex {
        do $$$AssertStatusOK(ex.AsStatus(), "An exception occurred in TestPackagePublishInstall.")
    }
    // Always clean up the Zot repo config
    do ##class(%IPM.Main).Shell("repo -n zot -delete")
}

}
