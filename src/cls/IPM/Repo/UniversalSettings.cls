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

Parameter DefaultLogEntryLimit = "DefaultLogEntryLimit";

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

/// Determines if the source folder should be physically deleted when a module is uninstalled.
Parameter CleanOnUninstall = "CleanOnUninstall";

Parameter CONFIGURABLE = "trackingId,analytics,ColorScheme,TerminalPrompt,PublishTimeout,PipCaller,UseStandalonePip,SemVerPostRelease,DefaultLogEntryLimit,CleanOnUninstall";

/// Returns configArray, that includes all configurable settings
ClassMethod GetAll(Output configArray) As %Status
{
    set configArray = ""
    for i=1:1:$length(..#CONFIGURABLE, ",") {
        set configArray($piece(..#CONFIGURABLE, ",",i)) = ..GetValue($parameter(..%ClassName(1),$piece(..#CONFIGURABLE, ",",i)))
    }
    return $$$OK
}

/// Writes in terminal key : value pairs for all configurable settings
ClassMethod PrintList()
{
    do ..GetAll(.confArr)
    set k = ""
    for {
        set k = $order(confArr(k))
        quit:(k="")
        write k_": "_confArr(k),!
    }
}

ClassMethod PrintOne(key As %String)
{
    set SettingsList = $listfromstring(..#CONFIGURABLE)
    if ('$listfind(SettingsList,key)) {
        write "Config key = """_key_""" not found",!
        quit
    }
    write key_":"_..GetValue($parameter(..%ClassName(1),key)),!
}

ClassMethod ResetToDefault(key As %String) As %Status
{
    set SettingsList = $listfromstring(..#CONFIGURABLE)
    if ('$listfind(SettingsList,key)) {
        write "Config key = """_key_""" not found",!
        quit
    }
    set sc = ..SetValue($parameter(..%ClassName(1),key), ..GetDefaultValue($parameter(..%ClassName(1),key)))
    if $$$ISOK(sc) {
        write "Value for """_key_""" succesfully reset to default",!
    } else {
        write "Error reseting value for """_key_"""",!
    }
    return sc
}

ClassMethod UpdateOne(
	key As %String,
	value As %String) As %Status
{
    set SettingsList = $listfromstring(..#CONFIGURABLE)
    if ('$listfind(SettingsList,key)) {
        write "Config key = """_key_""" not found",!
        quit
    }
    set sc = ..SetValue($parameter(..%ClassName(1),key), value)
    if $$$ISOK(sc) {
        write "Key """_key_""" succesfully updated",!
    } else {
        write "Error updating """_key_"""",!
    }
    return sc
}

/// Gets value from global array
/// indx - global subscript
ClassMethod GetValue(indx As %String = "") As %String
{
    new $namespace
    return:(indx="") ""
    set $namespace = "%SYS"
    return $get(^IPM.settings(indx))
}

ClassMethod GetDefaultValue(indx As %String = "") As %String
{
    new $namespace
    return:(indx="") ""
    set $namespace = "%SYS"
    return $get(^IPM.settings(indx,"default"))
}

ClassMethod SetValue(
	indx As %String = "",
	val As %String = "",
	overwrite As %Boolean = 1) As %Status
{
    if '$get(overwrite, 1) && (..GetValue(indx) '= "") {
        return $$$OK
    }
    return:(indx="") ""
    new $namespace
    set $namespace = "%SYS"
    set ^IPM.settings(indx) = val
    if ($data(^IPM.settings(indx,"default"))=0) {
        set ^IPM.settings(indx,"default") = val
    }
    return $$$OK
}

ClassMethod GetDefaultRegistry() As %String
{
    return ..GetValue(..#registry)
}

ClassMethod SetDefaultRegistry(
	val As %String,
	overwrite As %Boolean = 1) As %String
{
    return ..SetValue(..#registry, val, overwrite)
}

ClassMethod GetAnalyticsTrackingId() As %String
{
    return ..GetValue(..#trackingId)
}

ClassMethod SetAnalyticsTrackingId(
	val As %String,
	overwrite As %Boolean = 1) As %String
{
    return ..SetValue(..#trackingId, val, overwrite)
}

ClassMethod GetAnalyticsAvailable() As %Boolean
{
    return ..GetValue(..#analytics)
}

ClassMethod SetAnalyticsAvailable(
	val As %String,
	overwrite As %Boolean = 1) As %Boolean
{
    return ..SetValue(..#analytics, +val, overwrite)
}

ClassMethod GetCleanOnUninstall() As %String [ CodeMode = expression ]
{
..GetValue(..#CleanOnUninstall)
}

}
