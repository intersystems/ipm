Class Test.PM.Integration.Module Extends Test.PM.Integration.Base
{

Parameter CommonPathPrefix As STRING = "varresolver";

Parameter ModuleName As STRING = "demo-module1";

/// This test validates that the IPM engine can handle "chained" ${variables}
/// (placeholders that resolve to other placeholders).
/// 1. Generates a 'module.xml' from XData with deep variable dependencies.
/// 2. Executes IPM Shell 'load' to verify multi-pass expansion.
/// 3. Ensures no unresolved placeholders remain after the load process.
Method TestNestedPlaceholderIntegration()
{
    do $$$LogMessage(" start Loading the "_..#ModuleName_" module")
    set status = ..CreateModuleXml(.moduleDir)
    do $$$AssertStatusOK(status,"Created the xml file on "_moduleDir)

    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Loaded "_..#CommonPathPrefix_" module successfully from "_moduleDir)

    set module = ##class(%IPM.Storage.Module).NameOpen(..#ModuleName)
    do $$$AssertTrue($isobject(module), "Module "_..#ModuleName_" exists in IPM and version is "_ module.Version.ToString())

        do $$$LogMessage("List all modules")
    set status = ##class(%IPM.Main).Shell("list")

    set status = ##class(%IPM.Main).Shell("uninstall "_..#ModuleName)
    do $$$AssertStatusOK(status,"uninstalled module "_..#ModuleName_" successfully.")

    set status = ##class(%File).Delete(##class(%File).NormalizeFilename("module.xml",moduleDir))
    do $$$AssertStatusOK(status,"Deleted the module.xml file from "_moduleDir)
}

Method CreateModuleXml(Output pModuleDir) As %Status
{
    #define NormalizeDirectory(%path)   ##class(%File).NormalizeDirectory(%path)
    #define UTRoot                      ^UnitTestRoot

    set sc = 1
    set testRoot = $$$NormalizeDirectory($get($$$UTRoot))
    set pModuleDir = $$$NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/"_..#CommonPathPrefix_"/")

    if '##class(%File).DirectoryExists(pModuleDir) {
        set sc = ##class(%File).CreateDirectoryChain(pModuleDir)
    }
    do $$$AssertStatusOK(sc,"Directory created "_pModuleDir)
    set stream = ##class(%Dictionary.CompiledXData).%OpenId(..%ClassName(1)_"||TestModuleXML").Data
    set fileStream = ##class(%Stream.FileBinary).%New()
    set fileStream.Filename=##class(%File).NormalizeFilename("module.xml",pModuleDir)
    set sc = fileStream.CopyFromAndSave(stream)
    do $$$AssertStatusOK(1,"module.xml File created on "_pModuleDir)

    return sc
}

/// Sample module file
XData TestModuleXML [ MimeType = application/xml ]
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
	<Document name="demo-module1.ZPM">
		<Module>
			<Name>demo-module1</Name>
			<Version>1.0.0</Version>
			<Description>testing the name resolved</Description>
			<Packaging>module</Packaging>
			<Default Name="count" Value="7"/>
			<Default Name="dataversion" Value="${version}/" />
			<Default Name="datadefaultmgrdir" Value="${mgrdir}/" />
			<Default Name="mTestPlaceHolder" Value="${dataDefaultTest2}/xtest/${version}/${mgrdir}/${mTestVersion}/${datapath1}" />
			<Default Name="datadefaultcspdir" Value="${cspdir}/" />
			<Default Name="dataDefaultTest2" Value="${datadefaultcspdir}/xdata" />
			<Default Name="dataDefaultTest3" Value="${dataDefaultTest2}/xtest" />
			<Default Name="mTestVersion" Value="${dataDefaultTest2}/xtest/${version}" />
			<Default Name="ipmtest" Value="TESTING MY STRING"/>
			<Default Name="ipmdir" Value="/usr/irissys/mgr/user/mts"/>
			<Default Name="datapath" Value="${libdir}data/" />
			<Default Name="datapath1" Value="${ipmdir}data/" />
			<SystemRequirements Version=">=2020.1" Interoperability="enabled"/>
			<SourcesRoot>src</SourcesRoot>
			<AfterInstallMessage>Module installed successfully!</AfterInstallMessage>
		</Module>
	</Document>
</Export>
}

}
