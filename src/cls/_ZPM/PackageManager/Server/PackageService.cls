Class %ZPM.PackageManager.Server.PackageService Extends (%ZPM.PackageManager.Server.AbstractService, %ZPM.Repo.IPackageService, %ZPM.PackageManager.Core.ModuleInfo.QueryUtils) [ ProcedureBlock ]
{

/// Name of the WebService.
Parameter SERVICENAME = "PackageManagerService";

/// SOAP Namespace for the WebService
Parameter NAMESPACE = "http://www.intersystems.com/PackageManager";

/// Namespaces of referenced classes will be used in the WSDL.
Parameter USECLASSNAMESPACES = 1;

Method ListApplications(pSearchCriteria As %ZPM.Repo.SearchCriteria) As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.Storage.ModuleInfo") [ WebMethod ]
{
	Set tList = ##class(%Library.ListOfObjects).%New()
	Set tQuery = "select m.Name,m.VersionString from %ZPM_PackageManager_Server.Application_OrderedMatches(?,?,?) m "_
		"join %ZPM_PackageManager_Server.Application sm on sm.Name = m.Name and sm.VersionString = m.VersionString"
	Quit ..moduleSqlToList(tQuery,.pSearchCriteria)
}

Method ListModules(pSearchCriteria As %ZPM.Repo.SearchCriteria) As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.Storage.ModuleInfo") [ WebMethod ]
{
	Set tList = ##class(%Library.ListOfObjects).%New()
	Set tQuery = "select m.Name,m.VersionString from %ZPM_PackageManager_Server.Module_OrderedMatches(?,?,?) m "_
		"join %ZPM_PackageManager_Server._Module sm on sm.Name = m.Name and sm.VersionString = m.VersionString"
	Quit ..moduleSqlToList(tQuery,.pSearchCriteria)
}

Method HasApplication(pModuleReference As %ZPM.Storage.ModuleInfo) As %Boolean [ WebMethod ]
{
	Set tName = pModuleReference.Name
	Set tVersion = pModuleReference.VersionString
	Quit ##class(%ZPM.PackageManager.Server.Application).NameVersionExists(tName,tVersion)
}

Method HasModule(pModuleReference As %ZPM.Storage.ModuleInfo) As %Boolean [ WebMethod ]
{
	Set tName = pModuleReference.Name
	Set tVersion = pModuleReference.VersionString
	Quit ##class(%ZPM.PackageManager.Server.Module).NameVersionExists(tName,tVersion)
}

Method GetApplicationManifest(pModuleReference As %ZPM.Storage.ModuleInfo) As %Stream.GlobalCharacter [ WebMethod ]
{
	Set tName = pModuleReference.Name
	Set tVersion = pModuleReference.VersionString
	Set tApplication = ##class(%ZPM.PackageManager.Server.Application).NameVersionOpen(tName,tVersion,,.tStatus)
	$$$ThrowOnError(tStatus)
	Quit tApplication.Manifest
}

Method GetModuleManifest(pModuleReference As %ZPM.Storage.ModuleInfo) As %Stream.GlobalCharacter [ WebMethod ]
{
	Set tName = pModuleReference.Name
	Set tVersion = pModuleReference.VersionString
	Set tPackage = ##class(%ZPM.PackageManager.Server.Module).NameVersionOpen(tName,tVersion,,.tStatus)
	$$$ThrowOnError(tStatus)
	Quit tPackage.Manifest
}

Method GetApplication(pModuleReference As %ZPM.Storage.ModuleInfo) As %Stream.GlobalBinary [ WebMethod ]
{
	Set tName = pModuleReference.Name
	Set tVersion = pModuleReference.VersionString
	Set tApplication = ##class(%ZPM.PackageManager.Server.Application).NameVersionOpen(tName,tVersion,,.tStatus)
	$$$ThrowOnError(tStatus)
	Quit tApplication.Payload
}

Method GetModule(pModuleReference As %ZPM.Storage.ModuleInfo) As %Stream.GlobalBinary [ WebMethod ]
{
	Set tName = pModuleReference.Name
	Set tVersion = pModuleReference.VersionString
	Set tPackage = ##class(%ZPM.PackageManager.Server.Module).NameVersionOpen(tName,tVersion,,.tStatus)
	$$$ThrowOnError(tStatus)
	Quit tPackage.Payload
}

/// Returns 1 if the service supports a particular method.
ClassMethod Supports(pMethod As %String) As %Boolean
{
	// Only supports retrieval of module artifacts as single-file archives.
	Quit '(pMethod [ "Directory")
}

}
