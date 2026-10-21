Include %IPM.Common

Class %IPM.Repo.Http.PackageService Extends (%RegisteredObject, %IPM.Repo.IPackageService)
{

Parameter ALLOWPREFIXINLOCATION = 1;

Property Location As %IPM.DataType.RepoLocation;

Property Username As %String(MAXLEN = "");

Property Password As %String(MAXLEN = "");

Property Token As %String(MAXLEN = "");

Property TokenAuthMethod As %Boolean [ InitialExpression = "apiKey" ];

ClassMethod GetSSLConfiguration(name As %String) As %String
{
    new $namespace
    set $namespace = "%SYS"

    if '##class(Security.SSLConfigs).Exists(name) {
        do ##class(Security.SSLConfigs).Create(name)
    }
    quit name
}

/// Decomposes url with %Net.URLParser, defaulting the scheme to https and leaving no leading slash on the path.
/// e.g. "ghcr.io/myorg" gives scheme "https", host "ghcr.io" and path "myorg"
ClassMethod ParseLocation(
	url As %String,
	Output components)
{
    // %Net.URLParser misparses bare hostnames as path components; scheme must be present.
    if ($piece(url, "://") '[ "http") {
        set url = "https://" _ url
    }
    do ##class(%Net.URLParser).Decompose(url, .components)
    set path = $get(components("path"))
    if $extract(path) = "/" {
        set path = $extract(path, 2, *)
    }
    set components("path") = path
}

Method GetHttpRequest(tLocation As %IPM.DataType.RepoLocation = {..Location}) As %Net.HttpRequest
{
    set tRequest = ##class(%Net.HttpRequest).%New()

    set tRequest.FollowRedirect = 1

    do ..ParseLocation($$$URLDECODE(tLocation), .tComponents)

    if ($$$lcase(tComponents("scheme")) [ "http") {
        if ($data(tComponents("host"))#2) {
            set tRequest.Server = tComponents("host")
        }
        if ($data(tComponents("port"))#2) {
            set tRequest.Port = tComponents("port")
        }
        if ($$$lcase(tComponents("scheme")) = "https") {
            set tRequest.Https = 1
        }
        if (tComponents("path")'="") {
            if '..#ALLOWPREFIXINLOCATION {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Location should not contain a prefix"))
            }
            set tRequest.Location = tComponents("path")
        }
        if $extract(tRequest.Location, *) '= "/" {
            set tRequest.Location = tRequest.Location _ "/"
        }
        #; in case of redirection
        set tRequest.SSLConfiguration = ..GetSSLConfiguration(tRequest.Server)

        if (..Token '= "") {
            if ..TokenAuthMethod = "basic"{
                do tRequest.SetHeader("Authorization","Basic " _ ..Token)
            } elseif (..TokenAuthMethod = "apiKey") || (..TokenAuthMethod = "") {
                do tRequest.SetHeader("apikey",..Token)
            } elseif ..TokenAuthMethod = "bearer" {
                do tRequest.SetHeader("Authorization","Bearer " _ ..Token)
            } else {
                $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Unknown token auth method: ""%1""", ..TokenAuthMethod)))
            }
        }
        if (..Username '= "") && (..Password '= "") {
            // basic auth
            set tRequest.Username = ..Username
            set tRequest.Password = ..Password
        }
        set proxy=$system.Util.GetEnviron("https_proxy")
        if proxy'="" {
            do ##class(%Net.URLParser).Parse(proxy,.pr)
            if (tRequest.Https) {
                set tRequest.ProxyHTTPS=1
                set tRequest.ProxyTunnel=1
            }
            set tRequest.ProxyPort=pr("port")
            set tRequest.ProxyServer=pr("host")
            if $get(pr("username"))'="",$get(pr("password"))'="" {
                set tRequest.ProxyAuthorization="Basic "_$system.Encryption.Base64Encode(pr("username")_":"_pr("password"))
            }
        }
    }
    return tRequest
}

}
