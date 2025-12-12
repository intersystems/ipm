/// Class which defines the schema to be used for a dependency object within a lock file
Class %IPM.General.LockFile.Dependency Extends (%RegisteredObject, %JSON.Adaptor)
{

/// Version string for this dependency module
Property VersionString As %IPM.DataType.VersionString(%JSONFIELDNAME = "version");

/// Name of the repository this module comes from
Property Repository As %IPM.DataType.RepoName(%JSONFIELDNAME = "repository");

/// Array of transient dependencies required by this dependency module.
/// key: module name
/// value: semantic version expression (required by this module)
/// 
/// Example: {
///             "moduleOne": "^1.0.0",
///             "moduleTwo": "^2.1.3"
///          }
Property Dependencies As array Of %IPM.DataType.VersionString(%JSONFIELDNAME = "dependencies");

}
