Class Test.PM.Unit.SelectiveDeployResource Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
{
    // Setup repo for selective deploy tests
    set tSC = ##class(%IPM.Main).Shell("repo -n integration-tests -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/selective-deploy-resource-test/")
    do $$$AssertStatusOK(tSC,"Created integration-tests repo successfully.")
    return tSC
}

Method OnAfterAllTests() As %Status
{
    // Remove repo and installed modules after test run
    set tSC = ##class(%IPM.Main).Shell("uninstall selectively-undeploy")
    do $$$AssertStatusOK(tSC,"Uninstalled selectively-undeploy successfully.")

    set tSC = ##class(%IPM.Main).Shell("uninstall selectively-deploy")
    do $$$AssertStatusOK(tSC,"Uninstalled selectively-deploy successfully.")

    set tSC = ##class(%IPM.Main).Shell("repo -delete -name integration-tests")
    do $$$AssertStatusOK(tSC,"Deleted integration-tests repo successfully.")

    return tSC
}

Method TestSelectivelyUndeploy()
{
    set tSC = $$$OK
    try {
        // Initial install of module
        set tSC = ##class(%IPM.Main).Shell("install selectively-undeploy")
        do $$$AssertStatusOK(tSC,"Installed selectively-undeploy successfully.")
        set tSC = ##class(SelectivelyUndeploy.D1).Main()
        do $$$AssertStatusOK(tSC, "Class SelectivelyUndeploy.D1 installed correctly")
        set tSC = ##class(SelectivelyUndeploy.D2).Main()
        do $$$AssertStatusOK(tSC, "Class SelectivelyUndeploy.D2 installed correctly")

        // Package module
        set packageDir = $$$FileTempDir_"selectively-undeploy"
        set sc = ##class(%IPM.Main).Shell("selectively-undeploy package -only -v -DPath="_packageDir)
        do $$$AssertStatusOK(sc, "Successfully packaged module to "_packageDir)

        // Uninstall module
        set tSC = ##class(%IPM.Main).Shell("uninstall selectively-undeploy")
        do $$$AssertStatusOK(tSC,"Uninstalled selectively-undeploy successfully.")
        set doesClassExist=##class(%Dictionary.CompiledClass).%ExistsId("SelectivelyUndeploy.D1")
        do $$$AssertNotTrue(doesClassExist, "Class SelectivelyUndeploy.D1 DNE")
        set doesClassExist=##class(%Dictionary.CompiledClass).%ExistsId("SelectivelyUndeploy.D2")
        do $$$AssertNotTrue(doesClassExist, "Class SelectivelyUndeploy.D2 DNE")

        // Load module from package
        set tSC = ##class(%IPM.Main).Shell("load -v "_packageDir_".tgz")
        do $$$AssertStatusOK(tSC,"Loaded selectively-undeploy successfully.")
        set tSC = ##class(SelectivelyUndeploy.D1).Main()
        do $$$AssertStatusOK(tSC, "Class SelectivelyUndeploy.D1 installed correctly")
        set tSC = ##class(SelectivelyUndeploy.D2).Main()
        do $$$AssertStatusOK(tSC, "Class SelectivelyUndeploy.D2 installed correctly")

        // Check deployed status after loading
        set isDeployed = ##class(%Dictionary.CompiledClass).%OpenId("SelectivelyUndeploy.D1",0).Deployed
        do $$$AssertTrue(isDeployed, "Class SelectivelyUndeploy.D1 is deployed")
        set isDeployed = ##class(%Dictionary.CompiledClass).%OpenId("SelectivelyUndeploy.D2",0).Deployed
        do $$$AssertNotTrue(isDeployed, "Class SelectivelyUndeploy.D2 is NOT deployed")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestSelectivelyUndeploy.")
    }
}

Method TestSelectivelyDeploy()
{
    set tSC = $$$OK
    try {
        // Initial install of module
        set tSC = ##class(%IPM.Main).Shell("install selectively-deploy")
        do $$$AssertStatusOK(tSC,"Installed selectively-deploy successfully.")
        set tSC = ##class(SelectivelyDeploy.D1).Main()
        do $$$AssertStatusOK(tSC, "Class SelectivelyDeploy.D1 installed correctly")
        set tSC = ##class(SelectivelyDeploy.D2).Main()
        do $$$AssertStatusOK(tSC, "Class SelectivelyDeploy.D2 installed correctly")

        // Package module
        set packageDir = $$$FileTempDir_"selectively-deploy"
        set sc = ##class(%IPM.Main).Shell("selectively-deploy package -only -v -DPath="_packageDir)
        do $$$AssertStatusOK(sc, "Successfully packaged module to "_packageDir)

        // Uninstall module
        set tSC = ##class(%IPM.Main).Shell("uninstall selectively-deploy")
        do $$$AssertStatusOK(tSC,"Uninstalled selectively-deploy successfully.")
        set doesClassExist=##class(%Dictionary.CompiledClass).%ExistsId("SelectivelyDeploy.D1")
        do $$$AssertNotTrue(doesClassExist, "Class SelectivelyDeploy.D1 DNE")
        set doesClassExist=##class(%Dictionary.CompiledClass).%ExistsId("SelectivelyDeploy.D2")
        do $$$AssertNotTrue(doesClassExist, "Class SelectivelyDeploy.D2 DNE")

        // Load module from package
        set tSC = ##class(%IPM.Main).Shell("load -v "_packageDir_".tgz")
        do $$$AssertStatusOK(tSC,"Loaded selectively-deploy successfully.")
        set tSC = ##class(SelectivelyDeploy.D1).Main()
        do $$$AssertStatusOK(tSC, "Class SelectivelyDeploy.D1 installed correctly")
        set tSC = ##class(SelectivelyDeploy.D2).Main()
        do $$$AssertStatusOK(tSC, "Class SelectivelyDeploy.D2 installed correctly")

        // Check deployed status after loading
        set isDeployed = ##class(%Dictionary.CompiledClass).%OpenId("SelectivelyDeploy.D1",0).Deployed
        do $$$AssertNotTrue(isDeployed, "Class SelectivelyUndeploy.D1 is NOT deployed")
        set isDeployed = ##class(%Dictionary.CompiledClass).%OpenId("SelectivelyDeploy.D2",0).Deployed
        do $$$AssertTrue(isDeployed, "Class SelectivelyUndeploy.D2 is deployed")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestSelectivelyDeploy.")
    }
}

}
