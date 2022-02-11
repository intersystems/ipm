/// Description
Class %IPM.PackageManager.Developer.Extension.CompositeMethodOverrides
{

ClassMethod SetExtensionClasses(pPrimaryClassName As %String, pSubExtensionClassNames As %List) As %Status
{
	Set tStatus = $$$OK
	Quit tStatus
}

ClassMethod GetPrimaryExtensionClass() As %String [ SqlProc ]
{
	Quit ""
}

ClassMethod GetSubExtensionClasses() As %List [ SqlProc ]
{
	Quit ""
}


}