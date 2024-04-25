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

Method TestZPM()
{
    Do $$$AssertTrue(##class(%IPM.Storage.Module).NameExists("zpm"))
    Do $$$AssertTrue(##class(%IPM.StudioDocument.Module).Exists("zpm.ZPM"))
}

}
