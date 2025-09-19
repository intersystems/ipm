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
    set xdataID="Test.PM.Unit.MergeJSON||AllCases"
    set compiledXdata=##class(%Dictionary.CompiledXData).%OpenId(xdataID,0)
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
