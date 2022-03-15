<<<<<<< HEAD:src/%IPM/ExtensionBase/SourceControl/ResourceInfo.cls
Class %IPM.ExtensionBase.SourceControl.ResourceInfo Extends %RegisteredObject
=======
Class %IPM.PackageManager.Developer.Extension.SourceControl.ResourceInfo Extends %RegisteredObject
>>>>>>> 9978352e58b9926ce0ad0dd115f0edb16c99ed68:src/%IPM/PackageManager/Developer/Extension/SourceControl/ResourceInfo.cls
{

/// Set to 1 for resources that may be mapped to files/source control
Property SourceControlAware As %Boolean [ InitialExpression = 0 ];

/// The type of resource being considered (typically a document extension, or "/CSP/" for CSP resources).
Property ResourceType As %String;

/// The prefix (or possibly full name) of the resource.
/// e.g., MyModule.PackageName. for a package; MyModule.PackageName.ClassName for an individual class.
Property Prefix As %String;

/// Path to map the resource to, relative to the module root.
/// e.g., /cls/
Property RelativePath As %String;

/// Set to 1 if the relative path is a directory. (It almost always will be.)
Property IsDirectory As %Boolean [ InitialExpression = 1 ];

}
