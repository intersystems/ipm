Class Test.PM.Integration.FileCopy Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
{
    // Setup repo for FileCopy tests
    set tSC = ##class(%IPM.Main).Shell("repo -n integration-tests -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/")
    do $$$AssertStatusOK(tSC,"Created integration-tests repo successfully.")
    return tSC
}

Method TestModuleNoDependency()
{
    set tSC = $$$OK
    try {
        set tSC = ##class(%IPM.Main).Shell("install -dev fc-no-dep")
        do $$$AssertStatusOK(tSC,"Installed fc-no-dep module successfully.")
        set tSC = ##class(%IPM.Main).Shell("fc-no-dep package -only -export-deps 1 -DPath=/usr/irissys/mgr/fc-no-dep/")
        do $$$AssertStatusOK(tSC,"Packaged fc-no-dep module successfully.")
        set tSC = ##class(%IPM.Main).Shell("uninstall fc-no-dep -r")
        do $$$AssertStatusOK(tSC,"Uninstalled fc-no-dep module successfully.")
        set tSC = ##class(%IPM.Main).Shell("load /usr/irissys/mgr/fc-no-dep.tgz -DNoLock=1 -DNoTransaction=1 -DNoMapping=1")
        do $$$AssertStatusOK(tSC,"Loaded fc-no-dep module successfully.")

        set mgrDir = $system.Util.ManagerDirectory()
        // Check that ${mgrDir}/../fc-no-dep-src/ has text.txt/text2.txt in it
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-no-dep-src/text.txt"), "text.txt in fc-no-dep-src/ exists")

    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestModuleNoDependency.")
    }
}

Method TestModuleDependencyDifferentResourceNames()
{
    set tSC = $$$OK
    try {
        set tSC = ##class(%IPM.Main).Shell("install -dev fc-dep-diff-resource")
        do $$$AssertStatusOK(tSC,"Installed fc-dep-diff-resource module and dependency successfully.")
        set tSC = ##class(%IPM.Main).Shell("fc-dep-diff-resource package -only -export-deps 1 -DPath=/usr/irissys/mgr/fc-dep-diff-resource/")
        do $$$AssertStatusOK(tSC,"Packaged fc-dep-diff-resource module and dependency successfully.")
        set tSC = ##class(%IPM.Main).Shell("uninstall fc-dep-diff-resource -r")
        do $$$AssertStatusOK(tSC,"Uninstalled fc-dep-diff-resource module and dependency successfully.")
        set tSC = ##class(%IPM.Main).Shell("load /usr/irissys/mgr/fc-dep-diff-resource.tgz -DNoLock=1 -DNoTransaction=1 -DNoMapping=1")
        do $$$AssertStatusOK(tSC,"Loaded fc-dep-diff-resource module and dependency successfully.")

        set mgrDir = $system.Util.ManagerDirectory()
        // Check that ${mgrDir}/../fc-no-dep-src/ has text.txt/text2.txt in it
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-no-dep-src/text2.txt"), "text2.txt in fc-no-dep-src/ exists")
        // Check that ${mgrDir}/../fc-dep-diff-resource-src/ has text.txt/text2.txt/also-text2.txt
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-diff-resource-src/text.txt"), "text.txt in fc-dep-diff-resource-src/ exists")
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-diff-resource-src/also-text2.txt"), "also-text2.txt in fc-dep-diff-resource-src/ exists")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestModuleDependencyDifferentResourcesNames.")
    }
}

