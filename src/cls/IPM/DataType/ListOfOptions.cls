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
	Set odbcdelim=%parameter("ODBCDELIMITER")
	If odbcdelim="," Set odbcdelim=""
	Set odbcdelim=$select(odbcdelim'="":","""_odbcdelim_"""",1:"")
	$$$GENERATE("	Quit $listfromstring(val"_odbcdelim_")")
}

/// Converts the Cache $list value to the canonical SOAP encoded value.
/// Overridden to generate even in non-XML enabled classes (implementation copied from parent and minimally modified)
ClassMethod LogicalToXSD(val As %List) As %String [ CodeMode = generator ]
{
	Set odbcdelim=%parameter("ODBCDELIMITER")
	If odbcdelim="," Set odbcdelim=""
	Set odbcdelim=$select(odbcdelim'="":","""_odbcdelim_"""",1:",")
	$$$GENERATE("	Quit $zcvt($listtostring(val"_odbcdelim_",1),""O"",""XML"")")
}

/// Converts the input value <var>%val</var>, which is a string, into the logical string format,  based on <parameter>VALUELIST</parameter> and <parameter>DISPLAYLIST</parameter>.
/// Returns the logical value of the input string <var>%val</var>.
ClassMethod DisplayToLogical(%val As %String) As %String [ CodeMode = objectgenerator ]
{
	Set tDelimiter = %parameter("ODBCDELIMITER")
	Set tDelimiterCode = $Case(tDelimiter, ",":"", "":"", :","_$$$QUOTE(tDelimiter))
	If (%parameter("VALUELIST") '= "") && (%parameter("DISPLAYLIST") '= "") {
		Set tValuePointer = 0
		Set tDisplayPointer = 0
		Set tValueList = $ListFromString(%parameter("VALUELIST"))
		Set tDisplayList = $ListFromString(%parameter("DISPLAYLIST"))
		
		Do %code.WriteLine(" Set tLogicalList = """"")
		Do %code.WriteLine(" Set tPointer = 0")
		Do %code.WriteLine(" Set tVal = $ListFromString(%val"_tDelimiterCode_")")
		Do %code.WriteLine(" While $ListNext(tVal,tPointer,tValue) {")
		Do %code.WriteLine("  Set tLogicalList = tLogicalList_$ListBuild($Case(tValue")
		While $ListNext(tValueList,tValuePointer,tValue) && $ListNext(tDisplayList,tDisplayPointer,tDisplay) {
			Do %code.WriteLine("  ,"_$$$QUOTE(tDisplay)_":"_$$$QUOTE(tValue))
		}
		Do %code.WriteLine("  ))")
		Do %code.WriteLine(" }")
		Do %code.WriteLine(" Quit tLogicalList")
	} Else {
		Do %code.WriteLine(" Quit $ListFromString(%val"_tDelimiterCode_")")
	}
	Quit $$$OK
}

/// Converts the value of <var>%val</var>, which is in logical format, into a display string, based on <parameter>VALUELIST</parameter> and <parameter>DISPLAYLIST</parameter>.
/// <p>Returns the string value of <var>%val</var>.
ClassMethod LogicalToDisplay(%val As %String) As %String [ CodeMode = objectgenerator ]
{
	Set tDelimiter = %parameter("ODBCDELIMITER")
	Set tDelimiterCode = $Case(tDelimiter, ",":"", "":"", :","_$$$QUOTE(tDelimiter))
	If (%parameter("VALUELIST") '= "") && (%parameter("DISPLAYLIST") '= "") {
		Set tValuePointer = 0
		Set tDisplayPointer = 0
		Set tValueList = $ListFromString(%parameter("VALUELIST"))
		Set tDisplayList = $ListFromString(%parameter("DISPLAYLIST"))
		
		Do %code.WriteLine(" Set tDisplayList = """"")
		Do %code.WriteLine(" Set tPointer = 0")
		Do %code.WriteLine(" While $ListNext(%val,tPointer,tValue) {")
		Do %code.WriteLine("  Set tDisplayList = tDisplayList_$ListBuild($Case(tValue")
		While $ListNext(tValueList,tValuePointer,tValue) && $ListNext(tDisplayList,tDisplayPointer,tDisplay) {
			Do %code.WriteLine("  ,"_$$$QUOTE(tValue)_":"_$$$QUOTE(tDisplay))
		}
		Do %code.WriteLine("  ))")
		Do %code.WriteLine(" }")
		Do %code.WriteLine(" Quit $ListToString(tDisplayList"_tDelimiterCode_")")
	} Else {
		Do %code.WriteLine(" Quit $ListToString(%val"_tDelimiterCode_")")
	}
	Quit $$$OK
}

/// Tests if the logical value <var>%val</var>, which is a string, is valid.
/// The validation is based on the class parameter settings used for the class attribute this data type is associated with.
/// In this case, <a href="#MINLEN">MINLEN</a>, <a href="#MAXLEN">MAXLEN</a>, <a href="#VALUELIST">VALUELIST</a>, and <a href="#PATTERN">PATTERN</a>.
ClassMethod IsValid(%val As %CacheString) As %Status [ CodeMode = objectgenerator ]
{
	Do %code.WriteLine(" If '$ListValid(%val) {")
	Do %code.WriteLine("  Quit $$$ERROR($$$DTFailure,%val)")
	Do %code.WriteLine(" }")
	If (%parameter("VALUELIST") '= "") {
		Set tValueList = $ListFromString(%parameter("VALUELIST"))
		Set tValuePointer = 0
		Do %code.WriteLine(" Set tPointer = 0, tIsValid = 1")
		Do %code.WriteLine(" While tIsValid && $ListNext(%val,tPointer,tValue) {")
		Do %code.WriteLine("  Set tIsValid = tIsValid && $Case(tValue")
		While $ListNext(tValueList,tValuePointer,tValue) {
			Do %code.WriteLine("  ,"_$$$QUOTE(tValue)_":1")
		}
		Do %code.WriteLine("  ,:0)")
		Do %code.WriteLine(" }")
		Do %code.WriteLine(" If 'tIsValid { Quit $$$ERROR($$$DTValueList,tValue,"_$$$quote(%parameter("VALUELIST"))_") }")
	}
	Do %code.WriteLine(" Quit $$$OK")
	Quit $$$OK
}

}
