Class %IPM.Repo.Remote.PublishService Extends (%IPM.Repo.Remote.PackageService, %IPM.Repo.IPublishService)
{

Method PublishModule(pModule As %IPM.Repo.Remote.ModuleInfo) As %Status
{
    try {
        do ..Publish(pModule)
    } catch Ex {
        return Ex.AsStatus()
    }
    return $$$OK
}

Method Publish(pModule As %IPM.Repo.Remote.ModuleInfo)
{
    if ((..Username="") || (..Password="")) && (..Token="") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Publishing module, authorization required."))
    }

    set tRequest = ..GetHttpRequest()
    set tRequest.ContentType = "application/json"
    set publishTimeout =  ##class(%IPM.Repo.UniversalSettings).GetValue("publish_timeout")
    set:publishTimeout'="" tRequest.Timeout = publishTimeout

    $$$ThrowOnError(pModule.%JSONExportToStream(tRequest.EntityBody))
    $$$ThrowOnError(tRequest.Post(tRequest.Location_"packages"))

    if (tRequest.HttpResponse.StatusCode '= 200) {
        if tRequest.HttpResponse.StatusCode = 401 {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Publishing module, authorization required."))
        } else {
            set tMessage = "Publishing module, server responded with status code "_tRequest.HttpResponse.StatusCode_"."
            $$$ThrowStatus($$$ERROR($$$GeneralError, tMessage))
        }
    }
}

Method CheckUnpublishEnabled(
	packageName As %String,
	packageVersion As %String) As %Boolean
{
    if ((..Username="") || (..Password="")) && (..Token="") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, authorization required."))
    }
    set tRequest = ..GetHttpRequest()
    $$$ThrowOnError(tRequest.Send("OPTIONS",tRequest.Location_"packages/"_packageName_"/"_packageVersion))
    if (tRequest.HttpResponse.StatusCode = 200) {
        set allow = $$$ucase(tRequest.HttpResponse.GetHeader("allow"))
        if ( allow["DELETE" ) {
            return 1
        }
    }
    return 0
}

Method Unpublish(
	packageName As %String,
	packageVersion As %String) As %Status
{
    if ((..Username="") || (..Password="")) && (..Token="") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, authorization required."))
    }
    set tRequest = ..GetHttpRequest()
    $$$ThrowOnError(tRequest.Send("DELETE",tRequest.Location_"packages/"_packageName_"/"_packageVersion))
    if (tRequest.HttpResponse.StatusCode '= 200) {
        set errMsg = ""
        try {
            set errMsg = $piece({}.%FromJSON(tRequest.HttpResponse.Data).summary,":",2,*)
            if (errMsg'="") {set errMsg = ";"_errMsg}
        } catch { }
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, something went wrong (HTTP response status code: "_tRequest.HttpResponse.StatusCode_errMsg_")."))
    }
    return $$$OK
}

}
