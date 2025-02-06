Class Test.PM.Integration.PublishModuleWithDeps Extends Test.PM.Integration.Base
{

Parameter ModuleFolder = "publish-with-deps";

Method TestPublishWithDeps() As %Status
{
    Set moduleDir = ..GetModuleDir(..#ModuleFolder)

    Set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    Do $$$AssertStatusOK(sc, "Successfully loaded module (and dependencies) from folder")

    // This test should work in the CI environment, where the registry is already set up
    // To make it pass locally, you need to manually set up the registry at the following URL and set the username and password accordingly
    Set sc = ##class(%IPM.Main).Shell("repo -r -name localregistry -url http://registry:52773/registry -username admin -password SYS")
    Do $$$AssertStatusOK(sc, "Successfully set up local registry")

    Set sc = ##class(%IPM.Main).Shell("publish publish-with-deps -r localregistry -v -export-deps 1")
    Do $$$AssertStatusOK(sc, "Successfully published module with dependencies")

    Set sc = ##class(%IPM.Main).Shell("repo -delete -n localregistry")
    Do $$$AssertStatusOK(sc, "Successfully deleted local registry")

    Quit $$$OK
}

}
