Class %IPM.Storage.SystemRequirements Extends (%Persistent, %XML.Adaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.SystemRequirements";

Property VersionString As %String(MAXLEN = 100, XMLNAME = "Version", XMLPROJECTION = "ATTRIBUTE");

Property Version As %IPM.General.SemanticVersionExpression(XMLPROJECTION = "NONE");

Method VersionStringSet(tValue) As %Status
{
	Set i%VersionString = tValue
	Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tValue,.tExpression)
	If $$$ISOK(tSC) {
		Set ..Version = tExpression
	}
	Quit tSC
}

Property Interoperability As %String(VALUELIST = ",enabled,disabled", XMLPROJECTION = "ATTRIBUTE");

Property Health As %String(VALUELIST = ",true,false", XMLPROJECTION = "ATTRIBUTE");

Method CheckRequirements() As %Status
{
	Set tSC = $$$OK
	Set tSC = $SYSTEM.Status.AppendStatus(tSC,..CheckVersion())
	Set tSC = $SYSTEM.Status.AppendStatus(tSC,..CheckInteroperability())
	Set tSC = $SYSTEM.Status.AppendStatus(tSC,..CheckHealth())
	Return tSC
}

Method CheckVersion() As %Status
{
  Set tSystemVersion = +$SYSTEM.Version.GetMajor() _ "." _ +$SYSTEM.Version.GetMinor() ;_ "." _ +$System.Version.GetPoint() _ "+" _ $System.Version.GetBuildNumber()
	If (..VersionString = "") { Return $$$OK } 
	Try {
		Set CurrentSystemVersion = ##class(%IPM.General.SemanticVersion).FromString(tSystemVersion)
		If ('..Version.IsSatisfiedBy(CurrentSystemVersion)) {
			Return $$$ERROR($$$GeneralError,"The module cannot be installed on the current version (" _ tSystemVersion _ ") of the system, version """ _ ..VersionString _ """ is required")
    }
		Return $$$OK
	} Catch ex {
		Return $$$ERROR($$$GeneralError, "Unable to check reqired system version")
	}
}

/// Checks if Interoperability specification is satisfied. Health="true" implies Interoperability="enabled"
Method CheckInteroperability() As %Status
{
	If ..Interoperability = "enabled" {
		Set tInteroperabilityRequired = 1
	} ElseIf ..Interoperability = "disabled" {
		Set tInteroperabilityRequired = 0
	}  ElseIf ..Health = "true" {
		Set tInteroperabilityRequired = 1
	} Else {
		Set tInteroperabilityRequired = 0
	}
	Set tInteroperabilityEnabled = ##class(%EnsembleMgr).IsEnsembleNamespace($NAMESPACE) && ##class(%EnsembleMgr).validateNamespace($NAMESPACE, 1)
	If tInteroperabilityRequired && ('tInteroperabilityEnabled) {
		Return $$$ERROR($$$GeneralError, "The module requires Interoperability Production Enabled. Namespace <"_$NAMESPACE_"> doesn't support Interoperability Production")
	}
	Return $$$OK
}

Method CheckHealth() As %Status
{
	If ..Health = "true" && '$LISTFIND($SYSTEM.Version.GetISCComponents(), "Health") {
		Set msg = "The module requires IRIS-for-Health, HealthConnect, or HealthShare. Current system doesn't satisfy this requirement."
		Return $$$ERROR($$$GeneralError, msg)
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
<Value name="6">
<Value>Health</Value>
</Value>
</Data>
<DataLocation>^IPM.Storage.SystemRequirementsD</DataLocation>
<DefaultData>SystemRequirementsDefaultData</DefaultData>
<IdLocation>^IPM.Storage.SystemRequirementsD</IdLocation>
<IndexLocation>^IPM.Storage.SystemRequirementsI</IndexLocation>
<StreamLocation>^IPM.Storage.SystemRequirementsS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
