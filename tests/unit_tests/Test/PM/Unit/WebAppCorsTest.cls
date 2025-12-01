Class Test.PM.Unit.WebAppCorsTest Extends %UnitTest.TestCase
{

Parameter CommonPathPrefix As STRING = "cors-rest-apps";

Parameter WebAppName As STRING = "/testcors";

/// create web application using <CspApplcation> tag
Method TestCORSEnabledViaCSPAppTag()
{
    #define NormalizeDirectory(%path)   ##class(%File).NormalizeDirectory(%path)
    #define UTRoot                      ^UnitTestRoot

    set testRoot = $$$NormalizeDirectory($get($$$UTRoot))
    set moduleDir = $$$NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/"_..#CommonPathPrefix_"/")

    do $$$LogMessage("loading via <CspApplication> tag")
    if ##class(%File).Exists(moduleDir_"/module.xml"){
        set status= ##class(%File).Delete(moduleDir_"/module.xml")
        do $$$AssertStatusOK(status,"Removed the 'module.xml' file from "_moduleDir)
    }
    set status = ..GenerateTemplate(moduleDir)
    do $$$AssertStatusOK(status,"Creating module.xml on "_moduleDir_"  successfully. ")

    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Loaded "_..#CommonPathPrefix_" module successfully. "_moduleDir)
    do ..VerifyCORSSettings()

    set status = ##class(%IPM.Main).Shell("uninstall "_..#CommonPathPrefix)
    do $$$AssertStatusOK(status,"uninstalled "_..#CommonPathPrefix_" module successfully.")
}

/// create web application using <WebApplcation> tag
Method TestCORSEnabledViaWebAppTag()
{
    #define NormalizeDirectory(%path)   ##class(%File).NormalizeDirectory(%path)
    #define UTRoot                      ^UnitTestRoot

    do $$$LogMessage("loading via <WebApplcation> tag")
    set testRoot = $$$NormalizeDirectory($get($$$UTRoot))
    set moduleDir = $$$NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/"_..#CommonPathPrefix_"/webapp/")
    if '##class(%File).DirectoryExists(moduleDir) {
        do ##class(%File).CreateDirectoryChain(moduleDir)
    }
    if ##class(%File).Exists(moduleDir_"/module.xml"){
        set status= ##class(%File).Delete(moduleDir_"/module.xml")
        do $$$AssertStatusOK(status,"Removed the 'module.xml' file from "_moduleDir)
    }
    do $$$LogMessage("Creating module.xml with <WebApplcation> tag")
    set moduleStream = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||ModuleWithWebApTag").Data
    set fileStream = ##class(%Stream.FileBinary).%New()
    set fileStream.Filename=moduleDir_"/module.xml"
    set status= fileStream.CopyFromAndSave(moduleStream)
    do $$$AssertStatusOK(status,"Created module.xml manually on "_moduleDir_" successfully.")

    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Loaded "_..#CommonPathPrefix_" module successfully. "_moduleDir)
    do ..VerifyCORSSettings()

    set status = ##class(%IPM.Main).Shell("uninstall "_..#CommonPathPrefix)
    do $$$AssertStatusOK(status,"uninstalled "_..#CommonPathPrefix_" module successfully.")
}

Method VerifyCORSSettings()
{
    new $namespace
    set $namespace = "%SYS"
    set status = ##class(Security.Applications).Get(..#WebAppName,.tProps)
    do $$$AssertStatusOK(status,"Web applciation "_..#WebAppName_" created scuccessfully")
    if $data(tProps("CorsAllowlist"),tCorsAllowlist)&&(tCorsAllowlist'="") {
        do $$$AssertStatusOK(1,"CorsAllowlist values are defined")
        do $$$LogMessage(tCorsAllowlist)
    }
    if $data(tProps("CorsCredentialsAllowed"),tCorsAllow)&&(tCorsAllow'="") {
        do $$$AssertStatusOK(1,"CorsCredentialsAllowed values are defined")
        do $$$LogMessage(tCorsAllow)
    }
    if $data(tProps("CorsHeadersList"),tCorsHeadersList)&&(tCorsHeadersList'="") {
        do $$$AssertStatusOK(1,"CorsHeadersList values are defined")
        do $$$LogMessage(tCorsHeadersList)
    }
}

ClassMethod GenerateTemplate(pPath As %String = "") As %Status
{
    return:(pPath="") $$$OK
    set tTemplate = ##class(%IPM.Storage.ModuleTemplate).%New()
    //do tTemplate.SetTemplateProps()
    set tTemplate.Name = ..#CommonPathPrefix
    set tTemplate.VersionString = "1.0.0"
    set tTemplate.Description = "cors enabling testing on webapplication"
    set tTemplate.Keywords = "cors"

    set tTemplate.Packaging = "module"
    set tTemplate.SourcesRoot = "src"

    //set tTemplate.TemplateResources("cls") = "MyPackage.Demo.CLS"
    //set tTemplate.TemplateResources("cls","Directory") = "cls"

    // REST APP
    set tTemplate.TemplateResources(..#WebAppName) = ..#WebAppName
    set tTemplate.TemplateResources(..#WebAppName,"Url") = ..#WebAppName
    set tTemplate.TemplateResources(..#WebAppName,"CookiePath") = ..#WebAppName
    set tTemplate.TemplateResources(..#WebAppName,"UseCookies") = 2
    set tTemplate.TemplateResources(..#WebAppName,"PasswordAuthEnabled") = 1
    set tTemplate.TemplateResources(..#WebAppName,"UnauthenticatedEnabled") = 0
    set tTemplate.TemplateResources(..#WebAppName,"Recurse") = 1
    ;cors
    set tTemplate.TemplateResources(..#WebAppName,"CorsAllowlist") = "https://www.example.com,https://pm.intersystems.com"
    set tTemplate.TemplateResources(..#WebAppName,"CorsCredentialsAllowed") = 1
    set tTemplate.TemplateResources(..#WebAppName,"CorsHeadersList") = "Access-Control-Allow-Origin, Access-Control-Allow-Methods, Access-Control-Allow-Headers, Access-Control-Allow-Credentials, Access-Control-Max-Age, Access-Control-Expose-Headers, Access-Control-Request-Method, Access-Control-Request-Headers"
    do tTemplate.ProcessResources()
    return tTemplate.SaveFile(pPath)
}

XData ModuleWithWebApTag [ MimeType = application/xml ]
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
	<Document name="cors-rest-apps.ZPM">
		<Module>
			<Name>cors-rest-apps</Name>
			<Version>1.0.0</Version>
			<Description>cors enabling testing on webapplication</Description>
			<Keywords>cors</Keywords>
			<Packaging>module</Packaging>
			<WebApplication Url="/testcors" CookiePath="/testcors"
                CorsAllowlist="https://pm.intersystems.com"
                CorsCredentialsAllowed="1"
                CorsHeadersList="Access-Control-Allow-Origin, Access-Control-Allow-Methods, Access-Control-Allow-Headers, Access-Control-Allow-Credentials, Access-Control-Max-Age, Access-Control-Expose-Headers, Origin, Access-Control-Request-Method, Access-Control-Request-Headers"
                PasswordAuthEnabled="1" Recurse="1" UnauthenticatedEnabled="0" UseCookies="2"/>
			<LifecycleClass>%IPM.Lifecycle.Module</LifecycleClass>
			<SourcesRoot>src</SourcesRoot>
		</Module>
	</Document>
</Export>
}

}
