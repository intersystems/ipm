/// Deployed code installs where its resource mappings point when a namespace mapping already covers it.
Class Test.PM.Integration.DeployedMappings Extends Test.PM.Integration.Base
{

Parameter ModuleName = "deployed-mappings";

Parameter ScratchDB = "DEPLOYMAP";

Property ArchivePath As %String;

Method OnBeforeAllTests() As %Status
{
    // Packaged once, before any conflicting mapping exists, so IPM creates no explicit mappings.
    // Sharing the archive is safe because neither test modifies it.
    set folder = ..GetModuleDir("deployed-mappings")
    set outDir = ##class(%File).ManagerDirectory() _ "deployed-mappings-" _ $job
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ folder _ " -dev"))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("package " _ ..#ModuleName _ " -only -path " _ outDir))
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName))
    set ..ArchivePath = outDir _ ".tgz"
    quit $$$OK
}

Method OnBeforeOneTest(testName As %String) As %Status
{
    do $$$AssertStatusOK(##class(%IPM.Test.Utils).CreateNamespace(..#ScratchDB))
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).AddRoutineMapping($namespace, "DeployMapR*", , ..#ScratchDB))
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).AddPackageMapping($namespace, "DeployMapP", ..#ScratchDB))
    quit $$$OK
}

Method OnAfterOneTest(testName As %String) As %Status
{
    do ##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName)
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).RemoveRoutineMapping($namespace, "DeployMapR.Routine"))
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).RemoveRoutineMapping($namespace, "DeployMapR*"))
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).RemovePackageMapping($namespace, "DeployMapP.Inner"))
    do $$$AssertStatusOK(##class(%IPM.Utils.Module).RemovePackageMapping($namespace, "DeployMapP"))
    // Fresh database per test, so code orphaned here cannot satisfy the next test's reachability check
    do $$$AssertStatusOK(##class(%IPM.Test.Utils).DeleteNamespace(..#ScratchDB))
    quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    do ##class(%File).Delete(..ArchivePath)
    do ##class(%File).RemoveDirectoryTree($extract(..ArchivePath, 1, *-4))
    quit $$$OK
}

Method AssertReachable()
{
    try {
        do $$$AssertEquals(##class(DeployMapA.First).Hello(), "first")
    } catch e {
        do $$$AssertFailure(e.DisplayString())
    }
    try {
        do $$$AssertEquals(##class(DeployMapP.Inner.Thing).Hello(), "package")
    } catch e {
        do $$$AssertFailure(e.DisplayString())
    }
    try {
        do $$$AssertEquals($$Hello^DeployMapR.Routine(), "routine")
    } catch e {
        do $$$AssertFailure(e.DisplayString())
    }
}

Method TestDeployedCodeUsesResourceMappings()
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..ArchivePath))
    do ..AssertReachable()
    set defaultDir = ##class(%IPM.Utils.Module).GetRoutineDatabaseDir($namespace)
    do $$$AssertEquals($piece(##class(%SYS.Namespace).GetRoutineDest(, "DeployMapR.Routine"), "^", 2, *), defaultDir)
    do $$$AssertEquals($piece(##class(%SYS.Namespace).GetPackageDest(, "DeployMapP.Inner"), "^", 2, *), defaultDir)
    set inDefault = ($data(^|"^^"_defaultDir|rOBJ("DeployMapR.Routine")) > 0)
    do $$$AssertTrue(inDefault, "Routine object code is in the default routine database")
}

Method TestNoMappingFollowsExistingMappings()
{
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ ..ArchivePath _ " -DNoMapping=1"))
    do ..AssertReachable()
    set scratchDir = ##class(%IPM.Utils.Module).GetRoutineDatabaseDir(..#ScratchDB)
    do $$$AssertEquals($piece(##class(%SYS.Namespace).GetRoutineDest(, "DeployMapR.Routine"), "^", 2, *), scratchDir)
    do $$$AssertEquals($piece(##class(%SYS.Namespace).GetPackageDest(, "DeployMapP.Inner"), "^", 2, *), scratchDir)
}

}
