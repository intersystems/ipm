Include %ZPM.PackageManager.Common

Class %ZPM.PackageManager.Server.AbstractService Extends %RegisteredObject [ Abstract ]
{

/// Returns 1 if and only if the service is enabled for <var>pApplication</var>; if <var>pApplication</var> is unspecified,
/// returns 1 if and only if the service is enabled for any web application in the current namespace.
/// In the latter case, also returns an array of web applications for which the namespace is enabled.
ClassMethod IsEnabled(pApplication As %String = "", Output pAppArray) As %Boolean
{
	Set tEnabled = 0
	Quit tEnabled
}

/// Enables the specified web application for a given SOAP service
ClassMethod Enable(pApplication As %String) As %Status
{
	Quit $$$OK
}

/// Enables the specified web application for a given SOAP service
ClassMethod Disable(pApplication As %String = "") As %Status
{
	Quit $$$OK
}

}
