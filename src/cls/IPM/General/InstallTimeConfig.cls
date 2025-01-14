Class %IPM.General.InstallTimeConfig Extends %IPM.General.Singleton
{

Property Config As %Library.DynamicObject [ InitialExpression = {{}}, Private ];

/// Load the configuration from the specified path into <property>Config</property>
Method Load(path As %String) As %Status
{
    // TODO - Support merging (updating) the configuration instead of replacing it
    Set tSC = $$$OK
    Try {
        Set ..Config = {}.%FromJSONFile(path)
        If '($IsObject(..Config) && ..Config.%IsA("%Library.DynamicObject")) {
            Set tSC = $$$ERROR($$$GeneralError, "Invalid configuration file. Expected a JSON object, not JSON array")
            Quit
        }
    } Catch ex {
        Set tSC = $$$ADDSC(ex.AsStatus(), ..Clear())
    }
    Return tSC
}

/// Get the specified argument for the specified package
Method GetArg(package As %String, args... As %String) As %Any
{
    Set obj = ..Config.%Get(package)

    For i = 1:1:$Get(args) {
        If '($IsObject(obj) && obj.%IsA("%Library.DynamicObject")) {
            Return ""
        }
        Set obj = obj.%Get(args(i))
    }
    Return obj
}

Method Clear() As %Status
{
    Set ..Config = {}
    Quit $$$OK
}

Method ToJson() As %String
{
    Quit ..Config.%ToJSON()
}

Method SetJson(json As %String)
{
    Set ..Config = {}.%FromJSON(json)
}

Method IsEmpty()
{
    Return ..Config.%Size() = 0
}

}
