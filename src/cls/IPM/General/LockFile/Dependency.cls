Class %IPM.General.LockFile.Dependency Extends (%RegisteredObject, %JSON.Adaptor)
{

Property VersionString As %String(%JSONFIELDNAME = "version", MAXLEN = "");

Property Repository As %String(%JSONFIELDNAME = "repository", MAXLEN = "");

Property Dependencies As array Of %String(%JSONFIELDNAME = "dependencies");

}
