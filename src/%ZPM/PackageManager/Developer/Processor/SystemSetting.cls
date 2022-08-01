Class %ZPM.PackageManager.Developer.Processor.SystemSetting Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Name,Value";

Property Name As %String(MAXLEN = "") [ Required ];

Property Value As %String(MAXLEN = "");

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
  If pPhase = "Compile" {
    if $PIECE(..ResourceReference.Name, ".") = "CSP" {
      Set tName = $PIECE(..Name, ".", 2)
      If tName '= "" {
        Set ^%SYS("CSP", tName) = ..Value
        Set pResourceHandled = 1
      }
    }
  }
  Quit $$$OK
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
  Kill pResourceArray
  Quit $$$OK
}

}
