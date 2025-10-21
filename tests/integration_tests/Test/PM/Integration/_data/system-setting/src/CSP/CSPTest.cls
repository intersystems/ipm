Class CSPFile.CSPTest Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
   set html="<!DOCTYPE html>"
           _"<html lang=""en"" dir=""ltr"">"
           _"<body>"
           _"<h1>Basic Page</h1>"

   // examine %request object and
   // write more output...

   set html=html_"</body>"
                _"</html>"

   write html //finally, write the page
   quit $$$OK
}

}
