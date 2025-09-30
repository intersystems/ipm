Class ClassPackage.InvokedClass
{

ClassMethod InvokedMethod()
{
    write !, "This is ClassPackage.InvokedClass::InvokedMethod()"
    $$$ThrowOnError($$$ERROR($$$GeneralError, "ClassPackage.InvokedClass::InvokedMethod() threw an error."))
}

}
