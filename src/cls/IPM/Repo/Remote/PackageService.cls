Include %IPM.Common

Class %IPM.Repo.Remote.PackageService Extends %IPM.Repo.Http.PackageService
{

Method GetInfo() As %IPM.Repo.Remote.Info
{
    set tRequest = ..GetHttpRequest()
    set tRequest.Timeout = 2 // Short timeout in case it's unavailable
    set tSC = tRequest.Get()
    set info = ##class(%IPM.Repo.Remote.Info).%New()

    if $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
        $$$ThrowOnError(info.%JSONImport(tRequest.HttpResponse.Data))
    } else {
        set info.available = 0
    }

    return info
}

Method GetLatestModuleVersion(pModuleName As %String) As %String
{
    set jsonStream = ..GetModuleData(pModuleName)
    set versions = {}.%FromJSON(jsonStream)
    set latestVersion = versions.versions.%Pop()
    return latestVersion
}

Method ListModules(pSearchCriteria As %IPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%IPM.Storage.ModuleInfo")
{
    set tList = ##class(%Library.ListOfObjects).%New()
    set tRequest = ..GetHttpRequest()

    set name = $$$lcase(pSearchCriteria.Name)
    set tVersionExpression = pSearchCriteria.VersionExpression
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pSearchCriteria.VersionExpression, .tVersionExpression)
    $$$ThrowOnError(tSC)

    set tURL = tRequest.Location_"packages/-/all"
    if (name '= "") {
        set tURL = tRequest.Location_"packages/" _ name
    }
    do tRequest.SetParam("allVersions", pSearchCriteria.AllVersions)
    do tRequest.SetParam("includePrerelease", pSearchCriteria.IncludePrerelease)
    do tRequest.SetParam("includeSnapshots", pSearchCriteria.IncludeSnapshots)

    set tSC = tRequest.Get($$$URLENCODE(tURL))

    if $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
        set tRes = {}.%FromJSON(tRequest.HttpResponse.Data)
        if ('tRes.%IsA("%Library.DynamicArray")) {
            set tRes = [].%Push(tRes)
        }

        set tIter = tRes.%GetIterator()

        while tIter.%GetNext(.key, .item) {
            set allVersionsString = ""
            if (item.allVersions) {
                set tIterVer = item.allVersions.%GetIterator()
                while tIterVer.%GetNext(.key, .version) {
                    set allVersionsString = allVersionsString_$listbuild(version)
                }
            }
            set tIterVer = item.versions.%GetIterator()
            while tIterVer.%GetNext(.verkey, .version) {
                set tVersion = ##class(%IPM.General.SemanticVersion).FromString(version)
                continue:'tVersion.Satisfies(tVersionExpression)
                set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
                set tModRef.Name = item.name
                set tModRef.Repository = item.repository
                set tModRef.VersionString = version
                set tModRef.Description = item.description
                set tModRef.Deployed = item.deployed
                if $isobject(item."platform_versions") {
                    set tIterPVer = item."platform_versions".%GetIterator()
                    while tIterPVer.%GetNext(.tPVerKey, .platformVersion) {
                        do tModRef.PlatformVersions.Insert(platformVersion)
                    }
                }
                set tModRef.AllVersions = $listtostring(allVersionsString, ", ")
                set tModRef.Origin = item.origin
                do tList.Insert(tModRef)
            }
        }
    }

    return tList
}

Method GetModule(
	pModuleReference As %IPM.Storage.ModuleInfo,
	Output AsArchive As %Boolean = 1) As %Stream.Object
{
    set tRequest = ..GetHttpRequest()
    set tFileBinStream = ""
    set AsArchive = 1

    set name = pModuleReference.Name
    set version = pModuleReference.VersionString
    set deployed = pModuleReference.Deployed

    if deployed {
        set platformVersion = $system.Version.GetMajor() _ "." _$system.Version.GetMinor()
    }

    set tSC = tRequest.Get($$$URLENCODE(tRequest.Location _ "packages/" _ name _ "/" _ version _ $select(deployed: "/" _ platformVersion, 1: "")))
    set tPackageUrl = ""
    if $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
        set tRes = {}.%FromJSON(tRequest.HttpResponse.Data)

        set tPackageUrl = tRes.url
        set tHash = tRes.hash

        #; registry returns full url http://146.190.30.249:52773/download/sslclient/-/sslclient-1.0.4.tgz
        #; 1) host&port can be wrong in this url (available only for local requests)
        #; 2) path doesn't include "appname" that we have in tRequest.Location
        do ##class(%Net.URLParser).Parse(tPackageUrl,.tComponents)
        if ($data(tComponents("path"))#2) {
            if ($extract(tComponents("path"),1,1)="/") {
                set path = $extract(tComponents("path"),2,*)
            }
        }

        set tRequest = ..GetHttpRequest()
        set tRequest.Timeout = 300
        set tSC = tRequest.Get(tPackageUrl)

        if $$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode=200) {
            set tFileBinStream = ##class(%Stream.FileBinary).%New()
            set tFileBinStream.Filename = ##class(%File).TempFilename("tgz")
            do tFileBinStream.CopyFromAndSave(tRequest.HttpResponse.Data)
            if (tHash'="") {
                set tTestHash = $$$lcase(##class(%File).SHA1Hash(tFileBinStream.Filename, 1))
                if (tTestHash'=tHash) {
                    $$$ThrowStatus($$$ERROR($$$GeneralError, "Download module, hash mismatch. " _ tTestHash))
                }
            }
            set token = tRequest.HttpResponse.GetHeader("INSTALLTOKEN")
            if (token'="") {
                set ^IRIS.TempZPMRInst(name,version) = token
            }
        } else {
            if $$$ISERR(tSC) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "tRequest Get Error"))
            }
            if (tRequest.HttpResponse.StatusCode'=200) {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "tRequest statuscode not 200"))
            }
        }
    }
    if tFileBinStream="" {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Download module '" _ name _ "@" _ version _ "', something went wrong (StatusCode: " _ tRequest.HttpResponse.StatusCode _ ")." ))
    }
    quit tFileBinStream
}

