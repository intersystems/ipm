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
    If (..Username="") || (..Password="") {
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
    Return 1
}

Method UpdateUplink(pUplink As %DynamicObject) As %Status
{
    If (..Username="") || (..Password="") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Updating uplink, authorization required."))
    }
    Set tRequest = ..GetHttpRequest()
    Set tRequest.ContentType = "application/json"
    
    Do pUplink.%ToJSON(tRequest.EntityBody)
    $$$ThrowOnError(tRequest.Post(tRequest.Location_"uplinks"))
    If (tRequest.HttpResponse.StatusCode = 200) {
        Write "Uplink successfuly updated"
    } Else {
        If tRequest.HttpResponse.StatusCode = 401 {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Updating uplink, authorization required."))
        } Else {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Updating uplink, something went wrong."))
        }
    }
    Return $$$OK
}

Method Unpublish(pModuleName As %String, pModuleVersion As %String, pVerbose As %Integer = 0) As %Status
{
    If (..Username="") || (..Password="") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, authorization required."))
    }
    Set tRequest = ..GetHttpRequest()
    Set tRequest.ContentType = "application/json"
    Write:pVerbose !,"Unpublish module ", pModuleName,". (registry: ",..Location,")"
    $$$ThrowOnError(tRequest.Delete(tRequest.Location_"packages/"_pModuleName_"/"_pModuleVersion))
    If (tRequest.HttpResponse.StatusCode = 200) {
        Write:pVerbose !,"Module successfuly unpublished"
    } Else {
        If tRequest.HttpResponse.StatusCode = 401 {
            Write:pVerbose !,"Error - authorization required"
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, authorization required."))
        } Else {
            Write:pVerbose !,"Error unpublishing module"
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Unpublishing module, something went wrong."))
        }
    }

    Return $$$OK
}

}
