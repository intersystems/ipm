/// Loading a package installs every Deploy="true" resource, whether it was packaged in Deployed.xml or as source.
Class Test.PM.Integration.DeployedPackageLoad Extends Test.PM.Integration.Base
{

Method OnAfterOneTest(testName As %String) As %Status
{
    for module = "deployed-sources-root", "deployed-include" {
        if ##class(%IPM.Storage.Module).NameExists(module) {
            do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ module))
        }
    }
    quit $$$OK
}

/// Packages the fixture in <var>folder</var>, uninstalls it and loads the package.
Method PackageAndReload(
	folder As %String,
	module As %String)
{
    set outDir = ##class(%File).ManagerDirectory() _ module _ "-" _ $job
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..GetModuleDir("deployed-package-load", folder) _ " -dev"))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("package " _ module _ " -only -path " _ outDir))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ module))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ outDir _ ".tgz"))
    do ##class(%File).Delete(outDir _ ".tgz")
    do ##class(%File).RemoveDirectoryTree(outDir)
}

/// Confirms the load went through Deployed.xml, so the test exercises the deployed path.
Method AssertDeployed(className As %String)
{
    set class = ##class(%Dictionary.CompiledClass).%OpenId(className)
    set deployed = $isobject(class) && class.Deployed
    do $$$AssertTrue(deployed, className _ " is deployed")
}

Method TestSourcesRootWithOnlyDeployedResources()
{
    do ..PackageAndReload("sources-root", "deployed-sources-root")
    do ..AssertDeployed("DeployedSourcesRoot.Main")
    try {
        do $$$AssertEquals(##class(DeployedSourcesRoot.Main).Hello(), "class")
    } catch e {
        do $$$AssertFailure(e.DisplayString())
    }
    try {
        do $$$AssertEquals($$Hello^DeployedSourcesRoot.Routine(), "routine")
    } catch e {
        do $$$AssertFailure(e.DisplayString())
    }
}

Method TestDeployedIncludeLoadsFromSource()
{
    do ..PackageAndReload("include", "deployed-include")
    do ..AssertDeployed("DeployedInclude.Main")
    do $$$AssertTrue(##class(%Routine).Exists("DeployedInclude.Macros.INC"), "Include file installed")
    try {
        do $$$AssertEquals(##class(DeployedInclude.Consumer).Answer(), "include")
    } catch e {
        do $$$AssertFailure(e.DisplayString())
    }
}

}
