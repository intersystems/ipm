Class %IPM.Utils.CodeGeneration [ Abstract, System = 3 ]
{

ClassMethod BuildRelationshipSorter(pCodeStream As %Stream.MethodGenerator, pRelationshipName As %String, pObjectIdentifierExpression As %String) [ Internal ]
{
	// build an array containing all the relationship members
 	Do pCodeStream.WriteLine(" Set tTempArray = ##class(%Library.ArrayOfObjects).%New()")
 	Do pCodeStream.WriteLine(" Set tKey = """"")
 	Do pCodeStream.WriteLine(" While 1 {")
 	Do pCodeStream.WriteLine("  Set tElement = .." _ pRelationshipName _ ".GetNext(.tKey)")
 	Do pCodeStream.WriteLine("  Quit:tKey=""""")
 	Do pCodeStream.WriteLine("  Set tElementName = tElement." _ pObjectIdentifierExpression) // Property or method 
 	Do pCodeStream.WriteLine("  Set tSC = tTempArray.SetAt(tElement, tElementName)")
 	Do pCodeStream.WriteLine("  $$$ThrowOnError(tSC)")
 	Do pCodeStream.WriteLine("  Set tElementNames(tElementName) = """"")
 	Do pCodeStream.WriteLine(" }")
 	
 	// now go back in alphanumerical order and add them to a *list*	
 	Do pCodeStream.WriteLine(" Set tOutput = ##class(%Library.ListOfObjects).%New()")
 	Do pCodeStream.WriteLine(" Set tElementName = """"")
 	Do pCodeStream.WriteLine(" While 1 {")
 	Do pCodeStream.WriteLine("  Set tElementName = $Order(tElementNames(tElementName))")
 	Do pCodeStream.WriteLine("  Quit:tElementName=""""")
 	Do pCodeStream.WriteLine("  Do tOutput.Insert(tTempArray.GetAt(tElementName))")
 	Do pCodeStream.WriteLine(" }")
 	
 	Do pCodeStream.WriteLine(" Quit tOutput")
}

/// Checks if the necessary abstract methods and parameters have implementations in non abstract subclasses
ClassMethod CheckCompiledClassValidityAgainstAbstractClass(pCompiledClassToCheck As %Dictionary.CompiledClass, pClassNameToCheckAgainst As %String) As %Status
{
	Set tBaseClass = pCompiledClassToCheck
	Quit:tBaseClass.Abstract $$$OK
	
	Set tClassWithAbstractDefinitions = pClassNameToCheckAgainst
	Set tStatus = $$$OK
	
	// #### Check that necessary methods are implemented ####
	#define GetMethodOrigin(%className, %methodName) $$$comMemberKeyGet(%className, $$$cCLASSmethod, %methodName, $$$cMETHorigin)
	#define IsAbstractMethod(%className, %methodName) $$$comMemberKeyGet(%className, $$$cCLASSmethod, %methodName, $$$cMETHabstract)
	// Get abstract method names in tClassWithAbstractDefinitions
	Set tMethodsToBeImplemented = "", tMethodName = ""
	While 1 {
		Set tMethodName = $$$comMemberNext(tClassWithAbstractDefinitions, $$$cCLASSmethod, tMethodName)
		Quit:(tMethodName = "")
		If $$$IsAbstractMethod(tClassWithAbstractDefinitions, tMethodName) {
			Set tMethodsToBeImplemented = tMethodsToBeImplemented_","_tMethodName
		}
	}
	Set tMethodsToBeImplementedList = $ListFromString(tMethodsToBeImplemented)
	// Loop through abstract methods, throwing an error if not implemented
	Set tPtr = 0
	While $ListNext(tMethodsToBeImplementedList, tPtr, tMethodName) {
		Continue:(tMethodName = "")
		If $$$GetMethodOrigin(tBaseClass.Name, tMethodName) = tClassWithAbstractDefinitions {
			Set tStatus = $$$ERROR($$$GeneralError, "Implementation must be provided for method "_tMethodName)
			Quit
		}
	}
	
	// #### Check that necessary parameters are initialized ####
	#define GetParameterValue(%className, %paramName) $$$comMemberKeyGet(%className, $$$cCLASSparameter, %paramName, $$$cPARAMVALUEdefault)
	#define IsAbstractParameter(%className, %paramName) $$$comMemberKeyGet(%className, $$$cCLASSparameter, %paramName, $$$cPARAMabstract)
	// Get abstract parameter names in tClassWithAbstractDefinitions
	Set tParametersToBeInitialized = "", tParamName = ""
	While 1 {
		Set tParamName = $$$comMemberNext(tClassWithAbstractDefinitions, $$$cCLASSparameter, tParamName)
		Quit:(tParamName = "")
		If $$$IsAbstractParameter(tClassWithAbstractDefinitions, tParamName) {
			Set tParametersToBeInitialized = tParametersToBeInitialized_","_tParamName
		}
	}
	Set tParametersToBeInitializedList = $ListFromString(tParametersToBeInitialized)
	// Loop through abstract parameters, throwing an error if not initialized
	Set tPtr = 0
	While $ListNext(tParametersToBeInitializedList, tPtr, tParamName) {
		Continue:(tParamName = "")
		If $$$GetParameterValue(tBaseClass.Name, tParamName) = "" {
			Set tStatus = $$$ERROR($$$GeneralError, "Value must be provided for parameter "_tParamName)
			Quit
		}
	}
	Quit tStatus
}

}
