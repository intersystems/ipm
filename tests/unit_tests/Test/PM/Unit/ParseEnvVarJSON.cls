Class Test.PM.Unit.ParseEnvVarJSON Extends %UnitTest.TestCase
{

Parameter ENVNAME = "mySecretEnvVarName";

Parameter ENVVALUE = "This is a secret value";

XData SampleJSON [ MimeType = application/json ]
{
{
    "package": {
        "nested": {
            "key": "${mySecretEnvVarName}"
        },
        "other": [ 1, 2, 3 ]
    }
}
}

/// Run by <B>RunTest</B> immediately before each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required. 
/// </dl> 
Method OnBeforeOneTest(testname As %String) As %Status
{
    Try {
        Do ..SetEnvironmentVariable()
    } Catch ex {
        Return ex.AsStatus()
    }
    Quit $$$OK
}

/// Run by <B>RunTest</B> immediately after each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required. 
/// </dl> 
Method OnAfterOneTest(testname As %String) As %Status
{
    Try {
        Do ..UnsetEnvironmentVariable()
    } Catch ex {
        Return ex.AsStatus()
    }
    Quit $$$OK
}

ClassMethod SetEnvironmentVariable()
{
    // For lack of a better way, we'll set the environment variables using Embedded Python. 
    // Will update once we have a pure COS way to do this.
    Set os = ##class(%SYS.Python).Import("os")
    // Note: the putenv only affects environment variables for the current process without any mapping to the actual environment variables.
    Do os.putenv(..#ENVNAME, ..#ENVVALUE)
}

ClassMethod UnsetEnvironmentVariable()
{
    Set os = ##class(%SYS.Python).Import("os")
    Do os.environ.pop(..#ENVNAME, "")
}

Method TestParseEnvVarJSON()
{
    Do ..SetEnvironmentVariable()

    Set xdataID=$classname()_"||SampleJSON"
    Set compiledXdata=##class(%Dictionary.CompiledXData).%OpenId(xdataID)
    Set stream=compiledXdata.Data
    Do $$$AssertTrue($IsObject(stream))

    Set sampleJSON = {}.%FromJSON(stream)

    Set output = ##class(%IPM.General.EnvironmentConfig).%Evaluate(sampleJSON).%ToJSON()
    Set expected = $Replace(sampleJSON.%ToJSON(), "${"_..#ENVNAME_"}", ..#ENVVALUE)
    Do $$$AssertEquals(output, expected)

    Set output = ##class(%IPM.General.EnvironmentConfig).%Evaluate("${"_..#ENVNAME_"}")
    Set expected = ..#ENVVALUE
    Do $$$AssertEquals(output, expected)

    Do ..UnsetEnvironmentVariable()
}

}
