Class %ZPM.Repo.Remote.PublishService Extends (%ZPM.Repo.Remote.PackageService, %ZPM.Repo.IPublishService)
{

Method PublishModule(pModule As %ZPM.Repo.Remote.ModuleInfo) As %Boolean
{
  Quit ..Publish(pModule)
}

Method PublishApplication(pApplication As %ZPM.PackageManager.Core.Application) As %Boolean
{
  Quit ..Publish(pApplication)
}

Method Publish(pModule As %ZPM.Repo.Remote.ModuleInfo) As %Boolean
{
  if (..Username="") || (..Password="") {
    $$$ThrowStatus($$$ERROR($$$GeneralError, "Publishing module, authorization required."))
  }
  
  Set tRequest = ..GetHttpRequest()
  Set tRequest.ContentType = "application/json"
  Set publishTimeout =  ##class(%ZPM.Repo.UniversalSettings).GetValue("publish_timeout")
  Set:publishTimeout'="" tRequest.Timeout = publishTimeout
  
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
