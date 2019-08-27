Class %ZPM.PackageManager.Core.SemVer.Comparator Extends %SerialObject
{

Property Expression As %String [ ReadOnly ];

Property Operator As %String(VALUELIST = ",=,<,<=,>,>=") [ InitialExpression = "=", Required ];

Property Major As %Integer(MINVAL = 0) [ Required ];

Property Minor As %Integer(MINVAL = 0) [ Required ];

Property Patch As %Integer(MINVAL = 0) [ Required ];

Property Prerelease As %String(MAXLEN = 100);

Property Build As %String(MAXLEN = 100);

Method %OnNew(pExpr As %String) As %Status [ Private, ServerOnly = 1 ]
{
	Set i%Expression = pExpr
	Quit $$$OK
}

Method ToString() As %String [ CodeMode = expression ]
{
..Expression
}

Method ToResolvedString() As %String [ CodeMode = expression ]
{
..Operator_..Major_"."_..Minor_"."_..Patch_$Case(..Prerelease,"":"",:"-"_..Prerelease)_$Case(..Build,"":"",:"+"_..Build)
}

ClassMethod FromString(pExpr As %String, Output pComparator As %ZPM.PackageManager.Core.SemVer.Comparator) As %Status
{
	Set tSC = $$$OK
	Set pComparator = ..%New(pExpr)
	Try {
		Set tFirst = $E(pExpr)
		Set tSecond = $E(pExpr,2)
		If (tFirst '= +tFirst) {
			If (tSecond '= +tSecond) {
				Set pComparator.Operator = tFirst_tSecond
				Set pExpr = $E(pExpr,3,*)
			} Else {
				Set pComparator.Operator = tFirst
				Set pExpr = $E(pExpr,2,*)
			}
		}
		
		// Ensure we got a valid operator.
		Set tSC = ##class(%ZPM.PackageManager.Core.SemVer.Comparator).OperatorIsValid(pComparator.Operator)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set pComparator.Major = $Piece(pExpr,".",1)
		Set pComparator.Minor = $Piece(pExpr,".",2)
		Set tEnd = $Piece(pExpr,".",3)
		Set pComparator.Patch = $Piece($Piece(tEnd,"-"),"+") // Before -prerelease and/or +build
		Set pComparator.Prerelease = $Piece($Piece(tEnd,"-",2),"+") // After - and possibly before +build
		Set pComparator.Build = $Piece(tEnd,"+",2)
		
		Set tSC = pComparator.%ValidateObject()
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If $$$ISERR(tSC) {
		Set tSC = $System.Status.EmbedStatus($$$ERROR($$$GeneralError,"Error parsing semantic version expression: "_pExpr),tSC)
	}
	Quit tSC
}

Method Evaluate(pVersion As %ZPM.PackageManager.Core.SemanticVersion) As %Boolean
{
	// Must prereleases match?
	Set tEquals = (..Operator [ "=") && (pVersion.Major = ..Major) && (pVersion.Minor = ..Minor) && (pVersion.Patch = ..Patch) && (pVersion.Prerelease = ..Prerelease)
	If (..Operator = "=") {
		Quit tEquals
	}
	
	Set tCompVersion = ##class(%ZPM.PackageManager.Core.SemanticVersion).%New()
	Set tCompVersion.Major = ..Major
	Set tCompVersion.Minor = ..Minor
	Set tCompVersion.Patch = ..Patch
	Set tCompVersion.Prerelease = ..Prerelease
	
	If (..Operator [ "<") {
		Quit tCompVersion.Follows(pVersion) || tEquals
	} Else {
		Quit pVersion.Follows(tCompVersion) || tEquals
	}
	
	Quit 1
}

Storage Default
{
<Data name="ComparatorState">
<Value name="1">
<Value>Operator</Value>
</Value>
<Value name="2">
<Value>Major</Value>
</Value>
<Value name="3">
<Value>Minor</Value>
</Value>
<Value name="4">
<Value>Patch</Value>
</Value>
<Value name="5">
<Value>Metadata</Value>
</Value>
<Value name="6">
<Value>Expression</Value>
</Value>
<Value name="7">
<Value>Prerelease</Value>
</Value>
<Value name="8">
<Value>Build</Value>
</Value>
</Data>
<State>ComparatorState</State>
<StreamLocation>^ZPM.PackageManager.Core33CB.ComparatorS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
