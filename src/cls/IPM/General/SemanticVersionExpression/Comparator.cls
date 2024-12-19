Class %IPM.General.SemanticVersionExpression.Comparator Extends %SerialObject
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemVer.Comp";

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
..Operator 
_ ..Major 
_ "." _ ..Minor 
_ $Case(..Patch, "": "", : "." _ ..Patch) 
_ $Case(..Prerelease, "": "", : "-" _ ..Prerelease) 
_ $Case(..Build, "": "", : "+" _ ..Build)
}

ClassMethod FromString(pExpr As %String, Output pComparator As %IPM.General.SemanticVersionExpression.Comparator) As %Status
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
		Set tSC = ##class(%IPM.General.SemanticVersionExpression.Comparator).OperatorIsValid(pComparator.Operator)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set pComparator.Major = $Piece(pExpr,".",1)
		Set pComparator.Minor = $Piece(pExpr,".",2)
		Set tEnd = $Piece(pExpr,".",3,*)
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

Method Evaluate(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
	Set tEquals = (..Operator [ "=")
  If tEquals {
    For part = "Major", "Minor", "Patch", "Prerelease" {
      Set val1 = $Property(pVersion, part)
      Set val2 = $Property($this, part)
      Quit:((val1 = "")||(val2 = ""))
      Quit:((val1 = "*")||(val2 = "*"))
      Set tEquals = tEquals && (val1 = val2)
    }
  }
	If (+##class(%IPM.Repo.UniversalSettings).GetValue("SemVerPostRelease") = 0) || ($Extract(..Operator,1) = "=")  {
		// If SemVerPostRelease is disabled, then we should not consider post-release versions as equal to the base version
		// ..Operator = "=" means direct equality and not <= or >= so compare pre-release as well
		Set tEquals = tEquals && (pVersion.Prerelease = ..Prerelease)
	}
	If tEquals || (..Operator = "=") {
		Quit tEquals
	}
	
	// For purposes of this comparison, remove build metadata.
	// Normally, <released version>.Follows(<otherwise identical +snapshot version>) returns 1.
	// However, in this case, it should not; a semantic version expression requiring earlier/later
	// than 1.1.0, for example, should reject 1.1.0+snapshot
	#dim tVersion As %IPM.General.SemanticVersion
	Set tVersion = pVersion.%ConstructClone()
	Set tVersion.Build = ""
	
	Set tCompVersion = ##class(%IPM.General.SemanticVersion).%New()
	Set tCompVersion.Major = ..Major
	Set tCompVersion.Minor = ..Minor
	Set tCompVersion.Patch = ..Patch
	Set tCompVersion.Prerelease = ..Prerelease
	
	If (..Operator [ "<") {
		Quit tCompVersion.Follows(tVersion)
	} Else {
		Quit tVersion.Follows(tCompVersion)
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
<StreamLocation>^IPM.General.SemVer.CompS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
