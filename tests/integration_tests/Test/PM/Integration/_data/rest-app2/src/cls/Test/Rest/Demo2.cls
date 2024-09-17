Class Test.Rest.Demo2 Extends %CSP.REST
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/" Method="GET" Call="GetInfo" Cors="true"/>
</Routes>
}

ClassMethod GetInfo() As %Status
{
    Write "Hello, World!"
    Quit $$$OK
}

}
