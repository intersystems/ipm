Class %ZPM.PackageManager.Developer.InvokeReference Extends (%Persistent, %ZPM.PackageManager.Core.InvokeReference)
{

Property Class As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE") [ Required ];

Property Method As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE") [ Required ];

Property Phase As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = "Configure" ];

Property When As %String(MAXLEN = 255, VALUELIST = ",Before,After", XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = "After" ];

Property CheckStatus As %Boolean(XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = 0 ];

Property Arg As list Of %String(XMLNAME = "Arg", XMLPROJECTION = "ELEMENT");

Relationship Module As %ZPM.PackageManager.Developer.Module(XMLPROJECTION = "NONE") [ Cardinality = parent, Inverse = Invokes ];

Method GetArgsArray(pParams, Output args) As %Status
{
  Set args = ..Arg.Count()
  For i=1:1:..Arg.Count() {
    Set args(i) = ..Module.%Evaluate(..Arg.GetAt(i), .pParams)
    If (args(i)=$Char(0)) { Set args(i) = "" }
  }
}

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
  If (pPhase '= ..Phase) || ("Before" '= ..When) {
	  Quit $$$OK
  }

	Quit ..doInvoke(.pParams)
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
  If (pPhase '= ..Phase) || ("After" '= ..When) {
	  Quit $$$OK
  }

	Quit ..doInvoke(.pParams)
}

Method doInvoke(ByRef pParams) As %Status
{
  Set tSC = $$$OK
  Do ..GetArgsArray(.pParams, .args)

  Try {
    If ..CheckStatus {
      Set tSC = $ClassMethod(..Class, ..Method, args...)
    } Else {
      Do $ClassMethod(..Class, ..Method, args...)
    }
  } Catch ex {
    Set tSC = ex.AsStatus()
  }

  Quit tSC
}

Storage Default
{
<Data name="InvokeReferenceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Class</Value>
</Value>
<Value name="3">
<Value>Method</Value>
</Value>
<Value name="4">
<Value>Arg</Value>
</Value>
<Value name="5">
<Value>Phase</Value>
</Value>
<Value name="6">
<Value>CheckStatus</Value>
</Value>
<Value name="7">
<Value>When</Value>
</Value>
</Data>
<DataLocation>{%%PARENT}("Invokes")</DataLocation>
<DefaultData>InvokeReferenceDefaultData</DefaultData>
<IdLocation>^%ZPM.PackageManager360D.ModuleC("Invokes")</IdLocation>
<IndexLocation>^%ZPM.Packa360D.InvokeRefer378FI</IndexLocation>
<StreamLocation>^%ZPM.Packa360D.InvokeRefer378FS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
