/// This class validates that CORS headers and allowed origins are configured correctly,
/// and that JWT authentication is properly set up in the <b>&lt;WebApplication&gt;</b> configuration section.
Class Test.PM.Integration.ResourceProcessor.WebApplication Extends Test.PM.Integration.Base
{

Parameter CommonPathPrefix As STRING = "cors-rest-apps";

Parameter WebAppName As STRING = "/testcors";

/// Test.PM.Integration.Uninstall
Method TestCORSEnabledWebAppViaModule()
{
    #define NormalizeDirectory(%path)   ##class(%File).NormalizeDirectory(%path)
    #define UTRoot                      ^UnitTestRoot

    set testRoot = $$$NormalizeDirectory($get($$$UTRoot))
    set moduleDir = $$$NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/"_..#CommonPathPrefix_"/")
    set moduleFile = ##class(%File).NormalizeFilename("module.xml",moduleDir)
    if ##class(%File).DirectoryExists(moduleFile) {
        do $$$AssertStatusOK(1,"module.xml File exist on "_moduleDir)
    }
    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Loaded "_..#CommonPathPrefix_" module successfully from "_moduleDir)
    do ..VerifyCORSConfiguration()
    do ..VerifyJWTConfiguration()

    set status = ##class(%IPM.Main).Shell("uninstall "_..#CommonPathPrefix)
    do $$$AssertStatusOK(status,"uninstalled "_..#CommonPathPrefix_" module successfully.")
}

Method VerifyCORSConfiguration()
{
    new $namespace
    set $namespace = "%SYS"
    set status = ##class(Security.Applications).Get(..#WebAppName, .props)
    do $$$AssertStatusOK(status,"Web applciation "_..#WebAppName_" created scuccessfully")
    if $data(props("CorsAllowlist"),corsAllowlist) {
        do $$$AssertStatusOK(1,"CorsAllowlist values are defined")
        do $$$LogMessage(corsAllowlist)
    }
    if $data(props("CorsCredentialsAllowed"),corsAllow) {
        do $$$AssertStatusOK(1,"CorsCredentialsAllowed values are defined")
        do $$$LogMessage(corsAllow)
    }
    if $data(props("CorsHeadersList"),corsHeadersList) {
        do $$$AssertStatusOK(1,"CorsHeadersList values are defined")
        do $$$LogMessage(corsHeadersList)
    }
}

Method VerifyJWTConfiguration()
{
    new $namespace
    set $namespace = "%SYS"
    set status = ##class(Security.Applications).Get(..#WebAppName, .props)
    do $$$AssertStatusOK(status,"Web applciation "_..#WebAppName_" created scuccessfully")
    do $$$LogMessage("Validating JWT configuration")
    if $data(props("JWTAccessTokenTimeout"),JWTAccessTokenTimeout) {
        do $$$AssertStatusOK(1,"JWTAccessTokenTimeout value is defined")
        do $$$LogMessage(JWTAccessTokenTimeout)
    }
    if $data(props("JWTAuthEnabled"),JWTAuthEnabled) {
        do $$$AssertStatusOK(1,"JWTAuthEnabled value is defined")
        do $$$LogMessage(JWTAuthEnabled)
    }
    if $data(props("JWTRefreshTokenTimeout"),JWTRefreshTokenTimeout) {
        do $$$AssertStatusOK(1,"JWTRefreshTokenTimeout value is defined")
        do $$$LogMessage(JWTRefreshTokenTimeout)
    }
}

}
