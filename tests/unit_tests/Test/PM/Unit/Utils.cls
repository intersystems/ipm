/// Fixture builders shared by unit test classes. Extend this class to use them.
Class Test.PM.Unit.Utils Extends %UnitTest.TestCase
{

/// Returns an unsaved module with the given name and version.
ClassMethod NewModule(
	name As %String = "my-app",
	versionString As %String = "1.2.3") As %IPM.Storage.Module
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = name
    set module.VersionString = versionString
    return module
}

/// attributes alternates key and value, e.g. AddResource(module, "/api", "WebApplication", , "Url", "/api")
ClassMethod AddResource(
	module As %IPM.Storage.Module,
	name As %String,
	processorClass As %String = "",
	scope As %String = "",
	attributes... As %String) As %IPM.Storage.ResourceReference
{
    set resource = ##class(%IPM.Storage.ResourceReference).%New()
    set resource.Name = name
    set resource.ProcessorClass = processorClass
    set resource.Scope = scope
    for i = 1:2:$get(attributes) {
        do resource.Attributes.SetAt(attributes(i + 1), attributes(i))
    }
    set resource.Module = module
    return resource
}

ClassMethod AddDependency(
	module As %IPM.Storage.Module,
	name As %String,
	versionString As %String,
	scope As %String = "")
{
    set dependency = ##class(%IPM.Storage.ModuleReference).%New()
    set dependency.Name = name
    set dependency.VersionString = versionString
    set dependency.Scope = scope
    do module.Dependencies.Insert(dependency)
}

/// Saves a module record named name at version 1.0.0 that depends on each name in dependencyNames,
/// and on each name in testDependencyNames with Scope="test". The caller deletes the record.
Method SaveModule(
	name As %String,
	dependencyNames As %List = "",
	testDependencyNames As %List = "") As %IPM.Storage.Module
{
    set module = ..NewModule(name, "1.0.0")
    set ptr = 0
    while $listnext(dependencyNames, ptr, depName) {
        do ..AddDependency(module, depName, "1.0.0")
    }
    set ptr = 0
    while $listnext(testDependencyNames, ptr, depName) {
        do ..AddDependency(module, depName, "1.0.0", "test")
    }
    do $$$AssertStatusOK(module.%Save(), "Saved " _ name)
    return module
}

}
