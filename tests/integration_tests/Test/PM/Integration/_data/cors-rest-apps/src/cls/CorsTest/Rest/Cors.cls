Class CorsTest.Rest.Cors Extends %RegisteredObject
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/" Method="GET" Call="GetInfo" Cors="true"/>
</Routes>
}

ClassMethod GetInfo() As %Status
{
    write "Hello, World!"
    quit $$$OK
}

}
