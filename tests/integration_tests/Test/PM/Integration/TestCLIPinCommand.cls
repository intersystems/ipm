Class Test.PM.Integration.TestCLIPinCommand Extends %UnitTest.TestCase
{

/// Test.PM.Integration.Base
Parameter ModuleFolder = "pin";

/// lightweight library used for python pip installation and uninstallation.
Parameter TestZPMModule = "web-fslog";

// test pin command

Method TestCLIPinCommand()
{
    set sc = $$$OK
    set sc = ..InstallZPMModule()
    do $$$AssertStatusOK(sc, "installing the module "_..#TestZPMModule)
    set tCommand = "pin "_..#TestZPMModule
    set sc = ..RunCommand(tCommand)
    do $$$AssertStatusOK(sc, "pinned the module "_..#TestZPMModule)
    do ..RePinThePinnedMoudle()
    do ..PreventFromInstall()
    do ..PreventFromReInstall()
    do ..PreventFromUnInstall()
    do ..PreventFromUpdate()
    do ..CLIUnPinCommand()
    quit sc
}

/// test unpin command
Method CLIUnPinCommand()
{
    set sc = $$$OK
    set tCommand ="unpin "_..#TestZPMModule
    set sc = ..RunCommand(tCommand)
    do $$$AssertStatusOK(sc, "unpin the module "_..#TestZPMModule)
    do ..UnInstallZPMModule()
    do $$$AssertStatusOK(sc, "uninstalled the module "_..#TestZPMModule)
    do ..UnPinTheUnpinnedModule()
    quit sc
}

Method UnPinTheUnpinnedModule()
{
    set tCommand ="unpin x-textpacakge"
    set sc = ..RunCommand(tCommand)
    do $$$AssertStatusNotOK(sc, "Unpin the unpinned module x-textpacakge")
}

Method RePinThePinnedMoudle()
{
    set tCommand ="pin "_..#TestZPMModule
    set sc = ..RunCommand(tCommand)
    do $$$AssertStatusNotOK(sc, "pin the already pinned module "_..#TestZPMModule)
}

/// list -p : display all pinned modules
Method ListPinnedModules()
{
    set sc = ..RunCommand("list -p")
    do $$$AssertStatusOK(sc, "list all the pinned "_..#TestZPMModule)
    return sc
}

Method PreventFromInstall()
{
    set sc = ..RunCommand("install "_..#TestZPMModule)
    do $$$AssertStatusNotOK(sc, "prevent from install the module"_..#TestZPMModule)
    return sc
}

Method PreventFromReInstall()
{
    set sc = ..RunCommand("reinstall "_..#TestZPMModule)
    do $$$AssertStatusNotOK(sc, "prevent from reinstall the module"_..#TestZPMModule)
    return sc
}

Method PreventFromUnInstall()
{
    set sc = ..RunCommand("uninstall "_..#TestZPMModule)
    do $$$AssertStatusNotOK(sc, "prevent from uninstall the module"_..#TestZPMModule)
    return sc
}

Method PreventFromUpdate()
{
    set sc = ..RunCommand("update "_..#TestZPMModule)
    do $$$AssertStatusNotOK(sc, "prevent from update the module"_..#TestZPMModule)
}

Method InstallZPMModule(pModule As %String = {..#TestZPMModule})
{
    set tCommand="install "_pModule
    return ..RunCommand(tCommand)
}

Method UnInstallZPMModule(pModule As %String = "")
{
    set tCommand="uninstall "_pModule
    return ..RunCommand(tCommand)
}

Method RunCommand(pCommand As %String)
{
	set sc= ##class(%IPM.Main).Shell(pCommand)
	do $$$LogMessage("Run command: "_pCommand)
    return sc
}

}
