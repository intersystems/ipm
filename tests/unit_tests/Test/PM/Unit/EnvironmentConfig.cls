Class Test.PM.Unit.EnvironmentConfig Extends %UnitTest.TestCase
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

XData AllCases [ MimeType = application/json ]
{
[
    {
        "dest": { "a": 1, "b": 2 },
        "src": { "b": 3, "c": 4 },
        "expected": { "a": 1, "b": 3, "c": 4 }
    },
    {
        "dest": { "x": 10 },
        "src": { "y": 20 },
        "expected": { "x": 10, "y": 20 }
    },
    {
        "dest": {},
        "src": { "key": "value" },
        "expected": { "key": "value" }
    },
    {
        "dest": { "nested": { "a": 1 } },
        "src": { "nested": { "b": 2 } },
        "expected": { "nested": { "a":1, "b": 2 } }
    },
    {
        "dest": { "a": 1, "b": { "c": 3 } },
        "src": { "b": { "d": 4 }, "e": 5 },
        "expected": { "a": 1, "b": { "c":3, "d": 4 }, "e": 5 }
    },
    {
        "dest": { "a": null },
        "src": { "a": 1 },
        "expected": { "a": 1 }
    },
    {
        "dest": { "arr": [ 1, 2, 3 ] },
        "src": { "arr": [ 4, 5 ] },
        "expected": { "arr": [ 4, 5, 3 ] }
    },
    {
        "dest": { "a": [ 1, 2 ] },
        "src": { "b": [ 3, 4 ] },
        "expected": { "a": [ 1, 2 ], "b": [ 3, 4 ] }
    },
    {
        "dest": { "a": [ 1, 2 ], "b": { "c": [ 3, 4 ] } },
        "src": { "b": { "c": [ 5, 6 ] }, "d": [ 7, 8 ] },
        "expected": { "a": [ 1, 2 ], "b": { "c": [ 5, 6 ] }, "d": [ 7, 8 ] }
    },
    {
        "dest": { "a": [ 1, 2 ], "b": [ 3, 4 ] },
        "src": { "a": [ 5, 6 ] },
        "expected": { "a": [ 5, 6 ], "b": [ 3, 4 ] }
    },
    {
        "dest": { "list": [] },
        "src": { "list": [ 1, 2, 3 ] },
        "expected": { "list": [ 1, 2, 3 ] }
    },
    {
        "dest": { "x": [ null, 2 ] },
        "src": { "x": [ 1, null ] },
        "expected": { "x": [ 1, null ] }
    }
]
}

/// Run by <B>RunTest</B> immediately before each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required.
/// </dl>
Method OnBeforeOneTest(testname As %String) As %Status
{
    try {
        do ..SetEnvironmentVariable()
    } catch ex {
            return ex.AsStatus()
    }
    quit $$$OK
}

/// Run by <B>RunTest</B> immediately after each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required.
/// </dl>
Method OnAfterOneTest(testname As %String) As %Status
{
    try {
            do ..UnsetEnvironmentVariable()
    } catch ex {
            return ex.AsStatus()
    }
    quit $$$OK
}

ClassMethod SetEnvironmentVariable()
{
    set os = ##class(%SYS.Python).Import("os")
    do os.putenv(..#ENVNAME1, ..#ENVVALUE1)
    do os.putenv(..#ENVNAME2, ..#ENVVALUE2)
    do os.putenv(..#ENVNAME3, ..#ENVVALUE3)
    do os.putenv(..#ENVNAME4, ..#ENVVALUE4)
}

ClassMethod UnsetEnvironmentVariable()
{
    set os = ##class(%SYS.Python).Import("os")
    do os.environ.pop(..#ENVNAME1, "")
    do os.environ.pop(..#ENVNAME2, "")
    do os.environ.pop(..#ENVNAME3, "")
    do os.environ.pop(..#ENVNAME4, "")
}

Method TestMissingFileReportsPath()
{
    set path = "/tmp/ipm-missing-env-"_$system.Util.CreateGUID()_".json"
    set config = ##class(%IPM.General.EnvironmentConfig).%Get(.sc)
    $$$ThrowOnError(sc)

    try {
        do config.Load(path)
        do $$$AssertFailure("Loading a missing environment configuration file should throw an error.")
    } catch ex {
        set errorText = $system.Status.GetErrorText(ex.AsStatus())
        do $$$AssertTrue(errorText [ path, "The missing environment configuration error should include the supplied path: "_errorText)
        do $$$AssertTrue(errorText [ "does not exist", "The error should explain that the environment configuration file does not exist: "_errorText)
    }
}

Method TestParseEnvVarJSON()
{
    set xdataID=$classname()_"||SampleJSON"
    set compiledXdata=##class(%Dictionary.CompiledXData).%OpenId(xdataID)
    set stream=compiledXdata.Data
    do $$$AssertTrue($isobject(stream))
    set sampleJSON = {}.%FromJSON(stream)

    set parsedJSON = ##class(%IPM.General.EnvironmentConfig).%Evaluate(sampleJSON)
    do $$$AssertEquals(parsedJSON.package.nested.key, ..#ENVVALUE1)
    do $$$AssertEquals(parsedJSON.toplevel, ..#ENVVALUE2)
    do $$$AssertEquals(parsedJSON.arrayConcatenated."0", ..#ENVVALUE3_..#ENVVALUE4)
}

Method TestMergeDynamicObjects()
{
    set xdataID="Test.PM.Unit.EnvironmentConfig||AllCases"
    set compiledXdata=##class(%Dictionary.CompiledXData).%OpenId(xdataID)
    set stream=compiledXdata.Data
    do $$$AssertTrue($isobject(stream))

    set allTestCases = [].%FromJSON(stream)
    set iter = allTestCases.%GetIterator()
    while iter.%GetNext(.key, .case) {
        do ##class(%IPM.General.EnvironmentConfig).MergeDynamicObjects(case.dest, case.src)
        if '$$$AssertTrue(..Equal(case.dest, case.expected)) {
            set message = $$$FormatText("Failed test case: %1, output = %2", case.%ToJSON(), case.dest.%ToJSON())
            do $$$LogMessage(message)
        }
    }
}

ClassMethod Equal(
	j1 As %IPM.DataType.Any,
	j2 As %IPM.DataType.Any) As %Boolean
{
    quit ..IsSubset(j1, j2) && ..IsSubset(j2, j1)
}

ClassMethod IsSubset(
	j1 As %IPM.DataType.Any,
	j2 As %IPM.DataType.Any) As %Boolean
{
    if j1 = j2 {
        return 1
    }
    if ('$isobject(j1)) || ('$isobject(j2)) {
        return 0
    }
    if $classname(j1) '= $classname(j2) {
        return 0
    }

    set iter = j1.%GetIterator()
    while iter.%GetNext(.key, .value1, .type1) {
        if j2.%GetTypeOf(key) '= type1 {
            return 0
        }
        if '..IsSubset(value1, j2.%Get(key)) {
            return 0
        }
    }

    return 1
}

}
