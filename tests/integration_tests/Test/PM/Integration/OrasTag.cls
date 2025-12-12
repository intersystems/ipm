Class Test.PM.Integration.OrasTag Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "oras-tag";

Method TestOrasTagConversion()
{
    set moduleDir = ..GetModuleDir(..#TargetModuleName)

    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc,"Loaded module successfully")

    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc,"Deleted repos successfully")

    set sc = ##class(%IPM.Main).Shell("repo -o -name oras -url http://oras:5000 -publish 1")
    do $$$AssertStatusOK(sc,"Set up oras module successfully")

    set sc = ##class(%IPM.Main).Shell("publish oras-tag -r oras -verbose")
    do $$$AssertStatusOK(sc,"Published module successfully")

    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc,"Uninstalled module successfully")

    set sc = ##class(%IPM.Main).Shell("install oras-tag")
    do $$$AssertStatusOK(sc,"Installed module from ORAS registry successfully")

    // Cleanup
    set sc = ##class(%IPM.Main).Shell("unpublish oras/oras-tag all -force")
    do $$$AssertStatusOK(sc,"Unpublished module successfully")

    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc,"Deleted repos successfully")

    set sc = ##class(%IPM.Main).Shell("repo -reset-defaults")
    do $$$AssertStatusOK(sc,"Reset repos to default successfully")
}

Method TestOrasNamespace()
{
    set moduleDir = ..GetModuleDir(..#TargetModuleName)

    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc,"Loaded module successfully")

    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc,"Deleted repos successfully")

    // Set up oras module with namespace
    set sc = ##class(%IPM.Main).Shell("repo -o -name oras -url http://oras:5000 -ns testnamespace -publish 1")
    do $$$AssertStatusOK(sc,"Set up oras module with namespace successfully")

    // Publish module (should be stored as testnamespace/oras-tag)
    set sc = ##class(%IPM.Main).Shell("publish oras-tag -r oras -verbose")
    do $$$AssertStatusOK(sc,"Published module successfully to namespaced repo")

    // Uninstall and reinstall
    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc,"Uninstalled module successfully")

    set sc = ##class(%IPM.Main).Shell("install oras-tag")
    do $$$AssertStatusOK(sc,"Installed module from namespaced ORAS registry successfully")

    // Verify searching only shows modules in the namespace
    set sc = ##class(%IPM.Main).Shell("repo -list-modules -n oras")
    do $$$AssertStatusOK(sc,"Listed modules in namespaced repo successfully")

    // Reconfigure to no namespace to verify isolation
    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns """"")
    do $$$AssertStatusOK(sc,"Reconfigured oras repo without namespace")

    // Publish to the non-namespaced repo (should be stored as oras-tag)
    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc,"Uninstalled module before republishing")

    // Load module again
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc,"Reloaded module successfully")

    set sc = ##class(%IPM.Main).Shell("publish oras-tag -r oras -verbose")
    do $$$AssertStatusOK(sc,"Published module to non-namespaced repo")

    // Reconfigure back to namespace
    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns testnamespace")
    do $$$AssertStatusOK(sc,"Reconfigured oras repo with namespace again")

    // Verify we can install from the namespaced repo (should find testnamespace/oras-tag)
    set sc = ##class(%IPM.Main).Shell("install oras/oras-tag")
    do $$$AssertStatusOK(sc,"Installed module from namespaced repo using oras/oras-tag syntax")

    // Reconfigure to no namespace
    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns """"")
    do $$$AssertStatusOK(sc,"Reconfigured oras repo without namespace again")

    // Verify we can also install from the non-namespaced repo
    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc,"Uninstalled module successfully")

    set sc = ##class(%IPM.Main).Shell("install oras/oras-tag")
    do $$$AssertStatusOK(sc,"Installed module from non-namespaced repo using oras/oras-tag syntax")

    // Cleanup - unpublish from both namespaced and non-namespaced
    set sc = ##class(%IPM.Main).Shell("unpublish oras/oras-tag all -force")
    do $$$AssertStatusOK(sc,"Unpublished module from non-namespaced repo")

    set sc = ##class(%IPM.Main).Shell("repo -n oras -ns testnamespace")
    do $$$AssertStatusOK(sc,"Reconfigured oras repo with namespace for cleanup")

    set sc = ##class(%IPM.Main).Shell("unpublish oras/oras-tag all -force")
    do $$$AssertStatusOK(sc,"Unpublished module from namespaced repo")

    set sc = ##class(%IPM.Main).Shell("uninstall oras-tag")
    do $$$AssertStatusOK(sc,"Uninstalled module successfully")

    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc,"Deleted repos successfully")

    set sc = ##class(%IPM.Main).Shell("repo -reset-defaults")
    do $$$AssertStatusOK(sc,"Reset repos to default successfully")
}

}
