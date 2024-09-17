Include %IPM.Common

Class %IPM.Repo.Remote.PackageService Extends (%RegisteredObject, %IPM.Repo.IPackageService)
{

Property Location As %String;

Property Username As %String;

Property Password As %String;

Property Token As %String;

Method GetInfo() As %IPM.Repo.Remote.Info
{
 	Set tRequest = ..GetHttpRequest()
  Set tRequest.Timeout = 2 // Short timeout in case it's unavailable
 	Set tSC = tRequest.Get()
  Set info = ##class(%IPM.Repo.Remote.Info).%New()

  If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
    $$$ThrowOnError(info.%JSONImport(tRequest.HttpResponse.Data))
  } Else {
    Set info.available = 0
  }
  
  Return info
}

Method GetLatestModuleVersion(pModuleName As %String) As %String
{
	Set jsonStream = ..GetModuleData(pModuleName)
	Set versions = {}.%FromJSON(jsonStream)
	Set latestVersion = versions.versions.%Pop()
	Return latestVersion
}

Method ListModules(pSearchCriteria As %IPM.Repo.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%IPM.Storage.ModuleInfo")
{
  Set tList = ##class(%Library.ListOfObjects).%New()
  Set tRequest = ..GetHttpRequest()

  Set name = $$$lcase(pSearchCriteria.Name)
  Set tVersionExpression = pSearchCriteria.VersionExpression
  Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pSearchCriteria.VersionExpression, .tVersionExpression)
  $$$ThrowOnError(tSC)

  Set tURL = tRequest.Location_"packages/-/all"
  If (name '= "") {
    Set tURL = tRequest.Location_"packages/" _ name
  }
  Do tRequest.SetParam("allVersions", pSearchCriteria.AllVersions)
  Do tRequest.SetParam("includePrerelease", pSearchCriteria.IncludePrerelease)
  Do tRequest.SetParam("includeSnapshots", pSearchCriteria.IncludeSnapshots)

  Set tSC = tRequest.Get($$$URLENCODE(tURL))

  If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
    Set tRes = {}.%FromJSON(tRequest.HttpResponse.Data)
    If ('tRes.%IsA("%Library.DynamicArray")) {
      Set tRes = [].%Push(tRes)
    }
    
    Set tIter = tRes.%GetIterator()

    While tIter.%GetNext(.key, .item) {
      Set allVersionsString = ""
      If (item.allVersions) {
        Set tIterVer = item.allVersions.%GetIterator()
        While tIterVer.%GetNext(.key, .version) {
          Set allVersionsString = allVersionsString_$ListBuild(version)
        }
      }
      Set tIterVer = item.versions.%GetIterator()
      WHILE tIterVer.%GetNext(.verkey, .version) {
        Set tVersion = ##class(%IPM.General.SemanticVersion).FromString(version)
        CONTINUE:'tVersion.Satisfies(tVersionExpression)
        Set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
        Set tModRef.Name = item.name
        Set tModRef.Repository = item.repository
        Set tModRef.VersionString = version
        Set tModRef.Description = item.description
        Set tModRef.Deployed = item.deployed
        if $IsObject(item."platform_versions") {
          Set tIterPVer = item."platform_versions".%GetIterator() 
          While tIterPVer.%GetNext(.tPVerKey, .platformVersion) {
            Do tModRef.PlatformVersions.Insert(platformVersion)
          }
        }
        Set tModRef.AllVersions = $ListToString(allVersionsString, ", ")
        Set tModRef.Origin = item.origin
        Do tList.Insert(tModRef)
      }      
    }
  }
  
  Return tList
}

