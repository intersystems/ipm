Class Test.PM.Unit.LifecycleDatabase Extends %UnitTest.TestCase
{

/// Modules created outside of this test save modules to storage under fixed names; delete them
/// unconditionally so a failed assert cannot leave rows behind for the next run.
Method OnAfterOneTest(testName As %String) As %Status
{
    for name = "aa-root", "mm-mid", "zz-base", "bb-left", "cc-right", "zz-shared" {
        if ##class(%IPM.Storage.Module).NameExists(name) {
            do ##class(%IPM.Storage.Module).NameDelete(name)
        }
    }
    quit $$$OK
}

/// A module declaring Packaging="database" must resolve to %IPM.Lifecycle.Database, not the generic
/// %IPM.Lifecycle.Module. Covers both derivation branches in %OnValidateObject: the default
/// LifecycleClass being switched out, and an empty LifecycleClass being filled in.
Method TestPackagingDerivesLifecycleClass()
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = "derive-lifecycle-check"
    set module.VersionString = "1.0.0"
    set module.Packaging = "database"

    // LifecycleClass has an InitialExpression of %IPM.Lifecycle.Module, so this leaves the default
    // in place and validation must notice it disagrees with Packaging.
    do $$$AssertStatusOK(module.%ValidateObject(), "Module with default LifecycleClass and Packaging=database validates")
    do $$$AssertEquals(module.LifecycleClass, "%IPM.Lifecycle.Database", "Default LifecycleClass replaced from database packaging")

    // The other branch: nothing declared at all, so the class is derived rather than replaced.
    set module.LifecycleClass = ""
    do $$$AssertStatusOK(module.%ValidateObject(), "Module with empty LifecycleClass and Packaging=database validates")
    do $$$AssertEquals(module.LifecycleClass, "%IPM.Lifecycle.Database", "Empty LifecycleClass derived from database packaging")
}

