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
$listbuild("Transient", "Private", "Internal", "Calculated", "Relationship")
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
    set skipList = ..IgnoreKeywordList()
    set pointer = 0
    set shouldSkip = 0
    while $listnext(skipList, pointer, keyword) {
        set hasKeyword = +$property(pCompiledProperty, keyword)
        if hasKeyword {
            set shouldSkip = 1
            quit
        }
    }
    return shouldSkip
}

/// Compares the properties of the existing object to the provided object of the same type. <br />
/// If comparison of certain properties is to be skipped, the property names can be listed in
/// <var>pIgnorePropertyList</var>. <br />
/// Returns 1 if all properties match. Else 0.
/// <var>pDifferingPropertyArray</var> returns in an array, the values of the properties that
/// differed in the following format: <br />
/// pDifferingPropertyArray("property name", "any nested property names or indices/keys for iterable properties")
/// = $ListBuild("value in calling object", "value in pObj"). <br />
Method %CompareTo(
	pObj As %IPM.Utils.ComparisonAdaptor,
	pIgnorePropertyList As %Library.List = "",
	Output pDifferingPropertyArray As %Library.List) As %Boolean [ CodeMode = objectgenerator, ForceGenerate ]
{
    #define WriteLine(%line) Do %code.WriteLine($Char(9)_%line)
    set classname = %compiledclass.Name
    set methodName = %method.Name
    set skipCodeGeneration = +$get(%parameter("SkipCodeGeneration"))
    // Do not generate in this class
    set sourceClassname = "%IPM.Utils.ComparisonAdaptor"
    if (classname = sourceClassname) || skipCodeGeneration {
        return $$$OK
    }

    #dim propertyList As %Library.ListOfObjects
    #dim compiledProperty As %Dictionary.CompiledProperty
    set propertyList = %compiledclass.Properties

    $$$WriteLine("Kill pDifferingPropertyArray")
    // Iterate properties
    for i=1:1:propertyList.Count() {
        set compiledProperty = propertyList.GetAt(i)
        set propertyName = compiledProperty.Name

        #define CodeGenError(%message) $$$ThrowStatus($$$ERROR($$$GeneralError, "Property "_$$$QUOTE(propertyName)_" in class "_classname_" failed code generation. "_%message))

        set forceCodeGenerate = +compiledProperty.Parameters.GetAt("ForceCodeGenerate")

        // Ignore skipping checks if forced to generate
        // Skip if property meets skip condition or is forcefully skipped
        if (forceCodeGenerate = 0) || ((forceCodeGenerate '= 1) && ..CompareToSkipCondition(compiledProperty)) {
            continue
        }

        set collectionType = compiledProperty.Collection
        set isRelationship = +compiledProperty.Relationship

        $$$WriteLine("If '$ListFind(pIgnorePropertyList, "_$$$QUOTE(propertyName)_") {")
        if (collectionType = $$$cPROPCOLLECTIONLIST) {
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
            do ..GenerateCompareForSingleItem(%code, classname, propertyName, methodName, "item1", "item2", "i", 4)
            $$$WriteLine("		}")
            $$$WriteLine("	}")
        } elseif (collectionType = $$$cPROPCOLLECTIONARRAY) {
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
            do ..GenerateCompareForSingleItem(%code, classname, propertyName, methodName, "item1", "item2", "key", 4)
            $$$WriteLine("		}")
            $$$WriteLine("	}")
        } elseif (collectionType = "") {
            do ..GenerateCompareForSingleItem(%code, classname, propertyName, methodName, ".."_propertyName, "pObj."_propertyName, , 2)
        } else {
            $$$CodeGenError("Unknown collection type: "_collectionType)
        }
        $$$WriteLine("}")
    }
    $$$WriteLine("Return '$Data(pDifferingPropertyArray)")
    return $$$OK
}

/// Helper method to generate comparison between two ObjectScript
ClassMethod GenerateCompareForSingleItem(
	pCode As %Stream.MethodGenerator,
	pClassname As %Dictionary.Classname,
	pPropertyName As %Dictionary.CacheIdentifier,
	pMethodName As %Dictionary.Identifier,
	pItem1 As %String,
	pItem2 As %String,
	pIndexVariable As %String = "",
	pIndent As %Integer = 1) [ Internal ]
{
    set indexAppend = $case((pIndexVariable = ""), 1:"", :", "_pIndexVariable)
    set indent = ""
    // Calculate indent
    for i=1:1:pIndent {
        set indent = indent_$char(9)
    }
    #define CodeGenError(%message) $$$ThrowStatus($$$ERROR($$$GeneralError, "Property "_$$$QUOTE(pPropertyName)_" in class "_pClassname_" failed code generation. "_%message))
    #define WriteLine(%line) Do pCode.WriteLine(indent_%line)

    set propertyType = $$$comMemberKeyGet(pClassname, $$$cCLASSproperty, pPropertyName, $$$cPROPtype)
    set classTypeOfPropertyType = $$$comClassKeyGet(propertyType, $$$cCLASSclasstype)
    if (classTypeOfPropertyType = $$$cCLASSCLASSTYPEDATATYPE) {
        $$$WriteLine("If ("_pItem1_" '= "_pItem2_") {")
        $$$WriteLine("	Set pDifferingPropertyArray("_$$$QUOTE(pPropertyName)_indexAppend_") = $ListBuild("_pItem1_", "_pItem2_")")
        $$$WriteLine("}")
    } elseif (classTypeOfPropertyType = $$$cCLASSCLASSTYPEPERSISTENT) || (classTypeOfPropertyType = $$$cCLASSCLASSTYPESERIAL) || (classTypeOfPropertyType = $$$cCLASSCLASSTYPENONE) {
        // Check that the class extends this adaptor class
        set superClassList = ..FindAllSuperClasses(propertyType)
        if '$listfind(superClassList, "%IPM.Utils.ComparisonAdaptor") {
            $$$CodeGenError("The class "_$$$QUOTE(propertyType)_" needs to extend %IPM.Utils.ComparisonAdaptor")
        }
        $$$WriteLine("Set isEqual = "_pItem1_"."_pMethodName_"("_pItem2_", , .diffInfo)")
        $$$WriteLine("If 'isEqual {")
        $$$WriteLine("	Merge pDifferingPropertyArray("_$$$QUOTE(pPropertyName)_indexAppend_") = diffInfo")
        $$$WriteLine("}")
    } else {
        set errorMessage = "Unsupported class type: "_classTypeOfPropertyType
        $$$CodeGenError(errorMessage)
    }
}

