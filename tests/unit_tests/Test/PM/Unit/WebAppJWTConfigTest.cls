Class Test.PM.Unit.WebAppJWTConfigTest Extends %UnitTest.TestCase
{

Parameter CommonPathPrefix As STRING = "cors-rest-apps";

Parameter WebAppName As STRING = "/testcors";

/// create web application using <WebApplcation> tag
Method TestJWTEnabledViaWebAppTag()
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
    do ..VerifyJWTConfiguration()

    set status = ##class(%IPM.Main).Shell("uninstall "_..#CommonPathPrefix)
    do $$$AssertStatusOK(status,"uninstalled "_..#CommonPathPrefix_" module successfully.")
}

Method VerifyJWTConfiguration()
{
    new $namespace
    set $namespace = "%SYS"
    set status = ##class(Security.Applications).Get(..#WebAppName,.props)
    do $$$AssertStatusOK(status,"Web applciation "_..#WebAppName_" created scuccessfully")
    do $$$LogMessage("Validating JWT configuration")
    if $data(props("JWTAccessTokenTimeout"),tJWTAccessTokenTimeout) {
        do $$$AssertStatusOK(1,"JWTAccessTokenTimeout value is defined")
        do $$$LogMessage(tJWTAccessTokenTimeout)
    }
    if $data(props("JWTAuthEnabled"),tJWTAuthEnabled) {
        do $$$AssertStatusOK(1,"JWTAuthEnabled value is defined")
        do $$$LogMessage(tJWTAuthEnabled)
    }
    if $data(props("JWTRefreshTokenTimeout"),tJWTRefreshTokenTimeout) {
        do $$$AssertStatusOK(1,"JWTRefreshTokenTimeout value is defined")
        do $$$LogMessage(tJWTRefreshTokenTimeout)
    }
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
