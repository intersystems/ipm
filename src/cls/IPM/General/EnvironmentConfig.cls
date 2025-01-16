Class %IPM.General.EnvironmentConfig Extends %IPM.General.Singleton
{

Property Config As %Library.DynamicObject [ InitialExpression = {{}}, Private ];

/// Load the configuration from the specified path into <property>Config</property>
Method Load(path As %String)
{
    Try {
        Set stream = ##class(%Stream.FileCharacter).%New()
        Set stream.TranslateTable = "UTF8"
        $$$ThrowOnError(stream.LinkToFile(path))
        Set jsonString = ""
        While 'stream.AtEnd {
            Set jsonString = jsonString _ stream.Read()
        }
        Try {
            Set newConfig = {}.%FromJSON(jsonString)
        } Catch Ex {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid configuration file: " _ path))
        }

        If newConfig.%IsA("%Library.DynamicArray") {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid configuration file. Expected a JSON object, not a JSON array"))
        }
        Do ..MergeDynamicObjects(..Config, newConfig)
    } Catch ex {
        Do ..Clear()
        Throw ex
    }
}

/// Get the specified argument for the specified package
Method GetArg(package As %String, args... As %String) As %IPM.DataType.Any
{
    Set obj = ..Config.%Get(package)

    For i = 1:1:$Get(args) {
        If '($IsObject(obj) && obj.%IsA("%Library.DynamicAbstractObject")) {
            Return ""
        }
        Set obj = obj.%Get(args(i))
    }
    Return obj
}

Method Clear()
{
    Set ..Config = {}
    Quit $$$OK
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
