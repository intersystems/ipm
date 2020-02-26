Class %ZPM.PackageManager.Client.REST.PackageManagerClient Extends (%RegisteredObject, %ZPM.PackageManager.Core.IPackageService)
{

Property Location As %String;

Property Username As %String;

Property Password As %String;

Method ListModules(pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria) As %ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Core.ResolvedModuleReference")
{
  Set tList = ##class(%Library.ListOfObjects).%New()
  Set tRequest = ..GetHttpRequest()

  Set name = $$$lcase(pSearchCriteria.Name)
  Set tVersionExpression = pSearchCriteria.VersionExpression
  Set tSC = ##class(%ZPM.PackageManager.Core.SemanticVersionExpression).FromString(pSearchCriteria.VersionExpression, .tVersionExpression)
  $$$ThrowOnError(tSC)

  If name = "" {
    Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/-/all"))
  }
  Else {
    Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ name))
  }
  If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
    Set tRes = {}.%FromJSON(tRequest.HttpResponse.Data)
    If ('tRes.%IsA("%Library.DynamicArray")) {
      Set tRes = [].%Push(tRes)
    }
    
    Set tIter = tRes.%GetIterator()

    While tIter.%GetNext(.key, .item) {
      Set tIterVer = item.versions.%GetIterator()
      WHILE tIterVer.%GetNext(.verkey, .version) {
        Set tVersion = ##class(%ZPM.PackageManager.Core.SemanticVersion).FromString(version)
        CONTINUE:'tVersion.Satisfies(tVersionExpression)
        Set tModRef = ##class(%ZPM.PackageManager.Core.ResolvedModuleReference).%New()
        Set tModRef.Name = item.name
        Set tModRef.VersionString = version
        Do tList.Insert(tModRef)
      }      
    }
  }
  
  Return tList
}

Method GetModule(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference, Output AsArchive As %Boolean = 1) As %Stream.Object
{
  Set tRequest = ..GetHttpRequest()
  Set tFileBinStream = ""
  Set AsArchive = 1

  Set name = pModuleReference.Name
  Set version = pModuleReference.VersionString

  Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ name _ "/" _ version))
  Set tPackageUrl = ""
  If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
    Set tRes = {}.%FromJSON(tRequest.HttpResponse.Data)
    
    Set tPackageUrl = tRes.url
    Set tHash = tRes.hash

    Do ##class(%Net.URLParser).Parse(tPackageUrl,.tComponents)
    If ($Data(tComponents("path"))#2) {
      If ($Extract(tComponents("path"),1,1)="/") {
          Set path = $Extract(tComponents("path"),2,*)	
      }
    }
    Set tRequest = ..GetHttpRequest()
    Set tSC = tRequest.Get(tRequest.Location_path)
    If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
      Set tFileBinStream = ##class(%Stream.FileBinary).%New()
      Set tFileBinStream.Filename = ##class(%File).TempFilename("tgz")
      do tFileBinStream.CopyFromAndSave(tRequest.HttpResponse.Data)      
      If (tHash'="") {
        set tTestHash = $$$lcase(##class(%File).SHA1Hash(tFileBinStream.Filename, 1)) 
        if tTestHash'=tHash {
          $$$ThrowStatus($$$ERROR($$$GeneralError, "Download module, hash mismatch."))
        }
      }
      Set token = tRequest.HttpResponse.GetHeader("INSTALLTOKEN")
      If (token'="") {
        Set ^IRIS.TempZPMRInst(name,version) = token
      }
    }
  }
  If tFileBinStream="" {
    $$$ThrowStatus($$$ERROR($$$GeneralError,"Download module, something went wrong."))
  }
  Quit tFileBinStream
}

Method GetModuleManifest(pModuleReference As %ZPM.PackageManager.Core.ResolvedModuleReference) As %Stream.Object
{
  Set tRequest = ..GetHttpRequest()
  Set tFileBinStream = ""

  Set name = pModuleReference.Name
  Set version = pModuleReference.VersionString

  Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"packages/" _ name _ "/"_version_"/manifest"))
  If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
    Return tRequest.HttpResponse.Data
  }

  $$$ThrowStatus($$$ERROR($$$GeneralError,"Download package manifest, something went wrong."))
}

Method CollectAnalytics(action, name As %String, version As %String, success As %Boolean = 1, msg As %String = "") As %Status
{

    w

    Set jo = {}
    Set jo.name = name
    Set jo.version = version
    Set jo.guid = ##class(%SYS.System).InstanceGUID()
    Set jo."system_version" = $ZVersion

    Set ns = $Namespace
    Zn "%SYS"
    Set module = ##class(%ZPM.PackageManager.Developer.Module).NameOpen("zpm")
    If ($IsObject(module)) {
        Set jo."zpmclient_version" = module.VersionString
    } 
    Zn ns
    Do jo.%Set("success",success,"boolean")
    Set jo."error_msg" = msg

    Set tRequest = ..GetHttpRequest()
    Set tRequest.ContentType = "application/json"

    Do tRequest.SetHeader("INSTALLTOKEN", $Get(^IRIS.TempZPMRInst(name,version))) 

    Do jo.%ToJSON(tRequest.EntityBody) 

    Set tSC = tRequest.Post($$$URLENCODE(tRequest.Location_"collect/" _ action))
 /*
     If '($$$ISOK(tSC) && tRequest.HttpResponse.StatusCode=200) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Error Sending Analytics Data"))
    }
 */
    // google
    set req = ##class(%Net.HttpRequest).%New()
    set req.Server = "www.google-analytics.com"

    set requestString = "v=1&tid="_##class(%ZPM.PackageManager.Settings).GetAnalyticsTrackingId()
        _"&cid="_##class(%SYS.System).InstanceGUID()
        _"&ds=web&an="_name_" "_version_"&av="_##class(%ZPM.PackageManager.Settings).GetVersion()
        _"&t=event&aiid="_$ZCONVERT($zv, "O", "URL")_"&ec="_$ZCONVERT(action, "O", "URL")_"&ea="
        _$case($$$ISOK(success), 1: "Success", : "Failure")_"&el="
        _$ZCONVERT(msg, "O", "URL")
    write requestString
    do req.EntityBody.Write(requestString)
    try {
        return req.Post("/collect")
    } catch e {
        do e.Log()
        write !,"Unable to send analytics to " _ req.Server _ ", skipping analytics collection.",!
        return $$$OK
    }
}

/// For run-time checks to ensure the service is available before attempting to invoke it.
Method IsAvailable() As %Boolean
{
  Set tAvailable = 0
  Set tRequest = ..GetHttpRequest()
  
  Set tRequest.Timeout = 1
  Set tSC = tRequest.Get($$$URLENCODE(tRequest.Location_"_ping"))
  set status =tRequest.HttpResponse.StatusCode
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
    #; in case of redirection
    Set tRequest.SSLConfiguration = ..GetSSLConfiguration(tRequest.Server)
    
		If (..Username '= "") && (..Password '= "") {
      Set tRequest.Username = ..Username
      Set tRequest.Password = ..Password
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

}
