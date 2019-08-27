/// @PublicAPI
Class %ZPM.PackageManager.Core.ModuleReference Extends (%SerialObject, %XML.Adaptor) [ StorageStrategy = "" ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Name As %String(MAXLEN = 255) [ Required ];

Property Version As %ZPM.PackageManager.Core.SemanticVersionExpression(XMLPROJECTION = "NONE") [ Required ];

Property VersionString As %String(MAXLEN = 100, XMLNAME = "Version") [ Required ];

/// Restrict the scope in which this reference is relevant. Default is "all scopes"
Property Scope As %String(VALUELIST = ",test,verify", XMLPROJECTION = "ATTRIBUTE");

Method VersionStringSet(tValue) As %Status
{
	Set i%VersionString = tValue
	Set tSC = ##class(%ZPM.PackageManager.Core.SemanticVersionExpression).FromString(tValue,.tExpression)
	If $$$ISOK(tSC) {
		Set ..Version = tExpression
	}
	Quit tSC
}

Method NameSet(val As %RawString) As %Status
{
	set i%Name = $$$lcase(val)
	QUIT $$$OK
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
<StreamLocation>^ZPM.PackageManager9CFF.ModuleReferB471S</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
