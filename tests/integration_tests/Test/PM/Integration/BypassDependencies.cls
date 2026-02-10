Class Test.PM.Integration.BypassDependencies Extends Test.PM.Integration.Base
{

/// Validates the functionality of the '-bypass-deps' (or '-bd') flag during module installation.
/// This test ensures that the target module is installed successfully while its
/// defined dependencies are explicitly skipped.
Method TestBypassDependencies()
{
    set moduleDir = ##class(%File).NormalizeDirectory($get(^UnitTestRoot)_"/_data/bypass-dependencymods-flag/")
    set dependencyModules = $listbuild("test-dependency-1","test-dependency-2")

    do $$$LogMessage("Loading the module wit -bypass-deps to verify dependencies not installed...")
    set status = ##class(%IPM.Main).Shell("load " _ moduleDir_" -bypass-deps")
    do $$$AssertStatusOK(status,"Loaded SimpleApp demo-module1 with -bypass-deps successfully."_moduleDir)

    do $$$LogMessage("Verifying that dependencies were not installed...")
    set ptr = 0
    while $listnext(dependencyModules, ptr, module) {
        set exists = ##class(%IPM.Storage.Module).NameExists(module)
        do $$$AssertNotTrue(exists, "Dependency module '"_module_"' not installed when loading with -bypass-deps.")
    }

    // Now load again without -bypass-deps to verify dependencies get installed
    do $$$LogMessage("Now loading the module without -bypass-deps to verify dependencies get installed...")
    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Module demo-module1 is loaded without -bypass-deps")

    set ptr = 0
    while $listnext(dependencyModules, ptr, module) {
        set exists = ##class(%IPM.Storage.Module).NameExists(module)
        do $$$AssertTrue(exists, "Dependency module '"_module_"' should be installed when loading without -bypass-deps.")
    }

    do $$$LogMessage("uninstalling the demo-module1 and its dependencies...")
    set status = ##class(%IPM.Main).Shell("uninstall demo-module1 -r")
    do $$$AssertStatusOK(status,"Uninstalled demo-module1 and its dependencies successfully.")
}

}
