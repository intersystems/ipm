Class Test.PM.Integration.OrasVersionWithBuild Extends Test.PM.Integration.Base
{

Parameter Folder = "oras-version-with-build";

Parameter Module = "oras-version-with-build";

Parameter BuildVersion = "1.0.0-prerelease+build";

Parameter CleanVersion = "1.0.0-prerelease";

Method TestInstallSpecificBuildVersion()
{
    // Load the module with build metadata
    Set folder = ..GetModuleDir(..#Folder)
    Set sc = ##class(%IPM.Main).Shell("load " _ folder)
    Do $$$AssertStatusOK(sc, "Loaded module with build metadata")

    // Set up ORAS registry
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"))
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -o -name oras -url http://oras:5000 -publish 1"))

    // Publish the build version
    Do ..AssertVersion(..#BuildVersion)
    Set sc = ##class(%IPM.Main).Shell("publish "_..#Module_" -r oras -verbose")
    Do $$$AssertStatusOK(sc, "Published build metadata version")

    // Modify the module version to clean version (same base, no build)
    Set sc = ##class(%IPM.Main).Shell("modver "_..#Module_" "_..#CleanVersion_" -force")
    Do $$$AssertStatusOK(sc, "Changed version to clean prerelease")

    // Publish the clean version
    Do ..AssertVersion(..#CleanVersion)
    Set sc = ##class(%IPM.Main).Shell("publish "_..#Module_" -r oras -verbose -only")
    Do $$$AssertStatusOK(sc, "Published clean prerelease version")

    // Uninstall all local copies
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall "_..#Module))

    // Install the version with build explicitly
    Set sc = ##class(%IPM.Main).Shell("install oras/"_..#Module_" "_..#BuildVersion)
    Do $$$AssertStatusOK(sc, "Installed build version explicitly")

    // Verify correct version was installed
    Do ..AssertVersion(..#BuildVersion)

    // Install without build specified
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall "_..#Module))
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("install oras/"_..#Module_" "_..#CleanVersion))

    // Verify correct version was installed
    Do ..AssertVersion(..#CleanVersion)

    // Publish 3 builds of the same base version: build1, build2, build3
    For i=1:1:3 {
        Set buildVer = "1.0.0-prerelease+build"_i
        // Update the version with build metadata
        Do $$$AssertStatusOK(##class(%IPM.Main).Shell("modver "_..#Module_" "_buildVer_" -force"))
        Do ..AssertVersion(buildVer)
        // Publish only this version to ORAS
        Do $$$AssertStatusOK(##class(%IPM.Main).Shell("publish "_..#Module_" -r oras -verbose -only"))
    }

    // Uninstall current version before test
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall "_..#Module))

    // Install a specific older build (build2)
    Set specificBuild = "1.0.0-prerelease+build2"
    Set sc = ##class(%IPM.Main).Shell("install oras/"_..#Module_" "_specificBuild)
    Do $$$AssertStatusOK(sc, "Installed older build version explicitly")
    Do ..AssertVersion(specificBuild)

    // Clean up
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete-all"))
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -reset-defaults"))
}

Method AssertVersion(ver As %String) As %Boolean
{
    Set query = "SELECT VersionString FROM %IPM_Storage.ModuleItem WHERE Name = ?"
    Set rs = ##class(%SQL.Statement).%ExecDirect(, query, ..#Module)
    If '$$$AssertTrue(rs.%Next(), "Module "_..#Module_" found in SQL") {
        Return 0
    }
    Return $$$AssertEquals(rs.%Get("VersionString"), ver)
}

}
