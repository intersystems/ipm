Include %IPM.Common

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

/// Imports the module manifest in the named XData block of this class and opens the resulting module.
/// @Argument namespace	    Namespace containing the XData block.
/// @Argument xDataName	    Name of the XData block holding the module manifest.
/// @Argument module	    The imported module.
ClassMethod ReadXDataToModule(
	namespace As %String = {$namespace},
	xDataName As %String,
	ByRef module As %IPM.Storage.Module) As %Status
{
	new $namespace
	set initialNamespace = $namespace
	set status = $$$OK
	try {
		set $namespace = namespace
		set xData = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||"_xDataName,,.status)
		if $$$ISERR(status) {
			quit
		}

		// Find the module name by inspecting the XML prior to importing it as a document.
		set reader = ##class(%XML.Reader).%New()
		set sc = reader.OpenStream(xData.Data)
		if $$$ISERR(sc) {
			quit
		}

		do reader.Correlate("Module","%IPM.Storage.Module")
		do reader.Next(.parsedModule,.sc)
		set documentName = parsedModule.Name_".ZPM"
		do xData.Data.Rewind()

		set $namespace = initialNamespace

		set status = ##class(%IPM.StudioDocument.Module).ImportStream(.documentName,xData.Data)
		if $$$ISERR(status) {
			quit
		}

		set module = ##class(%IPM.Storage.Module).NameOpen($piece(documentName,".",1,*-1),,.status)
		if $$$ISERR(status) {
			quit
		}
	} catch ex {
		set status = ex.AsStatus()
	}
	quit status
}

/// Returns the normalized path to a test data directory under `_data`.
/// @Argument subfolders	Subdirectory names to append under `_data`.
ClassMethod GetModuleDir(subfolders... As %String) As %String
{
  set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
  set testRoot = ##class(%File).GetDirectory(testRoot)
  set moduleDir = ##class(%File).Construct(testRoot, "_data", subfolders...)
  set moduleDir = ##class(%File).NormalizeDirectory(moduleDir)
  quit moduleDir
}

/// Returns whether a substring is found in any element of a multi-dimensional array.
/// @Argument string	Substring to search for.
/// @Argument array	    Multidimensional array whose top-level elements are searched.
ClassMethod FindStringInMultiDimArray(
	string As %String,
	ByRef array) As %Boolean
{
	set subscript = ""
	for {
		set subscript = $order(array(subscript), 1, element)
		if subscript = "" {
			quit
		}
		if element [ string {
			return 1
		}
	}
	return 0
}

/// Returns whether any configured repository has the named module.
/// @Argument moduleName	Name of the module to look up.
ClassMethod ModuleAvailableInRepositories(moduleName As %String) As %Boolean
{
	set criteria = ##class(%IPM.Repo.SearchCriteria).%New()
	set criteria.Name = $$$lcase(moduleName)
	set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(criteria, .results)
	if $$$ISERR(sc) || '$isobject(results) {
		return 0
	}
	return results.Count() > 0
}

/// Returns whether <var>string</var> appears on any line of the file at <var>filePath</var>.
/// @Argument filePath	Path of the file to read.
/// @Argument string	Substring to search for.
ClassMethod FileContains(
	filePath As %String,
	string As %String) As %Boolean
{
	set stream = ##class(%Stream.FileCharacter).%New()
	set stream.Filename = filePath
	while 'stream.AtEnd {
		if (stream.ReadLine() [ string) {
			return 1
		}
	}
	return 0
}

/// Returns the first line of the file at <var>filePath</var> containing <var>string</var>, or "" if none does.
/// @Argument filePath	Path of the file to read.
/// @Argument string	Substring used to find the line.
ClassMethod GetLineInFile(
	filePath As %String,
	string As %String) As %String
{
	set stream = ##class(%Stream.FileCharacter).%New()
	set stream.Filename = filePath
	while 'stream.AtEnd {
		set line = stream.ReadLine()
		if (line [ string) {
			return line
		}
	}
	return ""
}

/// Sends a GET request to the local web server and returns an error unless the response is HTTP 200.
/// @Argument path	GET endpoint path (relative to the web server URL prefix).
ClassMethod HttpGet(path As %String = "/") As %Status
{
	new $namespace
	set $namespace = "%SYS"

	set sc = ##class(Config.Startup).Get(.props)
	if $$$ISERR(sc) {
		quit sc
	}

	set request = ##class(%Net.HttpRequest).%New()
	set request.Server = "127.0.0.1"
	set request.Port = props("WebServerPort")
	set fullPath = props("WebServerURLPrefix") _ "/" _ path
	set sc = request.Get(fullPath)
	if $$$ISERR(sc) {
		quit sc
	}
	if (request.HttpResponse.StatusCode '= 200) {
		quit $$$ERROR($$$GeneralError, "HTTP Status: "_request.HttpResponse.StatusCode_$char(13,10)_request.HttpResponse.Data.Read())
	}
	quit $$$OK
}


}
