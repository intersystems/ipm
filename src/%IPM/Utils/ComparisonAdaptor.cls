/// Handles code generation of a grab bag of useful functions to be code generated, such as the following:
/// - Comparison functions that compare instances of a class by comparing their properties.
Class %IPM.Utils.ComparisonAdaptor [ Abstract, PropertyClass = %IPM.Utils.ComparisonAdaptor.PropertyParams, System = 4 ]
{

/// Set to true to skip code generation in this class
Parameter SkipCodeGeneration As BOOLEAN = 0;

/// Returns a list of keywords such that, if a property contains any of these,
/// code generation of the property is ignored.
/// @API.Overrideable
ClassMethod IgnoreKeywordList() As %Library.List [ CodeMode = expression ]
{
$ListBuild("Transient", "Private", "Internal", "Calculated", "Relationship")
}

/// Condition under which a given property is skipped when generating code for the
/// <method>CompareTo</method>. The instance of the compiled property
/// is provided in <var>pCompiledProperty</var>. <br />
/// This is intended to be used only if the properties to be skipped match a certain
/// pattern. To hardcode specific properties to be skipped, use the property parameters. <br />
/// Returns 1 if the property should be skipped. 0 otherwise. <br />
ClassMethod CompareToSkipCondition(pCompiledProperty As %Dictionary.CompiledProperty) As %Boolean [ Final ]
{
	// Skip if property has one of these keywords set
	Set skipList = ..IgnoreKeywordList()
	Set pointer = 0
	Set shouldSkip = 0
	While $ListNext(skipList, pointer, keyword) {
		Set hasKeyword = +$Property(pCompiledProperty, keyword)
		If hasKeyword {
			Set shouldSkip = 1
			Quit
		}
	}
	Return shouldSkip
}

/// Compares the properties of the existing object to the provided object of the same type. <br />
/// If comparison of certain properties is to be skipped, the property names can be listed in
/// <var>pIgnorePropertyList</var>. <br />
/// Returns 1 if all properties match. Else 0.
/// <var>pDifferingPropertyArray</var> returns in an array, the values of the properties that
/// differed in the following format: <br />
/// pDifferingPropertyArray("property name", "any nested property names or indices/keys for iterable properties")
/// = $ListBuild("value in calling object", "value in pObj"). <br />
Method %CompareTo(pObj As %IPM.Utils.ComparisonAdaptor, pIgnorePropertyList As %Library.List = "", Output pDifferingPropertyArray As %Library.List) As %Boolean [ CodeMode = objectgenerator, ForceGenerate ]
{
	#define WriteLine(%line) Do %code.WriteLine($Char(9)_%line)
	Set classname = %compiledclass.Name
	Set methodName = %method.Name
	Set skipCodeGeneration = +$Get(%parameter("SkipCodeGeneration"))
	// Do not generate in this class
	Set sourceClassname = "%IPM.Utils.ComparisonAdaptor"
	If (classname = sourceClassname) || skipCodeGeneration {
		Return $$$OK
	}
	
	#dim propertyList As %Library.ListOfObjects
	#dim compiledProperty As %Dictionary.CompiledProperty
	Set propertyList = %compiledclass.Properties
	
	$$$WriteLine("Kill pDifferingPropertyArray")
	// Iterate properties
	For i=1:1:propertyList.Count() {
		Set compiledProperty = propertyList.GetAt(i)
		Set propertyName = compiledProperty.Name
		
		#define CodeGenError(%message) $$$ThrowStatus($$$ERROR($$$GeneralError, "Property "_$$$QUOTE(propertyName)_" in class "_classname_" failed code generation. "_%message))
		
		Set forceCodeGenerate = +compiledProperty.Parameters.GetAt("ForceCodeGenerate")
		
		// Ignore skipping checks if forced to generate
		// Skip if property meets skip condition or is forcefully skipped
		If (forceCodeGenerate = 0) || ((forceCodeGenerate '= 1) && ..CompareToSkipCondition(compiledProperty)) {
			Continue
		}
				
		Set collectionType = compiledProperty.Collection
		Set isRelationship = +compiledProperty.Relationship
		
		$$$WriteLine("If '$ListFind(pIgnorePropertyList, "_$$$QUOTE(propertyName)_") {")
		If (collectionType = $$$cPROPCOLLECTIONLIST) {
			// Lists or relationships
			// Check counts
			$$$WriteLine("	Set count1 = .."_propertyName_".Count()")
			$$$WriteLine("	Set count2 = pObj."_propertyName_".Count()")
			$$$WriteLine("	If (count1 '= count2) {")
			$$$WriteLine("		Set pDifferingPropertyArray("_$$$QUOTE(propertyName)_") = $ListBuild(count1, count2)")
			$$$WriteLine("	} Else {")
			// Check element wise
			$$$WriteLine("		For i=1:1:.."_propertyName_".Count() {")
			$$$WriteLine("			Set item1 = .."_propertyName_".GetAt(i)")
			$$$WriteLine("			Set item2 = pObj."_propertyName_".GetAt(i)")
			Do ..GenerateCompareForSingleItem(%code, classname, propertyName, methodName, "item1", "item2", "i", 4)
			$$$WriteLine("		}")
			$$$WriteLine("	}")
		} ElseIf (collectionType = $$$cPROPCOLLECTIONARRAY) {
			// Arrays
			// Check counts
			$$$WriteLine("	Set count1 = .."_propertyName_".Count()")
			$$$WriteLine("	Set count2 = pObj."_propertyName_".Count()")
			$$$WriteLine("	If (count1 '= count2) {")
			$$$WriteLine("		Set pDifferingPropertyArray("_$$$QUOTE(propertyName)_") = $ListBuild(count1, count2)")
			$$$WriteLine("	} Else {")
			// Check element wise
			$$$WriteLine("		Set key = """"")
			$$$WriteLine("		While 1 {")
			$$$WriteLine("			Set key = .."_propertyName_".Next(key)")
			$$$WriteLine("			If (key = """") {")
			$$$WriteLine("				Quit")
			$$$WriteLine("			}")
			$$$WriteLine("			Set item1 = .."_propertyName_".GetAt(key)")
			$$$WriteLine("			Set item2 = pObj."_propertyName_".GetAt(key)")
			Do ..GenerateCompareForSingleItem(%code, classname, propertyName, methodName, "item1", "item2", "key", 4)
			$$$WriteLine("		}")
			$$$WriteLine("	}")
		} ElseIf (collectionType = "") {
			Do ..GenerateCompareForSingleItem(%code, classname, propertyName, methodName, ".."_propertyName, "pObj."_propertyName, , 2)
		} Else {
			$$$CodeGenError("Unknown collection type: "_collectionType)
		}
		$$$WriteLine("}")
	}
	$$$WriteLine("Return '$Data(pDifferingPropertyArray)")
	Return $$$OK
}

/// Helper method to generate comparison between two ObjectScript
ClassMethod GenerateCompareForSingleItem(pCode As %Stream.MethodGenerator, pClassname As %Dictionary.Classname, pPropertyName As %Dictionary.CacheIdentifier, pMethodName As %Dictionary.Identifier, pItem1 As %String, pItem2 As %String, pIndexVariable As %String = "", pIndent As %Integer = 1) [ Internal ]
{
	Set indexAppend = $Case((pIndexVariable = ""), 1:"", :", "_pIndexVariable)
	Set indent = ""
	// Calculate indent
	For i=1:1:pIndent {
		Set indent = indent_$Char(9)
	}
	#define CodeGenError(%message) $$$ThrowStatus($$$ERROR($$$GeneralError, "Property "_$$$QUOTE(pPropertyName)_" in class "_pClassname_" failed code generation. "_%message))
	#define WriteLine(%line) Do pCode.WriteLine(indent_%line)
	
	Set propertyType = $$$comMemberKeyGet(pClassname, $$$cCLASSproperty, pPropertyName, $$$cPROPtype)
	Set classTypeOfPropertyType = $$$comClassKeyGet(propertyType, $$$cCLASSclasstype)
	If (classTypeOfPropertyType = $$$cCLASSCLASSTYPEDATATYPE) {
		$$$WriteLine("If ("_pItem1_" '= "_pItem2_") {")
		$$$WriteLine("	Set pDifferingPropertyArray("_$$$QUOTE(pPropertyName)_indexAppend_") = $ListBuild("_pItem1_", "_pItem2_")")
		$$$WriteLine("}")
	} ElseIf (classTypeOfPropertyType = $$$cCLASSCLASSTYPEPERSISTENT) || (classTypeOfPropertyType = $$$cCLASSCLASSTYPESERIAL) || (classTypeOfPropertyType = $$$cCLASSCLASSTYPENONE) {
		// Check that the class extends this adaptor class
		Set superClassList = ..FindAllSuperClasses(propertyType)
		If '$ListFind(superClassList, "%IPM.Utils.ComparisonAdaptor") {
			$$$CodeGenError("The class "_$$$QUOTE(propertyType)_" needs to extend %IPM.Utils.ComparisonAdaptor")
		}
		$$$WriteLine("Set isEqual = "_pItem1_"."_pMethodName_"("_pItem2_", , .diffInfo)")
		$$$WriteLine("If 'isEqual {")
		$$$WriteLine("	Merge pDifferingPropertyArray("_$$$QUOTE(pPropertyName)_indexAppend_") = diffInfo")
		$$$WriteLine("}")
	} Else {
		Set errorMessage = "Unsupported class type: "_classTypeOfPropertyType
		$$$CodeGenError(errorMessage)
	}
}

/// Returns a list of all super classes for a given class <var>pClassname</var>
ClassMethod FindAllSuperClasses(pClassname As %Dictionary.Classname) As %Library.List
{
	#dim superClassArray As %String
	#dim classesIteratedArray As %String
	#dim classesToIterateArray As %String
	
	Set classesToIterateArray(pClassname) = ""
	Set classname = ""
	While 1 {
		If '$Data(classesToIterateArray) {
			Quit
		}
		Set classname = $Order(classesToIterateArray(classname))
		If (classname = "") {
			Set classname = $Order(classesToIterateArray(classname))
		}
		// Find super classes
		Set superClasses = $$$defClassKeyGet(classname, $$$cCLASSsuper)
		Set superClassList = $ListFromString(superClasses, ",")
		// Add to super class array
		Set pointer = 0
		While $ListNext(superClassList, pointer, superClass) {
			Set superClassArray(superClass) = ""
			// Add to classes to iterate array if not yet seen
			If '$Data(classesIteratedArray(superClass)) {
				Set classesToIterateArray(superClass) = ""
			}
		}
		
		Set classesIteratedArray(classname) = ""
		Kill classesToIterateArray(classname)
	}
	
	// Construct list
	Set classname = ""
	Set totalSuperClassList = ""
	While 1 {
		Set classname = $Order(superClassArray(classname))
		If (classname = "") {
			Quit
		}
		Set totalSuperClassList = totalSuperClassList _ $ListBuild(classname)
	}
	Return totalSuperClassList
}

}
