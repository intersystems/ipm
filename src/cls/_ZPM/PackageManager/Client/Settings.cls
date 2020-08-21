/// ZPM settings are placed in ^zpm.settings global in %SYS namespace
/// Use this class to set or get settings
/// 
/// Available settings
/// default_registry (string) - default registry url 
/// analytics_tracking_id
/// analytics_available (boolean) - if 1 - send usage statistics
Class %ZPM.PackageManager.Client.Settings Extends %RegisteredObject
{

Parameter registry = "default_registry";

Parameter trackingId = "analytics_tracking_id";

Parameter analytics = "analytics_available";

Parameter ColorScheme = "ColorScheme";

Parameter CONFIGURABLE = "trackingId,analytics,ColorScheme";

/// Returns configArray, that includes all configurable settings
ClassMethod GetAll(Output configArray) As %Status
{
    Set configArray = ""
    For i=1:1:$Length(..#CONFIGURABLE, ",") {
        Set configArray($Piece(..#CONFIGURABLE, ",",i)) = ..GetValue($Parameter(..%ClassName(1),$Piece(..#CONFIGURABLE, ",",i)))
    }
    Return $$$OK
}

/// Writes in terminal key : value pairs for all configurable settings
ClassMethod PrintList()
{
    Do ..GetAll(.confArr)
    Set k = ""
    For {
        Set k = $Order(confArr(k))
        Quit:(k="")
        Write k_": "_confArr(k),! 
    }
}

ClassMethod PrintOne(key As %String)
{
    Set SettingsList = $Listfromstring(..#CONFIGURABLE)
    If ('$Listfind(SettingsList,key)) {
        Write "Config key = """_key_""" not found",!
        Quit
    }
    Write key_":"_..GetValue($Parameter(..%ClassName(1),key)),!
}

ClassMethod ResetToDefault(key As %String) As %Status
{
    Set SettingsList = $Listfromstring(..#CONFIGURABLE)
    If ('$Listfind(SettingsList,key)) {
        Write "Config key = """_key_""" not found",!
        Quit
    }
    Set sc = ..SetValue($Parameter(..%ClassName(1),key), ..GetDefaultValue($Parameter(..%ClassName(1),key)))
    If $$$ISOK(sc) {
        Write "Value for """_key_""" succesfully reset to default",!
    } Else {
        Write "Error reseting value for """_key_"""",!
    }
    Return sc
}

ClassMethod UpdateOne(key As %String, value As %String) As %Status
{
    Set SettingsList = $Listfromstring(..#CONFIGURABLE)
    If ('$Listfind(SettingsList,key)) {
        Write "Config key = """_key_""" not found",!
        Quit
    }
    Set sc = ..SetValue($Parameter(..%ClassName(1),key), value)
    If $$$ISOK(sc) {
        Write "Key """_key_""" succesfully updated",!
    } Else {
        Write "Error updating """_key_"""",!
    }
    Return sc
}

/// Gets value from global array
/// indx - global subscript
ClassMethod GetValue(indx As %String = "") As %String
{
    New $Namespace
    Return:(indx="") ""
    Set $Namespace = "%SYS"
    Return $Get(^zpm.settings(indx))
}

ClassMethod GetDefaultValue(indx As %String = "") As %String
{
    New $Namespace
    Return:(indx="") ""
    Set $Namespace = "%SYS"
    Return $Get(^zpm.settings(indx,"default"))
}

ClassMethod SetValue(indx As %String = "", val As %String = "") As %Status
{
    Return:(indx="") ""
    New $Namespace   
    Set $Namespace = "%SYS"
    Set ^zpm.settings(indx) = val
    If ($Data(^zpm.settings(indx,"default"))=0) {
        Set ^zpm.settings(indx,"default") = val
    }
    Return $$$OK
}

ClassMethod GetDefaultRegistry() As %String
{
    Return ..GetValue(..#registry)
}

ClassMethod SetDefaultRegistry(val As %String) As %String
{
    Return ..SetValue(..#registry, val)
}

ClassMethod GetAnalyticsTrackingId() As %String
{
    Return ..GetValue(..#trackingId)
}

ClassMethod SetAnalyticsTrackingId(val As %String) As %String
{
    Return ..SetValue(..#trackingId, val)
}

ClassMethod GetAnalyticsAvailable() As %Boolean
{
    Return ..GetValue(..#analytics)
}

ClassMethod SetAnalyticsAvailable(val As %String) As %Boolean
{
    Return ..SetValue(..#analytics, +val)
}

}

