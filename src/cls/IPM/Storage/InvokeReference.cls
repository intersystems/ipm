Class %IPM.Storage.InvokeReference Extends (%Persistent, %XML.Adaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.InvokeReference";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Class As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE") [ Required ];

Property Method As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE") [ Required ];

Property Phase As %IPM.DataType.PhaseName(XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = "Configure" ];

/// If provided, the Phase property will be ignored. This CustomPhase will be used and no corresponding lifecycle is required.
Property CustomPhase As %IPM.DataType.CustomPhaseName(XMLPROJECTION = "ATTRIBUTE");

Property When As %IPM.DataType.PhaseWhen(XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = "After", SqlFieldName = _WHEN ];

/// Whether to check the status returned by the invoked method.
/// <br/>Tri-state value:
/// <br/>  1: Check status and treat return type as %Status
/// <br/>  0: Do not check status
/// <br/>  "": As default, check the status iff the return type is %Status
Property CheckStatus As %Boolean(XMLPROJECTION = "ATTRIBUTE") [ Deprecated ];

Property Arg As list Of %String(MAXLEN = 255, XMLNAME = "Arg", XMLPROJECTION = "ELEMENT");

Relationship Module As %IPM.Storage.Module(XMLPROJECTION = "NONE") [ Cardinality = parent, Inverse = Invokes, SqlFieldName = ModuleItem ];

Method GetArgsArray(
	pParams,
	Output args) As %Status
{
    set args = ..Arg.Count()
    for i=1:1:..Arg.Count() {
        set args(i) = ..Module.%Evaluate(..Arg.GetAt(i), .pParams)
        if (args(i)=$char(0)) {
            set args(i) = ""
        }
    }
    // Add custom parameters support for Invoke args
    do ##class(%IPM.Storage.ModuleSetting.Default).GetCustomParameters(.customParams,..Module,.pParams)
    do ##class(%IPM.Storage.ModuleSetting.Default).EvaluateArgs(.args,.customParams)
    // Perform a second pass to manage embeded vars, ex:
    // <Default Name="MyDir" Value="${mgrdir}MySubDir"></Default>
    set i = ""
    for  {
        set i = $order(args(i),1,value)
        quit:i=""
        set args(i) = ..Module.%Evaluate(value, .pParams)
    }
    quit $$$OK
}

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tPhase = $select(..CustomPhase'="":..CustomPhase,1:..Phase)
    if (pPhase '= tPhase) || ("Before" '= ..When) {
        quit $$$OK
    }
    quit ..doInvoke(.pParams)
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tPhase = $select(..CustomPhase'="":..CustomPhase,1:..Phase)
    if (pPhase '= tPhase) || ("After" '= ..When) {
        quit $$$OK
    }
    quit ..doInvoke(.pParams)
}

Method doInvoke(ByRef pParams) As %Status
{
    set tSC = $$$OK
    do ..GetArgsArray(.pParams, .args)
    try {
        // By default, with no CheckStatus property set, check status iff return type is %Status
        // In deprecated behavior, CheckStatus=1 means check status regardless of type and CheckStatus=0 means do not check anything
        set rettype = $$$comMemberKeyGetO(origin,..Class,$$$cCLASSmethod,..Method,$$$cMETHreturntype)
        if (rettype="%Library.Status" || ..CheckStatus) && (..CheckStatus'=0) {
            set tSC = $classmethod(..Class, ..Method, args...)
        } else {
            do $classmethod(..Class, ..Method, args...)
        }
    } catch ex {
        set tSC = ex.AsStatus()
    }
    #; write !, "tSC: " _  tSC
    quit tSC
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
<Value name="8">
<Value>CustomPhase</Value>
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
