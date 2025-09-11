Class UpdateStepErrors.UpdatePackage.V1 Extends %IPM.General.Update.VersionBase
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
    write !, "This is UpdateStepErrors.UpdatePackage.V1::MethodA()"
}

ClassMethod MethodB()
{
    write !, "This is UpdateStepErrors.UpdatePackage.V1::MethodB()"
}

ClassMethod MethodC()
{
    write !, "This is UpdateStepErrors.UpdatePackage.V1::MethodC()"
}

}
