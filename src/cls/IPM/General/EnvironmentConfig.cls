Class %IPM.General.EnvironmentConfig Extends %IPM.General.Singleton
{

Property Config As %Library.DynamicObject [ InitialExpression = {{}}, Private ];

/// Load the configuration from the specified path into <property>Config</property>
Method Load(path As %String)
{
    try {
        set stream = ##class(%Stream.FileCharacter).%New()
        set stream.TranslateTable = "UTF8"
        $$$ThrowOnError(stream.LinkToFile(path))
        set jsonString = ""
        while 'stream.AtEnd {
            set jsonString = jsonString _ stream.Read()
        }
        try {
            set newConfig = {}.%FromJSON(jsonString)
        } catch Ex {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid configuration file: " _ path))
        }

        if newConfig.%IsA("%Library.DynamicArray") {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid configuration file. Expected a JSON object, not a JSON array"))
        }
        do ..MergeDynamicObjects(..Config, newConfig)
        set ..Config = ..%Evaluate(..Config)
    } catch ex {
        do ..Clear()
        throw ex
    }
}

/// Get the specified argument for the specified package
Method GetArg(
	package As %String,
	args... As %String) As %IPM.DataType.Any
{
    set obj = ..Config.%Get(package)

    for i = 1:1:$get(args) {
        if '($isobject(obj) && obj.%IsA("%Library.DynamicAbstractObject")) {
            return ""
        }
        set obj = obj.%Get(args(i))
    }
    return obj
}

/// The input could be a primitive type, a dynamic object, or a dynamic array
/// This function wll evaluate ${myVarName} to the value of the environment variable $myVarName
/// If the environment variable is not set, it will be empty string
ClassMethod %Evaluate(obj As %IPM.DataType.Any) As %IPM.DataType.Any
{
    return ..%EvaluateHelper(obj, 0)
}

/// Acutal implementation of %Evaluate
ClassMethod %EvaluateHelper(
	obj As %IPM.DataType.Any,
	copyCreated As %Boolean) As %IPM.DataType.Any [ Internal, Private ]
{
    if '$isobject(obj) {
        set regex= "\$\{([a-zA-Z0-9_]+)\}"
        for {
            set matcher = ##class(%Regex.Matcher).%New(regex, obj)
            if 'matcher.Locate() {
                quit
            }
            set varName = $extract(matcher.Group, 3, *-1)
            set obj = matcher.ReplaceFirst($system.Util.GetEnviron(varName))
        }
        return obj
    }

    // If the object is already a copy, we don't need to create a new copy recursively
    if 'copyCreated {
        set obj = obj.%FromJSON(obj.%ToJSON())
    }
    set iter = obj.%GetIterator()
    while iter.%GetNext(.key, .value, .type) {
        // type cannot be set for array / object
        if (type = "object") || (type = "array") {
            set type = ""
        }
        // since we are already in a recursive call, we don't need to create a new copy
        do obj.%Set(key, ..%EvaluateHelper(value, 1), type)
    }
    return obj
}

Method Clear()
{
    set ..Config = {}
    quit $$$OK
}

Method IsEmpty()
{
    return ..Config.%Size() = 0
}

/// Merge the source dynamic object into the destination dynamic object
/// The desination object will be updated in-place, with no reference to the source object, i.e., make deep copies wherever possible
ClassMethod MergeDynamicObjects(
	dest As %DynamicAbstractObject,
	src As %DynamicAbstractObject)
{
    if '($isobject(dest) && $isobject(src)) {
        set errorText = $$$FormatText("Invalid arguments. Expected two dynamic objects. Got %1 and %2", dest, src)
        $$$ThrowStatus($$$ERROR($$$GeneralError, errorText))
    }

    if (dest.%IsA("%Library.DynamicObject") '= src.%IsA("%Library.DynamicObject")) {
        set errorText = $$$FormatText("Invalid arguments. Expected two dynamic objects or two dynamic arrays. Got %1 and %2", $classname(dest), $classname(src))
        $$$ThrowStatus($$$ERROR($$$GeneralError, errorText))
    }

    set iter = src.%GetIterator()
    while iter.%GetNext(.key, .value, .type) {
        if (type = "object") || (type = "array") {
            if dest.%GetTypeOf(key) = "unassigned" {
                do dest.%Set(key, value.%New())
            }
            do ..MergeDynamicObjects(dest.%Get(key), src.%Get(key))
        } else {
            // primitive types can be directly set
            do dest.%Set(key, value, type)
        }
    }
}

}
