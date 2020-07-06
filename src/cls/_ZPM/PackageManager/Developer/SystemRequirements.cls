Class %ZPM.PackageManager.Developer.SystemRequirements Extends (%Persistent, %XML.Adaptor)
{

Property VersionString As %String(MAXLEN = 100, XMLNAME = "Version", XMLPROJECTION = "ATTRIBUTE");

Property Version As %ZPM.PackageManager.Core.SemanticVersionExpression(XMLPROJECTION = "NONE");

Method VersionStringSet(tValue) As %Status
{
	Set i%VersionString = tValue
	Set tSC = ##class(%ZPM.PackageManager.Core.SemanticVersionExpression).FromString(tValue,.tExpression)
	If $$$ISOK(tSC) {
		Set ..Version = tExpression
	}
	Quit tSC
}

Property Product As %String(XMLPROJECTION = "ATTRIBUTE");

Property Interoperability As %String(VALUELIST = ",enabled,disabled", XMLPROJECTION = "ATTRIBUTE");

Method CheckRequirements() As %Status
{
	Set tSC1 = ..CheckVersion()
	Set tSC2 = ..CheckInteroperability()
	Return $$$ADDSC(tSC1, tSC2)
}

Method CheckVersion() As %Status
{
	Set tSystemMajor = $System.Version.GetMajor()
	Set tSystemMinor = $System.Version.GetMinor()
	If (..VersionString = "") { Return $$$OK } 
	try {
		Set tOperator = ..Version.Options.GetAt(1).Comparators.GetAt(1).Operator
		Set tModuleMajor = ..Version.Options.GetAt(1).Comparators.GetAt(1).Major
		Set tModuleMinor = ..Version.Options.GetAt(1).Comparators.GetAt(1).Minor
		Set tVersionMatch = 0
		Set tCommand = "(tSystemMajor,tModuleMajor,tSystemMinor,tModuleMinor,tVersionMatch) If ((tSystemMajor "_tOperator_" tModuleMajor) && (tSystemMinor "_tOperator_" tModuleMinor)) { Set tVersionMatch = 1 }"

		Xecute (tCommand, tSystemMajor,tModuleMajor,tSystemMinor,tModuleMinor,.tVersionMatch)
		If (tVersionMatch'=1) {
			Return $$$ERROR($$$GeneralError,"The module cannot be installed on the current version ("_tSystemMajor_"."_tSystemMinor_") of the system, version """_..VersionString_""" is required")
		}
		Return $$$OK
	} Catch ex {
		w ex.DisplayString()
		Return $$$ERROR($$$GeneralError, "Unable to check reqired system version")
	}
}

Method CheckInteroperability() As %Status
{
 
	If ( (..Interoperability="enabled") && '##class(%EnsembleMgr).IsEnsembleNamespace($Namespace) ) {
		Return $$$ERROR($$$GeneralError, "The module requires Interoperability Production Enabled. Namespace <"_$Namespace_"> doesn't support Interoperability Production")
	}
	Return $$$OK
}

Storage Default
{
<Data name="SystemRequirementsDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>VersionString</Value>
</Value>
<Value name="3">
<Value>Product</Value>
</Value>
<Value name="4">
<Value>Interoperability</Value>
</Value>
<Value name="5">
<Value>Version</Value>
</Value>
</Data>
<DataLocation>^%ZPM.Packa360D.SystemRequi5D02D</DataLocation>
<DefaultData>SystemRequirementsDefaultData</DefaultData>
<IdLocation>^%ZPM.Packa360D.SystemRequi5D02D</IdLocation>
<IndexLocation>^%ZPM.Packa360D.SystemRequi5D02I</IndexLocation>
<StreamLocation>^%ZPM.Packa360D.SystemRequi5D02S</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
