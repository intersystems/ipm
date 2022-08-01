/// Independent class for code generation helper methods; should not depend on anything else, and must be compiled before
/// classes that use it in method generators (hence System = 4).
Class %ZPM.PackageManager.Developer.GeneratorUtils [ System = 4 ]
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

}
