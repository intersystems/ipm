Class %ZPM.PackageManager.Developer.DependencyAnalyzer.Problem Extends %Persistent
{

Index Run On Run [ Type = bitmap ];

Relationship Run As %ZPM.PackageManager.Developer.DependencyAnalyzer.ModuleResults [ Cardinality = one, Inverse = Problems ];

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
<Value>ReferencedModule</Value>
</Value>
<Value name="7">
<Value>ReferencedClass</Value>
</Value>
<Value name="8">
<Value>ProblemCode</Value>
</Value>
<Value name="9">
<Value>ReferencedClassExists</Value>
</Value>
</Data>
<DataLocation>^%ZPM.Dev.AnalyzerProblemD</DataLocation>
<DefaultData>ProblemDefaultData</DefaultData>
<IdLocation>^%ZPM.Dev.AnalyzerProblemD</IdLocation>
<IndexLocation>^%ZPM.Dev.AnalyzerProblemI</IndexLocation>
<StreamLocation>^%ZPM.Dev.AnalyzerProblemS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
