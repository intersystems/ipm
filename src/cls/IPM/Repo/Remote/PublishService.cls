Class %IPM.Repo.Remote.PublishService Extends (%IPM.Repo.Remote.PackageService, %IPM.Repo.IPublishService)
{

Method PublishModule(pModule As %IPM.Repo.Remote.ModuleInfo) As %Status
{
  Try {
    Do ..Publish(pModule)
  } Catch Ex {
    Return Ex.AsStatus()
  }
  Return $$$OK
}

Method Publish(pModule As %IPM.Repo.Remote.ModuleInfo)
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
      Set tMessage = "Publishing module, server responded with status code "_tRequest.HttpResponse.StatusCode_"."
      $$$ThrowStatus($$$ERROR($$$GeneralError, tMessage))
    }
  }
}

Method CheckUnpublishEnabled(packageName As %String, packageVersion As %String) As %Boolean
{
    If ((..Username="") || (..Password="")) && (..Token="") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, authorization required."))
    }
    Set tRequest = ..GetHttpRequest()
    $$$ThrowOnError(tRequest.Send("OPTIONS",tRequest.Location_"packages/"_packageName_"/"_packageVersion))
    If (tRequest.HttpResponse.StatusCode = 200) {
        Set allow = $$$ucase(tRequest.HttpResponse.GetHeader("allow"))
        If ( allow["DELETE" ) {
            Return 1
        }
    }
    Return 0
}

Method Unpublish(packageName As %String, packageVersion As %String) As %Status
{
    If ((..Username="") || (..Password="")) && (..Token="") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, authorization required."))
    }
    Set tRequest = ..GetHttpRequest()
    $$$ThrowOnError(tRequest.Send("DELETE",tRequest.Location_"packages/"_packageName_"/"_packageVersion))
    If (tRequest.HttpResponse.StatusCode '= 200) {
        set errMsg = ""
        try {
            set errMsg = $piece({}.%FromJSON(tRequest.HttpResponse.Data).summary,":",2,*)
            if (errMsg'="") {set errMsg = ";"_errMsg}
        } catch {}
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, something went wrong (HTTP response status code: "_tRequest.HttpResponse.StatusCode_errMsg_")."))
    }
    Return $$$OK
}

}
