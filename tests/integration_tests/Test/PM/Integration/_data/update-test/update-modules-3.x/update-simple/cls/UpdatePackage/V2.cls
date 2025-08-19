Class UpdatePackage.V2 Extends %IPM.General.VersionBase
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
    write !, "This is UpdatePackage.V2::MethodA()"
}

ClassMethod MethodB()
{
    write !, "This is UpdatePackage.V2::MethodB()"
}

ClassMethod MethodC()
{
    write !, "This is UpdatePackage.V2::MethodC()"
}

}
