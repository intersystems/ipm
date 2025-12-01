Class Test.PM.Integration.CorsAndJWTTest Extends Test.PM.Integration.Base
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
    if ##class(%File).DirectoryExists(moduleDir_"/module.xml") {
        do $$$AssertStatusOK(1,"Module.xml File exist on "_moduleDir)
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
    set status = ##class(Security.Applications).Get(..#WebAppName,.tProps)
    do $$$AssertStatusOK(status,"Web applciation "_..#WebAppName_" created scuccessfully")
    if $data(tProps("CorsAllowlist"),tCorsAllowlist) {
        do $$$AssertStatusOK(1,"CorsAllowlist values are defined")
        do $$$LogMessage(tCorsAllowlist)
    }
    if $data(tProps("CorsCredentialsAllowed"),tCorsAllow) {
        do $$$AssertStatusOK(1,"CorsCredentialsAllowed values are defined")
        do $$$LogMessage(tCorsAllow)
    }
    if $data(tProps("CorsHeadersList"),tCorsHeadersList) {
        do $$$AssertStatusOK(1,"CorsHeadersList values are defined")
        do $$$LogMessage(tCorsHeadersList)
    }
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

}
