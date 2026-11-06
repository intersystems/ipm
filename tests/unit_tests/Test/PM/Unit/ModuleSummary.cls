/// Unit tests for the lines that the show command prints. Modules are built in memory and never saved.
Class Test.PM.Unit.ModuleSummary Extends %UnitTest.TestCase
{

Method TestTitle()
{
    set module = ..NewModule()
    set module.ExternalName = "MyApp"
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do $$$AssertEquals(..Normalize(lines.%Get(0)), "MyApp (my-app) 1.2.3")

    set module.ExternalName = ""
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do $$$AssertEquals(..Normalize(lines.%Get(0)), "my-app 1.2.3")

    set module.ExternalName = "my-app"
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do $$$AssertEquals(..Normalize(lines.%Get(0)), "my-app 1.2.3")
}

Method TestHeader()
{
    set module = ..NewModule()
    set module.Description = "Does things"
    set module.Root = "/r/"
    set module.DeveloperMode = 1
    set module.Repository = "registry"
    set module.LastUpdated = "2026-11-04 10:15:00"
    set module.AfterInstallMessage = "Run it"
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do ..AssertInOrder(lines, "Description: Does things", "Root: /r/", "Mode: developer", "Repository: registry", "Last updated: 2026-11-04 10:15:00", "After install:", "Run it")

    set deployed = ..NewModule()
    set deployed.Deployed = 1
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(deployed, {}, [])
    do $$$AssertTrue(..LineIndex(lines, "Mode: deployed"))
}

Method TestMultiLineText()
{
    set module = ..NewModule()
    set module.Description = "Does things" _ $char(10) _ "        and more things."
    set module.AfterInstallMessage = "Run it" _ $char(13, 10) _ "    then this"
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do $$$AssertTrue(..LineIndex(lines, "Description: Does things and more things."), "Description folds onto one line")
    do ..AssertInOrder(lines, "After install:", "Run it", "then this")
    do $$$AssertNotTrue(..AnyLineContains(lines, $char(10)), "No line contains LF")
    do $$$AssertNotTrue(..AnyLineContains(lines, $char(13)), "No line contains CR")
}

Method TestEmptyModule()
{
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(..NewModule(), {}, [])
    do $$$AssertEquals(lines.%Size(), 1)
}

Method TestDefaults()
{
    set module = ..NewModule()
    set default = ##class(%IPM.Storage.ModuleSetting.Default).%New()
    set default.Name = "count"
    set default.Value = "7"
    do module.Defaults.Insert(default)
    set parameter = ##class(%IPM.Storage.ModuleSetting.Parameter).%New()
    set parameter.Name = "param"
    set parameter.Value = "value"
    do module.Defaults.Insert(parameter)
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do ..AssertInOrder(lines, "Defaults", "count = 7")
    do $$$AssertEquals(..LineIndex(lines, "param = value"), 0)
}

Method TestDependencies()
{
    set module = ..NewModule()
    do ..AddDependency(module, "testify", "1.0.2")
    do ..AddDependency(module, "fslog", "^1.0.0")
    do ..AddDependency(module, "alpha", "^2.0.0")
    do ..AddDependency(module, "pinned", "1.0.2")
    do ..AddDependency(module, "exact", "1.0.2")
    do ..AddDependency(module, "scoped", "1.0.0", "test")
    set installed = {"fslog":"1.0.3","alpha":"1.5.0","pinned":"1.0.3","exact":"1.0.2"}
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, installed, [{"name":"other-app","version":"2.0.0"}])
    do ..AssertInOrder(lines, "Depends on (5)",
        "alpha ^2.0.0 installed 1.5.0, unsatisfied",
        "exact 1.0.2 installed 1.0.2",
        "fslog ^1.0.0 installed 1.0.3",
        "pinned 1.0.2 installed 1.0.3, unsatisfied",
        "testify 1.0.2 not installed",
        "Required by directly (1)", "other-app 2.0.0")
    do $$$AssertNotTrue(..AnyLineContains(lines, "scoped"))
    set requiredBy = ..LineIndex(lines, "Required by directly (1)")
    do $$$AssertEquals(lines.%Get(requiredBy - 2), "", "Blank line separates the two lists")
}

