Class UpdateDepsAdded.UpdatePackage.V1 Extends %IPM.General.Update.VersionBase
{

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return ["MethodA", "MethodB"]
}

ClassMethod GetOrderedMethods() As %Library.DynamicArray
{
    return []
}

ClassMethod MethodA()
{
    write !, "This is UpdateDepsAdded.UpdatePackage.V1::MethodA()"
}

ClassMethod MethodB()
{
    write !, "This is UpdateDepsAdded.UpdatePackage.V1::MethodB()"
}

}