Method TestDependencySameResourceName()
{
    set tSC = $$$OK
    try {
        set tSC = ##class(%IPM.Main).Shell("install -dev fc-dep-same-resource")
        do $$$AssertStatusOK(tSC,"Installed fc-dep-same-resource module and dependencies successfully.")
        set tSC = ##class(%IPM.Main).Shell("fc-dep-same-resource package -only -export-deps 1 -DPath=/usr/irissys/mgr/fc-dep-same-resource/")
        do $$$AssertStatusOK(tSC,"Packaged fc-dep-same-resource module and dependencies successfully.")
        set tSC = ##class(%IPM.Main).Shell("uninstall fc-dep-same-resource -r")
        do $$$AssertStatusOK(tSC,"Uninstalled fc-dep-same-resource module and dependencies successfully.")
        set tSC = ##class(%IPM.Main).Shell("load /usr/irissys/mgr/fc-dep-same-resource.tgz -DNoLock=1 -DNoTransaction=1 -DNoMapping=1")
        do $$$AssertStatusOK(tSC,"Loaded fc-dep-same-resource module and dependencies successfully.")

        set mgrDir = $system.Util.ManagerDirectory()
        // Check that ${mgrDir}/../fc-no-dep-src/ has text.txt/text2.txt in it
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-no-dep-src/text2.txt"), "text2.txt in fc-no-dep-src/ exists")
        // Check that ${mgrDir}/../fc-dep-diff-resource-src/ has text.txt/text2.txt/also-text2.txt
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-diff-resource-src/text2.txt"), "text2.txt in fc-dep-diff-resource-src/ exists")
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-diff-resource-src/also-text2.txt"), "also-text2.txt in fc-dep-diff-resource-src/ exists")
        // Check that ${mgrDir}/../fc-dep-same-resource-src/ has text.txt/text2.txt/abc.txt
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-same-resource-src/text.txt"), "text.txt in fc-dep-same-resource-src/ exists")
        do $$$AssertTrue(##class(%File).Exists(mgrDir_"../fc-dep-same-resource-src/abc.txt"), "abc.txt in fc-dep-same-resource-src/ exists")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestDependencySameResourceName.")
    }
}

Method TestMakeDeployed()
{
    set tSC = $$$OK
    try {
        set tSC = ##class(%IPM.Main).Shell("install -dev fc-dep-same-resource")
        do $$$AssertStatusOK(tSC,"Installed fc-dep-same-resource module and dependencies successfully.")
        set tSC = ##class(%IPM.Main).Shell("makedeployed fc-dep-same-resource -r")
        do $$$AssertStatusOK(tSC,"makedeployed fc-dep-same-resource module and dependencies successfully.")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestMakeDeployed.")
    }
}

Method TestPackageNameExpression()
{
    set tSC = $$$OK
    try {
        set tModuleDir = ..GetModuleDir("packagename")
        set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
        do $$$AssertStatusOK(tSC,"Module successfully installed")

        // Verify the destination has correctly replaced $(packagename)
        set mgrDir = $system.Util.ManagerDirectory()
        do $$$AssertTrue(##class(%File).Exists(mgrDir _ "FileCopy/testmodule/cls/Test.cls"), "Test.cls in " _ mgrDir _ "FileCopy/testmodule/cls exists")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestPackageNameExpression.")
    }
}

Method TestFileCopyScope()
{
    set tSC = $$$OK
    try {
        // Only the non-scoped FileCopy should activate on load
        set tModuleDir = ..GetModuleDir("packagename")
        set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
        do $$$AssertStatusOK(tSC,"Module successfully installed")

        // Neither the Scope="test" Scope="verify" file should be copied
        set mgrDir = $system.Util.ManagerDirectory()
        do $$$AssertTrue(##class(%File).Exists(mgrDir _ "FileCopy/testmodule/cls/Test.cls"), "Test.cls in " _ mgrDir _ "FileCopy/testmodule/cls exists")
        do $$$AssertNotTrue(##class(%File).Exists(mgrDir _ "FileCopy/Scope/Test/test1.txt"), mgrDir _ "FileCopy/Scope/Test/test1.txt does not exist")
        do $$$AssertNotTrue(##class(%File).Exists(mgrDir _ "FileCopy/Scope/Verify/test2.txt"), mgrDir _ "FileCopy/Scope/Test/test2.txt does not exist")

        // call <module> test
        set tSC = ##class(%IPM.Main).Shell("testmodule test -v")
        do $$$AssertStatusOK(tSC,"Test phase succeeded")
        // The Scope="test" file should be copied
        do $$$AssertTrue(##class(%File).Exists(mgrDir _ "FileCopy/Scope/Test/test1.txt"), mgrDir _ "FileCopy/Scope/Test/test1.txt does exist")
        do $$$AssertNotTrue(##class(%File).Exists(mgrDir _ "FileCopy/Scope/Verify/test2.txt"), mgrDir _ "FileCopy/Scope/Test/test2.txt does not exist")

        // call <module> verify
        set tSC = ##class(%IPM.Main).Shell("testmodule verify -v")
        do $$$AssertStatusOK(tSC,"Verify phase succeeded")
        // The Scope="verify" file should be copied
        do $$$AssertTrue(##class(%File).Exists(mgrDir _ "FileCopy/Scope/Test/test1.txt"), mgrDir _ "FileCopy/Scope/Test/test1.txt does exist")
        do $$$AssertTrue(##class(%File).Exists(mgrDir _ "FileCopy/Scope/Verify/test2.txt"), mgrDir _ "FileCopy/Verify/Test/test2.txt does exist")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestFileCopyScope.")
    }
}

}
