Include %IPM.Common

Class Test.PM.Integration.Base Extends (%UnitTest.TestCase, Test.PM.General.Utils)
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

}
