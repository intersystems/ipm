Class UpdatePackage.V1 Extends %IPM.General.VersionBase
{

ClassMethod GetOrderedMirrorMethodNames() As %Library.DynamicArray
{
    return ["MethodA", "MethodC"]
}

ClassMethod GetOrderedNonMirroredMethodNames() As %Library.DynamicArray
{
    return ["MethodB"]
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
