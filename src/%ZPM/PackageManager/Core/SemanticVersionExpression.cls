Class %ZPM.PackageManager.Core.SemanticVersionExpression Extends (%SerialObject, %XML.Adaptor) [ StorageStrategy = "" ]
{

Property Options As list Of %ZPM.PackageManager.Core.SemVer.Range;

Property Expression As %String(MAXLEN = "");

Method %OnNew(pRangeExpr As %String) As %Status [ Private, ServerOnly = 1 ]
{
	Set i%Expression = $Get(pRangeExpr)
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
			Set tSC = ##class(%ZPM.PackageManager.Core.SemVer.Range).FromString(tRangeExpr,.tOption)
			If $$$ISERR(tSC) {
				Quit
			}
			Do ..Options.Insert(tOption)
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
	For i=1:1:..Options.Count() {
		Set tOpt = ..Options.GetAt(i)
		Set tOptList = tOptList_$ListBuild(tOpt.ToResolvedString())
	}
	Quit $ListToString(tOptList," || ")
}

ClassMethod FromString(pString As %String, Output pExpr As %ZPM.PackageManager.Core.SemanticVersionExpression) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pExpr = ..%New(pString)
		Set tOptions = $ListFromString(pString,"||")
		Set tPtr = 0
		While $ListNext(tOptions,tPtr,tRangeExpr) {
			Set tRangeExpr = $ZStrip(tRangeExpr,"<>W")
			Set tSC = ##class(%ZPM.PackageManager.Core.SemVer.Range).FromString(tRangeExpr,.tOption)
			If $$$ISERR(tSC) {
				Quit
			}
			Do pExpr.Options.Insert(tOption)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method IsSatisfiedBy(pVersion As %ZPM.PackageManager.Core.SemanticVersion) As %Boolean
{
	Set tSatisfied = (..Options.Count() = 0)
	For i=1:1:..Options.Count() {
		If ..Options.GetAt(i).InRange(pVersion) {
			Set tSatisfied = 1
			Quit
		}
	}
	Quit tSatisfied
}

Method And(pVersionExpression As %ZPM.PackageManager.Core.SemanticVersionExpression) As %ZPM.PackageManager.Core.SemanticVersionExpression
{
	For i=1:1:pVersionExpression.Options.Count() {
		Set tOption = pVersionExpression.Options.GetAt(i)
		If (..Options.Count() = 0) {
			Do ..Options.Insert(tOption)
		} Else {
			For j=1:1:..Options.Count() {
				For k=1:1:tOption.Comparators.Count() {
					Do ..Options.GetAt(j).Comparators.Insert(tOption.Comparators.GetAt(k))
				}
			}
		}
	}
	Set i%Expression = ..ToResolvedString()
	Quit $This
}

Method Or(pVersionExpression As %ZPM.PackageManager.Core.SemanticVersionExpression) As %ZPM.PackageManager.Core.SemanticVersionExpression
{
	For i=1:1:pVersionExpression.Options.Count() {
		Do ..Options.Insert(pVersionExpression.Options.GetAt(i))
	}
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
</Data>
<State>SemanticVersionExpressionState</State>
<StreamLocation>^ZPM.PackageManager9CFF.SemanticVer1833S</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
