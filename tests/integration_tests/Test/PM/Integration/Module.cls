Class Test.PM.Integration.Module Extends Test.PM.Integration.Base
{

Parameter CommonPathPrefix As STRING = "varresolver";

Parameter ModuleName As STRING = "demo-module1";

Parameter ClsDefName As STRING = "Test.TrackPlaceHolders";

/// This test validates that the IPM engine can handle "chained" ${variables}
/// (placeholders that resolve to other placeholders).
/// 1. Generates a 'module.xml' from XData with deep variable dependencies.
/// 2. Executes IPM Shell 'load' to verify multi-pass expansion.
/// 3. Ensures no unresolved placeholders remain after the load process.
Method TestNestedPlaceholderVar()
{
    do $$$LogMessage("Create '"_..#ClsDefName_"' class definition and method 'CaptureResolvedPlaceHolders' to capturing the placeholder variables")
    set status = ..CreateClassdef()
    do $$$AssertStatusOK(status,"Class definition created successfully")

    do $$$LogMessage(" start Loading the "_..#ModuleName_" module")
    set status = ..CreateModuleXml(.moduleDir)
    do $$$AssertStatusOK(status,"Created the xml file on "_moduleDir)

    set status = ##class(%IPM.Main).Shell("load "_moduleDir)
    do $$$AssertStatusOK(status,"Loaded "_..#CommonPathPrefix_" module successfully from "_moduleDir)

    do $$$LogMessage("Validate the place holder variable resolved values in ^IRIS.Temp.IPMVarTest global")
    set data = $get(^IRIS.Temp.IPMVarTest("frankenstein"))
    if data'="" {
        do $$$AssertTrue(1,"frankenstein place holder value is resolved to "_data)
    }
    do $$$LogMessage("Verifying other parameter values")
    do $$$LogMessage(" ^IRIS.Temp.IPMVarTest set on Namespace: "_$namespace)
    set sub=""
    for {
        set sub = $order(^IRIS.Temp.IPMVarTest(sub),1,data)
        quit:sub=""
        do $$$LogMessage("^IRIS.Temp.IPMVarTest("_sub_") and value : "_data)
    }
    set module = ##class(%IPM.Storage.Module).NameOpen(..#ModuleName)
    do $$$AssertTrue($isobject(module), "Module "_..#ModuleName_" exists in IPM and version is "_ module.Version.ToString())

    do $$$LogMessage("List all modules")
    set status = ##class(%IPM.Main).Shell("list")

    set status = ##class(%IPM.Main).Shell("uninstall "_..#ModuleName)
    do $$$AssertStatusOK(status,"uninstalled module "_..#ModuleName_" successfully.")

    set status = ##class(%File).Delete(##class(%File).NormalizeFilename("module.xml",moduleDir))
    do $$$AssertStatusOK(status,"Deleted the module.xml file from "_moduleDir)

    do $$$LogMessage("Deleting the "_..#ClsDefName_" generated test class")
    set status = ##class(%Dictionary.ClassDefinition).%DeleteId(..#ClsDefName)
    do $$$AssertStatusOK(status,"class "_..#ClsDefName_" is deleted successfully")

    do $$$LogMessage("Deleting the ^IRIS.Temp.IPMVarTest global")
    kill ^IRIS.Temp.IPMVarTest
}

/// Create class definition at runtime to capute the resovled reference value through <invoke> in manifest
ClassMethod CreateClassdef() As %Status
{
    set cls = ##class(%Dictionary.ClassDefinition).%New()
    set cls.Name = ..#ClsDefName
    // create sample method
    set method = ##class(%Dictionary.MethodDefinition).%New()
    set method.Name = "CaptureResolvedPlaceHolders"
    set method.ClassMethod = 1
    set method.FormalSpec = "frankenstein,args..."
    do method.Implementation.WriteLine($char(9)_"set ^IRIS.Temp.IPMVarTest(""frankenstein"")= frankenstein")
    do method.Implementation.WriteLine($char(9)_"merge ^IRIS.Temp.IPMVarTest = args")
    do cls.Methods.Insert(method)
    set sc = cls.%Save()
    do $system.OBJ.Compile(..#ClsDefName)
    return sc
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

            <Default Name="start" Value="${" />
            <Default Name="middle" Value="namespace" />
            <Default Name="end" Value="}" />
            <Default Name="frankenstein" Value="${start}${middle}${end}"/>
			<SystemRequirements Version=">=2020.1" Interoperability="enabled"/>
			<SourcesRoot>src</SourcesRoot>
            <Invoke Class="Test.TrackPlaceHolders" Method="CaptureResolvedPlaceHolders">
                <Arg>${frankenstein}</Arg>
                <Arg>${dataversion} </Arg>
				<Arg>"12121212" </Arg>
				<Arg>"12121212ASHOK"</Arg>
                <Arg>${datadefaultcspdir}</Arg>
                <Arg>${dataDefaultTest2}</Arg>
                <Arg>${dataDefaultTest3} </Arg>
                <Arg>${mTestVersion}</Arg>
                <Arg>${ipmtest}</Arg>
                <Arg>${datapath1}</Arg>
                <Arg>${ipmdir} </Arg>
                <Arg>${datadefaultmgrdir}</Arg>
            </Invoke>
			<AfterInstallMessage>Module installed successfully!</AfterInstallMessage>
		</Module>
	</Document>
</Export>
}

}
