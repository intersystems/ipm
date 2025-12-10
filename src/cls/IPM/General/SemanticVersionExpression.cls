Class %IPM.General.SemanticVersionExpression Extends (%SerialObject, %XML.Adaptor, %IPM.General.SemanticVersionExpression.IComparable) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemVerExpression";

/// List of ranges to provide support for ||. Any && would be consolidated into single ranges in the AnyOf list.
Property AnyOf As list Of %IPM.General.SemanticVersionExpression.Range;

/// String representation of this SemVer expression composed of the AnyOf and AllOf lists
/// Parentheses are not used in parsing but are merely stylistic
Property Expression As %String(MAXLEN = "");

Method %OnNew(rangeExpr As %String = "") As %Status [ Private, ServerOnly = 1 ]
{
    set ..Expression = rangeExpr
    quit $$$OK
}

Method ExpressionSet(value As %String) As %Status
{
    if (value [ "&&") && (value [ "||") {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Cannot mix '&&' and '||' in a single expression"))
    }
    if (value [ "&&") {
        set reqs = $listfromstring(value,"&&")
        set ptr = 0
        set andExpr = ""
        while $listnext(reqs,ptr,rangeExpr) {
            set rangeExpr = $zstrip(rangeExpr,"<>W")
            set rangeExpr = $zstrip(rangeExpr,"*","()")
            set sc = ##class(%IPM.General.SemanticVersionExpression.Range).FromString(rangeExpr,.option)
            $$$ThrowOnError(sc)
            if option.ToResolvedString() = "" {
                continue
            }
            if (andExpr = "") {
                set andExpr = option
            } else {
                set merged = ##class(%IPM.General.SemanticVersionExpression.Range).Intersect(andExpr, option)
                if (merged = "") {
                    $$$ThrowStatus($$$ERROR($$$GeneralError,"No overlapping versions in && operation for %1 and %2", andExpr.ToResolvedString(), option.ToResolvedString()))
                }
                set andExpr = merged
            }
        }
        if (andExpr.ToResolvedString() '= "") {
            do ..AnyOf.Insert(andExpr)
        }
    } else {
        set options = $listfromstring(value,"||")
        set ptr = 0
        while $listnext(options,ptr,rangeExpr) {
            set rangeExpr = $zstrip(rangeExpr,"<>W")
            set rangeExpr = $zstrip(rangeExpr,"*","()")
            set sc = ##class(%IPM.General.SemanticVersionExpression.Range).FromString(rangeExpr,.option)
            $$$ThrowOnError(sc)
            if option.ToResolvedString() = "" {
                continue
            }
            do ..AnyOf.Insert(option)
        }
    }
    set i%Expression = value
    // note: we throw errors and just return $$$Ok at the end because the returned status isn't
    // used by the caller. Its still needed though since without it, there will be errors at runtime
    // whenever this setter is used.
    return $$$OK
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
            if ..AnyOf.Count() > 1 {
                set optList = optList_$listbuild("(" _ resolvedString _ ")")
            } else {
                set optList = optList_$listbuild(resolvedString)
            }
        }
        quit $listtostring(optList," || ")
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
    } catch e {
        set status = e.AsStatus()
    }
    quit status
}

Method IsSatisfiedBy(version As %IPM.General.SemanticVersion) As %Boolean
{
    if (..AnyOf.Count() = 0) {
        return 1
    }
    for i=1:1:..AnyOf.Count() {
        if ..AnyOf.GetAt(i).IsSatisfiedBy(version) {
            return 1
            quit
        }
    }
    return 0
}

Method And(versionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
    if versionExpression.Expression '= "" {
        if (..AnyOf.Count() = 0) {
            // If current is empty, just copy in the new one
            set ..AnyOf = versionExpression.AnyOf
            set i%Expression = versionExpression.Expression
            return $this
        }
        if (versionExpression.AnyOf.Count() = 0) {
            // If the new one is empty, just return existing
            return $this
        }
        set current = ..%ConstructClone(1)
        do ..AnyOf.Clear()
        // Need to do an And on all possible combinations of the AnyOf lists
        for i = 1:1:current.AnyOf.Count() {
            for j = 1:1:versionExpression.AnyOf.Count() {
                set expr1 = current.AnyOf.GetAt(i)
                set expr2 = versionExpression.AnyOf.GetAt(j)
                set merged = ##class(%IPM.General.SemanticVersionExpression.Range).Intersect(expr1,expr2)
                if (merged '= "") {
                    do ..AnyOf.Insert(merged)
                }
            }
        }
        set resolvedString = ..ToResolvedString()
        if (resolvedString = "") {
            set msg = $$$FormatText("No overlapping versions in AND operation for %1 and %2",current.ToResolvedString(),versionExpression.ToResolvedString())
            $$$ThrowStatus($$$ERROR($$$GeneralError,msg))
        }
        set i%Expression = resolvedString
    }
    return $this
}

Method Or(versionExpression As %IPM.General.SemanticVersionExpression) As %IPM.General.SemanticVersionExpression
{
    if versionExpression.Expression '= "" {
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
