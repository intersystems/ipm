Class UpdatePackage.V1 Extends %IPM.General.VersionBase
{

ClassMethod GetOrderedMirrorMethodNames() As %Library.DynamicArray
{
    return ["MethodA"]
}

ClassMethod GetOrderedNonMirroredMethodNames() As %Library.DynamicArray
{
    return []
}

ClassMethod MethodA()
{
    write !, "This is UpdatePackage.V1::MethodA()"
}

}
