Class %IPM.ResourceProcessor.SystemSetting Extends %IPM.ResourceProcessor.Abstract
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
    write !, "Resource Reference Name: ", ..ResourceReference.Name
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
