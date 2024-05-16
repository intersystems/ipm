Class Test.PM.Migration.ModuleStorage Extends %UnitTest.TestCase
{

Method TestSSLClient()
{
    Do $$$AssertTrue(##class(%IPM.StudioDocument.Module).Exists("sslclient.ZPM"))
    If $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("sslclient")) {
        Set module = ##class(%IPM.Storage.Module).NameOpen("sslclient",,.sc)
        $$$ThrowOnError(sc)
        Do $$$AssertEquals(module.Resources.Count(),1)
        Do $$$AssertEquals(module.Invokes.Count(),1)
        Do $$$AssertEquals(module.Defaults.Count(),1)
    }
}

Method TestDSW()
{
    Do $$$AssertTrue(##class(%IPM.StudioDocument.Module).Exists("dsw.ZPM"))
    Do $$$AssertTrue(##class(%IPM.StudioDocument.Module).Exists("dsw.ZPM"))
    If $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("dsw")) {
        Set module = ##class(%IPM.Storage.Module).NameOpen("dsw",,.sc)
        $$$ThrowOnError(sc)
        Do $$$AssertEquals(module.Dependencies.Count(),1)
        Do $$$AssertEquals(module.Dependencies.GetAt(1).Name,"mdx2json")
    }
}

Method TestZPM()
{
    Do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("zpm"))
    Do $$$AssertTrue(##class(%IPM.StudioDocument.Module).Exists("zpm.ZPM"))
}

Method TestRepos()
{
    Set repo = ##class(%IPM.Repo.Remote.Definition).ServerDefinitionKeyOpen("registry")
    If $$$AssertTrue($IsObject(repo)) {
        Do $$$AssertEquals(repo.Enabled,1)
        Do $$$AssertEquals(repo.URL,"http://registry:52773/registry/")
        Do $$$AssertEquals(repo.Username,"admin")
        Do $$$AssertEquals(repo.Password,"SYS")
    }
}

}
