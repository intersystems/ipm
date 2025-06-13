Class %IPM.General.SemanticVersionExpression.Comparator Extends (%SerialObject, %IPM.General.SemanticVersionExpression.IComparable)
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
    set i%Expression = pExpr
    quit $$$OK
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
_ $case(..Patch, "": "", : "." _ ..Patch)
_ $case(..Prerelease, "": "", : "-" _ ..Prerelease)
_ $case(..Build, "": "", : "+" _ ..Build)
}

ClassMethod FromString(
	pExpr As %String,
	Output pComparator As %IPM.General.SemanticVersionExpression.Comparator) As %Status
{
    set tSC = $$$OK
    set pComparator = ..%New(pExpr)
    try {
        set tFirst = $extract(pExpr)
        set tSecond = $extract(pExpr,2)
        if (tFirst '= +tFirst) {
            if (tSecond '= +tSecond) {
                set pComparator.Operator = tFirst_tSecond
                set pExpr = $extract(pExpr,3,*)
            } else {
                set pComparator.Operator = tFirst
                set pExpr = $extract(pExpr,2,*)
            }
        }

        // Ensure we got a valid operator.
        set tSC = ##class(%IPM.General.SemanticVersionExpression.Comparator).OperatorIsValid(pComparator.Operator)
        if $$$ISERR(tSC) {
            quit
        }

        set pComparator.Major = $piece(pExpr,".",1)
        set pComparator.Minor = $piece(pExpr,".",2)
        set tEnd = $piece(pExpr,".",3,*)
        set pComparator.Patch = $piece($piece(tEnd,"-"),"+") // Before -prerelease and/or +build
        set pComparator.Prerelease = $piece($piece(tEnd,"-",2),"+") // After - and possibly before +build
        set pComparator.Build = $piece(tEnd,"+",2)

        set tSC = pComparator.%ValidateObject()
        if $$$ISERR(tSC) {
            quit
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if $$$ISERR(tSC) {
        set tSC = $system.Status.EmbedStatus($$$ERROR($$$GeneralError,"Error parsing semantic version expression: "_pExpr),tSC)
    }
    quit tSC
}

Method Evaluate(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
    set tEquals = (..Operator [ "=")
    if tEquals {
        for part = "Major", "Minor", "Patch", "Prerelease", "Build" {
            set val1 = $property(pVersion, part)
            set val2 = $property($this, part)
            quit:((val1 = "*")||(val2 = "*"))
            // Enforce exact match if comparator specifies the part (e.g., Prerelease or Build)
            if val2 '= "" {
                set tEquals = tEquals && (val1 = val2)
            }
        }
    }
    if (+##class(%IPM.Repo.UniversalSettings).GetValue("SemVerPostRelease") = 0) || ($extract(..Operator,1) = "=")  {
        // If SemVerPostRelease is disabled, then we should not consider post-release versions as equal to the base version
        // ..Operator = "=" means direct equality and not <= or >= so compare pre-release as well
        set tEquals = tEquals && (pVersion.Prerelease = ..Prerelease)
    }
    if tEquals || (..Operator = "=") {
        quit tEquals
    }

    // For purposes of this comparison, remove build metadata.
    // Normally, <released version>.Follows(<otherwise identical +snapshot version>) returns 1.
    // However, in this case, it should not; a semantic version expression requiring earlier/later
    // than 1.1.0, for example, should reject 1.1.0+snapshot
    #dim tVersion As %IPM.General.SemanticVersion
    set tVersion = pVersion.%ConstructClone()
    set tVersion.Build = ""

    set tCompVersion = ##class(%IPM.General.SemanticVersion).%New()
    set tCompVersion.Major = ..Major
    set tCompVersion.Minor = ..Minor
    set tCompVersion.Patch = ..Patch
    set tCompVersion.Prerelease = ..Prerelease

    if (..Operator [ "<") {
        quit tCompVersion.Follows(tVersion)
    } else {
        quit tVersion.Follows(tCompVersion)
    }

    quit 1
}

Method IsSatsifiedBy(pVersion As %IPM.General.SemanticVersion) As %Boolean [ Abstract ]
{
	Quit ..Evaluate(pVersion)
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
