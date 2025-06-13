Class %IPM.General.SemanticVersionExpression Extends (%SerialObject, %XML.Adaptor, %IPM.General.SemanticVersionExpression.IComparable) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemVerExpression";

Property AnyOf As list Of %IPM.General.SemanticVersionExpression.IComparable;

Property AllOf As list Of %IPM.General.SemanticVersionExpression.IComparable;

Property Expression As %String(MAXLEN = "");

Method %OnNew(pRangeExpr As %String = "") As %Status [ Private, ServerOnly = 1 ]
{
	Set i%Expression = pRangeExpr
	Quit $$$OK
}

Method ExpressionSet(pValue As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tOptions = $ListFromString(pValue,"||")
		Set tPtr = 0
		While $ListNext(tOptions,tPtr,tRangeExpr) {
			Set tRangeExpr = $ZStrip(tRangeExpr,"<>W")
			Set tSC = ##class(%IPM.General.SemanticVersionExpression.Range).FromString(tRangeExpr,.tOption)
			If $$$ISERR(tSC) {
				Quit
			}
			Do ..AnyOf.Insert(tOption)
		}
		Set i%Expression = pValue
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method ToString() As %String [ CodeMode = expression ]
{
..Expression
}

Method ToResolvedString() As %String
{
	Set tOptList = ""
	If ..AnyOf.Count() {
		For i=1:1:..AnyOf.Count() {
			Set tOpt = ..AnyOf.GetAt(i)
			Set tOptList = tOptList_$ListBuild(tOpt.ToResolvedString())
		}
		Quit $ListToString(tOptList," || ")
	}
	If ..AllOf.Count() {
		For i=1:1:..AllOf.Count() {
			Set tOpt = ..AllOf.GetAt(i)
			Set tOptList = tOptList_$ListBuild("("_tOpt.ToResolvedString()_")")
		}
		Quit $ListToString(tOptList," && ")
	}
	Quit ""
}

ClassMethod FromString(pString As %String, Output pExpr As %IPM.General.SemanticVersionExpression) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pExpr = ..%New(pString)
		Set tOptions = $ListFromString(pString,"||")
		Set tPtr = 0
		While $ListNext(tOptions,tPtr,tRangeExpr) {
			Set tRangeExpr = $ZStrip(tRangeExpr,"<>W")
			Set tSC = ##class(%IPM.General.SemanticVersionExpression.Range).FromString(tRangeExpr,.tOption)
			If $$$ISERR(tSC) {
				Quit
			}
			Do pExpr.AnyOf.Insert(tOption)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method IsSatisfiedBy(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
	Set tSatisfied = (..AnyOf.Count() = 0)
	For i=1:1:..AnyOf.Count() {
		If ..AnyOf.GetAt(i).IsSatisfiedBy(pVersion) {
			Set tSatisfied = 1
			Quit
		}
	}

	Set tAllSatisfied = (..AllOf.Count() = 0)
	For i=1:1:..AllOf.Count() {
		If ..AllOf.GetAt(i).IsSatisfiedBy(pVersion) {
			Set tAllSatisfied = 1
			Quit
		}
	}
	
	Set tSatisfied = tSatisfied && tAllSatisfied
	Quit tSatisfied
}

Method And(pVersionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
	Set expr1 = ..%ConstructClone()
	Do ..AnyOf.Clear()
	Do ..AllOf.Clear()
	Do ..AllOf.Insert(expr1)
	Do ..AllOf.Insert(pVersionExpression)
	Set i%Expression = ..ToResolvedString()
	Quit $This
}

Method Or(pVersionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
	Set expr1 = ..%ConstructClone()
	Do ..AnyOf.Clear()
	Do ..AllOf.Clear()
	Do ..AnyOf.Insert(expr1)
	Do ..AnyOf.Insert(pVersionExpression)
	Set i%Expression = ..ToResolvedString()
	Quit $This
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
<Value name="3">
<Value>AnyOf</Value>
</Value>
<Value name="4">
<Value>AllOf</Value>
</Value>
</Data>
<State>SemanticVersionExpressionState</State>
<StreamLocation>^IPM.General.SemVerExpressionS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
