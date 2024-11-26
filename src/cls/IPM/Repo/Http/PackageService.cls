Include %IPM.Common

Class %IPM.Repo.Http.PackageService Extends (%RegisteredObject, %IPM.Repo.IPackageService)
{

Parameter ALLOWPREFIXINLOCATION = 1;

Property Location As %IPM.DataType.RepoLocation;

Property Username As %String(MAXLEN = "");

Property Password As %String(MAXLEN = "");

Property Token As %String(MAXLEN = "");

Property TokenAuthMethod As %Boolean [ InitialExpression = 0 ];

ClassMethod GetSSLConfiguration(name As %String) As %String
{
	New $NAMESPACE
	Set $NAMESPACE = "%SYS"
	
	If '##class(Security.SSLConfigs).Exists(name) {
		Do ##class(Security.SSLConfigs).Create(name)
	}
	Quit name
}

Method GetHttpRequest(tLocation As %IPM.DataType.RepoLocation = {..Location}) As %Net.HttpRequest
{
	Set tRequest = ##class(%Net.HttpRequest).%New()

	Set tRequest.FollowRedirect = 1

	Set tLocation = $$$URLDECODE(tLocation)
	If ($piece(tLocation, "://")'["http") {
		Set tLocation = "https://" _ tLocation
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
			If '..#ALLOWPREFIXINLOCATION {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Location should not contain a prefix"))
			}
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
			If ..TokenAuthMethod = "basic"{
				Do tRequest.SetHeader("Authorization","Basic " _ ..Token)
			} ElseIf ..TokenAuthMethod = "apiKey" {
				Do tRequest.SetHeader("apikey",..Token)
			} ElseIf ..TokenAuthMethod = "bearer" {
				Do tRequest.SetHeader("Authorization","Bearer " _ ..Token)
			} Else {
				$$$ThrowStatus($$$ERROR(($$$GeneralError, $$$FormatText("Unknown token auth method: ""%1""", ..TokenAuthMethod))))
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
