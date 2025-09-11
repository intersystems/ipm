/// Abstract class for semantic version expressions
/// Extends %SerialObject so it can be embedded as property in SemanticVersionExpression
Class %IPM.General.SemanticVersionExpression.IComparable Extends %SerialObject [ Abstract ]
{

/// Returns whether this expression is satisfied by the given pVersion in accordance with Semantic Version conventions
/// E.g. "1.2.3" satisfies ">=1.0.0"
Method IsSatisfiedBy(version As %IPM.General.SemanticVersion) As %Boolean [ Abstract ]
{
}

/// Converts this expression into a standard composable form
Method ToResolvedString() As %String [ Abstract ]
{
}

Storage Default
{
<StreamLocation>^%IPM.General.S9EDF.IComparableS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
