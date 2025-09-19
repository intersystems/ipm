Class Test.PM.Integration.ModuleVersion Extends Test.PM.Integration.Base
{

Parameter OriginalVersion = "0.0.2-snapshot+build";

XData AllCases [ MimeType = application/json ]
{
[
  {
    "args": "major -prerelease alpha -force",
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
    "args": "-prerelease alpha -build mybuild -force",
    "expected": "0.0.2-alpha+mybuild"
  },
  {
    "args": "3.4.5-abc+xyz",
    "expected": ""
  },
  {
    "args": "3.4.5-abc+xyz -force",
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
    "args": "0.0.1 -force",
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
    set xdataID="Test.PM.Integration.ModuleVersion||AllCases"
    set compiledXdata=##class(%Dictionary.CompiledXData).%OpenId(xdataID,0)
    set stream=compiledXdata.Data
    do $$$AssertTrue($isobject(stream))

    set allTestCases = [].%FromJSON(stream)
    set iter = allTestCases.%GetIterator()
    while iter.%GetNext(.key, .case) {
        do $$$LogMessage("Running test case: "_case.%ToJSON())

        set args = case.args
        set expected = case.expected

        set modDir = ..GetModuleDir("module-version")
        set sc = ##class(%IPM.Main).Shell("load " _ modDir)
        do $$$AssertStatusOK(sc, "Loaded module successfully")

        set sc = ##class(%IPM.Main).Shell("modver mv " _ args)
        if expected = "" {
            do $$$AssertStatusNotOK(sc, "Module-version failed as expected")
            continue
        }
        do $$$AssertStatusOK(sc, "Module-version executed successfully")

        kill mod
        set mod = ##class(%IPM.Storage.Module).NameOpen("mv")
        do mod.%Reload()
        do $$$AssertEquals(mod.VersionString, expected)
        do $$$AssertEquals(mod.Version.ToString(), expected)

        kill stream
        set stream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen("mv")
        do stream.%Reload()
        set content = stream.Contents.Read()
        do $$$AssertTrue(content [ ("<Version>"_expected_"</Version>"))
        do $$$AssertNotTrue(content [ ("<Version>"_..#OriginalVersion_"</Version>"))
    }
}

}
