Class %ZPM.PackageManager.Developer.DependencyAnalyzer.ModuleResults Extends %Persistent
{

Index TargetModule On TargetModule;

Property TargetModule As %String(MAXLEN = 255) [ Required ];

Property TimeStamp As %TimeStamp [ InitialExpression = {$zdt($zts,3)} ];

Relationship Problems As %ZPM.PackageManager.Developer.DependencyAnalyzer.Problem [ Cardinality = many, Inverse = Run ];

/// Displays the module's results; particularly effective writing to the Studio output window, where lines can be clicked to jump to that spot in code.
Method Display()
{
	Set tProblemKey = ""
	For {
		#dim tProblem As %ZPM.PackageManager.Developer.DependencyAnalyzer.Problem
		Set tProblem = ..Problems.GetNext(.tProblemKey)
		If (tProblemKey = "") {
			Quit
		}
		
		Set tSub1 = $Select(tProblem.ReferencedClassExists:tProblem.ReferencedModule,1:" ")
		Set tSub2 = tProblem.ReferencedClass
		Set tProblemMap(tSub1,tSub2,$Increment(tProblemMap(tSub1,tSub2))) = tProblem.ToString()
	}
	
	Set tReferencedModuleKey = ""
	For {
		Set tReferencedModuleKey = $Order(tProblemMap(tReferencedModuleKey))
		If (tReferencedModuleKey = "") {
			Quit
		}
		If ($Increment(tIsFirst) > 1) {
			Write !!
		}
		If (tReferencedModuleKey = " ") {
			Write "Invalid references to missing classes:"
		} Else {
			Write "Invalid references to module ",tReferencedModuleKey," :"
		}
		
		Set tReferencedClassKey = ""
		For {
			Set tReferencedClassKey = $Order(tProblemMap(tReferencedModuleKey,tReferencedClassKey),1,tLineCount)
			If (tReferencedClassKey = "") {
				Quit
			}
			Write !,"Class ",tReferencedClassKey,$Case(tReferencedModuleKey," ":" (missing)",:" (@ "_tReferencedModuleKey_")")
			
			For tLine=1:1:tLineCount {
				Write !,tProblemMap(tReferencedModuleKey,tReferencedClassKey,tLine)
			}
		}
	}
}

Storage Default
{
<Data name="DataDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TargetModule</Value>
</Value>
<Value name="3">
<Value>TimeStamp</Value>
</Value>
</Data>
<DataLocation>^%ZPM.Dev.AnalyzerModuleD</DataLocation>
<DefaultData>DataDefaultData</DefaultData>
<IdLocation>^%ZPM.Dev.AnalyzerModuleD</IdLocation>
<IndexLocation>^%ZPM.Dev.AnalyzerModuleI</IndexLocation>
<StreamLocation>^%ZPM.Dev.AnalyzerModuleS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
