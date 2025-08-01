/// @API.Object.Instantiable
/// @Modifier Availability InterSystems
Class %IPM.Storage.ModuleReference Extends (%SerialObject, %XML.Adaptor, %IPM.Utils.ComparisonAdaptor) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleReference";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Name As %String(MAXLEN = 255) [ Required ];

/// Does not need code generation for comparison because <property>VersionString</property> comparison is good enough
Property Version As %IPM.General.SemanticVersionExpression(ForceCodeGenerate = 0, XMLPROJECTION = "NONE") [ Required ];

Property VersionString As %String(MAXLEN = 100, XMLNAME = "Version") [ Required ];

/// Restrict the scope in which this reference is relevant. Default is "all scopes"
Property Scope As %String(VALUELIST = ",test,verify", XMLPROJECTION = "ATTRIBUTE");

Property DisplayName As %String(MAXLEN = 255) [ Internal ];

Method VersionStringSet(tValue) As %Status
{
    set i%VersionString = tValue
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tValue,.tExpression)
    if $$$ISOK(tSC) {
        set ..Version = tExpression
    }
    quit tSC
}

Method NameSet(val As %RawString) As %Status
{
    set i%DisplayName = val
    set i%Name = $$$lcase(val)
    quit $$$OK
}

Storage Default
{
<Data name="ModuleReferenceState">
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>Version</Value>
</Value>
<Value name="3">
<Value>VersionString</Value>
</Value>
<Value name="4">
<Value>Scope</Value>
</Value>
<Value name="5">
<Value>DisplayName</Value>
</Value>
</Data>
<State>ModuleReferenceState</State>
<StreamLocation>^IPM.Storage.ModuleReferenceS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