Method TestSystemRequirements()
{
    set module = ..NewModule()
    set requirements = ##class(%IPM.Storage.SystemRequirements).%New()
    set requirements.VersionString = ">=2022.1"
    set requirements.Interoperability = "enabled"
    set requirements.Health = 1
    set requirements.IPMVersion = ">=0.9.0"
    set requirements.PythonVersion = ">=3.10"
    set requirements.SYSNamespace = 1
    set module.SystemRequirements = requirements
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do ..AssertInOrder(lines, "System requirements", "IRIS >=2022.1", "Interoperability enabled", "Health Connect, HealthShare, or IRIS for Health required", "IPM >=0.9.0", "Python >=3.10", "%SYS namespace required")

    set lines = ##class(%IPM.General.ModuleSummary).GetLines(..NewModule(), {}, [])
    do $$$AssertEquals(..LineIndex(lines, "System requirements"), 0, "No SystemRequirements object")

    set module = ..NewModule()
    set module.SystemRequirements = ##class(%IPM.Storage.SystemRequirements).%New()
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do $$$AssertEquals(..LineIndex(lines, "System requirements"), 0, "All SystemRequirements attributes empty")
}

Method TestMappings()
{
    set module = ..NewModule()
    set mapping = ##class(%IPM.Storage.MappingReference).%New()
    set mapping.Name = "MyLib.PKG"
    set mapping.Source = "MYLIBDB"
    set mapping.Module = module
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do ..AssertInOrder(lines, "Mappings", "MyLib.PKG from MYLIBDB")
}

Method TestResourceSections()
{
    set module = ..NewModule()
    do ..AddResource(module, "MyApp.PKG")
    do ..AddResource(module, "MyApp.Macros.INC")
    do ..AddResource(module, "MyApp.Settings.GBL")
    do ..AddResource(module, "/myapp/api", "WebApplication", , "Url", "/myapp/api", "DispatchClass", "MyApp.REST")
    do ..AddResource(module, "/wsgi", "WebApplication", , "Url", "/wsgi", "WSGIAppLocation", "${libdir}app/")
    do ..AddResource(module, "/files", "WebApplication", , "Name", "/files", "Path", "${cspdir}files/")
    do ..AddResource(module, "/hello", "CSPApplication", , "Url", "/hello", "Directory", "${cspdir}hello")
    do ..AddResource(module, "/bare", "WebApplication", , "Url", "/bare")
    do ..AddResource(module, "lib/", "FileCopy", , "Target", "${libdir}my-lib/")
    do ..AddResource(module, "CSP.DefaultFileCharset", "SystemSetting", , "Name", "CSP.DefaultFileCharset", "Value", "UTF-8")
    do ..AddResource(module, "x-1.0-py3-none-any.WHL", "PythonWheel", , "Name", "x-1.0-py3-none-any.whl")
    do ..AddResource(module, "merge.cpf", "CPF")
    do ..AddResource(module, "/internal/x")
    do ..AddResource(module, "Test.Unit.PKG", , "test")
    do ..AddResource(module, "/tests/", "UnitTest")
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do ..AssertInOrder(lines,
        "Code", "MyApp.PKG", "MyApp.Macros.INC",
        "Globals", "^MyApp.Settings",
        "Web applications", "/myapp/api dispatch MyApp.REST", "/wsgi wsgi ${libdir}app/", "/files files at ${cspdir}files/", "/hello files at ${cspdir}hello", "/bare",
        "Files", "lib/ -> ${libdir}my-lib/",
        "System settings", "CSP.DefaultFileCharset = UTF-8",
        "Python", "wheels: x-1.0-py3-none-any.whl",
        "Other resources", "merge.cpf (CPF)", "/internal/x")
    do $$$AssertNotTrue(..AnyLineContains(lines, "Test.Unit"))
    do $$$AssertNotTrue(..AnyLineContains(lines, "/tests/"))
}

