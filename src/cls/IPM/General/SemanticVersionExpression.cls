Class %IPM.General.SemanticVersionExpression Extends (%SerialObject, %XML.Adaptor) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemVerExpression";

Property Options As list Of %IPM.General.SemanticVersionExpression.Range;

Property Expression As %String(MAXLEN = "");

Method %OnNew(pRangeExpr As %String = "") As %Status [ Private, ServerOnly = 1 ]
{
    set i%Expression = pRangeExpr
    quit $$$OK
}

Method ExpressionSet(pValue As %String) As %Status
{
    set tSC = $$$OK
    try {
        set tOptions = $listfromstring(pValue,"||")
        set tPtr = 0
        while $listnext(tOptions,tPtr,tRangeExpr) {
            set tRangeExpr = $zstrip(tRangeExpr,"<>W")
            set tSC = ##class(%IPM.General.SemanticVersionExpression.Range).FromString(tRangeExpr,.tOption)
            if $$$ISERR(tSC) {
                quit
            }
            do ..Options.Insert(tOption)
        }
        set i%Expression = pValue
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method ToString() As %String [ CodeMode = expression ]
{
..Expression
}

Method ToResolvedString() As %String
{
    set tOptList = ""
    for i=1:1:..Options.Count() {
        set tOpt = ..Options.GetAt(i)
        set tOptList = tOptList_$listbuild(tOpt.ToResolvedString())
    }
    quit $listtostring(tOptList," || ")
}

ClassMethod FromString(
	pString As %String,
	Output pExpr As %IPM.General.SemanticVersionExpression) As %Status
{
    set tSC = $$$OK
    try {
        set pExpr = ..%New(pString)
        set tOptions = $listfromstring(pString,"||")
        set tPtr = 0
        while $listnext(tOptions,tPtr,tRangeExpr) {
            set tRangeExpr = $zstrip(tRangeExpr,"<>W")
            set tSC = ##class(%IPM.General.SemanticVersionExpression.Range).FromString(tRangeExpr,.tOption)
            if $$$ISERR(tSC) {
                quit
            }
            do pExpr.Options.Insert(tOption)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method IsSatisfiedBy(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
    set tSatisfied = (..Options.Count() = 0)
    for i=1:1:..Options.Count() {
        if ..Options.GetAt(i).InRange(pVersion) {
            set tSatisfied = 1
            quit
        }
    }
    quit tSatisfied
}

Method And(pVersionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
    for i=1:1:pVersionExpression.Options.Count() {
        set tOption = pVersionExpression.Options.GetAt(i)
        if (..Options.Count() = 0) {
            do ..Options.Insert(tOption)
        } else {
            for j=1:1:..Options.Count() {
                for k=1:1:tOption.Comparators.Count() {
                    do ..Options.GetAt(j).Comparators.Insert(tOption.Comparators.GetAt(k))
                }
            }
        }
    }
    set i%Expression = ..ToResolvedString()
    quit $this
}

Method Or(pVersionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
    for i=1:1:pVersionExpression.Options.Count() {
        do ..Options.Insert(pVersionExpression.Options.GetAt(i))
    }
    set i%Expression = ..ToResolvedString()
    quit $this
}

Storage Default
{
<Data name="SemanticVersionExpressionState">
<Value name="1">
<Value>Expression</Value>
</Value>
<Value name="2">
<Value>Options</Value>
</Value>
</Data>
<State>SemanticVersionExpressionState</State>
<StreamLocation>^IPM.General.SemVerExpressionS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
