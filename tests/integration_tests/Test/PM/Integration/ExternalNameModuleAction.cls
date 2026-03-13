Class Test.PM.Integration.ExternalNameModuleAction Extends Test.PM.Integration.Base
{

Parameter Folder = "ext-name-mod-action";

Parameter DefaultName = "default-name-mod-action";

Parameter ExternalName = "ext-name-mod-action";

Method TestExternalNameModuleAction()
{
    set dir = ..GetModuleDir(..#Folder)
    set sc = ##class(%IPM.Main).Shell("load "_dir)
    do $$$AssertStatusOK(sc, "Successfully loaded module")

    set sc = ##class(%IPM.Main).Shell(..#DefaultName_" greeting")
    do $$$AssertStatusOK(sc, "Successfully executed action by default name")

    set sc = ##class(%IPM.Main).Shell(..#ExternalName_" greeting")
    do $$$AssertStatusOK(sc, "Successfully executed action by external name")

    set sc = ##class(%IPM.Main).Shell(..#DefaultName_" package")
    do $$$AssertStatusOK(sc, "Successfully package by default name")

    set sc = ##class(%IPM.Main).Shell(..#ExternalName_" package")
    do $$$AssertStatusOK(sc, "Successfully package by external name")

    set sc = ##class(%IPM.Main).Shell("package "_..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully package by default name")

    set sc = ##class(%IPM.Main).Shell("package "_..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully package by external name")
}

}
