/// These tests verify that when a module is upgraded to a version with fewer
/// dependencies, the orphaned dependencies are handled based on the
/// -keep-orphans flag.
/// Scenarios:
/// 1. Standard Update: Orphaned dependencies are automatically uninstalled.
/// 2. -keep-orphans: Orphaned dependencies remain installed in the namespace.
Class Test.PM.Integration.UpdateOrphanCleanup Extends Test.PM.Integration.Base
{

Method TestRemoveOrphanedModsOnUpdate() As %Status
{
    #define NormalizeDir(%dir)              ##class(%File).NormalizeDirectory(%dir)
    #define NormalizeFilename(%file,%dir)   ##class(%File).NormalizeFilename(%file,%dir)

    do $$$LogMessage("Verify and uninstall the demo-module1 if it was installed.")

    set testRoot = $$$NormalizeDir($get(^UnitTestRoot))
    set moduleDir = $$$NormalizeDir(##class(%File).GetDirectory(testRoot)_"/_data/demo-module1/")

    set v1ModuleDir = $$$NormalizeDir(moduleDir_"/v1.0.0")
    set v2ModuleDir = $$$NormalizeDir(moduleDir_"/v2.0.0")
    set v3ModuleDir = $$$NormalizeDir(moduleDir_"/v3.0.0")

    do ..CreateDirectory(v1ModuleDir)
    do ..CreateDirectory(v2ModuleDir)
    do ..CreateDirectory(v3ModuleDir)

    set mainModule = "demo-module1"
    set isExist = ##class(%IPM.Storage.Module).NameExists(mainModule)
    if isExist {
        set status = ..RunCommand("uninstall demo-module1 -r")
        do $$$AssertStatusOK(status, "Uninstalled the demo-module1 successfully")
    }

    set status = ..CreateModuleFile(v1ModuleDir, "DemoModuleV1")
    do $$$AssertStatusOK(status, mainModule_" version 1.0.0 Module.xml created")
    do ..CreateDependencyModules(v1ModuleDir)

    do $$$LogMessage("Loading '" _ mainModule _ "' version 1.0.0")
    set status = ..RunCommand("load "_v1ModuleDir)
    do $$$AssertStatusOK(status, mainModule_" version 1.0.0 loaded successfully")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen(mainModule)

    if $isobject(moduleObj) {
        set depsCount = moduleObj.Dependencies.Count()
        for i=1:1:depsCount {
            set depsName = moduleObj.Dependencies.GetAt(i)
            do $$$LogMessage("Module '"_depsName.Name_ "' (dependency of " _mainModule _ ") installed successfully")
        }
        if depsCount = 3 {
            do $$$LogMessage("All 3 dependencies for '"_mainModule_"' have been loaded successfully")
        }
    }

    do $$$LogMessage("Updating '" _ mainModule _ "' to version 2.0.0.")
    set status = ..CreateModuleFile(v2ModuleDir, "DemoModuleV2")
    do $$$AssertStatusOK(status, mainModule_" version 2.0.0 Module.xml created")
    do ..CreateDependencyModules(v1ModuleDir)

    do $$$LogMessage("Updating '"_mainModule_"' to version 2.0.0. Orphaned dependencies should be automatically uninstalled (default behavior).")
    set status = ..RunCommand("update "_mainModule_" -p "_v2ModuleDir)
    do $$$AssertStatusOK(status, "Successfully updated '" _ mainModule _ "' to version 2.0.0.")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen(mainModule)
    if $isobject(moduleObj) {
    set depsCount = moduleObj.Dependencies.Count()
        for i=1:1:depsCount{
            set depsName = moduleObj.Dependencies.GetAt(i)
            do $$$LogMessage("Dependency module '"_depsName.Name_"' exists")
        }
        if depsCount = 2 {
            do $$$LogMessage("Only 2 Dependency modules are exist after update the "_mainModule)
        }
    }

    do $$$LogMessage("Verifying that 'test-dependency-1' was removed because it is no longer a dependency of " _ mainModule _ " in version 2.0.0")
    set isExist = ##class(%IPM.Storage.Module).NameExists("test-dependency-1")
    do $$$AssertTrue('isExist, "The orphaned dependency 'test-dependency-1' should be uninstalled after updating " _ mainModule _ " to version 2.0.0")

    do $$$LogMessage("Updating '"_mainModule_"' to version 3.0.0 with -keep-orphans flag. Orphaned dependencies should be retained.")

    set status = ..CreateModuleFile(v3ModuleDir, "DemoModuleV3")
    do $$$AssertStatusOK(status, mainModule_" version 3.0.0 Module.xml created")
    do ..CreateDependencyModules(v1ModuleDir)

    set status = ..RunCommand("update "_mainModule_" -p "_v3ModuleDir_" -keep-orphans")
    do $$$AssertStatusOK(status, "Successfully updated '"_mainModule_"' to 3.0.0; dependencies were retained as specified by the -keep-orphans flag.")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen(mainModule)
    set depsCount = moduleObj.Dependencies.Count()
    do $$$LogMessage("Dependency module count is "_depsCount)

    for i=1:1:depsCount {
        set depsName = moduleObj.Dependencies.GetAt(i)
        do $$$LogMessage("Dependency module '"_depsName.Name_"' exist after update "_mainModule_" to version 3.0.0")
    }
    set isExist = ##class(%IPM.Storage.Module).NameExists("test-dependency-2")
    do $$$AssertTrue(isExist,"The orphaned 'test-dependency-2' module was successfully retained as expected.")
}

Method RunCommand(Command) As %Status
{
    do $$$LogMessage("Executing command "_Command)
    set status = ##class(%IPM.Main).Shell(Command)
    return status
}

Method CreateDirectory(Directory As %String = "")
{
    if '##class(%File).DirectoryExists(Directory) {
        set status = ##class(%File).CreateDirectoryChain(Directory)
        do $$$AssertStatusOK(status, "Target directory '" _ Directory _ "' was successfully created.")
    }
}

Method CreateModuleFile(
	ModuleDir As %String = "",
	ModuleXdata As %String = "") As %Status
{
    if ModuleDir=""||(ModuleXdata="") {
        quit 0
    }

    set moduleFile = ##class(%File).NormalizeFilename("module.xml",ModuleDir)
    if '##class(%File).Exists(moduleFile) {
        do $$$LogMessage("Module file '" _ moduleFile _ "' not found; creating XML file.")
    }
    set fileStream = ##class(%Stream.FileCharacter).%New()
    set fileStream.Filename = moduleFile
    set modFileXData = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||"_ModuleXdata)
    do fileStream.CopyFrom(modFileXData.Data)
    set status = fileStream.%Save()
    do $$$AssertStatusOK(status, "Module manifest successfully created at '" _ moduleFile _ "'")
    return status
}

Method CreateDependencyModules(Directory As %String = "")
{
    if ##class(%File).DirectoryExists(Directory) {
        set dependencyModuleList = $listbuild("DepModule1", "DepModule2", "DepModule3" )
        set ptr = 0
        while $listnext(dependencyModuleList, ptr, dependencyModule){
            do $$$LogMessage("Processing: "_dependencyModule_" ptr:"_ptr)
            set dependencyModuleDir = ##class(%File).NormalizeDirectory(Directory_"/.modules/"_dependencyModule)
            set status = ##class(%File).CreateDirectoryChain(dependencyModuleDir)
            do $$$AssertStatusOK(status, ".module directory "_dependencyModuleDir_" created for creating the dependency modules")

            do $$$LogMessage("Creating "_dependencyModule_" for loading into main module 'demo-module1'")
            do ..CreateModuleFile(dependencyModuleDir, dependencyModule)
            do $$$LogMessage("module file creation successful'")
        }
    }
}

