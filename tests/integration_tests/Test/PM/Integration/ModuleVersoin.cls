Class Test.PM.Integration.ModuleVersoin Extends Test.PM.Integration.Base
{

Method TestModuleVersion()
{
    // TODO parameterize the test

    Set modDir = ..GetModuleDir("module-version")
    Set sc = ##class(%IPM.Main).Shell("load " _ modDir)
    Do $$$AssertStatusOK(sc, "Loaded module successfully")

    Set sc = ##class(%IPM.Main).Shell("modver mv major -prerelease alpha")
    Do $$$AssertStatusOK(sc, "Module version executed successfully")

    Set mod = ##class(%IPM.Storage.Module).NameOpen("mv")
    Do mod.%Reload()
    Do $$$AssertEquals(mod.VersionString, "1.0.0-alpha")
    Do $$$AssertEquals(mod.Version.ToString(), "1.0.0-alpha")

    Set stream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen("mv")
    Set content = stream.Contents.Read()
    Do $$$AssertTrue(content [ "<Version>1.0.0-alpha</Version>")
    Do $$$AssertNotTrue(content [ "<Version>0.0.1-snapshot+build</Version>")
}

}
