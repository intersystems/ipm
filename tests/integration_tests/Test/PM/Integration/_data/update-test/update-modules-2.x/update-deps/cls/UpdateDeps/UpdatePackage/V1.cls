Class UpdateDeps.UpdatePackage.V1 Extends %IPM.General.Update.VersionBase
{

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return ["MethodB", "MethodC"]
}

ClassMethod GetOrderedMethods() As %Library.DynamicArray
{
    return ["MethodA"]
}

ClassMethod MethodA()
{
    write !, "This is UpdateDeps.UpdatePackage.V1::MethodA()"
}

ClassMethod MethodB()
{
    write !, "This is UpdateDeps.UpdatePackage.V1::MethodB()"
}

ClassMethod MethodC()
{
    write !, "This is UpdateDeps.UpdatePackage.V1::MethodC()"
}

}
