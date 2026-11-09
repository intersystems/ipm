Include %occErrors

Class Test.PM.Unit.ResourceReference Extends %UnitTest.TestCase
{

Method TestDatabaseResources()
{
	do ..AssertResourceNameValid("My.Class.CLS")
	do ..AssertResourceNameValid("My.Package.PKG")
	do ..AssertResourceNameValid("Include.INC")
	#; Do ..AssertResourceNameInvalid("abc")
}

Method TestDirectoryResources()
{
	do ..AssertResourceNameValid("/ui")
	do ..AssertResourceNameValid("/ui/")
	do ..AssertResourceNameValid("/localize/MyErrorMessages.xml")
	#; Do ..AssertResourceNameInvalid("\badslash")
}

Method TestResolvedProcessorClass()
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = "my-app"

    set resource = ..NewResource(module, "Foo.PKG")
    do $$$AssertEquals(resource.ResolvedProcessorClass(), "%IPM.ResourceProcessor.Default.Package")
    do $$$AssertEquals($classname(resource.Processor), "%IPM.ResourceProcessor.Default.Package")

    set resource = ..NewResource(module, "Foo.GBL")
    do $$$AssertEquals(resource.ResolvedProcessorClass(), "%IPM.ResourceProcessor.Default.Global")

    set resource = ..NewResource(module, "lib/", "FileCopy")
    do $$$AssertEquals(resource.ResolvedProcessorClass(), "%IPM.ResourceProcessor.FileCopy")
    do $$$AssertEquals($classname(resource.Processor), "%IPM.ResourceProcessor.FileCopy")

    set resource = ..NewResource(module, "/web/")
    do $$$AssertEquals(resource.ResolvedProcessorClass(), "")
    do $$$AssertEquals(resource.Processor, $$$NULLOREF)

    set resource = ..NewResource(module, "x", "No.Such.Processor")
    do $$$AssertEquals(resource.ResolvedProcessorClass(), "No.Such.Processor")
    do $$$AssertEquals(resource.Processor, $$$NULLOREF)
}

ClassMethod NewResource(
	module As %IPM.Storage.Module,
	name As %String,
	processorClass As %String = "") As %IPM.Storage.ResourceReference
{
    set resource = ##class(%IPM.Storage.ResourceReference).%New()
    set resource.Name = name
    set resource.ProcessorClass = processorClass
    set resource.Module = module
    return resource
}

Method AssertResourceNameValid(pResourceName As %String)
{
	set tSC = ##class(%IPM.Storage.ResourceReference).NameIsValid(pResourceName)
	do $$$AssertStatusOK(tSC,"Resource name "_pResourceName_" is valid.")
}

Method AssertResourceNameInvalid(pResourceName As %String)
{
	set tSC = ##class(%IPM.Storage.ResourceReference).NameIsValid(pResourceName)
	do $$$AssertEquals($system.Status.GetErrorCodes(tSC),$$$DTPattern,"Resource name "_pResourceName_" is invalid.")
}

}
