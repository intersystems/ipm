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
    If ((..Username="") || (..Password="")) && (..Token="") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Publishing module, authorization required."))
    }

    Set tRequest = ..GetHttpRequest()
    Set tRequest.ContentType = "application/json"
    Set publishTimeout =  ##class(%ZPM.PackageManager.Client.Settings).GetValue("publish_timeout")
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
    Return 1
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
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, something went wrong (HTTP response status code: "_tRequest.HttpResponse.StatusCode_")."))
    }
    Return $$$OK
}

}
