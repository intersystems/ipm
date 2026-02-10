Class Test.PM.Integration.OrphanCleanup Extends Test.PM.Integration.Base
{

Method TestRemoveOrphanedModOnUpdate() As %Status
{
    #define NormalizeDir(%dir)              ##class(%File).NormalizeDirectory(%dir)
    #define NormalizeFilename(%file,%dir)   ##class(%File).NormalizeFilename(%file,%dir)

    do $$$LogMessage("Verify and uninstall the demo-module1 if it was installed.")
    set isExist = ##class(%IPM.Storage.Module).NameExists("demo-module1")
    if isExist{
        set status = ..RunCommand("uninstall demo-module1 -r")
        do $$$AssertStatusOK(status, "Uninstalled the demo-module1 successfully")
    }
    set testRoot = $$$NormalizeDir($get(^UnitTestRoot))
    set moduleDir = $$$NormalizeDir(##class(%File).GetDirectory(testRoot)_"/_data/demo-module/")

    set v1ModuleDir = $$$NormalizeDir(moduleDir_"/v1.0.0")
    set v2ModuleDir = $$$NormalizeDir(moduleDir_"/v2.0.0")
    set v3ModuleDir = $$$NormalizeDir(moduleDir_"/v3.0.0")

    do ..CreateDirectory(v1ModuleDir)
    set moduleFile = $$$NormalizeFilename("module.xml",v1ModuleDir)
    set status = ..CreateModuleFile(moduleFile, "DemoModuleV1")
    do $$$AssertStatusOK(status, "demo-module1 version 1.0.0 Module.xml created")

    do $$$LogMessage("Load demo-module version 1.0.0")
    set status = ..RunCommand("load "_v1ModuleDir)
    do $$$AssertStatusOK(status, "demo-module1 version 1.0.0 laoded successfully")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen("demo-module1")
    set depsCount = moduleObj.Dependencies.Count()
    for i=1:1:depsCount{
        set depsName = moduleObj.Dependencies.GetAt(i)
        do $$$LogMessage("Module "_depsName.Name_" installed successfully")
    }
    if depsCount = 3 {
        do $$$LogMessage("All 3 modules are loaded successfully")
    }

    do $$$LogMessage("Update the demo-module1 to version 2.0.0")
    do ..CreateDirectory(v2ModuleDir)
    set v2moduleFile = $$$NormalizeFilename("module.xml",v2ModuleDir)
    set status = ..CreateModuleFile(v2moduleFile, "DemoModuleV2")
    do $$$AssertStatusOK(status, "demo-module1 version 2.0.0 Module.xml created")
    ;
    do $$$LogMessage("update the demo-module to version 2.0.0 without -keep-orphans flag. So orphaed modules will be removed from the package manager")
    set status = ..RunCommand("update demo-module1 -p "_v2ModuleDir)
    do $$$AssertStatusOK(status, "demo-module1 version 2.0.0 updated successfully")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen("demo-module1")
    set depsCount = moduleObj.Dependencies.Count()

    for i=1:1:depsCount{
        set depsName = moduleObj.Dependencies.GetAt(i)
        do $$$LogMessage("Module "_depsName.Name_" exist")
    }
    if depsCount = 2 {
        do $$$LogMessage("Only 2 modules are exist after update the module")
    }
    do $$$LogMessage("Check the irisjwt module was uninstalled")
    set isExist = ##class(%IPM.Storage.Module).NameExists("irisjwt")
    do $$$AssertTrue('isExist," The orphaed irisjwt module was uninstalled successfully")

    //
    do $$$LogMessage("update the demo-module to version 3.0.0 with -keep-orphans flag. So No orphaed modules removed from the package manager")
    do ..CreateDirectory(v3ModuleDir)
    set v3moduleFile = $$$NormalizeFilename("module.xml",v3ModuleDir)
    set status = ..CreateModuleFile(v3moduleFile, "DemoModuleV3")
    do $$$AssertStatusOK(status, "demo-module1 version 2.0.0 Module.xml created")

    set status = ..RunCommand("update demo-module1 -p "_v3ModuleDir_" -keep-orphans")
    do $$$AssertStatusOK(status, "demo-module1 version updated to 3.0.0 successfully")

    set moduleObj = ##class(%IPM.Storage.Module).NameOpen("demo-module1")
    set depsCount = moduleObj.Dependencies.Count()
    do $$$LogMessage("Dependency module count is "_depsCount)

    for i=1:1:depsCount{
        set depsName = moduleObj.Dependencies.GetAt(i)
        do $$$LogMessage("Module "_depsName.Name_" exist")
    }
    set isExist = ##class(%IPM.Storage.Module).NameExists("LocalizationLab")
    do $$$AssertTrue(isExist," The orphaed LocalizationLab module still exist")
}

Method RunCommand(Command) As %Status
{
    do $$$LogMessage("executing command "_Command)
    set status = ##class(%IPM.Main).Shell(Command)
    return status
}

Method CreateDirectory(Directory)
{
    if '##class(%File).DirectoryExists(Directory) {
        set status = ##class(%File).CreateDirectoryChain(Directory)
        do $$$AssertStatusOK(status," Directory"_Directory_" not exist. So created the directory")
    }
    else {
        do $$$LogMessage("Directory "_Directory_" is already exist")
    }
}

Method CreateModuleFile(
	ModuleFile As %String = "",
	moduleXdata As %String = "")
{
    if ModuleFile=""||(moduleXdata="") {
        quit 0
    }
    if '##class(%File).Exists(ModuleFile) {
        do $$$LogMessage(ModuleFile_" not exist. So creating the xml")
    }
    set fileStream = ##class(%Stream.FileCharacter).%New()
    set fileStream.Filename = ModuleFile
    set v1ModFile = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||"_moduleXdata)
    do fileStream.CopyFrom(v1ModFile.Data)
    set status = fileStream.%Save()
    do $$$AssertStatusOK(status, "Module.xml created on "_ModuleFile)
    return status
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
        <Author>
                <Person>your name</Person>
                <Organization>your organization</Organization>
                <CopyrightDate>2020</CopyrightDate>
                <License>MIT</License>
                <Notes>notes</Notes>
        </Author>
        <Dependencies>
                <ModuleReference>
                        <Name>objectscript-math</Name>
                        <Version>0.0.5</Version>
                </ModuleReference>
                <ModuleReference>
                        <Name>LocalizationLab</Name>
                        <Version>1.0.0</Version>
                </ModuleReference>
                <ModuleReference>
                        <Name>irisjwt</Name>
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
        <Author>
                <Person>your name</Person>
                <Organization>your organization</Organization>
                <CopyrightDate>2020</CopyrightDate>
                <License>MIT</License>
                <Notes>notes</Notes>
        </Author>
        <Dependencies>
                <ModuleReference>
                        <Name>objectscript-math</Name>
                        <Version>0.0.5</Version>
                </ModuleReference>
                <ModuleReference>
                        <Name>LocalizationLab</Name>
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
        <Author>
                <Person>your name</Person>
                <Organization>your organization</Organization>
                <CopyrightDate>2020</CopyrightDate>
                <License>MIT</License>
                <Notes>notes</Notes>
        </Author>
        <Dependencies>
                <ModuleReference>
                        <Name>objectscript-math</Name>
                        <Version>0.0.5</Version>
                </ModuleReference>
        </Dependencies>
        <Packaging>module</Packaging>
        <Default Name="count" Value="7"/>
        <SourcesRoot>src</SourcesRoot>
</Module>
</Document>
</Export>
}

}