Method TestProcessorClassWinsOverSuffix()
{
    set module = ..NewModule()
    do ..AddResource(module, "Lib.PKG", "Copy")
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do ..AssertInOrder(lines, "Other resources", "Lib.PKG (Copy)")
    do $$$AssertEquals(..LineIndex(lines, "Code"), 0)
}

Method TestUnresolvableProcessorIsOther()
{
    set module = ..NewModule()
    do ..AddResource(module, "x", "No.Such.Processor")
    set lines = ##class(%IPM.General.ModuleSummary).GetLines(module, {}, [])
    do ..AssertInOrder(lines, "Other resources", "x (No.Such.Processor)")
}

Method TestParseRequirements()
{
    set stream = ##class(%Stream.FileCharacter).%New()
    do stream.Write("requests" _ $char(13, 10) _ $char(10) _ "# comment" _ $char(10) _ "  numpy>=1.26  " _ $char(13, 10) _ "--index-url https://example.com/simple" _ $char(10))
    set requirements = ##class(%IPM.General.ModuleSummary).ParseRequirements(stream)
    do $$$AssertEquals(requirements.%ToJSON(), ["requests","numpy>=1.26","--index-url https://example.com/simple"].%ToJSON())
}

ClassMethod NewModule() As %IPM.Storage.Module
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = "my-app"
    set module.VersionString = "1.2.3"
    return module
}

/// attributes alternates key and value, e.g. AddResource(module, "/api", "WebApplication", , "Url", "/api")
ClassMethod AddResource(
	module As %IPM.Storage.Module,
	name As %String,
	processorClass As %String = "",
	scope As %String = "",
	attributes... As %String) As %IPM.Storage.ResourceReference
{
    set resource = ##class(%IPM.Storage.ResourceReference).%New()
    set resource.Name = name
    set resource.ProcessorClass = processorClass
    set resource.Scope = scope
    for i = 1:2:$get(attributes) {
        do resource.Attributes.SetAt(attributes(i + 1), attributes(i))
    }
    set resource.Module = module
    return resource
}

ClassMethod AddDependency(
	module As %IPM.Storage.Module,
	name As %String,
	versionString As %String,
	scope As %String = "")
{
    set dependency = ##class(%IPM.Storage.ModuleReference).%New()
    set dependency.Name = name
    set dependency.VersionString = versionString
    set dependency.Scope = scope
    do module.Dependencies.Insert(dependency)
}

/// Returns the 1-based position of the first line whose normalized form equals expected, or 0.
ClassMethod LineIndex(
	lines As %DynamicArray,
	expected As %String) As %Integer
{
    for i = 0:1:lines.%Size() - 1 {
        if ..Normalize(lines.%Get(i)) = expected {
            return i + 1
        }
    }
    return 0
}

ClassMethod AnyLineContains(
	lines As %DynamicArray,
	text As %String) As %Boolean
{
    for i = 0:1:lines.%Size() - 1 {
        if lines.%Get(i) [ text {
            return 1
        }
    }
    return 0
}

ClassMethod Normalize(line As %String) As %String
{
    return $zstrip(line, "<=>W")
}

/// Asserts that each expected line is present and that each follows the previous one, not necessarily adjacent.
Method AssertInOrder(
	lines As %DynamicArray,
	expected... As %String)
{
    set previous = 0
    for i = 1:1:$get(expected) {
        set index = ..LineIndex(lines, expected(i))
        do $$$AssertTrue(index > previous, "'" _ expected(i) _ "' is present after line " _ previous)
        if index {
            set previous = index
        }
    }
}

}
