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

/// A path pointing either to a python executable or a pip executable, controlled by <parameter>UseStandalonePip</parameter>
/// In the special case where the path is empty, the script tries to resolve the path in the following order:
/// 1. Where available (typically 2024.2+) - Use PythonRuntimeLibrary in iris.cpf to find the directory containing the python executable
/// 2. On Windows, try to find <iris-root>/bin/irispip.exe
/// 3. Unless <parameter>UseStandalonePip</parameter> is explicitly set to 1, try to find whichever python3/python is first available in $PATH
/// 4. Unless <parameter>UseStandalonePip</parameter> is explicitly set to 0, try to find whichever pip3/pip is first available in $PATH
Parameter PipCaller = "PipCaller";

/// Possible values: "", 0, 1
/// Indicates whether <parameter>PipCaller</parameter> is a pip executable instead of python
Parameter UseStandalonePip = "UseStandalonePip";

/// Possible values: 0, 1
/// Indicates whether the SemVer comparison treats the version 1.0.0-1.m1 as a post-release of 1.0.0, hence 1.0.0-1.m1 > 1.0.0
/// Default value is 0, where 1.0.0-anystring is considered a pre-release of 1.0.0, hence 1.0.0-anystring < 1.0.0
Parameter SemVerPostRelease = "SemVerPostRelease";

Parameter CONFIGURABLE = "trackingId,analytics,ColorScheme,TerminalPrompt,PublishTimeout,PipCaller,UseStandalonePip,SemVerPostRelease";

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
