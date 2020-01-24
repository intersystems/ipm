Class %ZPM.PackageManager.Client.REST.PublishClient Extends (%ZPM.PackageManager.Client.REST.PackageManagerClient, %ZPM.PackageManager.Core.IPublishService)
{

Method PublishModule(pModule As %ZPM.PackageManager.Core.Module) As %Boolean
{
  Quit ..Publish(pModule)
}

Method PublishApplication(pApplication As %ZPM.PackageManager.Core.Application) As %Boolean
{
  Quit ..Publish(pApplication)
}

Method Publish(pModule As %ZPM.PackageManager.Core.VersionedBase) As %Boolean
{
  if (..Username="") || (..Password="") {
    $$$ThrowStatus($$$ERROR($$$GeneralError, "Publishing module, authorization required."))
  }
  
  Set tRequest = ..GetHttpRequest()
  Set tRequest.ContentType = "application/json"

  $$$ThrowOnError(pModule.%JSONExportToStream(tRequest.EntityBody))
  $$$ThrowOnError(tRequest.Post(tRequest.Location_"packages"))
  
  If (tRequest.HttpResponse.StatusCode '= 200) {
    If tRequest.HttpResponse.StatusCode = 401 {
      $$$ThrowStatus($$$ERROR($$$GeneralError, "Publishing module, authorization required."))
    } Else {
      $$$ThrowStatus($$$ERROR($$$GeneralError, "Publishing module, something went wrong."))
    }
  }
  Quit 1
}

}
