Class %IPM.DataType.ListOfOptions Extends %Library.List
{

/// If specified, validation ensures that each element in the list is one of the specified values.
Parameter VALUELIST;

/// Used in conjunction with <parameter>VALUELIST</parameter>.
Parameter DISPLAYLIST;

/// Converts the SOAP encoded input list value into a Cache $list value.
/// Overridden to generate even in non-XML enabled classes (implementation copied from parent and minimally modified)
ClassMethod XSDToLogical(val As %String) As %List [ CodeMode = generator ]
{
    set odbcdelim=%parameter("ODBCDELIMITER")
    if odbcdelim="," set odbcdelim=""
    set odbcdelim=$select(odbcdelim'="":","""_odbcdelim_"""",1:"")
    $$$GENERATE("	Quit $listfromstring(val"_odbcdelim_")")
}

/// Converts the Cache $list value to the canonical SOAP encoded value.
/// Overridden to generate even in non-XML enabled classes (implementation copied from parent and minimally modified)
ClassMethod LogicalToXSD(val As %List) As %String [ CodeMode = generator ]
{
    set odbcdelim=%parameter("ODBCDELIMITER")
    if odbcdelim="," set odbcdelim=""
    set odbcdelim=$select(odbcdelim'="":","""_odbcdelim_"""",1:",")
    $$$GENERATE("	Quit $zcvt($listtostring(val"_odbcdelim_",1),""O"",""XML"")")
}

/// Converts the input value <var>%val</var>, which is a string, into the logical string format,  based on <parameter>VALUELIST</parameter> and <parameter>DISPLAYLIST</parameter>.
/// Returns the logical value of the input string <var>%val</var>.
ClassMethod DisplayToLogical(%val As %String) As %String [ CodeMode = objectgenerator ]
{
    set tDelimiter = %parameter("ODBCDELIMITER")
    set tDelimiterCode = $case(tDelimiter, ",":"", "":"", :","_$$$QUOTE(tDelimiter))
    if (%parameter("VALUELIST") '= "") && (%parameter("DISPLAYLIST") '= "") {
        set tValuePointer = 0
        set tDisplayPointer = 0
        set tValueList = $listfromstring(%parameter("VALUELIST"))
        set tDisplayList = $listfromstring(%parameter("DISPLAYLIST"))

        do %code.WriteLine(" Set tLogicalList = """"")
        do %code.WriteLine(" Set tPointer = 0")
        do %code.WriteLine(" Set tVal = $ListFromString(%val"_tDelimiterCode_")")
        do %code.WriteLine(" While $ListNext(tVal,tPointer,tValue) {")
        do %code.WriteLine("  Set tLogicalList = tLogicalList_$ListBuild($Case(tValue")
        while $listnext(tValueList,tValuePointer,tValue) && $listnext(tDisplayList,tDisplayPointer,tDisplay) {
            do %code.WriteLine("  ,"_$$$QUOTE(tDisplay)_":"_$$$QUOTE(tValue))
        }
        do %code.WriteLine("  ))")
        do %code.WriteLine(" }")
        do %code.WriteLine(" Quit tLogicalList")
    } else {
        do %code.WriteLine(" Quit $ListFromString(%val"_tDelimiterCode_")")
    }
    quit $$$OK
}

/// Converts the value of <var>%val</var>, which is in logical format, into a display string, based on <parameter>VALUELIST</parameter> and <parameter>DISPLAYLIST</parameter>.
/// <p>Returns the string value of <var>%val</var>.
ClassMethod LogicalToDisplay(%val As %String) As %String [ CodeMode = objectgenerator ]
{
    set tDelimiter = %parameter("ODBCDELIMITER")
    set tDelimiterCode = $case(tDelimiter, ",":"", "":"", :","_$$$QUOTE(tDelimiter))
    if (%parameter("VALUELIST") '= "") && (%parameter("DISPLAYLIST") '= "") {
        set tValuePointer = 0
        set tDisplayPointer = 0
        set tValueList = $listfromstring(%parameter("VALUELIST"))
        set tDisplayList = $listfromstring(%parameter("DISPLAYLIST"))

        do %code.WriteLine(" Set tDisplayList = """"")
        do %code.WriteLine(" Set tPointer = 0")
        do %code.WriteLine(" While $ListNext(%val,tPointer,tValue) {")
        do %code.WriteLine("  Set tDisplayList = tDisplayList_$ListBuild($Case(tValue")
        while $listnext(tValueList,tValuePointer,tValue) && $listnext(tDisplayList,tDisplayPointer,tDisplay) {
            do %code.WriteLine("  ,"_$$$QUOTE(tValue)_":"_$$$QUOTE(tDisplay))
        }
        do %code.WriteLine("  ))")
        do %code.WriteLine(" }")
        do %code.WriteLine(" Quit $ListToString(tDisplayList"_tDelimiterCode_")")
    } else {
        do %code.WriteLine(" Quit $ListToString(%val"_tDelimiterCode_")")
    }
    quit $$$OK
}

/// Tests if the logical value <var>%val</var>, which is a string, is valid.
/// The validation is based on the class parameter settings used for the class attribute this data type is associated with.
/// In this case, <a href="#MINLEN">MINLEN</a>, <a href="#MAXLEN">MAXLEN</a>, <a href="#VALUELIST">VALUELIST</a>, and <a href="#PATTERN">PATTERN</a>.
ClassMethod IsValid(%val As %CacheString) As %Status [ CodeMode = objectgenerator ]
{
    do %code.WriteLine(" If '$ListValid(%val) {")
    do %code.WriteLine("  Quit $$$ERROR($$$DTFailure,%val)")
    do %code.WriteLine(" }")
    if (%parameter("VALUELIST") '= "") {
        set tValueList = $listfromstring(%parameter("VALUELIST"))
        set tValuePointer = 0
        do %code.WriteLine(" Set tPointer = 0, tIsValid = 1")
        do %code.WriteLine(" While tIsValid && $ListNext(%val,tPointer,tValue) {")
        do %code.WriteLine("  Set tIsValid = tIsValid && $Case(tValue")
        while $listnext(tValueList,tValuePointer,tValue) {
            do %code.WriteLine("  ,"_$$$QUOTE(tValue)_":1")
        }
        do %code.WriteLine("  ,:0)")
        do %code.WriteLine(" }")
        do %code.WriteLine(" If 'tIsValid { Quit $$$ERROR($$$DTValueList,tValue,"_$$$quote(%parameter("VALUELIST"))_") }")
    }
    do %code.WriteLine(" Quit $$$OK")
    quit $$$OK
}

}