XData DemoModuleV1 [ MimeType = application/xml ]
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
<Document name="demo-module1.ZPM">
<Module>
        <Name>demo-module1</Name>
        <Version>1.0.0</Version>
        <Description>description</Description>
        <Keywords>keywords</Keywords>
        <Dependencies>
                <ModuleReference>
                        <Name>test-dependency-1</Name>
                        <Version>1.0.0</Version>
                </ModuleReference>
                <ModuleReference>
                        <Name>test-dependency-2</Name>
                        <Version>1.0.0</Version>
                </ModuleReference>
                <ModuleReference>
                        <Name>test-dependency-3</Name>
                        <Version>1.0.0</Version>
                </ModuleReference>
        </Dependencies>
        <Packaging>module</Packaging>
        <Default Name="count" Value="7"/>
        <SourcesRoot>src</SourcesRoot>
</Module>
</Document>
</Export>
}

XData DemoModuleV2 [ MimeType = application/xml ]
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
<Document name="demo-module1.ZPM">
<Module>
        <Name>demo-module1</Name>
        <Version>2.0.0</Version>
        <Description>description</Description>
        <Keywords>keywords</Keywords>
        <Dependencies>
                <ModuleReference>
                        <Name>test-dependency-2</Name>
                        <Version>1.0.0</Version>
                </ModuleReference>
                <ModuleReference>
                        <Name>test-dependency-3</Name>
                        <Version>1.0.0</Version>
                </ModuleReference>
        </Dependencies>
        <Packaging>module</Packaging>
        <Default Name="count" Value="7"/>
        <SourcesRoot>src</SourcesRoot>
</Module>
</Document>
</Export>
}

XData DemoModuleV3 [ MimeType = application/xml ]
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
<Document name="demo-module1.ZPM">
<Module>
        <Name>demo-module1</Name>
        <Version>3.0.0</Version>
        <Description>description</Description>
        <Keywords>keywords</Keywords>
        <Dependencies>
                <ModuleReference>
                        <Name>test-dependency-3</Name>
                        <Version>1.0.0</Version>
                </ModuleReference>
        </Dependencies>
        <Packaging>module</Packaging>
        <Default Name="count" Value="7"/>
        <SourcesRoot>src</SourcesRoot>
</Module>
</Document>
</Export>
}

/// dependency modules for testing
XData DepModule1
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
  <Document name="test-dependency-1.ZPM">
    <Module>
      <Name>test-dependency-1</Name>
      <Version>1.0.0</Version>
      <Packaging>module</Packaging>
    </Module>
  </Document>
</Export>
}

XData DepModule2
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
  <Document name="test-dependency-2.ZPM">
    <Module>
      <Name>test-dependency-2</Name>
      <Version>1.0.0</Version>
      <Packaging>module</Packaging>
    </Module>
  </Document>
</Export>
}

XData DepModule3
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
  <Document name="test-dependency-3.ZPM">
    <Module>
      <Name>test-dependency-3</Name>
      <Version>1.0.0</Version>
      <Packaging>module</Packaging>
    </Module>
  </Document>
</Export>
}

}
