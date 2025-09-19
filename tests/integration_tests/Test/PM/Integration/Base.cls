Class Test.PM.Integration.Base Extends %UnitTest.TestCase
{

Parameter REGISTRYNAME = "test_registry";

Parameter CLIENTNS As STRING = "UTCLIENT";

Parameter NEEDSREGISTRY As BOOLEAN = 1;

Property UserCreated As %Boolean [ InitialExpression = 0 ];

Property ClientNSCreated As %Boolean [ InitialExpression = 0 ];

Property RegistryAdded As %Boolean [ InitialExpression = 0 ];

Method Setup() As %Status
{
	set tSC = $$$OK
	try {
		new $namespace
		do $$$AssertStatusOK(##class(%IPM.Repo.Filesystem.Definition).%DeleteExtent())
		do $$$AssertStatusOK(##class(%IPM.Repo.Remote.Definition).%DeleteExtent())

		if '$$$AssertStatusOK(##class(%IPM.Test.Utils).CreateNamespace(..#CLIENTNS)) {
			quit
		}
		set ..ClientNSCreated = 1

		// Client namespace setup
		if ..#NEEDSREGISTRY {
			if ($system.Util.GetEnviron("TEST_REGISTRY")="") {
				do $$$AssertSkipped("Registry Server not defined")
				quit
			}
			if ('..RegistryAdded) {
				for namespace = $namespace,..#CLIENTNS {
					set $namespace = namespace
					set tServerDefn = ##class(%IPM.Repo.Remote.Definition).%New()
					set tServerDefn.Name = ..#REGISTRYNAME
					set tServerDefn.Enabled = 1
					set tServerDefn.URL = $system.Util.GetEnviron("TEST_REGISTRY")
					set tServerDefn.DeploymentEnabled = 1
					set tServerDefn.Username = $system.Util.GetEnviron("TEST_REGISTRY_USER")
					set tServerDefn.Password = $system.Util.GetEnviron("TEST_REGISTRY_PASSWORD")
					set tServerDefn.Prereleases = 1
					set tServerDefn.Snapshots = 1
					do $$$AssertStatusOK(tServerDefn.%Save(),"Remote server definition saved.")

					set ..RegistryAdded = 1

					/// Clear any packages on remote registry for debug purposes
					do tServerDefn.GetPackageService().ResetRegistry()
				}
			}
		}
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

Method TearDown() As %Status
{
	set tSC = $$$OK
	try {
		new $namespace
		set tSC = ##class(%IPM.Test.Utils).DeleteNamespace(..#CLIENTNS)
		do:..ClientNSCreated $$$AssertStatusOK(tSC,"Client namespace deleted.")
		if ..RegistryAdded {
			do $$$AssertStatusOK(##class(%IPM.Repo.Definition).ServerDefinitionKeyDelete(..#REGISTRYNAME))
		}
	} catch e {
		set tSC = e.AsStatus()
	}
	quit tSC
}

ClassMethod ReadXDataToModule(
	pNamespace As %String = {$namespace},
	pXDataName As %String,
	ByRef pModule As %IPM.Storage.Module) As %Status
{
	new $namespace
	set tInitNS = $namespace
	set tStatus = $$$OK
	try {
		set $namespace = pNamespace
		set tXData = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||"_pXDataName,0,.tStatus)
		if $$$ISERR(tStatus) {
			quit
		}

		// Find the module name by inspecting the XML prior to importing it as a document.
		set tReader = ##class(%XML.Reader).%New()
		set tSC = tReader.OpenStream(tXData.Data)
		if $$$ISERR(tSC) {
			quit
		}

		do tReader.Correlate("Module","%IPM.Storage.Module")
		do tReader.Next(.tModule,.tSC)
		set tName = tModule.Name_".ZPM"
		do tXData.Data.Rewind()

		set $namespace = tInitNS

		set tStatus = ##class(%IPM.StudioDocument.Module).ImportStream(.tName,tXData.Data)
		if $$$ISERR(tStatus) {
			quit
		}

		set pModule = ##class(%IPM.Storage.Module).NameOpen($piece(tName,".",1,*-1),,.tStatus)
		if $$$ISERR(tStatus) {
			quit
		}
	} catch e {
		set tStatus = e.AsStatus()
	}
	quit tStatus
}

ClassMethod GetModuleDir(subfolders... As %String) As %String
{
  set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
  set tTestRoot = ##class(%File).GetDirectory(tTestRoot)
  set tModuleDir = ##class(%File).Construct(tTestRoot, "_data", subfolders...)
  set tModuleDir = ##class(%File).NormalizeDirectory(tModuleDir)
  quit tModuleDir
}

/// Returns whether a substring is found in any element of a multi-dimensional array
ClassMethod FindStringInMultiDimArray(
	pString As %String,
	ByRef pArray) As %Boolean
{
	set sub = ""
	for {
		set sub = $order(pArray(sub), 1, element)
		if sub = "" {
			quit
		}
		if element [ pString {
			return 1
		}
	}
	return 0
}

ClassMethod HttpGet(pPath As %String = "/") As %Status
{
	new $namespace
	set $namespace = "%SYS"

	set tSC = ##class(Config.Startup).Get(.props)
	if $$$ISERR(tSC) {
		quit tSC
	}

	set request = ##class(%Net.HttpRequest).%New()
	set request.Server = "127.0.0.1"
	set request.Port = props("WebServerPort")
	set path = props("WebServerURLPrefix") _ "/" _ pPath
	set tSC = request.Get(path)
	if $$$ISERR(tSC) {
		quit tSC
	}
	if (request.HttpResponse.StatusCode '= 200) {
		quit $$$ERROR($$$GeneralError, "HTTP Status: "_request.HttpResponse.StatusCode_$char(13,10)_request.HttpResponse.Data.Read())
	}
	quit $$$OK
}

}