Method GetModuleManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
    set tRequest = ..GetHttpRequest()

    set name = pModuleReference.Name
    set version = pModuleReference.VersionString

    set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ name _ "/"_version_"/manifest"))
    if ($$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode=200)) {
        return tRequest.HttpResponse.Data
    }

    $$$ThrowStatus($$$ERROR($$$GeneralError,"Download package manifest "_name_"-"_version_" failed, something went wrong."))
}

Method GetModuleInstallerManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
    set tRequest = ..GetHttpRequest()

    set name = pModuleReference.Name
    set version = pModuleReference.VersionString

    set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ name _ "/"_version_"/installer"))
    if ($$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode=200)) {
        return tRequest.HttpResponse.Data
    }

    $$$ThrowStatus($$$ERROR($$$GeneralError,"Download package installer manifest "_name_"-"_version_" failed, something went wrong."))
}

Method GetModuleData(pName As %String) As %Stream.Object
{
    set tRequest = ..GetHttpRequest()

    set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ pName))
    if ($$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode=200)) {
        return tRequest.HttpResponse.Data
    }

    $$$ThrowStatus($$$ERROR($$$GeneralError,"Getting package "_pName_"'s data failed, something went wrong."))
}

Method SendAnalyticsToRegistry(
	action As %String,
	data As %DynamicObject)
{
    set tRequest = ..GetHttpRequest()
    set tRequest.ContentType = "application/json"
    do tRequest.SetHeader("INSTALLTOKEN", $get(^IRIS.TempZPMRInst(data.name,data.version)))
    kill ^IRIS.TempZPMRInst(data.name,data.version)
    do data.%ToJSON(tRequest.EntityBody)
    set tSC = tRequest.Post($$$URLENCODE(tRequest.Location_"collect/" _ action))
    if ($$$ISERR(tSC) || (tRequest.HttpResponse.StatusCode'=200)) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Error Sending Analytics Data"))
    }
}

Method SendAnalyticsToGoogle(
	action As %String,
	data As %DynamicObject)
{
    set TrackingID = ##class(%IPM.Repo.UniversalSettings).GetAnalyticsTrackingId()
    quit:(TrackingID = "") 0
    set tRequest = ##class(%Net.HttpRequest).%New()
    set tRequest.FollowRedirect = 1
    set tRequest.Server = "www.google-analytics.com"
    set tRequest.SSLConfiguration = ..GetSSLConfiguration(tRequest.Server)

    set status = $case($$$ISOK(data.success), 1: "Success", : "Failure")
    set version = data.version
    set irisPlatform = $system.Version.GetPlatform()
    set irisVersion = $system.Version.GetNumber()
    set irisProduct = $system.Version.GetProduct()

    do tRequest.SetParam("v","1")
    do tRequest.SetParam("tid",TrackingID)
    do tRequest.SetParam("cid",##class(%SYS.System).InstanceGUID())
    do tRequest.SetParam("ds","web")
    do tRequest.SetParam("t","event")
    do tRequest.SetParam("ec",data.name)
    do tRequest.SetParam("ea",status)
    do tRequest.SetParam("el",version_", "_irisProduct_", "_irisPlatform_", "_irisVersion)
    return tRequest.Post("/collect")
}

Method CollectAnalytics(
	action As %String,
	name As %String,
	version As %String,
	success As %Boolean = 1,
	msg As %String = "") As %Status
{
    if ('##class(%IPM.Repo.UniversalSettings).GetAnalyticsAvailable()) {
        return $$$OK
    }
    set jo = {}
    set jo.name = name
    set jo.version = version
    set jo.guid = ##class(%SYS.System).InstanceGUID()
    set jo."system_version" = $zversion
    set zpmVersion = ##class(%IPM.Repo.Utils).GetZPMVersion()
    if (zpmVersion'="") {
        set jo."zpmclient_version" = zpmVersion
    }
    do jo.%Set("success",success,"boolean")
    set jo."error_msg" = msg
    try {
        do ..SendAnalyticsToRegistry(action, jo)
        do ..SendAnalyticsToGoogle(action, jo)
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
    set tAvailable = 0
    set tRequest = ..GetHttpRequest()

    // The three second timeout here is somewhat arbitrary, but reasonable:
    // a well-behaving/stable registry will certainly respond within that time,
    // and an unhealthy registry shouldn't be given e.g. 30 seconds (the default)
    // which more likely indicates a setup issue on the client, like using the wrong URL.
    set tRequest.Timeout = 3
    set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"_ping"))
    if $$$ISOK(tSC), tRequest.HttpResponse.StatusCode = 401 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Registry "_..Location_": authorization required."))
    }
    if $$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode = 200) {
        set tAvailable = 1
    }
    return tAvailable
}

/// Used for unittests, reset's external temporary registry from any packages.
Method ResetRegistry() As %Status
{
    set debugKey = $system.Util.GetEnviron("TEST_REGISTRY_DEBUG")
    if (debugKey="") {
        quit $$$OK
    }

    set tRequest = ..GetHttpRequest()
    do tRequest.SetHeader("REGISTRY_DEBUG", debugKey)

    quit tRequest.Get(tRequest.Location_"_reset")
}

}
