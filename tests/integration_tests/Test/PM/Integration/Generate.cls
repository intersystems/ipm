/// Tests the module.xml that <code>generate</code> writes. These call <class>%IPM.Storage.ModuleTemplate</class>
/// directly, because <code>generate</code> itself only prompts and then calls the same methods.
Class Test.PM.Integration.Generate Extends Test.PM.Integration.Base
{

Parameter RestApp As STRING = "/genfixture-rest";

Parameter CSPApp As STRING = "/genfixture-csp";

Parameter WebAppsModule As STRING = "generate-web-apps";

/// Native-filesystem directory that each test writes module.xml into
Property TempDir As %String(MAXLEN = "");

Method OnBeforeOneTest(testName As %String) As %Status
{
    set ..TempDir = ##class(%File).NormalizeDirectory("generate-test", ##class(%File).ManagerDirectory())
    do ..RemoveTempDir()
    quit ##class(%IPM.Utils.File).CreateDirectoryChain(..TempDir)
}

Method OnAfterOneTest(testName As %String) As %Status
{
    if ##class(%IPM.Storage.Module).NameExists(..#WebAppsModule) {
        do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall "_..#WebAppsModule))
    }
    do ..DeleteWebApps()
    set cspDir = ..CSPAppDirectory()
    if ##class(%File).DirectoryExists(cspDir) {
        do ##class(%File).RemoveDirectoryTree(cspDir)
    }
    do ..RemoveTempDir()
    quit $$$OK
}

Method RemoveTempDir()
{
    // Guard the recursive delete so an empty or unexpected path can never wipe the manager directory
    set managerDir = ##class(%File).ManagerDirectory()
    if ($length(..TempDir) > $length(managerDir)) && ($extract(..TempDir, 1, $length(managerDir)) = managerDir) && ##class(%File).DirectoryExists(..TempDir) {
        do ##class(%File).RemoveDirectoryTree(..TempDir)
    }
}

Method TestUnitTestsFromTestsFolder()
{
    set template = ##class(%IPM.Storage.ModuleTemplate).NewTemplate(..GetModuleDir("generate", "unit-tests"), "generate-unit-tests", "1.0.0")
    do template.ReadResources("src", "tests")
    do ..Save(template)
    do $$$AssertEquals(..Summarize("Resource", "Directory"), "GenFixture.App.PKG Directory=cls")
    do $$$AssertEquals(..Summarize("UnitTest", "Package", "Phase"), "/tests/unit_tests/ Package=GenFixture.Test.Unit Phase=test")
}

/// With the module root as the source folder, the tests folder is inside it and its classes belong only to the UnitTest
Method TestTestsUnderSourceFolderAreNotPackaged()
{
    set template = ##class(%IPM.Storage.ModuleTemplate).NewTemplate(..GetModuleDir("generate", "unit-tests"), "generate-unit-tests", "1.0.0")
    do template.ReadResources("", "tests")
    do ..Save(template)
    do $$$AssertEquals(..Summarize("Resource", "Directory"), "GenFixture.App.PKG Directory=src/cls")
    do $$$AssertEquals(..Summarize("UnitTest", "Package", "Phase"), "/tests/unit_tests/ Package=GenFixture.Test.Unit Phase=test")
}