/// Guards the ComputeSHA256Hex output contract (64-char lowercase hex): the hash is produced
/// via the %xsd.hexBinary encoder, so this pins the length and lowercasing.
Method TestSHA256HexFormat()
{
    // Write a small known file and hash it.
    set tmp = ##class(%Library.File).TempFilename("bin")
    set stream = ##class(%Stream.FileBinary).%New()
    do $$$AssertStatusOK(stream.LinkToFile(tmp), "Linked stream to temp file")
    do $$$AssertStatusOK(stream.Write("abc"), "Wrote test content")
    do $$$AssertStatusOK(stream.%Save(), "Saved temp file")
    set hex = ##class(%IPM.Utils.File).ComputeSHA256Hex(tmp)
    do ##class(%Library.File).Delete(tmp)

    // SHA-256 of "abc" is a well-known constant, in lowercase hex.
    do $$$AssertEquals(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256('abc') matches known value")
}

/// The packaging transform replaces an existing SystemRequirements Version with the IRIS version
/// packaging ran on.
Method TestPackagingTransformReplacesSystemRequirementsVersion()
{
    set source = ##class(%Stream.TmpCharacter).%New()
    do source.Write("<Export generator=""IRIS"" version=""26""><Document name=""sysreq-check.ZPM""><Module>")
    do source.Write("<Name>sysreq-check</Name><Version>1.0.0</Version><SystemRequirements Version=""2020.1""/>")
    do source.Write("</Module></Document></Export>")
    do source.Rewind()

    set compiled = ##class(%IPM.Lifecycle.Database).CompilePackagingTransform("abc", "2099.1")
    do $$$AssertStatusOK(##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(source, compiled, .transformed), "Applied packaging transform")
    set result = transformed.Read($$$MaxStringLength)

    do $$$AssertTrue(result [ "<SystemRequirements Version=""2099.1""", "SystemRequirements Version is the packaging IRIS version: " _ result)
    do $$$AssertNotTrue(result [ "2020.1", "Previous SystemRequirements Version is gone")
}

/// GetDependencyNames must place a dependency before its dependent. Module names sort against the
/// required order, so name order and dependency order differ.
Method TestTopologicalDependencyOrder()
{
    // "zz-base" <- "mm-mid" <- root. Name order would give mm-mid, zz-base.
    do ..SaveModule("zz-base")
    do ..SaveModule("mm-mid", $listbuild("zz-base"))
    set root = ..SaveModule("aa-root", $listbuild("mm-mid"))

    set ordered = root.GetDependencyNames()
    do $$$AssertEquals($listtostring(ordered, ","), "zz-base,mm-mid", "Dependency precedes dependent")
}

/// A dependency reached through two paths is listed once, before both of its dependents.
Method TestSharedDependencyListedOnce()
{
    do ..SaveModule("zz-shared")
    do ..SaveModule("bb-left", $listbuild("zz-shared"))
    do ..SaveModule("cc-right", $listbuild("zz-shared"))
    set root = ..SaveModule("aa-root", $listbuild("bb-left", "cc-right"))

    set ordered = root.GetDependencyNames()
    do $$$AssertEquals($listlength(ordered), 3, "Each dependency listed once: " _ $listtostring(ordered, ","))
    do $$$AssertEquals($listget(ordered, 1), "zz-shared", "Shared dependency precedes both dependents")
}

/// A declared dependency with no installed record is left out, wherever it is declared.
/// A test-scoped dependency is the usual case: a normal install never installs it.
Method TestUninstalledDependencyOmitted()
{
    do ..SaveModule("mm-mid", $listbuild("qq-missing"))
    set root = ..SaveModule("aa-root", $listbuild("mm-mid"), $listbuild("qq-missing"))

    set ordered = root.GetDependencyNames()
    do $$$AssertEquals($listtostring(ordered, ","), "mm-mid", "Uninstalled dependency omitted")
}

/// StageModuleResources hands every resource with a processor to that processor, not only the
/// processor classes it knows about.
Method TestStagingHookCalledForEveryProcessor()
{
    set targetDir = ##class(%IPM.Utils.File).CreateTempDirectory()
    set module = ..NewModuleWithResource("probe-resource", "Test.PM.Unit.StagingProbe")
    do ##class(%IPM.Lifecycle.Database).StageModuleResources(module, targetDir, 0, .params)

    do $$$AssertTrue(##class(%Library.File).Exists(##class(%Library.File).NormalizeFilename("probe-staged", targetDir)), "Processor staged its own file")
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(targetDir)
}

/// A FileCopy whose SourceDirectory is an expression copies from outside the module root at
/// install time, so nothing under the module root is staged for it.
Method TestFileCopyExpressionSourceNotStaged()
{
    set rootDir = ##class(%IPM.Utils.File).CreateTempDirectory()
    set targetDir = ##class(%IPM.Utils.File).CreateTempDirectory()
    set stream = ##class(%Stream.FileCharacter).%New()
    do $$$AssertStatusOK(stream.LinkToFile(##class(%Library.File).NormalizeFilename("expr-source.txt", rootDir)), "Linked root file")
    do $$$AssertStatusOK(stream.Write("not staged"), "Wrote root file")
    do $$$AssertStatusOK(stream.%Save(), "Saved root file")

    set module = ..NewModuleWithResource("expr-source.txt", "FileCopy")
    set module.Root = rootDir
    set resource = module.Resources.GetAt(1)
    // Module.xml import records Name as an attribute too and it overrides its SourceDirectory alias.
    do resource.Attributes.SetAt("expr-source.txt", "Name")
    do resource.Attributes.SetAt("${mgrdir}does-not-exist/", "SourceDirectory")
    do resource.Attributes.SetAt("${mgrdir}expr-target/", "Target")
    do ##class(%IPM.Lifecycle.Database).StageModuleResources(module, targetDir, 0, .params)

    do $$$AssertEquals(##class(%IPM.Utils.File).FindFiles(targetDir), 0, "Nothing staged for an expression SourceDirectory")

    do ##class(%IPM.Utils.File).RemoveDirectoryTree(rootDir)
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(targetDir)
}

/// Returns an unsaved module holding one resource named resourceName handled by processorClass.
Method NewModuleWithResource(
	resourceName As %String,
	processorClass As %String) As %IPM.Storage.Module
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = "staging-check"
    set module.VersionString = "1.0.0"
    set resource = ##class(%IPM.Storage.ResourceReference).%New()
    set resource.Name = resourceName
    set resource.ProcessorClass = processorClass
    do module.Resources.Insert(resource)
    quit module
}

/// Saves a module record named name at version 1.0.0 that depends on each name in dependencyNames,
/// and on each name in testDependencyNames with Scope="test".
Method SaveModule(
	name As %String,
	dependencyNames As %List = "",
	testDependencyNames As %List = "") As %IPM.Storage.Module
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = name
    set module.VersionString = "1.0.0"
    do ..AddDependencies(module, dependencyNames, "")
    do ..AddDependencies(module, testDependencyNames, "test")
    do $$$AssertStatusOK(module.%Save(), "Saved " _ name)
    quit module
}

/// Adds a dependency at version 1.0.0 with the given scope for each name in names.
Method AddDependencies(
	module As %IPM.Storage.Module,
	names As %List,
	scope As %String)
{
    set ptr = 0
    while $listnext(names, ptr, depName) {
        set dep = ##class(%IPM.Storage.ModuleReference).%New()
        set dep.Name = depName
        set dep.VersionString = "1.0.0"
        set dep.Scope = scope
        do module.Dependencies.Insert(dep)
    }
}

/// Pins the exclusions actually taking effect, so removing one is a visible test change rather
/// than a silent behavior change.
Method TestDependencyPhasesExcludeReloadAndCompile()
{
    for isUpdate = 0, 1 {
        set phases = ##class(%IPM.Lifecycle.Database).GetDependencyInstallPhases(isUpdate)
        do $$$AssertNotTrue($listfind(phases, "Reload"), "Dependencies skip Reload")
        do $$$AssertNotTrue($listfind(phases, "Compile"), "Dependencies skip Compile")
        // An update runs each dependency's own update steps, matching a source update.
        do $$$AssertEquals($listfind(phases, "ApplyUpdateSteps") > 0, isUpdate, "Dependencies run ApplyUpdateSteps only on an update")
    }
}

}
