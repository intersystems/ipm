Class Test.PM.Unit.MergeJSON Extends %UnitTest.TestCase
{

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

Method TestMergeDynamicObjects()
{
    Set xdataID="Test.PM.Unit.MergeJSON||AllCases"
    Set compiledXdata=##class(%Dictionary.CompiledXData).%OpenId(xdataID)
    Set stream=compiledXdata.Data
    Do $$$AssertTrue($IsObject(stream))

    Set allTestCases = [].%FromJSON(stream)
    Set iter = allTestCases.%GetIterator()
    While iter.%GetNext(.key, .case) {
        Do ##class(%IPM.General.EnvironmentConfig).MergeDynamicObjects(case.dest, case.src)
        If '$$$AssertTrue(..Equal(case.dest, case.expected)) {
            Set message = $$$FormatText("Failed test case: %1, output = %2", case.%ToJSON(), case.dest.%ToJSON())
            Do $$$LogMessage(message)
        }
    }
}

ClassMethod Equal(j1 As %IPM.DataType.Any, j2 As %IPM.DataType.Any) As %Boolean
{
    Quit ..IsSubset(j1, j2) && ..IsSubset(j2, j1)
}

ClassMethod IsSubset(j1 As %IPM.DataType.Any, j2 As %IPM.DataType.Any) As %Boolean
{
    If j1 = j2 {
        Return 1
    }
    If ('$IsObject(j1)) || ('$IsObject(j2)) {
        Return 0
    }
    If $classname(j1) '= $classname(j2) {
        Return 0
    }

    Set iter = j1.%GetIterator()
    While iter.%GetNext(.key, .value1, .type1) {
        If j2.%GetTypeOf(key) '= type1 {
            Return 0
        }
        If '..IsSubset(value1, j2.%Get(key)) {
            Return 0
        }
    }

    Return 1
}

}