Method GetModule(pModuleReference As %IPM.Storage.ModuleInfo, Output AsArchive As %Boolean = 1) As %Stream.Object
{
  Set tRequest = ..GetHttpRequest()
  Set tFileBinStream = ""
  Set AsArchive = 1

  Set name = pModuleReference.Name
  Set version = pModuleReference.VersionString
  Set deployed = pModuleReference.Deployed

  If deployed {
    Set platformVersion = $System.Version.GetMajor() _ "." _$System.Version.GetMinor()
  }

  Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location _ "packages/" _ name _ "/" _ version _ $Select(deployed: "/" _ platformVersion, 1: "")))
  Set tPackageUrl = ""
  If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
    Set tRes = {}.%FromJSON(tRequest.HttpResponse.Data)
    
    Set tPackageUrl = tRes.url
    Set tHash = tRes.hash

    #; registry returns full url http://146.190.30.249:52773/download/sslclient/-/sslclient-1.0.4.tgz
    #; 1) host&port can be wrong in this url (available only for local requests)
    #; 2) path doesn't include "appname" that we have in tRequest.Location
    Do ##class(%Net.URLParser).Parse(tPackageUrl,.tComponents)
    If ($Data(tComponents("path"))#2) {
      If ($Extract(tComponents("path"),1,1)="/") {
         Set path = $Extract(tComponents("path"),2,*)	
      }
    }

    Set tRequest = ..GetHttpRequest()
    Set tRequest.Timeout = 300
    Set tSC = tRequest.Get(tPackageUrl)
    
    If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
      Set tFileBinStream = ##class(%Stream.FileBinary).%New()
      Set tFileBinStream.Filename = ##class(%File).TempFilename("tgz")
      Do tFileBinStream.CopyFromAndSave(tRequest.HttpResponse.Data)
      If (tHash'="") {
        Set tTestHash = $$$lcase(##class(%File).SHA1Hash(tFileBinStream.Filename, 1)) 
        If tTestHash'=tHash {
          $$$ThrowStatus($$$ERROR($$$GeneralError, "Download module, hash mismatch. " _ tTestHash))
        }
      }
      Set token = tRequest.HttpResponse.GetHeader("INSTALLTOKEN")
      If (token'="") {
        Set ^IRIS.TempZPMRInst(name,version) = token
      }
    } Else {
      If $$$ISERR(tSC) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "tRequest Get Error"))
      }
      If (tRequest.HttpResponse.StatusCode'=200) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "tRequest statuscode not 200"))
      }
    }
  }
  If tFileBinStream="" {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Download module '" _ name _ "@" _ version _ "', something went wrong (StatusCode: " _ tRequest.HttpResponse.StatusCode _ ")." ))
  }
  Quit tFileBinStream
}

Method GetModuleManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
  Set tRequest = ..GetHttpRequest()

  Set name = pModuleReference.Name
  Set version = pModuleReference.VersionString

  Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ name _ "/"_version_"/manifest"))
  If ($$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode=200)) {
    Return tRequest.HttpResponse.Data
  }

  $$$ThrowStatus($$$ERROR($$$GeneralError,"Download package manifest "_name_"-"_version_" failed, something went wrong."))
}

Method GetModuleInstallerManifest(pModuleReference As %IPM.Storage.ModuleInfo) As %Stream.Object
{
  Set tRequest = ..GetHttpRequest()

  Set name = pModuleReference.Name
  Set version = pModuleReference.VersionString

  Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ name _ "/"_version_"/installer"))
  If ($$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode=200)) {
    Return tRequest.HttpResponse.Data
  }

  $$$ThrowStatus($$$ERROR($$$GeneralError,"Download package installer manifest "_name_"-"_version_" failed, something went wrong."))
}

Method GetModuleData(pName As %String) As %Stream.Object
{
  Set tRequest = ..GetHttpRequest()

  Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ pName))
  If ($$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode=200)) {
    Return tRequest.HttpResponse.Data
  }

  $$$ThrowStatus($$$ERROR($$$GeneralError,"Getting package "_pName_"'s data failed, something went wrong."))
}

Method SendAnalyticsToRegistry(action As %String, data As %DynamicObject)
{
    Set tRequest = ..GetHttpRequest()
    Set tRequest.ContentType = "application/json"
    Do tRequest.SetHeader("INSTALLTOKEN", $Get(^IRIS.TempZPMRInst(data.name,data.version))) 
    Kill ^IRIS.TempZPMRInst(data.name,data.version)
    Do data.%ToJSON(tRequest.EntityBody) 
    Set tSC = tRequest.Post($$$URLENCODE(tRequest.Location_"collect/" _ action))
    If ($$$ISERR(tSC) || (tRequest.HttpResponse.StatusCode'=200)) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Error Sending Analytics Data"))
    }
}

Method SendAnalyticsToGoogle(action As %String, data As %DynamicObject)
{
    Set TrackingID = ##class(%IPM.Repo.UniversalSettings).GetAnalyticsTrackingId()
    Quit:(TrackingID = "") 0
    Set tRequest = ##class(%Net.HttpRequest).%New()
    Set tRequest.FollowRedirect = 1
    Set tRequest.Server = "www.google-analytics.com"
    Set tRequest.SSLConfiguration = ..GetSSLConfiguration(tRequest.Server)

    Set status = $case($$$ISOK(data.success), 1: "Success", : "Failure")
    Set version = data.version
    Set irisPlatform = $system.Version.GetPlatform()
    Set irisVersion = $system.Version.GetNumber()
    Set irisProduct = $system.Version.GetProduct()

    Do tRequest.SetParam("v","1")
    Do tRequest.SetParam("tid",TrackingID)
    Do tRequest.SetParam("cid",##class(%SYS.System).InstanceGUID())
    Do tRequest.SetParam("ds","web")
    Do tRequest.SetParam("t","event")
    Do tRequest.SetParam("ec",data.name)
    Do tRequest.SetParam("ea",status)
    Do tRequest.SetParam("el",version_", "_irisProduct_", "_irisPlatform_", "_irisVersion)
    Return tRequest.Post("/collect")
}

Method CollectAnalytics(action As %String, name As %String, version As %String, success As %Boolean = 1, msg As %String = "") As %Status
{
    If ('##class(%IPM.Repo.UniversalSettings).GetAnalyticsAvailable()) {
        Return $$$OK
    }
    Set jo = {}
    Set jo.name = name
    Set jo.version = version
    Set jo.guid = ##class(%SYS.System).InstanceGUID()
    Set jo."system_version" = $ZVersion
    Set zpmVersion = ##class(%IPM.Repo.Utils).GetZPMVersion()
    If (zpmVersion'="") {
        Set jo."zpmclient_version" = zpmVersion
    } 
    Do jo.%Set("success",success,"boolean")
    Set jo."error_msg" = msg
    Try {
        Do ..SendAnalyticsToRegistry(action, jo)
        Do ..SendAnalyticsToGoogle(action, jo)
    } Catch ex {
        Return ex.AsStatus()
    }
    Return $$$OK
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
  Set tAvailable = 0
  Set tRequest = ..GetHttpRequest()
  
  Set tRequest.Timeout = 30
  Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"_ping"))
  If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode = 401 {
     $$$ThrowStatus($$$ERROR($$$GeneralError, "Registry "_..Location_": authorization required."))
  }
  If $$$ISOK(tSC) && (tRequest.HttpResponse.StatusCode = 200) {
    Set tAvailable = 1
  }
  Return tAvailable
}

