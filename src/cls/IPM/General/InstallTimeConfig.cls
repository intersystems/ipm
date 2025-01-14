Class %IPM.General.InstallTimeConfig Extends %IPM.General.Singleton
{

Property Config As %Library.DynamicObject [ InitialExpression = {{}}, Private ];

/// Load the configuration from the specified path into <property>Config</property>
Method Load(path As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set newConfig = {}.%FromJSONFile(path)
        If '($IsObject(newConfig) && newConfig.%IsA("%Library.DynamicObject")) {
            Set tSC = $$$ERROR($$$GeneralError, "Invalid configuration file. Expected a JSON object, not JSON array")
            Quit
        }
        Do ..MergeDynamicObjects(..Config, newConfig)
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

/// Merge the source dynamic object into the destination dynamic object
/// The desination object will be updated in-place, with no reference to the source object, i.e., make deep copies wherever possible
ClassMethod MergeDynamicObjects(dest As %DynamicAbstractObject, src As %DynamicAbstractObject)
{
    If '($IsObject(dest) && $IsObject(src)) {
        Set errorText = $$$FormatText("Invalid arguments. Expected two dynamic objects. Got %1 and %2", dest, src)
        $$$ThrowStatus($$$ERROR($$$GeneralError, errorText))
    }

    If (dest.%IsA("%Library.DynamicObject") '= src.%IsA("%Library.DynamicObject")) {
        Set errorText = $$$FormatText("Invalid arguments. Expected two dynamic objects or two dynamic arrays. Got %1 and %2", $classname(dest), $classname(src))
        $$$ThrowStatus($$$ERROR($$$GeneralError, errorText))
    }

    Set iter = src.%GetIterator()
    While iter.%GetNext(.key, .value, .type) {
        If (type = "object") || (type = "array") {
            If dest.%GetTypeOf(key) = "unassigned" {
                Do dest.%Set(key, value.%New())
            }
            Do ..MergeDynamicObjects(dest.%Get(key), src.%Get(key))
        } Else {
            // primitive types can be directly set
            Do dest.%Set(key, value, type)
        }
    }
}

}
