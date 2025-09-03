Class %IPM.General.SemanticVersionExpression Extends (%SerialObject, %XML.Adaptor, %IPM.General.SemanticVersionExpression.IComparable) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemVerExpression";

/// List of semantic version expressions to provide support for ||
Property AnyOf As list Of %IPM.General.SemanticVersionExpression.IComparable(CLASSNAME = 1);

/// Used to combine multiple semantic version expressions when doing dependency resolution
Property AllOf As list Of %IPM.General.SemanticVersionExpression.IComparable(CLASSNAME = 1);

Property Expression As %String(MAXLEN = "");

Method %OnNew(rangeExpr As %String = "") As %Status [ Private, ServerOnly = 1 ]
{
  set i%Expression = rangeExpr
  quit $$$OK
}

Method ExpressionSet(value As %String) As %Status
{
  set status = $$$OK
  try {
    set options = $listfromstring(value,"||")
    set ptr = 0
    while $listnext(options,ptr,rangeExpr) {
      set rangeExpr = $zstrip(rangeExpr,"<>W")
      set status = ##class(%IPM.General.SemanticVersionExpression.Range).FromString(rangeExpr,.option)
      if $$$ISERR(status) {
        quit
      }
      do ..AnyOf.Insert(option)
    }
    set i%Expression = value
  } catch e {
    set status = e.AsStatus()
  }
  quit status
}

Method ToString() As %String [ CodeMode = expression ]
{
..Expression
}

Method ToResolvedString() As %String
{
  set optList = ""
  if ..AnyOf.Count() {
    for i=1:1:..AnyOf.Count() {
      set opt = ..AnyOf.GetAt(i)
      set resolvedString = opt.ToResolvedString()
      if resolvedString '= "" {
        set optList = optList_$listbuild("(" _ resolvedString _ ")")
      }
    }
    quit $listtostring(optList," || ")
  }
  if ..AllOf.Count() {
    for i=1:1:..AllOf.Count() {
      set opt = ..AllOf.GetAt(i)
      set optList = optList_$listbuild("(" _ opt.ToResolvedString() _ ")")
    }
    quit $listtostring(optList," && ")
  }
  quit ""
}

ClassMethod FromString(
	string As %String,
	Output expr As %IPM.General.SemanticVersionExpression) As %Status
{
  set status = $$$OK
  try {
      set expr = ..%New(string)
      set options = $listfromstring(string,"||")
      set ptr = 0
      while $listnext(options,ptr,rangeExpr) {
          set rangeExpr = $zstrip(rangeExpr,"<>W")
          set status = ##class(%IPM.General.SemanticVersionExpression.Range).FromString(rangeExpr,.option)
          if $$$ISERR(status) {
              quit
          }
          do expr.AnyOf.Insert(option)
      }
  } catch e {
      set status = e.AsStatus()
  }
  quit status
}

Method IsSatisfiedBy(version As %IPM.General.SemanticVersion) As %Boolean
{
  set satisfied = (..AnyOf.Count() = 0)
  for i=1:1:..AnyOf.Count() {
    if ..AnyOf.GetAt(i).IsSatisfiedBy(version) {
      set satisfied = 1
      quit
    }
  }

  set allSatisfied = 1
  for i=1:1:..AllOf.Count() {
    if '..AllOf.GetAt(i).IsSatisfiedBy(version) {
      set allSatisfied = 0
      quit
    }
  }

  quit satisfied && allSatisfied
}

Method And(versionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
  if versionExpression.Expression '= "" {
    set expr1 = ..%ConstructClone()
    do ..AnyOf.Clear()
    do ..AllOf.Clear()
    do ..AllOf.Insert(expr1)
    do ..AllOf.Insert(versionExpression)
    set i%Expression = ..ToResolvedString()
  }
  quit $this
}

Method Or(versionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
  if versionExpression.Expression '= "" {
    set expr1 = ..%ConstructClone()
    do ..AnyOf.Clear()
    do ..AllOf.Clear()
    do ..AnyOf.Insert(expr1)
    do ..AnyOf.Insert(versionExpression)
    set i%Expression = ..ToResolvedString()
  }
	quit $this
}

Method %OnOpen() As %Status [ Private, ServerOnly = 1 ]
{
  // On-the-fly data migration to tack on list-of-serial CLASSNAME=1 with default classname of %IPM.General.SemanticVersionExpression.Range
  set key = ""
  for {
    set key = $order(i%AnyOf(key),1,data)
    if key="" {
      quit
    }
    if $listlength(data) = 1 {
      set $list(data,2) = "%IPM.General.SemanticVersionExpression.Range"
    }
    set i%AnyOf(key) = data
  }
  quit $$$OK
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
