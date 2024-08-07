Include %IPM.Common

Class %IPM.Repo.Http.PackageService Extends (%RegisteredObject, %IPM.Repo.IPackageService)
{

Property Location As %String;

Property Username As %String;

Property Password As %String;

Property Token As %String;

ClassMethod GetSSLConfiguration(host) As %String
{
	New $NAMESPACE
	Set $NAMESPACE = "%SYS"
	
	If '##class(Security.SSLConfigs).Exists(host) {
		Do ##class(Security.SSLConfigs).Create(host)
	}
	Quit host
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
			If (tLocation [ "aws") {
				// aws token auth
				Do tRequest.SetHeader("Authorization","Basic " _ ..Token)
			} Else {
				// key auth
				Do tRequest.SetHeader("apikey",..Token)
			}
		}
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

}