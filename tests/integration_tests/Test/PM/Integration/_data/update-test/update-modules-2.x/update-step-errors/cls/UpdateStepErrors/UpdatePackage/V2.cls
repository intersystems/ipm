Class UpdateStepErrors.UpdatePackage.V2 Extends %IPM.General.Update.VersionBase
{

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return ["MethodA", "MethodC"]
}

ClassMethod GetOrderedMethods() As %Library.DynamicArray
{
    return ["MethodB"]
}

ClassMethod MethodA()
{
    write !, "This is UpdateStepErrors.UpdatePackage.V2::MethodA()"
}

ClassMethod MethodB()
{
    write !, "This is UpdateStepErrors.UpdatePackage.V2::MethodB()"
    $$$ThrowOnError($$$ERROR($$$GeneralError, "UpdateStepErrors.UpdatePackage.V2::MethodB() threw an error."))
}

ClassMethod MethodC()
{
    write !, "This is UpdateStepErrors.UpdatePackage.V2::MethodC()"
}

}
