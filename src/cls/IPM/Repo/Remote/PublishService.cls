Class %IPM.Repo.Remote.PublishService Extends (%IPM.Repo.Remote.PackageService, %IPM.Repo.IPublishService)
{

Method PublishModule(pModule As %IPM.Repo.Remote.ModuleInfo) As %Boolean
{
  Quit ..Publish(pModule)
}

Method Publish(pModule As %IPM.Repo.Remote.ModuleInfo) As %Boolean
{
  If ((..Username="") || (..Password="")) && (..Token="") {
    $$$ThrowStatus($$$ERROR($$$GeneralError, "Publishing module, authorization required."))
  }
  
  Set tRequest = ..GetHttpRequest()
  Set tRequest.ContentType = "application/json"
  Set publishTimeout =  ##class(%IPM.Repo.UniversalSettings).GetValue("publish_timeout")
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
