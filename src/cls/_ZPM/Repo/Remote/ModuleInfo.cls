Class %ZPM.Repo.Remote.ModuleInfo Extends (%RegisteredObject, %ZPM.PackageManager.Core.VersionedBase)
{

Parameter XMLTYPE = "CoreModule";

Property Payload As %Stream.GlobalBinary(%JSONFIELDNAME = "package");

}
