Class Test.PM.Integration.ExternalNameModuleAction Extends Test.PM.Integration.Base
{

Parameter Folder = "ext-name-mod-action";

Parameter DefaultName = "default-name-mod-action";

Parameter ExternalName = "ext-name-mod-action";

Method TestExternalNameModuleAction()
{
    Set dir = ..GetModuleDir(..#Folder)
    Set sc = ##class(%IPM.Main).Shell("load "_dir)
    Do $$$AssertStatusOK(sc, "Successfully loaded module")

    Set sc = ##class(%IPM.Main).Shell(..#DefaultName_" greeting")
    Do $$$AssertStatusOK(sc, "Successfully executed action by default name")

    Set sc = ##class(%IPM.Main).Shell(..#ExternalName_" greeting")
    Do $$$AssertStatusOK(sc, "Successfully executed action by default name")
}

}
