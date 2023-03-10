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
	Set tClass = %compiledclass.Name
	Set tDefaultData = $Get($$$EXTdefaultdata($$$pEXT,tClass))
	If (tDefaultData = "") || %compiledclass.Abstract || %compiledclass.NoExtent {
		Do %code.WriteLine(" Quit $$$OK")
		Quit $$$OK
	}
	
	// Expression to get default data. e.g., $Get(^Some.GlobalD(id)) - where "id" needs to be replaced with a reasonable value. (Ick.)
	Set tDefaultDataRef = $$$EXTPROPondisk($$$pEXT,tClass,tDefaultData)
	
	// Map of property to slot within that.
	Set tDefaultStorageSlot = ""
	For {
		Set tDefaultStorageSlot = $Order($$$EXTPROPSLOT($$$pEXT,tClass,tDefaultData,tDefaultStorageSlot),1,tProperty)
		If (tDefaultStorageSlot = "") {
			Quit
		}
		Set tPropertySlots(tProperty) = tDefaultStorageSlot
	}
	
	Do %code.WriteLine(" Set tSC = $$$OK")
	Do %code.WriteLine(" Try {")
	Do %code.WriteLine("  Set id = ..Key") //"id" variable is part of the code in tDefaultDataRef
	Do %code.WriteLine("  Set tData = "_tDefaultDataRef)
	Set tKey = ""
	For {
		#dim tProperty As %Dictionary.CompiledProperty
		Set tProperty = %compiledclass.Properties.GetNext(.tKey)
		If (tKey = "") {
			Quit
		}
		If tProperty.Calculated || tProperty.MultiDimensional || tProperty.Transient || tProperty.ReadOnly || '$Data(tPropertySlots(tProperty.Name),tSlot) {
			Continue
		}
		
		Do %code.Write("  If ((.."_$$$QN(tProperty.Name)_" = """") && '$ListData(tData,"_tSlot_")) {")
		Do %code.WriteLine(" Set .."_$$$QN(tProperty.Name)_" = "_tProperty.InitialExpression_" }")
	}
	Do %code.WriteLine(" } Catch e { Set tSC = e.AsStatus() }")
	Do %code.WriteLine(" Quit tSC")
	Quit $$$OK
}

/// Returns true if a value is defined for setting <var>pName</var>.
ClassMethod SettingIsDefined(pName As %String) As %Boolean
{
	Set tInstance = ..%Get(.tSC)
	$$$ThrowOnError(tSC)
	Quit ($Property(tInstance, pName) '= "")
}

/// Clears value of setting <var>pName</var>
ClassMethod GetSettingValue(pName As %String) As %String
{
	Set tInstance = ..%Get(.tSC)
	$$$ThrowOnError(tSC)
	Quit $Property(tInstance, pName)
}

/// Clears value of setting <var>pName</var>
ClassMethod ClearSettingValue(pName As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tInstance = ..%Get(.tSC)
		$$$ThrowOnError(tSC)
		Set $Property(tInstance,pName) = ""
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Sets setting <var>pName</var> to <var>pValue</var>. Should return an error %Status if <var>pValue</var> is invalid.
ClassMethod SetSettingValue(pName As %String, pValue As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tInstance = ..%Get(.tSC)
		$$$ThrowOnError(tSC)
		If (tInstance.%Id() '= "") {
			// Reload in case another process has made changes.
			$$$ThrowOnError(tInstance.%Reload())
		}
		Set $Property(tInstance,pName) = pValue
		Set tSC = tInstance.%Save()
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns the datatype of a setting, as one of:
/// boolean, string
/// The default implementation is to always return "string"
ClassMethod GetSettingType(pName As %String) As %String [ CodeMode = objectgenerator ]
{
	Do %code.WriteLine(" Quit $Case(pName,")
	Set tKey = ""
	For {
		#dim tProperty As %Dictionary.CompiledProperty
		Set tProperty = %compiledclass.Properties.GetNext(.tKey)
		If (tKey = "") {
			Quit
		}
		If tProperty.Calculated || tProperty.MultiDimensional || tProperty.Transient || tProperty.ReadOnly {
			Continue
		}
		
		Set tType = $Case(tProperty.RuntimeType,"%Library.Boolean":"boolean",:"string")
		Do %code.WriteLine("  "_$$$QUOTE(tProperty.Name)_":"""_tType_""",")
	}
	Do %code.WriteLine("  :""string"")")
}

/// Returns a list of all properties available as "settings" (for IConfigurable),
/// along with their triple-slash comments as descriptions.
/// Omits calculated, multidimensional, transient, and read-only properties.
ClassMethod GetSettingsParameterValue() As %String [ CodeMode = objectgenerator ]
{
	// List of properties in this class, returned in the format ..#SETTINGS expects, with documentation from the property description.
	// Key:Description[|Key:Description...]
	Set tSettings = ""
	
	Set tKey = ""
	For {
		#dim tProperty As %Dictionary.CompiledProperty
		Set tProperty = %compiledclass.Properties.GetNext(.tKey)
		If (tKey = "") {
			Quit
		}
		If tProperty.Calculated || tProperty.MultiDimensional || tProperty.Transient || tProperty.ReadOnly {
			Continue
		}
		
		Set tSettings = tSettings_$ListBuild(tProperty.Name_":"_tProperty.Description)
	}
	
	Set tSettings = $ListToString(tSettings,"|")
	// Different version of $$$QUOTE to also convert newlines into $c(10) (for example) - this is what zwrite calls.
	Do %code.WriteLine(" Quit "_$$Quote^%qcr(tSettings))
	Quit $$$OK
}

}
