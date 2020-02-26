/// ZPM settings are placed in ^zpm.settings global in %SYS namespace
/// Use this class to set or get settings
/// 
/// Available settings
/// version (string) - zpm client version 
/// analytics_tracking_id
/// analytics_available (boolean) - if 1 - send usage statistics
Class %ZPM.PackageManager.Settings
{

Parameter VERSION = "version";

Parameter TRACKINGID = "analytics_tracking_id";

Parameter ANALYTICS = "analytics_available";

ClassMethod GetValue(key As %String = "") As %String
{
    Return:(key="") ""
    Set ns = $Namespace
    Set $Namespace = "%SYS"
    Set val = $Get(^zpm.settings(key))
    Set $Namespace = ns
    Return val
}

ClassMethod SetValue(key As %String = "", val As %String = "") As %Status
{
    Return:(key="") ""
    Set ns = $Namespace
    Set $Namespace = "%SYS"
    Set ^zpm.settings(key) = val
    Set $Namespace = ns
    Return $$$OK
}

ClassMethod GetVersion() As %String
{
    Return ..GetValue(..#VERSION)
}

ClassMethod SetVersion(val As %String) As %String
{
    Return ..SetValue(..#VERSION, val)
}

ClassMethod GetAnalyticsTrackingId() As %String
{
    Return ..GetValue(..#TRACKINGID)
}

ClassMethod SetAnalyticsTrackingId(val As %String) As %String
{
    Return ..SetValue(..#TRACKINGID, val)
}

ClassMethod GetAnalyticsAvailable() As %Boolean
{
    Return ..GetValue(..#ANALYTICS)
}

ClassMethod SetAnalyticsAvailable(val As %String) As %Boolean
{
    Return ..SetValue(..#ANALYTICS, +val)
}

}
