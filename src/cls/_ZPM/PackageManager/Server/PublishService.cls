Class %ZPM.PackageManager.Server.PublishService Extends (%ZPM.PackageManager.Server.AbstractService, %ZPM.PackageManager.Core.IPublishService) [ ProcedureBlock ]
{

/// Name of the WebService.
Parameter SERVICENAME = "PackagePublishService";

/// SOAP Namespace for the WebService
Parameter NAMESPACE = "http://www.intersystems.com/PackageManager";

/// Namespaces of referenced classes will be used in the WSDL.
Parameter USECLASSNAMESPACES = 1;

Method PublishModule(pModule As %ZPM.PackageManager.Core.Module) As %Boolean [ WebMethod ]
{
	Set tModule = ##class(%ZPM.PackageManager.Server.Module).NameVersionOpen(pModule.Name,pModule.VersionString)
	If '$IsObject(tModule) {
		Set tModule = ##class(%ZPM.PackageManager.Server.Module).%New()
	}
	Set tModule.Name = pModule.Name
	Set tModule.VersionString = pModule.VersionString
	Do tModule.Manifest.CopyFrom(pModule.Manifest)
	Do tModule.Installer.CopyFrom(pModule.Installer)
	Do tModule.Payload.CopyFrom(pModule.Payload)
	$$$ThrowOnError(tModule.%Save())
	Quit 1
}

Method PublishApplication(pApplication As %ZPM.PackageManager.Core.Application) As %Boolean [ WebMethod ]
{
	Set tApplication = ##class(%ZPM.PackageManager.Server.Application).NameVersionOpen(pApplication.Name,pApplication.VersionString)
	If '$IsObject(tApplication) {
		Set tApplication = ##class(%ZPM.PackageManager.Server.Application).%New()
	}
	Set tApplication.Name = pApplication.Name
	Set tApplication.VersionString = pApplication.VersionString
	Do tApplication.Manifest.CopyFrom(pApplication.Manifest)
	Do tApplication.Payload.CopyFrom(pApplication.Payload)
	$$$ThrowOnError(tApplication.%Save())
	Quit 1
}

}
