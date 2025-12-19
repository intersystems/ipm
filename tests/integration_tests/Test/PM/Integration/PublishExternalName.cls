Class Test.PM.Integration.PublishExternalName Extends Test.PM.Integration.Base
{

Parameter DefaultName = "default-name";

Parameter ExternalName = "external-name";

Parameter Folder = "publish-external-name";

Method TestExternalName()
{
    set moduleDir = ..GetModuleDir(..#Folder)

    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc, "Deleted all repos")

    set sc = ##class(%IPM.Main).Shell("repo -o -name oras -url http://oras:5000 -publish 1")
    do $$$AssertStatusOK(sc, "Added ORAS repo")

    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir _ "/0.0.1"))
    do $$$AssertStatusOK(sc, "Loaded module")

    set sc = ##class(%IPM.Main).Shell($$$FormatText("publish %1 -use-ext", ..#DefaultName))
    do $$$AssertStatusOK(sc, "Published module with default name")

    set sc = ##class(%IPM.Main).Shell($$$FormatText("uninstall %1", ..#DefaultName))
    do $$$AssertStatusOK(sc, "Deleted module")

    set sc = ##class(%IPM.Main).Shell($$$FormatText("install %1", ..#ExternalName))
    do $$$AssertStatusOK(sc, "Installed module by external name")

    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc, "Deleted all repos")

    set sc = ##class(%IPM.Main).Shell("repo -reset-defaults")
    do $$$AssertStatusOK(sc, "Reset repos to default")
}

}
