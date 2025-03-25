Class Test.PM.Integration.OrasVersionAnnotations Extends Test.PM.Integration.Base
{

Parameter Folder = "oras-version-annotations";

Parameter Module = "oras-version-annotations";

Parameter OrignalVersion = "1.0.0-prerelease+build";

Parameter UpdatedVersion = "1.0.0";

Method TestOrasVersionAnnotations()
{
    Set folder = ..GetModuleDir(..#Folder)

    Set sc = ##class(%IPM.Main).Shell("load " _ folder)
    Do $$$AssertStatusOK(sc, "Successfully loaded module at "_folder)

    Do ..AssertVersion(..#OrignalVersion)

    Set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(sc,"Deleted repos successfully")

    Set sc = ##class(%IPM.Main).Shell("repo -o -name oras -url http://oras:5000 -publish 1")
    Do $$$AssertStatusOK(sc,"Set up oras module successfully")

    Set sc = ##class(%IPM.Main).Shell("publish "_..#Module_" -r oras -verbose")
    Do $$$AssertStatusOK(sc,"Published module successfully")

    Do ..AssertVersion(..#OrignalVersion)

    Set sc = ##class(%IPM.Main).Shell("modver "_..#Module_" "_..#UpdatedVersion_" -force")
    Do $$$AssertStatusOK(sc,"Updated module version to "_..#UpdatedVersion)

    Do ..AssertVersion(..#UpdatedVersion)

    Set sc = ##class(%IPM.Main).Shell("publish "_..#Module_" -r oras -verbose -only")
    Do $$$AssertStatusOK(sc,"Published module successfully")

    Do ..AssertVersion(..#UpdatedVersion)

    Set sc = ##class(%IPM.Main).Shell("uninstall "_..#Module)
    Do $$$AssertStatusOK(sc,"Uninstalled module successfully")

    Set sc = ##class(%IPM.Main).Shell("install "_..#Module)
    Do $$$AssertStatusOK(sc,"Installed module from ORAS registry successfully")

    Do ..AssertVersion(..#UpdatedVersion)

    Set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(sc,"Deleted repos successfully")

    Set sc = ##class(%IPM.Main).Shell("repo -reset-defaults")
    Do $$$AssertStatusOK(sc,"Reset repos to default successfully")
}

Method AssertVersion(ver As %String) As %Boolean
{
    Set query = "SELECT Name FROM %IPM_Storage.ModuleItem WHERE Name = ?"
    Set rs = ##class(%SQL.Statement).%ExecDirect(, query, ..#Module)
    If '$$$AssertTrue(rs.%Next(), "Module "_..#Module_" found in SQL") {
        Return 0
    }
    Set module = ##class(%IPM.Storage.Module).NameOpen(rs.%Get("Name"))
    If '$$$AssertNotEquals(module, "", "Module set") {
        Return 0
    }
    Return $$$AssertEquals(module.VersionString, ver) && $$$AssertEquals(module.Version.ToString(), ver)
}

}
