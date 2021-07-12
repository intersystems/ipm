Class %ZPM.PackageManager.Developer.Annotation.CosEntity.QueryProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity.MemberWithArguments
{

Parameter XMLNAME = "Query";

Parameter AcceptableAnchorTags = "API.Overrideable,API.Query,DoesNotInheritTags";

Parameter DictionaryKey = {$$$cCLASSquery};

Parameter ParsedSpecKey = {$$$cQUERYformalspecparsed};

Property QueryType As %String(VALUELIST = ",Basic,Custom", XMLPROJECTION = "attribute");

Property RowSpec As %String(MAXLEN = 500, XMLPROJECTION = "attribute");

Property ContainID As %Integer(XMLPROJECTION = "attribute");

Property SqlName As %String(XMLPROJECTION = "attribute");

Property SqlProc As %Integer(XMLPROJECTION = "attribute");

Index QueryProxyExtentIndex [ Extent ];

Method HandleExtraProperties()
{
	/*
	The query's parameters are stored in a sub-array. 
	
	The distinction between "basic" (%SQLQuery) and "custom" (%Query) queries seems to be indicated by 
	the absence or presence of a "SQLQUERY" entry in the parameter list; if it's absent, it's a custom 
	query. 
	*/
	
	set tParameterName = "" 
	while 1 {
		set tParameterName = $$$comSubMemberNext(..ParentClassName, $$$cCLASSquery, ..Name, $$$cQUERYparameter, tParameterName)
		if tParameterName = "" {
			quit
		}
		
		set tParameterValue = $$$comMemberArrayGet(..ParentClassName, $$$cCLASSquery, ..Name, $$$cQUERYparameter, tParameterName)
		
		if tParameterValue '= "" {
			if tParameterName = "ROWSPEC" {
				set ..RowSpec = tParameterValue
			}
			elseif tParameterName = "CONTAINID" {
				set ..ContainID = tParameterValue
			}
		}
		elseif tParameterName = "SQLQUERY" {
			set ..QueryType = "Basic"
		}
	}
	
	if ..QueryType = "" {
		set ..QueryType = "Custom"
	}
	
	
	// SQL name is weird. If no name is specified in the code, then ^oddCOM will hold a 
	// generated SQLName, and ^oddDEF will not. But if a value is specified in the source code, 
	// it will be stored in ^oddDEF only (and ^oddCOM will contain no value). So we check one 
	// and then fall back to the other. 
	set ..SqlName = $$$defMemberKeyGet(..ParentClassName, $$$cCLASSquery, ..Name, $$$cQUERYsqlname)
	if ..SqlName = "" {
		set ..SqlName = $$$comMemberKeyGet(..ParentClassName, $$$cCLASSquery, ..Name, $$$cQUERYsqlname)
	}
	
	set tIsSqlProc = $$$defMemberKeyGet(..ParentClassName, $$$cCLASSquery, ..Name, $$$cQUERYsqlproc)
	set ..SqlProc = ''$get(tIsSqlProc,0)
	
	do ##super()
}

Storage Default
{
<Data name="QueryProxyDefaultData">
<Subscript>"QueryProxy"</Subscript>
<Value name="1">
<Value>RowSpec</Value>
</Value>
<Value name="2">
<Value>ContainID</Value>
</Value>
<Value name="3">
<Value>SqlName</Value>
</Value>
<Value name="4">
<Value>SqlProc</Value>
</Value>
<Value name="5">
<Value>QueryType</Value>
</Value>
</Data>
<DefaultData>QueryProxyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
