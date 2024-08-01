/// IPM settings are placed in ^IPM.settings global in %SYS namespace
/// Use this class to set or get settings
/// 
/// Available settings
/// default_registry (string) - default registry url 
/// analytics_tracking_id
/// analytics_available (boolean) - if 1 - send usage statistics
Class %IPM.Repo.UniversalSettings Extends %RegisteredObject
{

Parameter registry = "default_registry";

Parameter trackingId = "analytics_tracking_id";

Parameter analytics = "analytics_available";

/// Possible values: yes, none
Parameter ColorScheme = "ColorScheme";

/// Possible values: green, red, magenta, blue, yellow, cyan, none
Parameter TerminalPrompt = "TerminalPrompt";

Parameter PublishTimeout = "publish_timeout";

Parameter PipCaller = "PipCaller";

Parameter CONFIGURABLE = "trackingId,analytics,ColorScheme,TerminalPrompt,PublishTimeout,PipCaller";

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
        Write k_": "_..PrettyFormat(confArr(k)),! 
    }
}

ClassMethod PrintOne(key As %String)
{
    Set SettingsList = $Listfromstring(..#CONFIGURABLE)
    If ('$Listfind(SettingsList,key)) {
        Write "Config key = """_key_""" not found",!
        Quit
    }
    Write key_":"_..PrettyFormat(..GetValue($Parameter(..%ClassName(1),key))),!
}

/// A helper method to format string/number/$lb() recursively
ClassMethod PrettyFormat(input As %String) As %String
{
    If $Data(input) # 2 = 0 { Return "" }
    If input = $lb() { Return "$lb()" }
    If input = "" { Return """""" }
    Try {
        Set ptr = 0
        Set output = ""
        While $ListNext(input, ptr, value) {
            If output = "" {
                Set output = "$lb(" _ ..PrettyFormat(value)
            } Else {
                Set output = output _ ", " _ ..PrettyFormat(value)
            }
        }
        Set output = output _ ")"
        Return output
    } Catch ex {
        If input = +input {
            Return input
        }
        Return """" _ input _ """"
    }

    Return "Failed to Format input: " _ input
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
    Return $Get(^IPM.settings(indx))
}

ClassMethod GetDefaultValue(indx As %String = "") As %String
{
    New $Namespace
    Return:(indx="") ""
    Set $Namespace = "%SYS"
    Return $Get(^IPM.settings(indx,"default"))
}

ClassMethod SetValue(indx As %String = "", val As %String = "", overwrite As %Boolean = 1) As %Status
{
    if '$GET(overwrite, 1) && (..GetValue(indx) '= "") {
        Return $$$OK
    }
    Return:(indx="") ""
    New $Namespace   
    Set $Namespace = "%SYS"
    Set ^IPM.settings(indx) = val
    If ($Data(^IPM.settings(indx,"default"))=0) {
        Set ^IPM.settings(indx,"default") = val
    }
    Return $$$OK
}

ClassMethod GetDefaultRegistry() As %String
{
    Return ..GetValue(..#registry)
}

ClassMethod SetDefaultRegistry(val As %String, overwrite As %Boolean = 1) As %String
{
    Return ..SetValue(..#registry, val, overwrite)
}

ClassMethod GetAnalyticsTrackingId() As %String
{
    Return ..GetValue(..#trackingId)
}

ClassMethod SetAnalyticsTrackingId(val As %String, overwrite As %Boolean = 1) As %String
{
    Return ..SetValue(..#trackingId, val, overwrite)
}

ClassMethod GetAnalyticsAvailable() As %Boolean
{
    Return ..GetValue(..#analytics)
}

ClassMethod SetAnalyticsAvailable(val As %String, overwrite As %Boolean = 1) As %Boolean
{
    Return ..SetValue(..#analytics, +val, overwrite)
}

}
