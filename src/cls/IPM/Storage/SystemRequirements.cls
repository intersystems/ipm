Include %IPM.Common

Class %IPM.Storage.SystemRequirements Extends (%Persistent, %XML.Adaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.SystemRequirements";

Property VersionString As %String(MAXLEN = 100, XMLNAME = "Version", XMLPROJECTION = "ATTRIBUTE");

Property Version As %IPM.General.SemanticVersionExpression(XMLPROJECTION = "NONE");

Method VersionStringSet(tValue) As %Status
{
    set i%VersionString = tValue
    set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tValue,.tExpression)
    if $$$ISOK(tSC) {
        set ..Version = tExpression
    }
    quit tSC
}

Property Interoperability As %String(VALUELIST = ",enabled,disabled", XMLPROJECTION = "ATTRIBUTE");

Property Health As %Boolean(XMLPROJECTION = "ATTRIBUTE");

Property IPMVersion As %String(MAXLEN = 256, XMLPROJECTION = "ATTRIBUTE");

Method CheckRequirements() As %Status
{
    set tSC = $$$OK
    set tSC = $system.Status.AppendStatus(tSC,..CheckVersion())
    set tSC = $system.Status.AppendStatus(tSC,..CheckInteroperability())
    set tSC = $system.Status.AppendStatus(tSC,..CheckHealth())
    set tSC = $system.Status.AppendStatus(tSC,..CheckIPMVersion())
    return tSC
}

Method CheckVersion() As %Status
{
    set tSystemVersion = +$system.Version.GetMajor() _ "." _ +$system.Version.GetMinor() ;_ "." _ +$System.Version.GetPoint() _ "+" _ $System.Version.GetBuildNumber()
    if (..VersionString = "") {
        return $$$OK
    }
    try {
        set CurrentSystemVersion = ##class(%IPM.General.SemanticVersion).FromString(tSystemVersion)
        if ('..Version.IsSatisfiedBy(CurrentSystemVersion)) {
            return $$$ERROR($$$GeneralError,"The module cannot be installed on the current version (" _ tSystemVersion _ ") of the system, version """ _ ..VersionString _ """ is required")
        }
        return $$$OK
    } catch ex {
        return $$$ERROR($$$GeneralError, "Unable to check reqired system version")
    }
}

/// Checks if Interoperability specification is satisfied. Health="true" implies Interoperability="enabled"
Method CheckInteroperability() As %Status
{
    set tInteroperabilityRequired = $case(..Interoperability, "enabled":1, :0) || ..Health
    set tInteroperabilityEnabled = ..IsInteroperabilityEnabled()
    if tInteroperabilityRequired && ('tInteroperabilityEnabled) {
        return $$$ERROR($$$GeneralError, "This module requires an interoperability-enabled namespace. "_$namespace_" is not interoperability-enabled.")
    }
    return $$$OK
}

Method CheckHealth() As %Status
{
    set tIsHealthInstance = ..IsHealthInstance()
    if ..Health && 'tIsHealthInstance {
        set msg = "The module requires InterSystems IRIS for Health, HealthConnect, or HealthShare. Current system is not compatible."
        return $$$ERROR($$$GeneralError, msg)
    } elseif ..Health = 0 && tIsHealthInstance {
        set msg = "The module cannot be installed on InterSystems IRIS for Health, HealthConnect, or HealthShare. Current system is not compatible."
        return $$$ERROR($$$GeneralError, msg)
    }
    return $$$OK
}

Method CheckIPMVersion() As %Status
{
    if ..IPMVersion = "" {
        return $$$OK
    }
    do ##class(%IPM.Main).GetVersion($$$IPMModuleName,.out)
    set tVersion = ##class(%IPM.General.SemanticVersion).FromString($listget(out($$$IPMModuleName), 2))
    $$$ThrowOnError(##class(%IPM.General.SemanticVersionExpression).FromString(..IPMVersion,.tExpression))
    if tVersion.Satisfies(tExpression) {
        return $$$OK
    }
    return $$$ERROR($$$GeneralError, "The module requires IPM version "_..IPMVersion_". Current IPM version is "_tVersion.ToString())
}

ClassMethod IsHealthInstance() As %Boolean
{
  set cls = "%ZHSLIB.HealthShareMgr", mthd = "IsHealthShareInstance"
  return $listfind($system.Version.GetISCComponents(), "Health") || ($system.CLS.IsMthd(cls, mthd) && $classmethod(cls, mthd))
}

ClassMethod IsInteroperabilityEnabled() As %Boolean
{
  return ##class(%EnsembleMgr).IsEnsembleNamespace($namespace) && ##class(%EnsembleMgr).validateNamespace($namespace, 1)
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
<Value name="7">
<Value>IPMVersion</Value>
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
