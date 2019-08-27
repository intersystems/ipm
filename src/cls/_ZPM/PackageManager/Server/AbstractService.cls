Include %ZPM.PackageManager.Common

Class %ZPM.PackageManager.Server.AbstractService Extends %RegisteredObject [ Abstract ]
{

/// Returns 1 if and only if the service is enabled for <var>pApplication</var>; if <var>pApplication</var> is unspecified,
/// returns 1 if and only if the service is enabled for any web application in the current namespace.
/// In the latter case, also returns an array of web applications for which the namespace is enabled.
ClassMethod IsEnabled(pApplication As %String = "", Output pAppArray) As %Boolean
{
	Kill pAppArray
	Set tEnabled = 0
	If (pApplication = "") {
		Merge pAppArray = $$$ZPMConfig("SOAPService", $classname())
		Set tEnabled = ''$Data(pAppArray)
	} Else {
		// Strip off trailing / if it's coming from %session.Application
		// to match the format of Security.Applications
		If ($Extract(pApplication,*) = "/") {
			Set pApplication = $Extract(pApplication,1,*-1)
		}
		Set tEnabled = $Get($$$ZPMConfig("SOAPService", $classname(), pApplication), 0)
	}
	Quit tEnabled
}

/// Enables the specified web application for a given SOAP service
ClassMethod Enable(pApplication As %String) As %Status
{
	Set $$$ZPMConfig("SOAPService", $classname(), pApplication) = 1
	Quit $$$OK
}

/// Enables the specified web application for a given SOAP service
ClassMethod Disable(pApplication As %String = "") As %Status
{
	If (pApplication = "") {
		Kill $$$ZPMConfig("SOAPService", $classname())
	} Else {
		Kill $$$ZPMConfig("SOAPService", $classname(), pApplication)
	}
	Quit $$$OK
}

}
