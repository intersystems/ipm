Class %IPM.Storage.InvokeReference Extends (%Persistent, %XML.Adaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.InvokeReference";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Class As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE") [ Required ];

Property Method As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE") [ Required ];

Property Phase As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = "Configure" ];

Property When As %String(MAXLEN = 255, VALUELIST = ",Before,After", XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = "After", SqlFieldName = _WHEN ];

Property CheckStatus As %Boolean(XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = 0 ];

Property Arg As list Of %String(MAXLEN = 255, XMLNAME = "Arg", XMLPROJECTION = "ELEMENT");

Relationship Module As %IPM.Storage.Module(XMLPROJECTION = "NONE") [ Cardinality = parent, Inverse = Invokes, SqlFieldName = ModuleItem ];

Method GetArgsArray(pParams, Output args) As %Status
{
  Set args = ..Arg.Count()
  For i=1:1:..Arg.Count() {
    Set args(i) = ..Module.%Evaluate(..Arg.GetAt(i), .pParams)
    If (args(i)=$Char(0)) { Set args(i) = "" }
  }
  
  /// Add custom parameters support for Invoke args
  Do ##class(%IPM.Storage.ModuleSetting.Default).GetCustomParameters(.customParams,..Module,.pParams)
  Do ##class(%IPM.Storage.ModuleSetting.Default).EvaluateArgs(.args,.customParams)
  /// Perform a second pass to manage embeded vars, ex:
  /// <Default Name="MyDir" Value="${mgrdir}MySubDir"></Default>
  Set i = ""
  For  {
  	Set i = $Order(args(i),1,value)
  	Quit:i=""
  	Set args(i) = ..Module.%Evaluate(value, .pParams)
  }
  	
  Quit $$$OK
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
<Value>CheckStatus</Value>
</Value>
<Value name="6">
<Value>Phase</Value>
</Value>
<Value name="7">
<Value>When</Value>
</Value>
</Data>
<DataLocation>{%%PARENT}("Invokes")</DataLocation>
<DefaultData>InvokeReferenceDefaultData</DefaultData>
<IdLocation>^IPM.Storage.InvokeReferenceC("Invokes")</IdLocation>
<IndexLocation>^IPM.Storage.InvokeReferenceI</IndexLocation>
<StreamLocation>^IPM.Storage.InvokeReferenceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
