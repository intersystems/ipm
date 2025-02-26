Class Test.PM.Unit.ParseEnvVarJSON Extends %UnitTest.TestCase
{

Parameter ENVNAME1 = "mySecretEnvVarName1";

Parameter ENVNAME2 = "mySecretEnvVarName2";

Parameter ENVNAME3 = "mySecretEnvVarName3";

Parameter ENVNAME4 = "mySecretEnvVarName4";

Parameter ENVVALUE1 = "This is a secret value 1 with "" ";

Parameter ENVVALUE2 = "This is a secret value 2 with "" ";

Parameter ENVVALUE3 = "This is a secret value 3 with "" ";

Parameter ENVVALUE4 = "This is a secret value 4 with "" ";

XData SampleJSON [ MimeType = application/json ]
{
{
    "package": {
        "nested": {
            "key": "${mySecretEnvVarName1}"
        },
        "other": [ 1, 2, 3 ]
    },
    "toplevel": "${mySecretEnvVarName2}",
    "arrayConcatenated": ["${mySecretEnvVarName3}${mySecretEnvVarName4}"]
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
    Do os.putenv(..#ENVNAME1, ..#ENVVALUE1)
    Do os.putenv(..#ENVNAME2, ..#ENVVALUE2)
    Do os.putenv(..#ENVNAME3, ..#ENVVALUE3)
    Do os.putenv(..#ENVNAME4, ..#ENVVALUE4)
}

ClassMethod UnsetEnvironmentVariable()
{
    Set os = ##class(%SYS.Python).Import("os")
    Do os.environ.pop(..#ENVNAME1, "")
    Do os.environ.pop(..#ENVNAME2, "")
    Do os.environ.pop(..#ENVNAME3, "")
    Do os.environ.pop(..#ENVNAME4, "")
}

Method TestParseEnvVarJSON()
{
    Do ..SetEnvironmentVariable()

    Set xdataID=$CLASSNAME()_"||SampleJSON"
    Set compiledXdata=##class(%Dictionary.CompiledXData).%OpenId(xdataID)
    Set stream=compiledXdata.Data
    Do $$$AssertTrue($ISOBJECT(stream))
    Set sampleJSON = {}.%FromJSON(stream)

    Set parsedJSON = ##class(%IPM.General.EnvironmentConfig).%Evaluate(sampleJSON)
    Do $$$AssertEquals(parsedJSON.package.nested.key, ..#ENVVALUE1)
    Do $$$AssertEquals(parsedJSON.toplevel, ..#ENVVALUE2)
    Do $$$AssertEquals(parsedJSON.arrayConcatenated."0", ..#ENVVALUE3_..#ENVVALUE4)

    Do ..UnsetEnvironmentVariable()
}

}
