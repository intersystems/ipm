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

    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir))
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

Method TestInterchangeableNames()
{
    // Set up repo
    set sc = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
    do $$$AssertStatusOK(sc,"Zot repo configured succesfully")
    // Make sure modules are not already published
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")

    // Load module
    set moduleDir = ..GetModuleDir(..#Folder)
    set sc = ##class(%IPM.Main).Shell($$$FormatText("load %1", moduleDir))
    do $$$AssertStatusOK(sc, "Loaded module")

    // Test 1: Publish with default name and install using external name

    // Publish module
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#DefaultName _ " -verbose -r zot")
    do $$$AssertStatusOK(sc,"Published module successfully with default name")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module with external name")

    // Install using external name
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully installed module with external name")

    // Cleanup by unpublishing
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished default name succesfully")
    // Verify cannot install now
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Correctly failed to install module with external name")


    // Test 2: Publish with external name using -use-ext flag and install using internal name
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#DefaultName _ " -verbose -r zot -use-ext")
    do $$$AssertStatusOK(sc,"Published module successfully with default name but -use-ext flag")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module with default name")

    // Install using internal name
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully installed module with default name")

    // Cleanup by unpublishing
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#ExternalName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    // Verify cannot install now
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Correctly failed to install module with external name")


    // Test 3: Publish with external name without -use-ext flag (will appear in repo under internal name) and install using internal name
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#ExternalName _ " -verbose -r zot")
    do $$$AssertStatusOK(sc,"Published module successfully with external name")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module with default name")

    // Install using internal name
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully installed module with default name")

    // Cleanup by unpublishing
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Correctly failed to install module with external name")


    // Test 4: Publish with external name without -use-ext flag and install using external name
    set sc = ##class(%IPM.Main).Shell("publish " _ ..#ExternalName _ " -verbose -r zot")
    do $$$AssertStatusOK(sc,"Published module successfully with external name")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName)
    do $$$AssertStatusOK(sc, "Successfully uninstalled module with default name")

    // Install using internal name
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusOK(sc, "Successfully installed module with external name")

    // Cleanup by unpublishing
    set sc = ##class(%IPM.Main).Shell("unpublish zot/" _ ..#DefaultName _ " all -force")
    do $$$AssertStatusOK(sc,"Unpublished external name succesfully")
    set sc = ##class(%IPM.Main).Shell("install " _ ..#DefaultName)
    do $$$AssertStatusNotOK(sc, "Correctly failed to install module with default name")
    set sc = ##class(%IPM.Main).Shell("install " _ ..#ExternalName)
    do $$$AssertStatusNotOK(sc, "Correctly failed to install module with external name")



    // Cleanup by uninstalling module and removing zot repo
    $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall " _ ..#DefaultName))
    $$$ThrowOnError(##class(%IPM.Main).Shell("repo -n zot -delete"))
}

}
