Include %IPM.Common

Class Test.PM.Integration.Base Extends %UnitTest.TestCase
{

Parameter REGISTRYNAME = "test_registry";

Parameter CLIENTNS As STRING = "UTCLIENT";

Parameter NEEDSREGISTRY As BOOLEAN = 1;

Property UserCreated As %Boolean [ InitialExpression = 0 ];

Property ClientNSCreated As %Boolean [ InitialExpression = 0 ];

Property RegistryAdded As %Boolean [ InitialExpression = 0 ];

Property PreexistingModules As %Library.ArrayOfDataTypes;

Property OriginalNamespace As %String;

// Multidimensional doesn't work well

Method Setup() As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set tSC = $$$ADDSC(tSC, ..RecordOldModules())
		do $$$AssertStatusOK(##class(%IPM.Repo.Filesystem.Definition).%DeleteExtent())
		do $$$AssertStatusOK(##class(%IPM.Repo.Remote.Definition).%DeleteExtent())
		
		If '$$$AssertStatusOK(##class(%IPM.Test.Utils).CreateNamespace(..#CLIENTNS)) {
			Quit
		}
		Set ..ClientNSCreated = 1
		
		// Client namespace setup
		if ..#NEEDSREGISTRY {
			if ($system.Util.GetEnviron("TEST_REGISTRY")="") {
				Do $$$AssertSkipped("Registry Server not defined")
				Quit
			}
			if ('..RegistryAdded) {
				for namespace = $Namespace,..#CLIENTNS {
					set $Namespace = namespace
					Set tServerDefn = ##class(%IPM.Repo.Remote.Definition).%New()
					Set tServerDefn.Name = ..#REGISTRYNAME
					Set tServerDefn.Enabled = 1
					Set tServerDefn.URL = $system.Util.GetEnviron("TEST_REGISTRY")
					Set tServerDefn.DeploymentEnabled = 1
					Set tServerDefn.Username = $system.Util.GetEnviron("TEST_REGISTRY_USER")
					Set tServerDefn.Password = $system.Util.GetEnviron("TEST_REGISTRY_PASSWORD")
					Set tServerDefn.Prereleases = 1
					Set tServerDefn.Snapshots = 1
					Do $$$AssertStatusOK(tServerDefn.%Save(),"Remote server definition saved.")
			
					Set ..RegistryAdded = 1

					/// Clear any packages on remote registry for debug purposes
					Do tServerDefn.GetPackageService().ResetRegistry()
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method TearDown() As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set tSC = ##class(%IPM.Test.Utils).DeleteNamespace(..#CLIENTNS)
		Do:..ClientNSCreated $$$AssertStatusOK(tSC,"Client namespace deleted.")
		if ..RegistryAdded {
			Do $$$AssertStatusOK(##class(%IPM.Repo.Definition).ServerDefinitionKeyDelete(..#REGISTRYNAME))
		}
		Set tSC = $$$ADDSC(tSC, ..DeleteNewModules())
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method DeleteNewModules() As %Status
{
	Set sc = $$$OK
	Try {
		Do ##class(%IPM.Main).GetListModules(..OriginalNamespace, "", .list)	
		Zwrite "", "DeleteNewModules", $classname(), list
		For i = 1:1:list {
			Set modName = $ListGet(list(i))
			// $$$IPMModuleName should be already in PreexistingModules, but just in case
			If modName = $$$IPMModuleName { 
				Continue
			}
			If ..PreexistingModules.IsDefined(modName) {
				Set sc = $$$ADDSC(sc, ##class(%IPM.Main).Shell("uninstall "_modName))
			}
		}
	} Catch e {
		Set sc = $$$ADDSC(sc, e.AsStatus())
	}
	Return sc
}

/// OnBeforeAllTests is not compatible with $$$AssertSkipped
Method RecordOldModules() As %Status
{
	Try {
		Set ..OriginalNamespace = $Namespace
		Do ##class(%IPM.Main).GetListModules($Namespace, "", .list)
		Zwrite "", "RecordOldModules", $classname(), list
		Do ..PreexistingModules.Clear()
		For i = 1:1:list {
			Set modName = $ListGet(list(i))
			Do ..PreexistingModules.SetAt("", modName)
		}
	} Catch e {
		Return e.AsStatus()
	}
	Return $$$OK
}

ClassMethod ReadXDataToModule(pNamespace As %String = {$NAMESPACE}, pXDataName As %String, ByRef pModule As %IPM.Storage.Module) As %Status
{
	New $Namespace
	Set tInitNS = $Namespace
	Set tStatus = $$$OK
	Try {
		Set $Namespace = pNamespace
		Set tXData = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||"_pXDataName,,.tStatus)
		If $$$ISERR(tStatus) {
			Quit
		}
		
		// Find the module name by inspecting the XML prior to importing it as a document.
		Set tReader = ##class(%XML.Reader).%New()
		Set tSC = tReader.OpenStream(tXData.Data)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Do tReader.Correlate("Module","%IPM.Storage.Module")
		Do tReader.Next(.tModule,.tSC)
		Set tName = tModule.Name_".ZPM"
		Do tXData.Data.Rewind()
		
		Set $Namespace = tInitNS
			
		Set tStatus = ##class(%IPM.StudioDocument.Module).ImportStream(.tName,tXData.Data)
		If $$$ISERR(tStatus) {
			Quit
		}
		
		Set pModule = ##class(%IPM.Storage.Module).NameOpen($Piece(tName,".",1,*-1),,.tStatus)
		If $$$ISERR(tStatus) {
			Quit
		}
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

ClassMethod GetModuleDir(subfolders... As %String) As %String
{
  Set tTestRoot = ##class(%File).NormalizeDirectory($GET(^UnitTestRoot))
  Set tTestRoot = ##class(%File).GetDirectory(tTestRoot)
  Set tModuleDir = ##class(%File).Construct(tTestRoot, "_data", subfolders...)
  Set tModuleDir = ##class(%File).NormalizeDirectory(tModuleDir)
  Quit tModuleDir
}

ClassMethod HttpGet(pPath As %String = "/") As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"

	Set tSC = ##class(Config.Startup).Get(.props)
	If $$$ISERR(tSC) {
		Quit tSC
	}

	Set request = ##class(%Net.HttpRequest).%New()
	Set request.Server = "127.0.0.1"
	Set request.Port = props("WebServerPort")
	Set path = props("WebServerURLPrefix") _ "/" _ pPath
	Set tSC = request.Get(path)
	If $$$ISERR(tSC) {
		Quit tSC
	}
	If (request.HttpResponse.StatusCode '= 200) {
		Quit $$$ERROR($$$GeneralError, "HTTP Status: "_request.HttpResponse.StatusCode_$char(13,10)_request.HttpResponse.Data.Read())
	}
	Quit $$$OK
}

}
