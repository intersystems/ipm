Class %IPM.DependencyAnalyzer.ModuleResults Extends %Persistent
{

Parameter DEFAULTGLOBAL = "^IPM.DependencyAnalyzer.Module";

Index TargetModule On TargetModule;

Property TargetModule As %String(MAXLEN = 255) [ Required ];

Property TimeStamp As %TimeStamp [ InitialExpression = {$zdt($zts,3)} ];

Relationship Problems As %IPM.DependencyAnalyzer.Problem [ Cardinality = many, Inverse = Run ];

/// Displays the module's results; particularly effective writing to the Studio output window, where lines can be clicked to jump to that spot in code.
Method Display()
{
	Set tProblemKey = ""
	For {
		#dim tProblem As %IPM.DependencyAnalyzer.Problem
		Set tProblem = ..Problems.GetNext(.tProblemKey)
		If (tProblemKey = "") {
			Quit
		}
		
		Set tSub1 = $Select(tProblem.ReferencedItemExists:tProblem.ReferencedModule,1:" ")
		Set tSub2 = tProblem.ReferencedFileType
		Set tSub3 = tProblem.ReferencedItem
		Set tProblemMap(tSub1,tSub2,tSub3, $Increment(tProblemMap(tSub1,tSub2,tSub3))) = tProblem.ToString()
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
			Write "Invalid references to missing classes/include file"
		} Else {
			Write "Invalid references to module ",tReferencedModuleKey," :"
		}
		
		Set tFileTypeKey = ""
		For {
			Set tFileTypeKey = $Order(tProblemMap(tReferencedModuleKey,tFileTypeKey))
			If (tFileTypeKey = "") {
				Quit
			}
			Set tReferencedItemKey = ""
			For {
				Set tReferencedItemKey = $Order(tProblemMap(tReferencedModuleKey,tFileTypeKey, tReferencedItemKey),1,tLineCount)
				If (tReferencedItemKey = "") {
					Quit
				}
				Write !, $Case(tFileTypeKey, ".INC": "Include File ",:"Class "),tReferencedItemKey_tFileTypeKey,$Case(tReferencedModuleKey," ":" (missing)",:" (@ "_tReferencedModuleKey_")")
			
				For tLine=1:1:tLineCount {
					Write !,tProblemMap(tReferencedModuleKey,tFileTypeKey,tReferencedItemKey, tLine)
				}
			}
		}
	}
}

Storage Default
{
<Data name="ModuleResultsDefaultData">
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
<DataLocation>^IPM.DependencyAnalyzer.ModuleD</DataLocation>
<DefaultData>ModuleResultsDefaultData</DefaultData>
<IdLocation>^IPM.DependencyAnalyzer.ModuleD</IdLocation>
<IndexLocation>^IPM.DependencyAnalyzer.ModuleI</IndexLocation>
<StreamLocation>^IPM.DependencyAnalyzer.ModuleS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
