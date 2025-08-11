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
    write !, "This is MethodA()"
    return $$$OK
}

}
