Class Test.PM.Unit.WebAppCorsTest Extends %UnitTest.TestCase
{

Parameter CommonPathPrefix As STRING = "cors-rest-apps";

Parameter WebAppName As STRING = "/testcors";

/// create web application using <CspApplcation> tag
Method TestCORSEnabledViaCSPAppTag()
{
    set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set moduleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/"_..#CommonPathPrefix_"/")
    set moduleFile = ##class(%File).NormalizeFilename("module.xml",moduleDir)

    do $$$LogMessage("loading via <CspApplication> tag")
    if ##class(%File).Exists(moduleFile){
        set status= ##class(%File).Delete(moduleFile)
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
    do $$$LogMessage("loading via <WebApplcation> tag")
    set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set moduleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/"_..#CommonPathPrefix_"/webapp/")
    if '##class(%File).DirectoryExists(moduleDir) {
        do ##class(%File).CreateDirectoryChain(moduleDir)
    }
    set moduleFile = ##class(%File).NormalizeFilename("module.xml",moduleDir)
    if ##class(%File).Exists(moduleFile){
        set status= ##class(%File).Delete(moduleFile)
        do $$$AssertStatusOK(status,"Removed the 'module.xml' file from "_moduleDir)
    }
    do $$$LogMessage("Creating module.xml with <WebApplcation> tag")
    set moduleStream = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||ModuleWithWebApTag").Data
    set fileStream = ##class(%Stream.FileBinary).%New()
    set fileStream.Filename=moduleFile
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
    set status = ##class(Security.Applications).Get(..#WebAppName,.props)
    do $$$AssertStatusOK(status,"Web applciation "_..#WebAppName_" created scuccessfully")
    if $data(props("CorsAllowlist"),corsAllowlist)&&(corsAllowlist'="") {
        do $$$AssertStatusOK(1,"CorsAllowlist values are defined")
        do $$$LogMessage(corsAllowlist)
    }
    if $data(props("CorsCredentialsAllowed"),corsAllow)&&(corsAllow'="") {
        do $$$AssertStatusOK(1,"CorsCredentialsAllowed values are defined")
        do $$$LogMessage(corsAllow)
    }
    if $data(props("CorsHeadersList"),corsHeadersList)&&(corsHeadersList'="") {
        do $$$AssertStatusOK(1,"CorsHeadersList values are defined")
        do $$$LogMessage(corsHeadersList)
    }
}

ClassMethod GenerateTemplate(pPath As %String = "") As %Status
{
    return:(pPath="") $$$OK
    set template = ##class(%IPM.Storage.ModuleTemplate).%New()
    set template.Name = ..#CommonPathPrefix
    set template.VersionString = "1.0.0"
    set template.Description = "cors enabling testing on webapplication"
    set template.Keywords = "cors"

    set template.Packaging = "module"
    set template.SourcesRoot = "src"

    // REST APP
    set template.TemplateResources(..#WebAppName) = ..#WebAppName
    set template.TemplateResources(..#WebAppName,"Url") = ..#WebAppName
    set template.TemplateResources(..#WebAppName,"CookiePath") = ..#WebAppName
    set template.TemplateResources(..#WebAppName,"UseCookies") = 2
    set template.TemplateResources(..#WebAppName,"PasswordAuthEnabled") = 1
    set template.TemplateResources(..#WebAppName,"UnauthenticatedEnabled") = 0
    set template.TemplateResources(..#WebAppName,"Recurse") = 1
    ;cors
    set template.TemplateResources(..#WebAppName,"CorsAllowlist") = "https://www.example.com,https://pm.intersystems.com"
    set template.TemplateResources(..#WebAppName,"CorsCredentialsAllowed") = 1
    set template.TemplateResources(..#WebAppName,"CorsHeadersList") = "Access-Control-Allow-Origin, Access-Control-Allow-Methods, Access-Control-Allow-Headers, Access-Control-Allow-Credentials, Access-Control-Max-Age, Access-Control-Expose-Headers, Access-Control-Request-Method, Access-Control-Request-Headers"
    do template.ProcessResources()
    return template.SaveFile(pPath)
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
