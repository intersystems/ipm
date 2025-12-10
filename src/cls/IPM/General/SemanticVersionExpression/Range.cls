Class %IPM.General.SemanticVersionExpression.Range Extends %IPM.General.SemanticVersionExpression.IComparable
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

Method IsSatisfiedBy(version As %IPM.General.SemanticVersion) As %Boolean
{
	quit ..InRange(version)
}

/// Find the intersection of two ranges.
/// Returns a new Range object representing the intersection.
/// Return "" if there is no intersection.
/// Example: Merge(">=1.0.0 <3.0.0", ">1.1.0 <3.4.0") returns ">1.1.0 <3.0.0"
ClassMethod Intersect(
	range1 As %IPM.General.SemanticVersionExpression.Range,
	range2 As %IPM.General.SemanticVersionExpression.Range) As %IPM.General.SemanticVersionExpression.Range
{
    // Collect all comparators from both ranges
    set lowerBounds = ##class(%ListOfObjects).%New()  // List of >= or > comparators
    set upperBounds = ##class(%ListOfObjects).%New()  // List of < or <= comparators
    set exactMatches = ##class(%ListOfObjects).%New()  // List of = comparators

    // Process comparators from ranges
    do ..GroupComparators(range1,.lowerBounds,.upperBounds,.exactMatches)
    do ..GroupComparators(range2,.lowerBounds,.upperBounds,.exactMatches)

    // If any exact matches exist, they must all be equal and the final range is just that version
    if (exactMatches.Count() > 0) {
        set firstExact = exactMatches.GetAt(1)
        for i = 2:1:exactMatches.Count() {
            set comp = exactMatches.GetAt(i)
            if (firstExact.Major '= comp.Major) || (firstExact.Minor '= comp.Minor) || (firstExact.Patch '= comp.Patch) || (firstExact.Prerelease '= comp.Prerelease) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Exact version matches do not agree: %1 and %2", firstExact.ToResolvedString(), comp.ToResolvedString())))
            }
        }
        // All exact matches agree; return that version after converting to range
        set sc = ..FromString(firstExact.ToString(), .firstExactRange)
        $$$ThrowOnError(sc)
        return firstExactRange
    }

    // Find the most restrictive lower bound (the maximum of all lower bounds)
    set maxLowerBound = ""
    for i = 1:1:lowerBounds.Count() {
        set comp = lowerBounds.GetAt(i)
        if (maxLowerBound = "") {
            set maxLowerBound = comp
        } else {
            // Compare the two bounds and keep the more restrictive one
            if ..CompareVersions(maxLowerBound, comp) < 0 {
                // comp is more restrictive (higher version or stricter operator)
                set maxLowerBound = comp
            }
        }
    }

    // Find the most restrictive upper bound (the minimum of all upper bounds)
    set minUpperBound = ""
    for i = 1:1:upperBounds.Count() {
        set comp = upperBounds.GetAt(i)
        if (minUpperBound = "") {
            set minUpperBound = comp
        } else {
            // Compare the two bounds and keep the more restrictive one
            if ..CompareVersions(minUpperBound, comp) > 0 {
                // comp is more restrictive (lower version or stricter operator)
                set minUpperBound = comp
            }
        }
    }

    // Validate that the intersection is non-empty
    if (maxLowerBound '= "") && (minUpperBound '= "") {
        if '..IsIntersectionValid(maxLowerBound, minUpperBound) {
            return ""
        }
    }

    // Build the merged range
    set mergedExpression = ""
    if (maxLowerBound '= "") {
        set mergedExpression = maxLowerBound.ToResolvedString()
    }
    if (minUpperBound '= "") {
        if (mergedExpression '= "") {
            set mergedExpression = mergedExpression_" "
        }
        set mergedExpression = mergedExpression_minUpperBound.ToResolvedString()
    }

    if (mergedExpression = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Cannot merge ranges %1 and %2: no valid comparators found", maxLowerBound.ToResolvedString(), minUpperBound.ToResolvedString())))
    }

    // Create and return the merged range
    set sc = ..FromString(mergedExpression, .mergedRange)
    $$$ThrowOnError(sc)

    return mergedRange
}

/// Group comparators into lower bounds, upper bounds, and exact matches.
ClassMethod GroupComparators(
	range As %IPM.General.SemanticVersionExpression.Range,
	ByRef lowerBounds As %ListOfObjects,
	ByRef upperBounds As %ListOfObjects,
	ByRef exactMatches As %ListOfObjects) [ Internal, Private ]
{
    for i=1:1:range.Comparators.Count() {
        set comp = range.Comparators.GetAt(i)
        if (comp.Operator = ">=") || (comp.Operator = ">") {
            do lowerBounds.Insert(comp)
        } elseif (comp.Operator = "<") || (comp.Operator = "<=") {
            do upperBounds.Insert(comp)
        } elseif (comp.Operator = "=") {
            do exactMatches.Insert(comp)
        }
    }
}

/// Helper method to compare two version comparators
/// Returns: 1 if comp1 > comp2, -1 if comp1 < comp2, 0 if equal
ClassMethod CompareVersions(
	comp1 As %IPM.General.SemanticVersionExpression.Comparator,
	comp2 As %IPM.General.SemanticVersionExpression.Comparator) As %Integer [ Internal, Private ]
{
    // Create semantic versions for comparison
    set v1 = comp1.ExtractToSemanticVersion()
    set v2 = comp2.ExtractToSemanticVersion()

    // Compare versions
    if v1.Follows(v2) {
        set result = 1
    } elseif v2.Follows(v1) {
        set result = -1
    } else {
        // Versions are equal, compare operators
        // For lower bounds: > is more restrictive than >=
        // For upper bounds: < is more restrictive than <=
        if (comp1.Operator = ">") && (comp2.Operator = ">=") {
            set result = 1
        } elseif (comp1.Operator = ">=") && (comp2.Operator = ">") {
            set result = -1
        } elseif (comp1.Operator = "<") && (comp2.Operator = "<=") {
            set result = -1
        } elseif (comp1.Operator = "<=") && (comp2.Operator = "<") {
            set result = 1
        } else {
            set result = 0
        }
    }
    return result
}

/// Helper method to validate that lower bound < upper bound. Returns 1 if so, else 0.
ClassMethod IsIntersectionValid(
	lowerBound As %IPM.General.SemanticVersionExpression.Comparator,
	upperBound As %IPM.General.SemanticVersionExpression.Comparator) As %Boolean [ Internal, Private ]
{
    // Create semantic versions for comparison
    set vLower = lowerBound.ExtractToSemanticVersion()
    set vUpper = upperBound.ExtractToSemanticVersion()

    // Check if lower bound is less than upper bound
    if vUpper.Follows(vLower) {
        // Valid: upper > lower
        return 1
    }
    if vLower.Follows(vUpper) {
        // Invalid: lower > upper
        return 0
    }
    // Versions are equal, check operators
    // Valid cases: >=X and <=X (allows exactly X)
    // Invalid cases: >X and <X (no version can satisfy both)
    if (lowerBound.Operator = ">") || (upperBound.Operator = "<") {
        return 0
    }
    return 1
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
