Class Test.PM.Unit.WebApJWTConfigTest Extends %UnitTest.TestCase
{

Parameter CommonPathPrefix As STRING = "cors-rest-apps";

Parameter WebAppName As STRING = "/testcors";

/// create web application using <CspApplcation> tag
Method TestJWTEnabledViaCspAppTag()
{
    #define NormalizeDirectory(%path)   ##class(%File).NormalizeDirectory(%path)
    #define UTRoot                      ^UnitTestRoot

    set testRoot = $$$NormalizeDirectory($get($$$UTRoot))
    set moduleDir = $$$NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/"_..#CommonPathPrefix_"/")

    do $$$LogMessage("loading via <CspApplication> tag")

    if ##class(%File).DirectoryExists(moduleDir_"/module.xml"){
        set status= ##class(%File).Delete(moduleDir_"/module.xml")
        do $$$AssertStatusOK(status,"file already exist.So, Removed the 'module.xml' file from "_moduleDir)
    }
    set status = ..GenerateTemplate(moduleDir)
    do $$$AssertStatusOK(status,"Creating module.xml on "_moduleDir_"  successfully. ")

    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Loaded "_..#CommonPathPrefix_" module successfully. "_moduleDir)
    do ..VerifyJWTConfiguration()

    set status = ##class(%IPM.Main).Shell("uninstall "_..#CommonPathPrefix)
    do $$$AssertStatusOK(status,"uninstalled "_..#CommonPathPrefix_" module successfully.")
}

/// create web application using <WebApplcation> tag
Method TestJWTEnabledViaWebAppTag()
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
    do ..VerifyJWTConfiguration()

    set status = ##class(%IPM.Main).Shell("uninstall "_..#CommonPathPrefix)
    do $$$AssertStatusOK(status,"uninstalled "_..#CommonPathPrefix_" module successfully.")
}

Method VerifyJWTConfiguration()
{
    new $namespace
    set $namespace = "%SYS"
    set status = ##class(Security.Applications).Get(..#WebAppName,.tProps)
    do $$$AssertStatusOK(status,"Web applciation "_..#WebAppName_" created scuccessfully")
    do $$$LogMessage("Validating JWT configuration")
    if $data(tProps("JWTAccessTokenTimeout"),tJWTAccessTokenTimeout) {
        do $$$AssertStatusOK(1,"JWTAccessTokenTimeout value is defined")
        do $$$LogMessage(tJWTAccessTokenTimeout)
    }
    if $data(tProps("JWTAuthEnabled"),tJWTAuthEnabled) {
        do $$$AssertStatusOK(1,"JWTAuthEnabled value is defined")
        do $$$LogMessage(tJWTAuthEnabled)
    }
    if $data(tProps("JWTRefreshTokenTimeout"),tJWTRefreshTokenTimeout) {
        do $$$AssertStatusOK(1,"JWTRefreshTokenTimeout value is defined")
        do $$$LogMessage(tJWTRefreshTokenTimeout)
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
    set tTemplate.TemplateResources(..#WebAppName,"JWTAccessTokenTimeout") = 60
    set tTemplate.TemplateResources(..#WebAppName,"JWTAuthEnabled") = 1
    set tTemplate.TemplateResources(..#WebAppName,"JWTRefreshTokenTimeout") = 900
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
			<WebApplication Url="/testcors"
                CookiePath="/testcors"
                JWTAccessTokenTimeout="60"
                JWTAuthEnabled="1"
                JWTRefreshTokenTimeout="900"
                PasswordAuthEnabled="1" Recurse="1" UnauthenticatedEnabled="0" UseCookies="2"/>
			<LifecycleClass>%IPM.Lifecycle.Module</LifecycleClass>
			<SourcesRoot>src</SourcesRoot>
		</Module>
	</Document>
</Export>
}

}