Method GetHttpRequest(tLocation = {..Location}) As %Net.HttpRequest
{
  Set tRequest = ##class(%Net.HttpRequest).%New()

  Set tRequest.FollowRedirect = 1

  Set tLocation = $$$URLDECODE(tLocation)
  If ($piece(tLocation, "://")'["http") {
    Set tLocation = "http://" _ tLocation
  }
  
  Do ##class(%Net.URLParser).Parse(tLocation,.tComponents)
  
	If ($$$lcase(tComponents("scheme")) [ "http") {
		If ($Data(tComponents("host"))#2) {
			Set tRequest.Server = tComponents("host")
		}
		If ($Data(tComponents("port"))#2) {
			Set tRequest.Port = tComponents("port")
		}
		If ($$$lcase(tComponents("scheme")) = "https") {
			Set tRequest.Https = 1
    }
    If ($Get(tComponents("path"))'="") {
			Set path = tComponents("path")
			If ($Extract(path,1,1)="/") {
				Set path = $Extract(path,2,*)	
			}
			Set tRequest.Location = path
		}
    If $Extract(tRequest.Location, *) '= "/" {
      Set tRequest.Location = tRequest.Location _ "/"
    }
    #; in case of redirection
    Set tRequest.SSLConfiguration = ..GetSSLConfiguration(tRequest.Server)

    If (..Token '= "") {
      // key auth
      Do tRequest.SetHeader("apikey",..Token)
    }
    // basic auth
		If (..Username '= "") && (..Password '= "") {
        // basic auth
        Set tRequest.Username = ..Username
        Set tRequest.Password = ..Password
		}
    Set proxy=$System.Util.GetEnviron("https_proxy")
    If proxy'="" {
      Do ##class(%Net.URLParser).Parse(proxy,.pr)
      If (tRequest.Https) {
        Set tRequest.ProxyHTTPS=1
        Set tRequest.ProxyTunnel=1
      }
      Set tRequest.ProxyPort=pr("port")
      Set tRequest.ProxyServer=pr("host")
      If $Get(pr("username"))'="",$Get(pr("password"))'="" {
        Set tRequest.ProxyAuthorization="Basic "_$system.Encryption.Base64Encode(pr("username")_":"_pr("password"))
      }
    }
  }
  Return tRequest
}

ClassMethod GetSSLConfiguration(host) As %String
{
  NEW $NAMESPACE
  SET $NAMESPACE = "%SYS"
  
  IF '##class(Security.SSLConfigs).Exists(host) {
    DO ##class(Security.SSLConfigs).Create(host)
  }
  QUIT host
}

/// Used for unittests, reset's external temporary registry from any packages.
Method ResetRegistry() As %Status
{
  Set debugKey = $system.Util.GetEnviron("TEST_REGISTRY_DEBUG")
  if (debugKey="") {
    Quit $$$OK
  }

  Set tRequest = ..GetHttpRequest()
  Do tRequest.SetHeader("REGISTRY_DEBUG", debugKey)
  
  Quit tRequest.Get(tRequest.Location_"_reset")
}

}