Method TestMissingSourceFolderThrows()
{
    set template = ##class(%IPM.Storage.ModuleTemplate).NewTemplate(..GetModuleDir("generate", "unit-tests"), "generate-unit-tests", "1.0.0")
    try {
        do template.ReadResources("missing")
        do $$$AssertFailure("ReadResources did not throw for a missing source folder")
    } catch e {
        do $$$AssertTrue($system.Status.GetErrorText(e.AsStatus()) [ "doesn't exist")
    }
}

/// Generates a module from a REST app and a CSP app, deletes the apps, and loads the module to recreate them
Method TestWebApplicationsLoad()
{
    set namespace = $namespace
    set matchRoles = ":"_##class(%IPM.Utils.Module).GetDatabaseRole()
    set rest("NameSpace") = namespace
    set rest("DispatchClass") = "GenFixture.REST"
    set rest("AutheEnabled") = $$$AutheCache
    // Recurse=0 differs from the Security.Applications default, so module.xml must carry it
    set rest("Recurse") = 0
    set csp("NameSpace") = namespace
    set csp("Path") = ..CSPAppDirectory()
    set csp("AutheEnabled") = $$$AutheUnauthenticated
    set csp("MatchRoles") = matchRoles
    set csp("DeepSeeEnabled") = 1
    do ..CreateWebApp(..#RestApp, .rest)
    do ..CreateWebApp(..#CSPApp, .csp)

    do $$$AssertStatusOK(##class(%IPM.Utils.File).CopyDir(..GetModuleDir("generate", "web-apps"), ..TempDir))
    set template = ##class(%IPM.Storage.ModuleTemplate).NewTemplate(..TempDir, ..#WebAppsModule, "1.0.0")
    set jwt("enableJWT") = 1
    set jwt("JWTAccessTokenTO") = 120
    set jwt("JWTRefreshTokenTO") = 1800
    do template.SetJWTProps(..#RestApp, .jwt)
    do $$$AssertStatusOK(template.AddWebApps(..#RestApp_","_..#CSPApp, .cspApps))
    do $$$AssertEquals($listtostring(cspApps), ..#CSPApp)
    do template.SetSourcePathForCSPApp(..#CSPApp, "web/")
    do ..Save(template)
    // Written even when it is the Security.Applications default, so readers of module.xml can see each app's authentication
    do $$$AssertEquals(..Summarize("WebApplication", "AutheEnabled"), ..#CSPApp_" AutheEnabled="_$$$AutheUnauthenticated_", "_..#RestApp_" AutheEnabled="_$$$AutheCache)

    do ..DeleteWebApps()
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load "_..TempDir))

    new $namespace
    set $namespace = "%SYS"
    do $$$AssertStatusOK(##class(Security.Applications).Get(..#RestApp, .restProps))
    do $$$AssertEquals($get(restProps("NameSpace")), namespace)
    do $$$AssertEquals($get(restProps("DispatchClass")), "GenFixture.REST")
    do $$$AssertEquals($get(restProps("AutheEnabled")), $$$AutheCache)
    do $$$AssertEquals($get(restProps("Recurse")), 0)
    do $$$AssertEquals($get(restProps("JWTAuthEnabled")), 1)
    do $$$AssertEquals($get(restProps("JWTAccessTokenTimeout")), 120)
    do $$$AssertEquals($get(restProps("JWTRefreshTokenTimeout")), 1800)
    do $$$AssertStatusOK(##class(Security.Applications).Get(..#CSPApp, .cspProps))
    do $$$AssertEquals($get(cspProps("Path")), ..CSPAppDirectory())
    do $$$AssertEquals($get(cspProps("AutheEnabled")), $$$AutheUnauthenticated)
    do $$$AssertEquals($get(cspProps("MatchRoles")), matchRoles)
    do $$$AssertEquals($get(cspProps("DeepSeeEnabled")), 1)
    set $namespace = namespace
    do $$$AssertTrue(##class(%File).Exists(##class(%File).NormalizeFilename("index.html", ..CSPAppDirectory())), "CSP source files were copied to the app's path")
}

Method TestTemplateUsesValidAttributes()
{
    do $$$AssertStatusOK(##class(%IPM.Storage.ModuleTemplate).GenerateTemplate(..TempDir))
    set webApps = ..ReadElements("WebApplication")
    do $$$AssertEquals(webApps.%Size(), 2)
    set invalid = ""
    set iterator = webApps.%GetIterator()
    while iterator.%GetNext(, .webApp) {
        set attributes = webApp.%GetIterator()
        while attributes.%GetNext(.name) {
            if '..IsWebAppProperty(name) {
                set invalid = invalid_$listbuild(name)
            }
        }
    }
    do $$$AssertEquals($listtostring(invalid), "")
    do $$$AssertEquals(..Summarize("UnitTest", "Package", "Phase"), "/tests/unit_tests/ Package=Test.Unit Phase=test")
    do $$$AssertEquals(..Summarize("FileCopy", "Target"), "web/ Target={$cspdir}myapp/")
}

ClassMethod IsWebAppProperty(name As %String) As %Boolean
{
    new $namespace
    set $namespace = "%SYS"
    return ##class(%Dictionary.CompiledProperty).%ExistsId("Security.Applications||"_name)
}

Method Save(template As %IPM.Storage.ModuleTemplate)
{
    do template.ProcessResources()
    do $$$AssertStatusOK(template.SaveFile(..TempDir))
}

/// Returns one dynamic object of attributes for each <var>elementName</var> element in the generated module.xml
Method ReadElements(elementName As %String) As %DynamicArray
{
    set elements = []
    $$$ThrowOnError(##class(%XML.TextReader).ParseFile(##class(%File).NormalizeFilename("module.xml", ..TempDir), .reader))
    while reader.Read() {
        continue:((reader.NodeType '= "element") || (reader.LocalName '= elementName))
        set element = {}
        for i=1:1:reader.AttributeCount {
            do reader.MoveToAttributeIndex(i)
            do element.%Set(reader.LocalName, reader.Value)
        }
        do elements.%Push(element)
    }
    return elements
}

/// Summarizes each <var>elementName</var> element as its Name followed by the given attributes, sorted, e.g.
/// <example>Sample.PKG Directory=cls, Other.PKG Directory=cls</example>
Method Summarize(
	elementName As %String,
	attributes... As %String) As %String
{
    set iterator = ..ReadElements(elementName).%GetIterator()
    while iterator.%GetNext(, .element) {
        set line = element.%Get("Name")
        for i=1:1:$get(attributes) {
            set line = line_" "_attributes(i)_"="_element.%Get(attributes(i))
        }
        set lines(line) = ""
    }
    set summary = ""
    set line = ""
    for {
        set line = $order(lines(line))
        quit:line=""
        set summary = summary_$select(summary="":"", 1:", ")_line
    }
    return summary
}

ClassMethod CSPAppDirectory() As %String
{
    return ##class(%File).NormalizeDirectory("genfixture-csp", ##class(%File).NormalizeDirectory("csp", $system.Util.InstallDirectory()))
}

ClassMethod CreateWebApp(
	name As %String,
	ByRef props)
{
    new $namespace
    set $namespace = "%SYS"
    $$$ThrowOnError(##class(Security.Applications).Create(name, .props))
}

ClassMethod DeleteWebApps()
{
    new $namespace
    set $namespace = "%SYS"
    for name = ..#RestApp, ..#CSPApp {
        if ##class(Security.Applications).Exists(name) {
            $$$ThrowOnError(##class(Security.Applications).Delete(name))
        }
    }
}

}
