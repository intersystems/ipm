Class %IPM.DependencyAnalyzer.Problem Extends %Persistent
{

Parameter DEFAULTGLOBAL = "^IPM.DependencyAnalyzer.Problem";

Index Run On Run [ Type = bitmap ];

Relationship Run As %IPM.DependencyAnalyzer.ModuleResults [ Cardinality = one, Inverse = Problems ];

Property ProblemClass As %Dictionary.Classname [ Required ];

Property ProblemMember As %Dictionary.Identifier [ Required ];

Property ProblemLine As %Integer(MINVAL = 0) [ Required ];

Property ProblemCode As %String(MAXLEN = "") [ Required ];

Property ReferencedModule As %String(MAXLEN = 255);

Property ReferencedClass As %Dictionary.Classname [ Required ];

Property ReferencedClassExists As %Boolean [ InitialExpression = 1 ];

/// Returns a string that, when shown in the Studio output pane, can be clicked to jump to this location in code.
Method ToString() As %String [ CodeMode = expression ]
{
..ProblemClass_".CLS("_..ProblemMember_"+"_..ProblemLine_") "_..ProblemCode
}

Storage Default
{
<Data name="ProblemDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>ProblemClass</Value>
</Value>
<Value name="4">
<Value>ProblemMember</Value>
</Value>
<Value name="5">
<Value>ProblemLine</Value>
</Value>
<Value name="6">
<Value>ProblemCode</Value>
</Value>
<Value name="7">
<Value>ReferencedModule</Value>
</Value>
<Value name="8">
<Value>ReferencedClass</Value>
</Value>
<Value name="9">
<Value>ReferencedClassExists</Value>
</Value>
</Data>
<DataLocation>^IPM.DependencyAnalyzer.ProblemD</DataLocation>
<DefaultData>ProblemDefaultData</DefaultData>
<IdLocation>^IPM.DependencyAnalyzer.ProblemD</IdLocation>
<IndexLocation>^IPM.DependencyAnalyzer.ProblemI</IndexLocation>
<StreamLocation>^IPM.DependencyAnalyzer.ProblemS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
