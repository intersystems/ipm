Class %IPM.General.SemanticVersionExpression.Range Extends %SerialObject
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemVer.Range";

Property Expression As %String [ ReadOnly ];

Property Comparators As list Of %IPM.General.SemanticVersionExpression.Comparator;

Method %OnNew(pRangeExpr As %String) As %Status [ Private, ServerOnly = 1 ]
{
	Set i%Expression = pRangeExpr
	Quit $$$OK
}

Method ToString() As %String [ CodeMode = expression ]
{
..Expression
}

Method ToResolvedString() As %String
{
	Set tCompList = ""
	For i=1:1:..Comparators.Count() {
		Set tComp = ..Comparators.GetAt(i)
		Set tCompList = tCompList_$ListBuild(tComp.ToResolvedString())
	}
	Quit $ListToString(tCompList," ")
}

ClassMethod FromString(pRangeExpr As %String, Output pRange As %IPM.General.SemanticVersionExpression.Range) As %Status
{
	Set tSC = $$$OK
	Set pRange = ..%New(pRangeExpr)
	Try {
		// Separate AND-ed comparators, rejoining ranges with dashes to handle individually
		Set tSpaceParts = $ListFromString(pRangeExpr," ")
		Set tPtr = 0
		Set tExpressions = ""
		While $ListNext(tSpaceParts,tPtr,tPart) {
			If (tPart = "-") {
				// Convert hyphen ranges to simple comparators
				Set tFound = $ListNext(tSpaceParts,tPtr,tMax)
				If 'tFound {
					Set tSC = $$$ERROR($$$GeneralError,"Invalid range expression: "_pRangeExpr)
					Quit
				}
				
				Set tMin = $List(tExpressions,*)
				
				// Partial version as min version: add zeros.
				Set tMinDotLength = $Length(tMin,".")
				If (tMinDotLength < 3) {
					For i=2:-1:tMinDotLength {
						Set tMin = tMin_".0"
					}
				}
				Set $List(tExpressions,*) = ">="_tMin
				
				// Partial version as max version: implied .x
				Set tMaxDotLength = $Length(tMax,".")
				Set tOp = "<="
				If (tMaxDotLength < 3) {
					Set tOp = "<"
					Set $Piece(tMax,".",tMaxDotLength) = 1 + $Piece(tMax,".",tMaxDotLength)
					For i=2:-1:tMaxDotLength {
						Set tMax = tMax_".0"
					}
				}
				Set tExpressions = tExpressions_$ListBuild(tOp_tMax)
			} Else {
				Set tExpressions = tExpressions_$ListBuild(tPart)
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Convert advanced ranges to primitive comparators
		Set tComparators = ""
		Set tPtr = 0
		While $ListNext(tExpressions,tPtr,tExpr) {
			// Get part after operator and before build/metadata
			// Normalize x ranges
			Set tMajorMinorPatch = $Translate($ZStrip($Piece($Piece(tExpr,"-"),"+"),"<W","<>=^~"),"X*","xx")
      If tMajorMinorPatch?1"20"2N1"."1N {
        Set tExpr = tExpr _ ".0"
        Set tMajorMinorPatch = tMajorMinorPatch _ ".0"
      }
			Set tMajor = $Piece(tMajorMinorPatch,".",1)
			Set tMinor = $Piece(tMajorMinorPatch,".",2)
			Set tPatch = $Piece(tMajorMinorPatch,".",3)
			
			// Detect different expression cases
			Set tIsXRange = (tMajorMinorPatch [ "x") || (tExpr = "*") || (tMinor = "") || (tPatch = "")
			Set tIsTildeRange = ($Extract(tExpr) = "~")
			Set tIsCaretRange = ($Extract(tExpr) = "^")
			
			If '(tIsXRange || tIsTildeRange || tIsCaretRange) {
				// Primitive comparator
				Set tComparators = tComparators_$ListBuild(tExpr)
			} ElseIf tIsTildeRange {
				// Tilde ranges:
				// "Allows patch-level changes if a minor version is specified on the comparator. Allows minor-level changes if not."
				
				Set tExpr = $Extract(tExpr,2,*)
				Set tDotLength = $Length(tExpr,".")
				
				If (tDotLength < 3) {
					// Convert missing minor/patch to "X range":
					Set tExpr = tExpr_".x"
					Set tIsXRange = 1
				} Else {
					// Minimum: at least the full specified version
					Set tComparators = tComparators_$ListBuild(">="_tExpr)
					
					// Maximum based on leftmost nonzero value
					Set tMajor = $Piece(tExpr,".",1)
					Set tMinor = $Piece(tExpr,".",2)
					
					Set tComparators = tComparators_$ListBuild("<"_tMajor_"."_(tMinor+1)_".0-0")
				}
			} ElseIf tIsCaretRange {
				// Caret ranges:
				// "Allows changes that do not modify the left-most non-zero digit in the [major, minor, patch] tuple.
				// In other words, this allows patch and minor updates for versions 1.0.0 and above, patch updates for versions 0.X >=0.1.0,
				// and no updates for versions 0.0.X."
				// This case also handles the "x range" and caret range in combination.
				
				Set tExpr = $Extract(tExpr,2,*)
				Set tDotLength = $Length(tExpr,".")
				Set tMajor = $Piece(tMajorMinorPatch,".",1)
				Set tMinor = $Piece(tMajorMinorPatch,".",2)
				Set tPatch = $Piece(tMajorMinorPatch,".",3)
				If (tDotLength < 3) {
					If (tMajor '= 0) && 'tIsXRange {
						Set tComparators = tComparators_$ListBuild(">="_$Replace(tExpr,".x",".0"),"<"_(tMajor+1)_".0.0-0")
						Set tIsXRange = 0
					} Else {
						// Detected and properly handled by X-range.
					}
				} Else {
					// Minimum
					Set tComparators = tComparators_$ListBuild(">="_$Replace(tExpr,".x",".0"))
					
					Set tMax = ""
					If (+tMajor = 0) && (tMinor '= "x") {
						If (+tMinor = 0) && (tPatch '= "x") {
							Set tMax = "0.0."_(tPatch+1)_"-0"
						} Else {
							Set tMax = "0."_(tMinor+1)_".0-0"
						}
					} Else {
						Set tMax = (tMajor+1)_".0.0-0"
					}
					
					// Maximum
					Set tComparators = tComparators_$ListBuild("<"_tMax)
					
					// X ranges have been handled for this case - disable adding another comparator later.
					Set tIsXRange = 0
				}
			}
			
			If tIsXRange {
				// X ranges
				// Recompute tMajorMinorPatch based on tExpr (possibly modified in other parsing)
				Set tMajorMinorPatch = $Translate($ZStrip($Piece($Piece(tExpr,"-"),"+"),"<W","<>="),"X*","xx")
				Set tMajor = $Piece(tMajorMinorPatch,".",1)
				Set tMinor = $Piece(tMajorMinorPatch,".",2)
				Set tPatch = $Piece(tMajorMinorPatch,".",3)
				
				If (tExpr = "") || (tExpr = "*") || (tMajor = "") {
					// Accept anything!
					Set tComparators = tComparators_$ListBuild(">=0.0.0")
				} ElseIf (tMinor = "") || (tMinor = "x") {
					Set tComparators = tComparators_$ListBuild(">="_tMajor_".0.0","<"_(tMajor+1)_".0.0-0")
				} ElseIf (tPatch = "") || (tPatch = "x") {
					Set tComparators = tComparators_$ListBuild(">="_tMajor_"."_tMinor_".0","<"_tMajor_"."_(tMinor+1)_".0-0")
				}
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Actually add primitive comparators to the list.
		Set tPtr = 0
		While $ListNext(tComparators,tPtr,tExpr) {
			// >=0.0.0 seems to be a no-op, so skip it. (Implications for prerelease 0.0.0 versions?)
			If (tExpr '= ">=0.0.0") {
				Set tSC = ##class(%IPM.General.SemanticVersionExpression.Comparator).FromString(tExpr,.tComparator)
				If $$$ISERR(tSC) {
					Quit
				}
				Do pRange.Comparators.Insert(tComparator)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method InRange(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
	Set tSatisfied = 1
	For i=1:1:..Comparators.Count() {
		If '..Comparators.GetAt(i).Evaluate(pVersion) {
			Set tSatisfied = 0
			Quit
		}
	}
	Quit tSatisfied
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
