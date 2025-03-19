Class Test.PM.Integration.FileCopy Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
{
    // Setup repo for FileCopy tests
    Set tSC = ##class(%IPM.Main).Shell("repo -n integration-tests -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/")
    Do $$$AssertStatusOK(tSC,"Created integration-tests repo successfully.")
    return tSC
}

Method TestModuleNoDependency()
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(%IPM.Main).Shell("install -dev fc-no-dep")
        Do $$$AssertStatusOK(tSC,"Installed fc-no-dep module successfully.")
        Set tSC = ##class(%IPM.Main).Shell("fc-no-dep package -only -export-deps 1 -DPath=/usr/irissys/mgr/fc-no-dep/")
        Do $$$AssertStatusOK(tSC,"Packaged fc-no-dep module successfully.")
        Set tSC = ##class(%IPM.Main).Shell("uninstall fc-no-dep -r")
        Do $$$AssertStatusOK(tSC,"Uninstalled fc-no-dep module successfully.")
        Set tSC = ##class(%IPM.Main).Shell("load /usr/irissys/mgr/fc-no-dep.tgz -DNoLock=1 -DNoTransaction=1 -DNoMapping=1")
        Do $$$AssertStatusOK(tSC,"Loaded fc-no-dep module successfully.")

        set mgrDir = $SYSTEM.Util.ManagerDirectory()
        // Check that ${mgrDir}/../fc-no-dep-src/ has text.txt/text2.txt in it
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-no-dep-src/text.txt"), "text.txt in fc-no-dep-src/ exists")

    } Catch e {
        Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestModuleNoDependency.")
    }
}

Method TestModuleDependencyDifferentResourceNames()
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(%IPM.Main).Shell("install -dev fc-dep-diff-resource")
        Do $$$AssertStatusOK(tSC,"Installed fc-dep-diff-resource module and dependency successfully.")
        Set tSC = ##class(%IPM.Main).Shell("fc-dep-diff-resource package -only -export-deps 1 -DPath=/usr/irissys/mgr/fc-dep-diff-resource/")
        Do $$$AssertStatusOK(tSC,"Packaged fc-dep-diff-resource module and dependency successfully.")
        Set tSC = ##class(%IPM.Main).Shell("uninstall fc-dep-diff-resource -r")
        Do $$$AssertStatusOK(tSC,"Uninstalled fc-dep-diff-resource module and dependency successfully.")
        Set tSC = ##class(%IPM.Main).Shell("load /usr/irissys/mgr/fc-dep-diff-resource.tgz -DNoLock=1 -DNoTransaction=1 -DNoMapping=1")
        Do $$$AssertStatusOK(tSC,"Loaded fc-dep-diff-resource module and dependency successfully.")

        set mgrDir = $SYSTEM.Util.ManagerDirectory()
        // Check that ${mgrDir}/../fc-no-dep-src/ has text.txt/text2.txt in it
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-no-dep-src/text2.txt"), "text2.txt in fc-no-dep-src/ exists")
        // Check that ${mgrDir}/../fc-dep-diff-resource-src/ has text.txt/text2.txt/also-text2.txt
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-diff-resource-src/text.txt"), "text.txt in fc-dep-diff-resource-src/ exists")
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-diff-resource-src/also-text2.txt"), "also-text2.txt in fc-dep-diff-resource-src/ exists")
    } Catch e {
        Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestModuleDependencyDifferentResourcesNames.")
    }
}

Method TestDependencySameResourceName()
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(%IPM.Main).Shell("install -dev fc-dep-same-resource")
        Do $$$AssertStatusOK(tSC,"Installed fc-dep-same-resource module and dependencies successfully.")
        Set tSC = ##class(%IPM.Main).Shell("fc-dep-same-resource package -only -export-deps 1 -DPath=/usr/irissys/mgr/fc-dep-same-resource/")
        Do $$$AssertStatusOK(tSC,"Packaged fc-dep-same-resource module and dependencies successfully.")
        Set tSC = ##class(%IPM.Main).Shell("uninstall fc-dep-same-resource -r")
        Do $$$AssertStatusOK(tSC,"Uninstalled fc-dep-same-resource module and dependencies successfully.")
        Set tSC = ##class(%IPM.Main).Shell("load /usr/irissys/mgr/fc-dep-same-resource.tgz -DNoLock=1 -DNoTransaction=1 -DNoMapping=1")
        Do $$$AssertStatusOK(tSC,"Loaded fc-dep-same-resource module and dependencies successfully.")

        set mgrDir = $SYSTEM.Util.ManagerDirectory()
        // Check that ${mgrDir}/../fc-no-dep-src/ has text.txt/text2.txt in it
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-no-dep-src/text2.txt"), "text2.txt in fc-no-dep-src/ exists")
        // Check that ${mgrDir}/../fc-dep-diff-resource-src/ has text.txt/text2.txt/also-text2.txt
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-diff-resource-src/text2.txt"), "text2.txt in fc-dep-diff-resource-src/ exists")
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-diff-resource-src/also-text2.txt"), "also-text2.txt in fc-dep-diff-resource-src/ exists")
        // Check that ${mgrDir}/../fc-dep-same-resource-src/ has text.txt/text2.txt/abc.txt
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-same-resource-src/text.txt"), "text.txt in fc-dep-same-resource-src/ exists")
        Do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-same-resource-src/abc.txt"), "abc.txt in fc-dep-same-resource-src/ exists")
    } Catch e {
        Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestDependencySameResourceName.")
    }
}

Method TestMakeDeployed()
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(%IPM.Main).Shell("install -dev fc-dep-same-resource")
        Do $$$AssertStatusOK(tSC,"Installed fc-dep-same-resource module and dependencies successfully.")
        Set tSC = ##class(%IPM.Main).Shell("makedeployed fc-dep-same-resource -r")
        Do $$$AssertStatusOK(tSC,"makedeployed fc-dep-same-resource module and dependencies successfully.")
    } Catch e {
        Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestMakeDeployed.")
    }
}

}
