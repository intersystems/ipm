Class Test.PM.Integration.PublishExternalName Extends Test.PM.Integration.Base
{

Parameter DefaultName = "default-name";

Parameter ExternalName = "external-name";

Parameter Folder = "publish-external-name";

Method TestExternalName()
{
    Set moduleDir = ..GetModuleDir(..#Folder)

    Set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(sc, "Deleted all repos")

    Set sc = ##class(%IPM.Main).Shell("repo -o -name oras -url http://oras:5000 -publish 1")
    Do $$$AssertStatusOK(sc, "Added ORAS repo")

    Set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir))
    Do $$$AssertStatusOK(sc, "Loaded module")

    Set sc = ##class(%IPM.Main).Shell($$$FormatText("publish %1 -use-ext", ..#DefaultName))
    Do $$$AssertStatusOK(sc, "Published module with default name")

    Set sc = ##class(%IPM.Main).Shell($$$FormatText("uninstall %1", ..#DefaultName))
    Do $$$AssertStatusOK(sc, "Deleted module")

    Set sc = ##class(%IPM.Main).Shell($$$FormatText("install %1", ..#ExternalName))
    Do $$$AssertStatusOK(sc, "Installed module by external name")

    Set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(sc, "Deleted all repos")

    Set sc = ##class(%IPM.Main).Shell("repo -reset-defaults")
    Do $$$AssertStatusOK(sc, "Reset repos to default")
}

}
