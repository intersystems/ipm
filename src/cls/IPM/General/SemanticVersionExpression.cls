Class %IPM.General.SemanticVersionExpression Extends (%SerialObject, %XML.Adaptor, %IPM.General.SemanticVersionExpression.IComparable) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemVerExpression";

Property AnyOf As list Of %IPM.General.SemanticVersionExpression.IComparable;

Property AllOf As list Of %IPM.General.SemanticVersionExpression.IComparable;

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
            do ..AnyOf.Insert(tOption)
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
	if ..AnyOf.Count() {
		for i=1:1:..AnyOf.Count() {
			set tOpt = ..AnyOf.GetAt(i)
			set tOptList = tOptList_$listbuild(tOpt.ToResolvedString())
		}
		quit $listtostring(tOptList," || ")
	}
	if ..AllOf.Count() {
		for i=1:1:..AllOf.Count() {
			set tOpt = ..AllOf.GetAt(i)
			set tOptList = tOptList_$listbuild("("_tOpt.ToResolvedString()_")")
		}
		quit $listtostring(tOptList," && ")
	}
	quit ""
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
            do pExpr.AnyOf.Insert(tOption)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method IsSatisfiedBy(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
	set tSatisfied = (..AnyOf.Count() = 0)
	for i=1:1:..AnyOf.Count() {
		if ..AnyOf.GetAt(i).IsSatisfiedBy(pVersion) {
			set tSatisfied = 1
			quit
		}
	}

	set tAllSatisfied = (..AllOf.Count() = 0)
	for i=1:1:..AllOf.Count() {
		if ..AllOf.GetAt(i).IsSatisfiedBy(pVersion) {
			set tAllSatisfied = 1
			quit
		}
	}

	set tSatisfied = tSatisfied && tAllSatisfied
	quit tSatisfied
}

Method And(pVersionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
	set expr1 = ..%ConstructClone()
	do ..AnyOf.Clear()
	do ..AllOf.Clear()
	do ..AllOf.Insert(expr1)
	do ..AllOf.Insert(pVersionExpression)
	set i%Expression = ..ToResolvedString()
	quit $this
}

Method Or(pVersionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
	set expr1 = ..%ConstructClone()
	do ..AnyOf.Clear()
	do ..AllOf.Clear()
	do ..AnyOf.Insert(expr1)
	do ..AnyOf.Insert(pVersionExpression)
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
<Value>AnyOf</Value>
</Value>
<Value name="3">
<Value>AllOf</Value>
</Value>
</Data>
<State>SemanticVersionExpressionState</State>
<StreamLocation>^IPM.General.SemVerExpressionS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
