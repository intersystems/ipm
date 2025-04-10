Class Test.PM.Integration.OrasTag Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "oras-tag";

Method TestOrasTagConversion()
{
    Set tModuleDir = ..GetModuleDir(..#TargetModuleName)

    Set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded module successfully")

    Set tSC = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(tSC,"Deleted repos successfully")

    Set tSC = ##class(%IPM.Main).Shell("repo -o -name oras -url http://oras:5000 -publish 1")
    Do $$$AssertStatusOK(tSC,"Set up oras module successfully")

    Set tSC = ##class(%IPM.Main).Shell("publish oras-tag -r oras -verbose")
    Do $$$AssertStatusOK(tSC,"Published module successfully")

    Set tSC = ##class(%IPM.Main).Shell("uninstall oras-tag")
    Do $$$AssertStatusOK(tSC,"Uninstalled module successfully")

    Set tSC = ##class(%IPM.Main).Shell("install oras-tag")
    If '$$$AssertStatusOK(tSC,"Installed module from ORAS registry successfully") {
        Zwrite %objlasterror
        Zwrite tSC
    }

    Set tSC = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(tSC,"Deleted repos successfully")

    Set tSC = ##class(%IPM.Main).Shell("repo -reset-defaults")
    Do $$$AssertStatusOK(tSC,"Reset repos to default successfully")
}

}
