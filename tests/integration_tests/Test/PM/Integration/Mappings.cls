Class Test.PM.Integration.Mappings Extends %UnitTest.TestCase
{

Method TestWrapped()
{
    Do ..RunTestCase("_data/mapping-test-wrapped","MappingTestWrapped")
}

Method TestUnwrappedWrapped()
{
    Do ..RunTestCase("_data/mapping-test-unwrapped","MappingTestUnwrapped")
}

Method RunTestCase(
	subdirectory As %String,
	packageName As %String)
{
    Try {
        Set tTestRoot = $Get(^UnitTestRoot)
        Set tParams("Verbose") = 1
        Set tModuleDirectory = ##class(%File).NormalizeDirectory(subdirectory, tTestRoot)
        $$$ThrowOnError(##class(%IPM.Utils.Module).LoadModuleFromDirectory(tModuleDirectory,.tParams))
        Set module = ##class(%IPM.Storage.Module).NameOpen(packageName,,.sc)
        $$$ThrowOnError(sc)
        Do $$$AssertEquals(module.Mappings.Count(),1)
        
        Do ..AssertPackageMappingExists(packageName_".Foo")
    } Catch e {
        Do $$$AssertFailure("An exception occurred: "_$System.Status.GetErrorText(e.AsStatus()))
    }
}

Method AssertPackageMappingExists(mappingName As %String)
{
    Set namespace = $namespace
    New $namespace
    Set $namespace = "%SYS"
    Set mappingCreated = ##class(Config.MapPackages).Exists("USER-VERIFY","MappingTestUnwrapped.Foo")
    Set $namespace = namespace
    Do $$$AssertTrue(mappingCreated)
}

}
