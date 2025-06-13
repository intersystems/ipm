Class Test.PM.Unit.SelectiveDeployResource Extends Test.PM.Integration.Base
{

Method OnBeforeAllTests() As %Status
{
    // Setup repo for selective deploy tests
    Set tSC = ##class(%IPM.Main).Shell("repo -n integration-tests -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/selective-deploy-resource-test/")
    Do $$$AssertStatusOK(tSC,"Created integration-tests repo successfully.")
    return tSC
}

Method OnAfterAllTests() As %Status
{
    // Remove repo and installed modules after test run
    Set tSC = ##class(%IPM.Main).Shell("uninstall selectively-undeploy")
    Do $$$AssertStatusOK(tSC,"Uninstalled selectively-undeploy successfully.")

    Set tSC = ##class(%IPM.Main).Shell("uninstall selectively-deploy")
    Do $$$AssertStatusOK(tSC,"Uninstalled selectively-deploy successfully.")

    Set tSC = ##class(%IPM.Main).Shell("repo -delete -name integration-tests")
    Do $$$AssertStatusOK(tSC,"Deleted integration-tests repo successfully.")

    return tSC
}

Method TestSelectivelyUndeploy()
{
    Set tSC = $$$OK
    Try {
        // Initial install of module
        Set tSC = ##class(%IPM.Main).Shell("install selectively-undeploy")
        Do $$$AssertStatusOK(tSC,"Installed selectively-undeploy successfully.")
        Set tSC = ##class(SelectivelyUndeploy.D1).Main()
        Do $$$AssertStatusOK(tSC, "Class SelectivelyUndeploy.D1 installed correctly")
        Set tSC = ##class(SelectivelyUndeploy.D2).Main()
        Do $$$AssertStatusOK(tSC, "Class SelectivelyUndeploy.D2 installed correctly")

        // Package module
        Set packageDir = $$$FileTempDir_"selectively-undeploy"
        Set sc = ##class(%IPM.Main).Shell("selectively-undeploy package -only -v -DPath="_packageDir)
        Do $$$AssertStatusOK(sc, "Successfully packaged module to "_packageDir)

        // Uninstall module
        Set tSC = ##class(%IPM.Main).Shell("uninstall selectively-undeploy")
        Do $$$AssertStatusOK(tSC,"Uninstalled selectively-undeploy successfully.")
        Set tSC=##class(%Dictionary.CompiledClass).%ExistsId("SelectivelyUndeploy.D1")
        Do $$$AssertNotTrue(tSC, "Class SelectivelyUndeploy.D1 DNE")
        Set tSC=##class(%Dictionary.CompiledClass).%ExistsId("SelectivelyUndeploy.D2")
        Do $$$AssertNotTrue(tSC, "Class SelectivelyUndeploy.D2 DNE")

        // Load module from package
        Set tSC = ##class(%IPM.Main).Shell("load -v "_packageDir_".tgz")
        Do $$$AssertStatusOK(tSC,"Installed selectively-undeploy successfully.")
        Set tSC = ##class(SelectivelyUndeploy.D1).Main()
        Do $$$AssertStatusOK(tSC, "Class SelectivelyUndeploy.D1 installed correctly")
        Set tSC = ##class(SelectivelyUndeploy.D2).Main()
        Do $$$AssertStatusOK(tSC, "Class SelectivelyUndeploy.D2 installed correctly")
        
        // Check deployed status after loading
        Set tSC = ##class(%Dictionary.CompiledClass).%OpenId("SelectivelyUndeploy.D1").Deployed
        Do $$$AssertTrue(tSC, "Class SelectivelyUndeploy.D1 is deployed")
        Set tSC = ##class(%Dictionary.CompiledClass).%OpenId("SelectivelyUndeploy.D2").Deployed
        Do $$$AssertNotTrue(tSC, "Class SelectivelyUndeploy.D2 is NOT deployed")
    } Catch e {
        Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestSelectivelyUndeploy.")
    }
}

Method TestSelectivelyDeploy()
{
    Set tSC = $$$OK
    Try {
        // Initial install of module
        Set tSC = ##class(%IPM.Main).Shell("install selectively-deploy")
        Do $$$AssertStatusOK(tSC,"Installed selectively-deploy successfully.")
        Set tSC = ##class(SelectivelyDeploy.D1).Main()
        Do $$$AssertStatusOK(tSC, "Class SelectivelyDeploy.D1 installed correctly")
        Set tSC = ##class(SelectivelyDeploy.D2).Main()
        Do $$$AssertStatusOK(tSC, "Class SelectivelyDeploy.D2 installed correctly")

        // Package module
        Set packageDir = $$$FileTempDir_"selectively-deploy"
        Set sc = ##class(%IPM.Main).Shell("selectively-deploy package -only -v -DPath="_packageDir)
        Do $$$AssertStatusOK(sc, "Successfully packaged module to "_packageDir)

        // Uninstall module
        Set tSC = ##class(%IPM.Main).Shell("uninstall selectively-deploy")
        Do $$$AssertStatusOK(tSC,"Uninstalled selectively-deploy successfully.")
        Set tSC=##class(%Dictionary.CompiledClass).%ExistsId("SelectivelyDeploy.D1")
        Do $$$AssertNotTrue(tSC, "Class SelectivelyDeploy.D1 DNE")
        Set tSC=##class(%Dictionary.CompiledClass).%ExistsId("SelectivelyDeploy.D2")
        Do $$$AssertNotTrue(tSC, "Class SelectivelyDeploy.D2 DNE")

        // Load module from package
        Set tSC = ##class(%IPM.Main).Shell("load -v "_packageDir_".tgz")
        Do $$$AssertStatusOK(tSC,"Installed selectively-deploy successfully.")
        Set tSC = ##class(SelectivelyDeploy.D1).Main()
        Do $$$AssertStatusOK(tSC, "Class SelectivelyDeploy.D1 installed correctly")
        Set tSC = ##class(SelectivelyDeploy.D2).Main()
        Do $$$AssertStatusOK(tSC, "Class SelectivelyDeploy.D2 installed correctly")

        // Check deployed status after loading
        Set tSC = ##class(%Dictionary.CompiledClass).%OpenId("SelectivelyDeploy.D1").Deployed
        Do $$$AssertNotTrue(tSC, "Class SelectivelyUndeploy.D1 is NOT deployed")
        Set tSC = ##class(%Dictionary.CompiledClass).%OpenId("SelectivelyDeploy.D2").Deployed
        Do $$$AssertTrue(tSC, "Class SelectivelyUndeploy.D2 is deployed")
    } Catch e {
        Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred in TestSelectivelyDeploy.")
    }
}

}
