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

Method VersionStringSet(tValue) As %Status
{
	Set i%VersionString = tValue
	Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tValue,.tExpression)
	If $$$ISOK(tSC) {
		Set ..Version = tExpression
	}
	Quit tSC
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
</Data>
<State>ModuleReferenceState</State>
<StreamLocation>^IPM.Storage.ModuleReferenceS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
