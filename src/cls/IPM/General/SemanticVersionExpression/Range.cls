Class %IPM.General.SemanticVersionExpression.Range Extends (%SerialObject, %IPM.General.SemanticVersionExpression.IComparable)
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemVer.Range";

Property Expression As %String [ ReadOnly ];

Property Comparators As list Of %IPM.General.SemanticVersionExpression.Comparator;

Method %OnNew(pRangeExpr As %String) As %Status [ Private, ServerOnly = 1 ]
{
    set i%Expression = pRangeExpr
    quit $$$OK
}

Method ToString() As %String [ CodeMode = expression ]
{
..Expression
}

Method ToResolvedString() As %String
{
    set tCompList = ""
    for i=1:1:..Comparators.Count() {
        set tComp = ..Comparators.GetAt(i)
        set tCompList = tCompList_$listbuild(tComp.ToResolvedString())
    }
    quit $listtostring(tCompList," ")
}

ClassMethod FromString(
	pRangeExpr As %String,
	Output pRange As %IPM.General.SemanticVersionExpression.Range) As %Status
{
    set tSC = $$$OK
    set pRange = ..%New(pRangeExpr)
    try {
        // Separate AND-ed comparators, rejoining ranges with dashes to handle individually
        set tSpaceParts = $listfromstring(pRangeExpr," ")
        set tPtr = 0
        set tExpressions = ""
        while $listnext(tSpaceParts,tPtr,tPart) {
            if (tPart = "-") {
                // Convert hyphen ranges to simple comparators
                set tFound = $listnext(tSpaceParts,tPtr,tMax)
                if 'tFound {
                    set tSC = $$$ERROR($$$GeneralError,"Invalid range expression: "_pRangeExpr)
                    quit
                }

                set tMin = $list(tExpressions,*)

                // Partial version as min version: add zeros.
                set tMinDotLength = $length(tMin,".")
                if (tMinDotLength < 3) {
                    for i=2:-1:tMinDotLength {
                        set tMin = tMin_".0"
                    }
                }
                set $list(tExpressions,*) = ">="_tMin

                // Partial version as max version: implied .x
                set tMaxDotLength = $length(tMax,".")
                set tOp = "<="
                if (tMaxDotLength < 3) {
                    set tOp = "<"
                    set $piece(tMax,".",tMaxDotLength) = 1 + $piece(tMax,".",tMaxDotLength)
                    for i=2:-1:tMaxDotLength {
                        set tMax = tMax_".0"
                    }
                }
                set tExpressions = tExpressions_$listbuild(tOp_tMax)
            } else {
                set tExpressions = tExpressions_$listbuild(tPart)
            }
        }
        if $$$ISERR(tSC) {
            quit
        }

        // Convert advanced ranges to primitive comparators
        set tComparators = ""
        set tPtr = 0
        while $listnext(tExpressions,tPtr,tExpr) {
            // Get part after operator and before build/metadata
            // Normalize x ranges
            set tMajorMinorPatch = $translate($zstrip($piece($piece(tExpr,"-"),"+"),"<W","<>=^~"),"X*","xx")
            if tMajorMinorPatch?1"20"2N1"."1N {
                set tExpr = tExpr _ ".0"
                set tMajorMinorPatch = tMajorMinorPatch _ ".0"
            }
            set tMajor = $piece(tMajorMinorPatch,".",1)
            set tMinor = $piece(tMajorMinorPatch,".",2)
            set tPatch = $piece(tMajorMinorPatch,".",3)

            // Detect different expression cases
            set tIsXRange = (tMajorMinorPatch [ "x") || (tExpr = "*") || (tMinor = "") || (tPatch = "")
            set tIsTildeRange = ($extract(tExpr) = "~")
            set tIsCaretRange = ($extract(tExpr) = "^")

            if '(tIsXRange || tIsTildeRange || tIsCaretRange) {
                // Primitive comparator
                set tComparators = tComparators_$listbuild(tExpr)
            } elseif tIsTildeRange {
                // Tilde ranges:
                // "Allows patch-level changes if a minor version is specified on the comparator. Allows minor-level changes if not."

                set tExpr = $extract(tExpr,2,*)
                set tDotLength = $length(tExpr,".")

                if (tDotLength < 3) {
                    // Convert missing minor/patch to "X range":
                    set tExpr = tExpr_".x"
                    set tIsXRange = 1
                } else {
                    // Minimum: at least the full specified version
                    set tComparators = tComparators_$listbuild(">="_tExpr)

                    // Maximum based on leftmost nonzero value
                    set tMajor = $piece(tExpr,".",1)
                    set tMinor = $piece(tExpr,".",2)

                    set tComparators = tComparators_$listbuild("<"_tMajor_"."_(tMinor+1)_".0-0")
                }
            } elseif tIsCaretRange {
                // Caret ranges:
                // "Allows changes that do not modify the left-most non-zero digit in the [major, minor, patch] tuple.
                // In other words, this allows patch and minor updates for versions 1.0.0 and above, patch updates for versions 0.X >=0.1.0,
                // and no updates for versions 0.0.X."
                // This case also handles the "x range" and caret range in combination.

                set tExpr = $extract(tExpr,2,*)
                set tDotLength = $length(tExpr,".")
                set tMajor = $piece(tMajorMinorPatch,".",1)
                set tMinor = $piece(tMajorMinorPatch,".",2)
                set tPatch = $piece(tMajorMinorPatch,".",3)
                if (tDotLength < 3) {
                    if (tMajor '= 0) && 'tIsXRange {
                        set tComparators = tComparators_$listbuild(">="_$replace(tExpr,".x",".0"),"<"_(tMajor+1)_".0.0-0")
                        set tIsXRange = 0
                    } else {
                        // Detected and properly handled by X-range.
                    }
                } else {
                    // Minimum
                    set tComparators = tComparators_$listbuild(">="_$replace(tExpr,".x",".0"))

                    set tMax = ""
                    if (+tMajor = 0) && (tMinor '= "x") {
                        if (+tMinor = 0) && (tPatch '= "x") {
                            set tMax = "0.0."_(tPatch+1)_"-0"
                        } else {
                            set tMax = "0."_(tMinor+1)_".0-0"
                        }
                    } else {
                        set tMax = (tMajor+1)_".0.0-0"
                    }

                    // Maximum
                    set tComparators = tComparators_$listbuild("<"_tMax)

                    // X ranges have been handled for this case - disable adding another comparator later.
                    set tIsXRange = 0
                }
            }

            if tIsXRange {
                // X ranges
                // Recompute tMajorMinorPatch based on tExpr (possibly modified in other parsing)
                set tMajorMinorPatch = $translate($zstrip($piece($piece(tExpr,"-"),"+"),"<W","<>="),"X*","xx")
                set tMajor = $piece(tMajorMinorPatch,".",1)
                set tMinor = $piece(tMajorMinorPatch,".",2)
                set tPatch = $piece(tMajorMinorPatch,".",3)

                if (tExpr = "") || (tExpr = "*") || (tMajor = "") {
                    // Accept anything!
                    set tComparators = tComparators_$listbuild(">=0.0.0")
                } elseif (tMinor = "") || (tMinor = "x") {
                    set tComparators = tComparators_$listbuild(">="_tMajor_".0.0","<"_(tMajor+1)_".0.0-0")
                } elseif (tPatch = "") || (tPatch = "x") {
                    set tComparators = tComparators_$listbuild(">="_tMajor_"."_tMinor_".0","<"_tMajor_"."_(tMinor+1)_".0-0")
                }
            }
        }
        if $$$ISERR(tSC) {
            quit
        }

        // Actually add primitive comparators to the list.
        set tPtr = 0
        while $listnext(tComparators,tPtr,tExpr) {
            // >=0.0.0 seems to be a no-op, so skip it. (Implications for prerelease 0.0.0 versions?)
            if (tExpr '= ">=0.0.0") {
                set tSC = ##class(%IPM.General.SemanticVersionExpression.Comparator).FromString(tExpr,.tComparator)
                if $$$ISERR(tSC) {
                    quit
                }
                do pRange.Comparators.Insert(tComparator)
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method InRange(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
    set tSatisfied = 1
    for i=1:1:..Comparators.Count() {
        if '..Comparators.GetAt(i).Evaluate(pVersion) {
            set tSatisfied = 0
            quit
        }
    }
    quit tSatisfied
}

Method IsSatisfiedBy(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
	Quit ..InRange(pVersion)
}

Storage Default
{
<Data name="RangeState">
<Value name="1">
<Value>Comparators</Value>
</Value>
<Value name="2">
<Value>Expression</Value>
</Value>
</Data>
<State>RangeState</State>
<StreamLocation>^IPM.General.SemVer.RangeS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
