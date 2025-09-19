Class UpdateDepInvokeErrors.UpdatePackage.V1 Extends %IPM.General.Update.VersionBase
{

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return []
}

ClassMethod GetOrderedMethods() As %Library.DynamicArray
{
    return ["MethodA"]
}

ClassMethod MethodA()
{
  write !, "This is  UpdateDepInvokeErrors.UpdatePackage.V1::MethodA()"
}

}