/// Returns a list of all super classes for a given class <var>pClassname</var>
ClassMethod FindAllSuperClasses(pClassname As %Dictionary.Classname) As %Library.List
{
    #dim superClassArray As %String
    #dim classesIteratedArray As %String
    #dim classesToIterateArray As %String

    set classesToIterateArray(pClassname) = ""
    set classname = ""
    while 1 {
        if '$data(classesToIterateArray) {
            quit
        }
        set classname = $order(classesToIterateArray(classname))
        if (classname = "") {
            set classname = $order(classesToIterateArray(classname))
        }
        // Find super classes
        set superClasses = $$$defClassKeyGet(classname, $$$cCLASSsuper)
        set superClassList = $listfromstring(superClasses, ",")
        // Add to super class array
        set pointer = 0
        while $listnext(superClassList, pointer, superClass) {
            set superClassArray(superClass) = ""
            // Add to classes to iterate array if not yet seen
            if '$data(classesIteratedArray(superClass)) {
                set classesToIterateArray(superClass) = ""
            }
        }

        set classesIteratedArray(classname) = ""
        kill classesToIterateArray(classname)
    }

    // Construct list
    set classname = ""
    set totalSuperClassList = ""
    while 1 {
        set classname = $order(superClassArray(classname))
        if (classname = "") {
            quit
        }
        set totalSuperClassList = totalSuperClassList _ $listbuild(classname)
    }
    return totalSuperClassList
}

}
