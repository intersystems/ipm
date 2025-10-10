Class UpdatePackage.V1 Extends %IPM.General.Update.VersionBase
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
    write !, "This is UpdatePackage.V1::MethodA()"
}

ClassMethod MethodB()
{
    write !, "This is UpdatePackage.V1::MethodB()"
}

ClassMethod MethodC()
{
    write !, "This is UpdatePackage.V1::MethodC()"
}

}
