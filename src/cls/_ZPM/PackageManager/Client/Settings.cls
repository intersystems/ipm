/// ZPM settings are placed in ^zpm.settings global in %SYS namespace
/// Use this class to set or get settings
/// 
/// Available settings
/// default_registry (string) - default registry url 
/// analytics_tracking_id
/// analytics_available (boolean) - if 1 - send usage statistics
Class %ZPM.PackageManager.Client.Settings
{

Parameter REGISTRY = "default_registry";

Parameter TRACKINGID = "analytics_tracking_id";

Parameter ANALYTICS = "analytics_available";

ClassMethod GetValue(key As %String = "") As %String
{
    New $Namespace
    Return:(key="") ""
    Set $Namespace = "%SYS"
    Return $Get(^zpm.settings(key))
}

ClassMethod SetValue(key As %String = "", val As %String = "") As %Status
{
    Return:(key="") ""
    New $Namespace   
    Set $Namespace = "%SYS"
    Set ^zpm.settings(key) = val
    Return $$$OK
}

ClassMethod GetDefaultRegistry() As %String
{
    Return ..GetValue(..#REGISTRY)
}

ClassMethod SetDefaultRegistry(val As %String) As %String
{
    Return ..SetValue(..#REGISTRY, val)
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
