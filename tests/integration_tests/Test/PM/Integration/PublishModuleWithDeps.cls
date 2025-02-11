Class Test.PM.Integration.PublishModuleWithDeps Extends Test.PM.Integration.Base
{

Method TestPublishWithDeps() As %Status
{
    Set moduleDir = ..GetModuleDir()

    Set sc = ##class(%IPM.Main).Shell("repo -fs -name localrepo -path " _ moduleDir)
    Do $$$AssertStatusOK(sc, "Successfully configured local filesystem repo")

    Set sc = ##class(%IPM.Main).Shell("install -v localrepo/publish-with-deps")
    Do $$$AssertStatusOK(sc, "Successfully installed module from local filesystem repo")

    Set sc = ##class(%IPM.Main).Shell("repo -delete -n localrepo")
    Do $$$AssertStatusOK(sc, "Successfully deleted local filesystem repo")

    // This test should work in the CI environment, where the registry is already set up
    // To make it pass locally, you need to manually set up the registry at the following URL and set the username and password accordingly
    Set sc = ##class(%IPM.Main).Shell("repo -r -name customrepo -url http://registry:52773/registry -username admin -password SYS")
    Do $$$AssertStatusOK(sc, "Successfully set up custom repo")

    Set sc = ##class(%IPM.Main).Shell("publish publish-with-deps -r customrepo -v -export-deps 1")
    Do $$$AssertStatusOK(sc, "Successfully published module with dependencies")

    Set sc = ##class(%IPM.Main).Shell("uninstall publish-with-deps-dep")
    Do $$$AssertStatusOK(sc, "Successfully uninstalled dependency")

    Set sc = ##class(%IPM.Main).Shell("uninstall publish-with-deps")
    Do $$$AssertStatusOK(sc, "Successfully uninstalled module")

    Set sc = ##class(%IPM.Main).Shell("install -v customrepo/publish-with-deps")
    Do $$$AssertStatusOK(sc, "Successfully installed module from custom repo")

    Set sc = ##class(%IPM.Main).Shell("repo -delete -n customrepo")
    Do $$$AssertStatusOK(sc, "Successfully deleted local registry")

    Set sc = ##class(%IPM.Main).Shell("uninstall publish-with-deps-dep")
    Do $$$AssertStatusOK(sc, "Successfully uninstalled dependency again")

    Set sc = ##class(%IPM.Main).Shell("uninstall publish-with-deps")
    Do $$$AssertStatusOK(sc, "Successfully uninstalled module again")

    Quit $$$OK
}

}
