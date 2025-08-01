/// Intended use case:
/// If you want a configuration-related class of which there will be at most one instance, that has settings with names defined in code
/// (not just magic strings, and possibly with default values) that are configurable via the "init" command in the Package Manager shell
/// and the Package Manager > Configuration menu item, extend AbstractSettings and add some properties, and you get all that.
/// The description of the settings is taken from the triple-slash documentation for them.
Class %IPM.General.AbstractSettings Extends (%Persistent, %IPM.General.Singleton, %IPM.General.IConfigurable) [ Abstract, NoExtent ]
{

Property Key As %String [ InitialExpression = "Settings", ReadOnly ];

Index Key On Key [ IdKey, Unique ];

/// A delimited string in the format:
/// Key:Description[|Key:Description...]
Parameter SETTINGS As COSEXPRESSION = "..GetSettingsParameterValue()";

/// For properties without a defined value in data, automatically populates with the InitialExpression for that property.
/// (Only handles properties in the default storage for the class.)
Method %OnOpen() As %Status [ CodeMode = objectgenerator, Private, ServerOnly = 1 ]
{
    set tClass = %compiledclass.Name
    set tDefaultData = $get($$$EXTdefaultdata($$$pEXT,tClass))
    if (tDefaultData = "") || %compiledclass.Abstract || %compiledclass.NoExtent {
        do %code.WriteLine(" Quit $$$OK")
        quit $$$OK
    }

    // Expression to get default data. e.g., $Get(^Some.GlobalD(id)) - where "id" needs to be replaced with a reasonable value. (Ick.)
    set tDefaultDataRef = $$$EXTPROPondisk($$$pEXT,tClass,tDefaultData)

    // Map of property to slot within that.
    set tDefaultStorageSlot = ""
    for {
        set tDefaultStorageSlot = $order($$$EXTPROPSLOT($$$pEXT,tClass,tDefaultData,tDefaultStorageSlot),1,tProperty)
        if (tDefaultStorageSlot = "") {
            quit
        }
        set tPropertySlots(tProperty) = tDefaultStorageSlot
    }

    do %code.WriteLine(" Set tSC = $$$OK")
    do %code.WriteLine(" Try {")
    do %code.WriteLine("  Set id = ..Key") //"id" variable is part of the code in tDefaultDataRef
    do %code.WriteLine("  Set tData = "_tDefaultDataRef)
    set tKey = ""
    for {
        #dim tProperty As %Dictionary.CompiledProperty
        set tProperty = %compiledclass.Properties.GetNext(.tKey)
        if (tKey = "") {
            quit
        }
        if tProperty.Calculated || tProperty.MultiDimensional || tProperty.Transient || tProperty.ReadOnly || '$data(tPropertySlots(tProperty.Name),tSlot) {
            continue
        }

        do %code.Write("  If ((.."_$$$QN(tProperty.Name)_" = """") && '$ListData(tData,"_tSlot_")) {")
        do %code.WriteLine(" Set .."_$$$QN(tProperty.Name)_" = "_tProperty.InitialExpression_" }")
    }
    do %code.WriteLine(" } Catch e { Set tSC = e.AsStatus() }")
    do %code.WriteLine(" Quit tSC")
    quit $$$OK
}

/// Returns true if a value is defined for setting <var>pName</var>.
ClassMethod SettingIsDefined(pName As %String) As %Boolean
{
    set tInstance = ..%Get(.tSC)
    $$$ThrowOnError(tSC)
    quit ($property(tInstance, pName) '= "")
}

/// Clears value of setting <var>pName</var>
ClassMethod GetSettingValue(pName As %String) As %String
{
    set tInstance = ..%Get(.tSC)
    $$$ThrowOnError(tSC)
    quit $property(tInstance, pName)
}

/// Clears value of setting <var>pName</var>
ClassMethod ClearSettingValue(pName As %String) As %Status
{
    set tSC = $$$OK
    try {
        set tInstance = ..%Get(.tSC)
        $$$ThrowOnError(tSC)
        set $property(tInstance,pName) = ""
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Sets setting <var>pName</var> to <var>pValue</var>. Should return an error %Status if <var>pValue</var> is invalid.
ClassMethod SetSettingValue(
	pName As %String,
	pValue As %String) As %Status
{
    set tSC = $$$OK
    try {
        set tInstance = ..%Get(.tSC)
        $$$ThrowOnError(tSC)
        if (tInstance.%Id() '= "") {
            // Reload in case another process has made changes.
            $$$ThrowOnError(tInstance.%Reload())
        }
        set $property(tInstance,pName) = pValue
        set tSC = tInstance.%Save()
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns the datatype of a setting, as one of:
/// boolean, string
/// The default implementation is to always return "string"
ClassMethod GetSettingType(pName As %String) As %String [ CodeMode = objectgenerator ]
{
    do %code.WriteLine(" Quit $Case(pName,")
    set tKey = ""
    for {
        #dim tProperty As %Dictionary.CompiledProperty
        set tProperty = %compiledclass.Properties.GetNext(.tKey)
        if (tKey = "") {
            quit
        }
        if tProperty.Calculated || tProperty.MultiDimensional || tProperty.Transient || tProperty.ReadOnly {
            continue
        }

        set tType = $case(tProperty.RuntimeType,"%Library.Boolean":"boolean",:"string")
        do %code.WriteLine("  "_$$$QUOTE(tProperty.Name)_":"""_tType_""",")
    }
    do %code.WriteLine("  :""string"")")
}

/// Returns a list of all properties available as "settings" (for IConfigurable),
/// along with their triple-slash comments as descriptions.
/// Omits calculated, multidimensional, transient, and read-only properties.
ClassMethod GetSettingsParameterValue() As %String [ CodeMode = objectgenerator ]
{
    // List of properties in this class, returned in the format ..#SETTINGS expects, with documentation from the property description.
    // Key:Description[|Key:Description...]
    set tSettings = ""

    set tKey = ""
    for {
        #dim tProperty As %Dictionary.CompiledProperty
        set tProperty = %compiledclass.Properties.GetNext(.tKey)
        if (tKey = "") {
            quit
        }
        if tProperty.Calculated || tProperty.MultiDimensional || tProperty.Transient || tProperty.ReadOnly {
            continue
        }

        set tSettings = tSettings_$listbuild(tProperty.Name_":"_tProperty.Description)
    }

    set tSettings = $listtostring(tSettings,"|")
    // Different version of $$$QUOTE to also convert newlines into $c(10) (for example) - this is what zwrite calls.
    do %code.WriteLine(" Quit "_$$Quote^%qcr(tSettings))
    quit $$$OK
}

}
