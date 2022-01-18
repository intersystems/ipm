Class %ZPM.PackageManager.Core.InstallationInfo Extends %RegisteredObject
{

Property Namespace As %String [ Required ];

Property IsUpgrade As %Boolean [ InitialExpression = 0, Required ];

Property ModuleReference As %ZPM.Storage.QualifiedModuleInfo [ Required ];

Property Parameters As array Of %String;

}
