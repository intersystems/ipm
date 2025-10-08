/// This resource processor sets the ^%SYS("CSP") global to a specified value during the Compile phase
/// This is primarily for backwards compatibility with older IPM versions (v0.7 or earlier) that used this to control CSP application settings.
/// Newer versions of IPM (v0.9 and later) should use the CPF resource processor instead
/// Example usage in module.xml:
/// ```
/// <SystemSetting Name="CSP.Test" Value="123"/>
/// ```
/// This will set ^%SYS("CSP","Test") = "123"
Class %IPM.ResourceProcessor.SystemSetting Extends %IPM.ResourceProcessor.Abstract [ Deprecated ]
{

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Name,Value";

Property Name As %String(MAXLEN = "") [ Required ];

Property Value As %String(MAXLEN = "");

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
  if pPhase = "Compile" {
    if $piece(..ResourceReference.Name, ".") = "CSP" {
      set tName = $piece(..Name, ".", 2)
      if tName '= "" {
        set ^%SYS("CSP", tName) = ..Value
        set pResourceHandled = 1
      }
    }
  }
  quit $$$OK
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
  kill pResourceArray
  quit $$$OK
}

}
