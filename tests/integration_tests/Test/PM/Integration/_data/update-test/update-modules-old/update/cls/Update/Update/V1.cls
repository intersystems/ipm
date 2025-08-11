Class Update.Update.V1 Extends %IPM.General.VersionBase
{

ClassMethod GetOrderedMirrorMethodNames() As %Library.DynamicArray
{
    return ["MethodA"]
}

ClassMethod GetOrderedNonMirroredMethodNames() As %Library.DynamicArray
{
    return []
}

ClassMethod MethodA() As %Status
{
    write !, "This is Update.Update.V1::MethodA()"
    return $$$OK
}

}
