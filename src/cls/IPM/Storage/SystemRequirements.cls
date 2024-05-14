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

Property Health As %Boolean(XMLPROJECTION = "ATTRIBUTE");

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
  Set tSystemVersion = +$System.Version.GetMajor() _ "." _ +$System.Version.GetMinor() ;_ "." _ +$System.Version.GetPoint() _ "+" _ $System.Version.GetBuildNumber()
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
	Set tInteroperabilityRequired = $Case(..Interoperability, "enabled":1, :0) || ..Health
	Set tInteroperabilityEnabled = ..IsInteroperabilityEnabled()
	If tInteroperabilityRequired && ('tInteroperabilityEnabled) {
		Return $$$ERROR($$$GeneralError, "This module requires an interoperability-enabled namespace. "_$Namespace_" is not interoperability-enabled.")
	}
	Return $$$OK
}

Method CheckHealth() As %Status
{
	set tIsHealthInstance = ..IsHealthInstance()
	If ..Health && 'tIsHealthInstance {
		Set msg = "The module requires InterSystems IRIS for Health, HealthConnect, or HealthShare. Current system is not compatible."
		Return $$$ERROR($$$GeneralError, msg)
	} ElseIf ..Health = 0 && tIsHealthInstance {
		Set msg = "The module cannot be installed on InterSystems IRIS for Health, HealthConnect, or HealthShare. Current system is not compatible."
		Return $$$ERROR($$$GeneralError, msg)
	}
	Return $$$OK
}

ClassMethod IsHealthInstance() As %Boolean
{
  set cls = "%ZHSLIB.HealthShareMgr", mthd = "IsHealthShareInstance"
  return $ListFind($System.Version.GetISCComponents(), "Health") || ($System.CLS.IsMthd(cls, mthd) && $ClassMethod(cls, mthd))
}

ClassMethod IsInteroperabilityEnabled() As %Boolean
{
  Return ##class(%EnsembleMgr).IsEnsembleNamespace($NAMESPACE) && ##class(%EnsembleMgr).validateNamespace($NAMESPACE, 1)
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
