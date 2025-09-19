Class UpdateSeededStepErrors.UpdatePackage.V2 Extends %IPM.General.Update.VersionBase
{

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return ["MethodA"]
}

ClassMethod GetOrderedMethods() As %Library.DynamicArray
{
    return []
}

ClassMethod MethodA()
{
    write !, "This is UpdateSeededStepErrors.UpdatePackage.V2::MethodA()"
}

}
