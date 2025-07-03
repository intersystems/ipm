Class %IPM.Utils.CodeGeneration [ Abstract, System = 3 ]
{

ClassMethod BuildRelationshipSorter(
	pCodeStream As %Stream.MethodGenerator,
	pRelationshipName As %String,
	pObjectIdentifierExpression As %String) [ Internal ]
{
    // build an array containing all the relationship members
     do pCodeStream.WriteLine(" Set tTempArray = ##class(%Library.ArrayOfObjects).%New()")
     do pCodeStream.WriteLine(" Set tKey = """"")
     do pCodeStream.WriteLine(" While 1 {")
     do pCodeStream.WriteLine("  Set tElement = .." _ pRelationshipName _ ".GetNext(.tKey)")
     do pCodeStream.WriteLine("  Quit:tKey=""""")
     do pCodeStream.WriteLine("  Set tElementName = tElement." _ pObjectIdentifierExpression) // Property or method
     do pCodeStream.WriteLine("  Set tSC = tTempArray.SetAt(tElement, tElementName)")
     do pCodeStream.WriteLine("  $$$ThrowOnError(tSC)")
     do pCodeStream.WriteLine("  Set tElementNames(tElementName) = """"")
     do pCodeStream.WriteLine(" }")

     // now go back in alphanumerical order and add them to a *list*
     do pCodeStream.WriteLine(" Set tOutput = ##class(%Library.ListOfObjects).%New()")
     do pCodeStream.WriteLine(" Set tElementName = """"")
     do pCodeStream.WriteLine(" While 1 {")
     do pCodeStream.WriteLine("  Set tElementName = $Order(tElementNames(tElementName))")
     do pCodeStream.WriteLine("  Quit:tElementName=""""")
     do pCodeStream.WriteLine("  Do tOutput.Insert(tTempArray.GetAt(tElementName))")
     do pCodeStream.WriteLine(" }")

     do pCodeStream.WriteLine(" Quit tOutput")
}

/// Checks if the necessary abstract methods and parameters have implementations in non abstract subclasses
ClassMethod CheckCompiledClassValidityAgainstAbstractClass(
	pCompiledClassToCheck As %Dictionary.CompiledClass,
	pClassNameToCheckAgainst As %String) As %Status
{
    set tBaseClass = pCompiledClassToCheck
    quit:tBaseClass.Abstract $$$OK

    set tClassWithAbstractDefinitions = pClassNameToCheckAgainst
    set tStatus = $$$OK

    // #### Check that necessary methods are implemented ####
    #define GetMethodOrigin(%className, %methodName) $$$comMemberKeyGet(%className, $$$cCLASSmethod, %methodName, $$$cMETHorigin)
    #define IsAbstractMethod(%className, %methodName) $$$comMemberKeyGet(%className, $$$cCLASSmethod, %methodName, $$$cMETHabstract)
    // Get abstract method names in tClassWithAbstractDefinitions
    set tMethodsToBeImplemented = "", tMethodName = ""
    while 1 {
        set tMethodName = $$$comMemberNext(tClassWithAbstractDefinitions, $$$cCLASSmethod, tMethodName)
        quit:(tMethodName = "")
        if $$$IsAbstractMethod(tClassWithAbstractDefinitions, tMethodName) {
            set tMethodsToBeImplemented = tMethodsToBeImplemented_","_tMethodName
        }
    }
    set tMethodsToBeImplementedList = $listfromstring(tMethodsToBeImplemented)
    // Loop through abstract methods, throwing an error if not implemented
    set tPtr = 0
    while $listnext(tMethodsToBeImplementedList, tPtr, tMethodName) {
        continue:(tMethodName = "")
        if $$$GetMethodOrigin(tBaseClass.Name, tMethodName) = tClassWithAbstractDefinitions {
            set tStatus = $$$ERROR($$$GeneralError, "Implementation must be provided for method "_tMethodName)
            quit
        }
    }

    // #### Check that necessary parameters are initialized ####
    #define GetParameterValue(%className, %paramName) $$$comMemberKeyGet(%className, $$$cCLASSparameter, %paramName, $$$cPARAMVALUEdefault)
    #define IsAbstractParameter(%className, %paramName) $$$comMemberKeyGet(%className, $$$cCLASSparameter, %paramName, $$$cPARAMabstract)
    // Get abstract parameter names in tClassWithAbstractDefinitions
    set tParametersToBeInitialized = "", tParamName = ""
    while 1 {
        set tParamName = $$$comMemberNext(tClassWithAbstractDefinitions, $$$cCLASSparameter, tParamName)
        quit:(tParamName = "")
        if $$$IsAbstractParameter(tClassWithAbstractDefinitions, tParamName) {
            set tParametersToBeInitialized = tParametersToBeInitialized_","_tParamName
        }
    }
    set tParametersToBeInitializedList = $listfromstring(tParametersToBeInitialized)
    // Loop through abstract parameters, throwing an error if not initialized
    set tPtr = 0
    while $listnext(tParametersToBeInitializedList, tPtr, tParamName) {
        continue:(tParamName = "")
        if $$$GetParameterValue(tBaseClass.Name, tParamName) = "" {
            set tStatus = $$$ERROR($$$GeneralError, "Value must be provided for parameter "_tParamName)
            quit
        }
    }
    quit tStatus
}

}
