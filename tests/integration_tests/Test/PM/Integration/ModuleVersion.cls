Class Test.PM.Integration.ModuleVersion Extends Test.PM.Integration.Base
{

XData AllCases [ MimeType = application/json ]
{
[
  {
    "args": "major -prerelease alpha",
    "expected": "1.0.0-alpha"
  },
  {
    "args": "minor",
    "expected": "0.1.0"
  },
  {
    "args": "patch",
    "expected": "0.0.3"
  },
  {
    "args": "-prerelease alpha -build mybuild",
    "expected": "0.0.2-alpha+mybuild"
  },
  {
    "args": "3.4.5-abc+xyz",
    "expected": "3.4.5-abc+xyz"
  },
  {
    "args": "invalid string",
    "expected": ""
  },
  {
    "args": "0.0.1",
    "expected": ""
  },
  {
    "args": "0.0.1 -permit-downgrade",
    "expected": "0.0.1"
  },
  {
    "args": "0.0.2",
    "expected": "0.0.2"
  }
]
}

Method TestModuleVersion()
{
    Set xdataID="Test.PM.Integration.ModuleVersion||AllCases"
    Set compiledXdata=##class(%Dictionary.CompiledXData).%OpenId(xdataID)
    Set stream=compiledXdata.Data
    Do $$$AssertTrue($IsObject(stream))

    Set allTestCases = [].%FromJSON(stream)
    Set iter = allTestCases.%GetIterator()
    While iter.%GetNext(.key, .case) {
        Do $$$LogMessage("Running test case: "_case.%ToJSON())

        Set args = case.args
        Set expected = case.expected

        Set modDir = ..GetModuleDir("module-version")
        Set sc = ##class(%IPM.Main).Shell("load " _ modDir)
        Do $$$AssertStatusOK(sc, "Loaded module successfully")

        Set sc = ##class(%IPM.Main).Shell("modver mv " _ args)
        If expected = "" {
            Do $$$AssertStatusNotOK(sc, "Module-version failed as expected")
            Continue
        }
        Do $$$AssertStatusOK(sc, "Module-version executed successfully")

        Kill mod
        Set mod = ##class(%IPM.Storage.Module).NameOpen("mv")
        Do mod.%Reload()
        Do $$$AssertEquals(mod.VersionString, expected)
        Do $$$AssertEquals(mod.Version.ToString(), expected)

        Kill stream
        Set stream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen("mv")
        Do stream.%Reload()
        Set content = stream.Contents.Read()
        Do $$$AssertTrue(content [ "<Version>"_expected_"</Version>")
        Do $$$AssertNotTrue(content [ "<Version>0.0.2-snapshot+build</Version>")
    }
}

}
