Class UpdateDeps.UpdatePackage.V2 Extends %IPM.General.Update.VersionBase
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
    write !, "This is UpdateDeps.UpdatePackage.V2::MethodA()"
}

ClassMethod MethodB()
{
    write !, "This is UpdateDeps.UpdatePackage.V2::MethodB()"
}

ClassMethod MethodC()
{
    write !, "This is UpdateDeps.UpdatePackage.V2::MethodC()"
}

}
